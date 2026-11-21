CREATE OR REPLACE FUNCTION tf_order_structures_validate_restaurant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_restaurant_id UUID;
    product_restaurant_id UUID;
BEGIN
    SELECT restaurant_id INTO order_restaurant_id FROM orders
    WHERE order_id = NEW.order_id;

    SELECT restaurant_id INTO product_restaurant_id from product
    WHERE product_id = NEW.product_id;

    IF order_restaurant_id != product_restaurant_id THEN
        RAISE EXCEPTION 'Продукт (id=%) принадлежит другому ресторану',
            NEW.product_id; 
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION tf_product_validate_restaurant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM order_structure os
        JOIN orders o ON os.order_id = o.order_id
        WHERE os.product_id = NEW.product_id and o.restaurant_id <> NEW.restaurant_id
    ) THEN
        RAISE EXCEPTION 'Изменение ресторана продукта нарушает принадлежность блюд заказам';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION tf_order_validate_restaurant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM order_structure os
        JOIN product p ON os.product_id = p.product_id
        WHERE os.order_id = NEW.order_id and p.restaurant_id <> NEW.restaurant_id
    ) THEN
        RAISE EXCEPTION 'Изменение ресторана заказа нарушает принадлежность блюд ресторану';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION tf_payment_validate_amount() 
RETURNS TRIGGER
LANGUAGE plpgsql 
AS $$ 
DECLARE 
    order_total_amount NUMERIC(12,2);
BEGIN 
    SELECT total_amount INTO order_total_amount FROM orders
    WHERE order_id = NEW.order_id;

    IF order_total_amount != NEW.amount THEN
        RAISE EXCEPTION 'Итоговая сумма заказа не совпадает с суммой попытки оплаты';
    END IF;

    RETURN NEW;
END; 
$$;

CREATE OR REPLACE FUNCTION tf_orders_validate_amount()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN 
    IF EXISTS (
        SELECT 1 FROM payment p
        WHERE p.order_id = NEW.order_id and p.amount <> NEW.total_amount
    ) THEN
        RAISE EXCEPTION 'Итоговая сумма заказа не совпадает с суммой попытки оплаты';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sorokin_food.tf_payment_update_order_pay_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_order_id UUID;
    v_new_order_id UUID;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new_order_id := NEW.order_id;
    ELSIF TG_OP = 'DELETE' THEN
        v_old_order_id := OLD.order_id;
    ELSE
        v_old_order_id := OLD.order_id;
        v_new_order_id := NEW.order_id;
    END IF;

    UPDATE sorokin_food.orders o
    SET pay_status = (
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM sorokin_food.payment p
                WHERE p.order_id = o.order_id
                    AND p.status = 'успех'
            ) THEN 'оплачен'

            WHEN EXISTS (
                SELECT 1
                FROM sorokin_food.payment p
                WHERE p.order_id = o.order_id
                    AND p.status = 'в_обработке'
            ) THEN 'ожидает'

            WHEN EXISTS (
                SELECT 1
                FROM sorokin_food.payment p
                WHERE p.order_id = o.order_id
            ) THEN 'ошибка'

            ELSE 'ожидает'
        END
    )::sorokin_food.order_pay_status
    WHERE o.order_id IN (v_old_order_id, v_new_order_id);

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION tf_review_validate_entity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN 
    IF EXISTS (
        SELECT 1 FROM orders
        WHERE order_id = NEW.order_id and client_id <> NEW.client_id
    ) THEN
        RAISE EXCEPTION 'Клиент может оставить отзыв только на свои заказы';
    END IF;

    CASE
        WHEN NEW.entity_type = 'заказ' AND NEW.entity_id <> NEW.order_id
            THEN 
                 RAISE EXCEPTION 'entity_id должен совпадать с order_id';
        WHEN NEW.entity_type = 'ресторан' AND EXISTS (
            SELECT 1 FROM orders
            WHERE order_id = NEW.order_id and restaurant_id <> NEW.entity_id
        ) THEN 
            RAISE EXCEPTION 'entity_id должен совпадать с restaurant_id';
        WHEN NEW.entity_type = 'блюдо' AND NOT EXISTS (
            SELECT 1 FROM order_structure
            WHERE order_id = NEW.order_id and product_id = NEW.entity_id 
        ) THEN
            RAISE EXCEPTION 'entity_id должен совпадать с product_id';

        ELSE NULL;
    END CASE;
    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    target_row review%ROWTYPE;
    i INT;
BEGIN
    FOR i IN 1..2 LOOP
        IF i = 1 THEN
            IF TG_OP = 'INSERT' THEN
                target_row := NEW;
            ELSE
                target_row := OLD;
            END IF;
        ELSE
            IF TG_OP <> 'UPDATE' THEN
                EXIT;
            END IF;

            IF OLD.entity_id = NEW.entity_id
               AND OLD.entity_type = NEW.entity_type THEN
                EXIT;
            END IF;
            target_row := NEW;
        END IF;

        CASE
            WHEN target_row.entity_type = 'блюдо' THEN
                UPDATE product
                SET rating = (
                    SELECT AVG(r.rating)
                    FROM review r
                    WHERE r.entity_type = 'блюдо'
                      AND r.entity_id = target_row.entity_id
                )
                WHERE product_id = target_row.entity_id;

            WHEN target_row.entity_type = 'ресторан' THEN
                UPDATE restaurant
                SET rating = (
                    SELECT AVG(r.rating)
                    FROM review r
                    WHERE r.entity_type = 'ресторан'
                      AND r.entity_id = target_row.entity_id
                )
                WHERE restaurant_id = target_row.entity_id;
            ELSE
                NULL;
        END CASE;
    END LOOP;
    RETURN NULL;
END;
$$;


CREATE OR REPLACE FUNCTION get_statistic()
RETURNS TABLE (
    restaurant_name TEXT,
    best_product_name TEXT,
    total_amount NUMERIC,
    avg_amount NUMERIC,
    best_user TEXT
)
LANGUAGE sql
AS $$
    WITH delivered AS MATERIALIZED (
        SELECT order_id, restaurant_id, client_id, total_amount
        FROM orders
        WHERE status = 'доставлен'
    ),
    amounts AS (
        SELECT
            restaurant_id,
            SUM(total_amount) AS total_amount,
            AVG(total_amount) AS avg_amount
        FROM delivered
        GROUP BY restaurant_id
    ),
    popular_products AS (
        SELECT
            d.restaurant_id,
            os.product_id,
            SUM(os.quantity) AS total_quantity
        FROM delivered d
        JOIN order_structure os ON os.order_id = d.order_id
        GROUP BY d.restaurant_id, os.product_id
    ),
    best_products AS (
        SELECT DISTINCT ON (restaurant_id)
            restaurant_id,
            product_id
        FROM popular_products
        ORDER BY restaurant_id, total_quantity DESC, RANDOM()
    ),
    active_clients AS (
        SELECT
            restaurant_id,
            client_id,
            COUNT(*) AS orders_count
        FROM delivered
        GROUP BY restaurant_id, client_id
    ),
    best_clients AS (
        SELECT DISTINCT ON (restaurant_id)
            restaurant_id,
            client_id
        FROM active_clients
        ORDER BY restaurant_id, orders_count DESC, RANDOM()
    )
    SELECT
        r.restaurant_name::TEXT,
        p.product_name::TEXT,
        COALESCE(a.total_amount, 0),
        a.avg_amount,
        c.login::TEXT
    FROM restaurant r
    LEFT JOIN amounts a ON a.restaurant_id = r.restaurant_id
    LEFT JOIN best_products bp ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN product p ON p.product_id = bp.product_id
    LEFT JOIN best_clients bc ON bc.restaurant_id = r.restaurant_id
    LEFT JOIN client c ON c.client_id = bc.client_id;
$$;
