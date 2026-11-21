CREATE OR REPLACE PROCEDURE add_product(
    p_restaurant_id UUID,
    p_product_category_id UUID,
    p_name VARCHAR,
    p_price NUMERIC,
    p_rating NUMERIC,
    p_status sorokin_food.dish_status,
    p_description TEXT,
    p_photo_url TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM restaurant
        WHERE restaurant_id = p_restaurant_id
    ) THEN
        RAISE EXCEPTION 'Ресторан с id % не найден', p_restaurant_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM product_category
        WHERE product_category_id = p_product_category_id
    ) THEN
        RAISE EXCEPTION 'Категория с id % не найдена', p_product_category_id;
    END IF;

    IF p_price < 0 THEN
        RAISE EXCEPTION 'Цена блюда не может быть отрицательной';
    END IF;

    IF p_rating NOT BETWEEN 0 AND 5 THEN
        RAISE EXCEPTION 'Рейтинг должен находиться в диапазоне от 0 до 5';
    END IF;

    INSERT INTO product (
        product_id,
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    )
    VALUES (
        exts.uuid_generate_v4(),
        p_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        NULL,
        p_status,
        p_description
    );
END;
$$;


CREATE OR REPLACE PROCEDURE courier_salary()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO courier_pay (
        year, month, courier_id, amount, coefficient_used
    )
    SELECT
        EXTRACT(YEAR FROM CURRENT_DATE)::SMALLINT,
        EXTRACT(MONTH FROM CURRENT_DATE)::SMALLINT,
        c.courier_id,
        ROUND(
            COALESCE(SUM(o.commission), 0)
            * COALESCE(cp.coefficient_used, c.coefficient),
            2
        ),
        COALESCE(cp.coefficient_used, c.coefficient)
    FROM courier c
    LEFT JOIN orders o
        ON o.courier_id = c.courier_id
        AND o.status = 'доставлен'
        AND o.order_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
        AND o.order_timestamp < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
    LEFT JOIN courier_pay cp
        ON cp.courier_id = c.courier_id
        AND cp.year = EXTRACT(YEAR FROM CURRENT_DATE)
        AND cp.month = EXTRACT(MONTH FROM CURRENT_DATE)
    GROUP BY c.courier_id, c.coefficient, cp.coefficient_used
    ON CONFLICT (year, month, courier_id)
    DO UPDATE SET
        amount = EXCLUDED.amount,
        coefficient_used = EXCLUDED.coefficient_used;

    WITH monthly AS (
        SELECT
            c.courier_id,
            COUNT(o.order_id) AS delivery_count
        FROM courier c
        LEFT JOIN orders o
            ON o.courier_id = c.courier_id
            AND o.status = 'доставлен'
            AND o.order_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
            AND o.order_timestamp < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
        GROUP BY c.courier_id
    )
    UPDATE courier c
    SET coefficient = CASE
        WHEN m.delivery_count <= 150 THEN 0.1
        WHEN m.delivery_count <= 250 THEN 0.2
        WHEN m.delivery_count <= 500 THEN 0.3
        ELSE 0.5
    END
    FROM monthly m
    WHERE c.courier_id = m.courier_id
        AND c.status <> 'уволен';
END;
$$;
