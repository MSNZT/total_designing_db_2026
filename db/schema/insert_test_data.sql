CREATE SEQUENCE IF NOT EXISTS food_test_seq
AS BIGINT
START WITH 9000000000
MINVALUE 9000000000
MAXVALUE 9999999999;

CREATE OR REPLACE PROCEDURE insert_test_data(value INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch BIGINT;
    v_addresses UUID[];
    v_clients UUID[];
    v_couriers UUID[];
    v_restaurants UUID[];
    v_categories UUID[];
    v_products UUID[];
    v_orders UUID[];
    v_first_month DATE;
BEGIN
    IF value IS NULL OR value < 1 THEN
        RAISE EXCEPTION 'value должен быть положительным числом';
    END IF;

    v_batch := NEXTVAL('sorokin_food.food_test_seq');

    v_first_month := (
        DATE_TRUNC('month', CURRENT_DATE)
        - INTERVAL '5 months'
    )::DATE;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_addresses
    FROM generate_series(1, value * 5) AS n;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_clients
    FROM generate_series(1, value) AS n;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_couriers
    FROM generate_series(1, value) AS n;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_restaurants
    FROM generate_series(1, value) AS n;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_categories
    FROM generate_series(1, value) AS n;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_products
    FROM generate_series(1, value * 5) AS n;

    SELECT ARRAY_AGG(exts.uuid_generate_v4() ORDER BY n)
    INTO v_orders
    FROM generate_series(1, value * 5) AS n;

    INSERT INTO address (
        address_id, street, house_number, apartment_office
    )
    SELECT
        v_addresses[n],
        'Улица ' || v_batch || '-' || n,
        n::TEXT,
        CASE
            WHEN n <= value THEN NULL
            ELSE '1'
        END
    FROM generate_series(1, value * 5) AS n;

    INSERT INTO client (
        client_id, login, password, phone_number
    )
    SELECT
        v_clients[n],
        'user_' || v_batch || '_' || n,
        MD5(RANDOM()::TEXT),
        '+7' || NEXTVAL('sorokin_food.food_test_seq')::TEXT
    FROM generate_series(1, value) AS n;

    INSERT INTO client_address (
        client_id, address_id
    )
    SELECT
        v_clients[r],
        v_addresses[value + (r - 1) * 4 + n]
    FROM generate_series(1, value) AS r
    CROSS JOIN generate_series(1, 4) AS n;

    INSERT INTO restaurant (
        restaurant_id, restaurant_name, address_id,
        description, work_start, work_end,
        inn, ogrn, checking_account, rating, status
    )
    SELECT
        v_restaurants[n],
        'Ресторан ' || v_batch || '-' || n,
        v_addresses[n],
        'Описание ресторана',
        TIME '09:00',
        TIME '22:00',
        LPAD((v_batch + n)::TEXT, 12, '0'),
        LPAD((v_batch + n)::TEXT, 15, '0'),
        LPAD((v_batch + n)::TEXT, 20, '0'),
        NULL,
        (enum_range(NULL::restaurant_status))[
            1 + FLOOR(
                RANDOM() * CARDINALITY(enum_range(NULL::restaurant_status))
            )::INT
        ]
    FROM generate_series(1, value) AS n;

    INSERT INTO product_category (
        product_category_id, product_category_name
    )
    SELECT
        v_categories[n],
        'Категория ' || v_batch || '-' || n
    FROM generate_series(1, value) AS n;

    WITH generated AS MATERIALIZED (
        SELECT
            n,
            CASE
                WHEN n = 1 THEN 'свободен'::courier_status
                ELSE (enum_range(NULL::courier_status))[
                    1 + FLOOR(
                        RANDOM() * CARDINALITY(enum_range(NULL::courier_status))
                    )::INT
                ]
            END AS status
        FROM generate_series(1, value) AS n
    )
    INSERT INTO courier (
        courier_id, fio, phone_number,
        status, hire_date, dismissal_date, coefficient
    )
    SELECT
        v_couriers[n],
        'Иванов Иван Иванович-' || n,
        '+7' || NEXTVAL('sorokin_food.food_test_seq')::TEXT,
        status,
        v_first_month,
        CASE
            WHEN status = 'уволен' THEN CURRENT_DATE
            ELSE NULL
        END,
        0.1
    FROM generated;

    INSERT INTO product (
        product_id, product_name, product_category_id,
        price, restaurant_id, photo_url,
        rating, status, description
    )
    SELECT
        v_products[(r - 1) * 5 + n],
        'Блюдо ' || v_batch || '-' || r || '-' || n,
        v_categories[r],
        (1000 + FLOOR(RANDOM() * 1500))::NUMERIC(10,2),
        v_restaurants[r],
        NULL,
        NULL,
        (enum_range(NULL::dish_status))[
            1 + FLOOR(
                RANDOM() * CARDINALITY(enum_range(NULL::dish_status))
            )::INT
        ],
        'Описание блюда'
    FROM generate_series(1, value) AS r
    CROSS JOIN generate_series(1, 5) AS n;

    WITH generated AS MATERIALIZED (
        SELECT
            r,
            n,
            v_first_month::TIMESTAMP
                + RANDOM() * (
                    LOCALTIMESTAMP
                    - INTERVAL '2 hours'
                    - v_first_month::TIMESTAMP
                ) AS created_at,
            CASE
                WHEN n = 1 THEN 'доставлен'::order_status
                ELSE (enum_range(NULL::order_status))[
                    1 + FLOOR(
                        RANDOM() * CARDINALITY(enum_range(NULL::order_status))
                    )::INT
                ]
            END AS status
        FROM generate_series(1, value) AS r
        CROSS JOIN generate_series(1, 5) AS n
    )
    INSERT INTO orders (
        order_id, courier_id, client_id, address_id,
        restaurant_id, order_timestamp, delivery_timestamp,
        order_amount, status, pay_status, description
    )
    SELECT
        v_orders[(g.r - 1) * 5 + g.n],
        v_couriers[g.r],
        v_clients[g.r],
        v_addresses[value + (g.r - 1) * 4 + 1],
        v_restaurants[g.r],
        g.created_at,
        CASE
            WHEN g.status = 'доставлен'
                THEN g.created_at + INTERVAL '45 minutes'
            ELSE NULL
        END,
        p.price,
        g.status,
        'оплачен',
        'Заказ ' || v_batch || '-' || g.r || '-' || g.n
    FROM generated g
    JOIN product p
        ON p.product_id = v_products[(g.r - 1) * 5 + g.n];

    INSERT INTO order_structure (
        order_id, product_id, quantity
    )
    SELECT
        v_orders[(r - 1) * 5 + n],
        v_products[(r - 1) * 5 + n],
        1.0
    FROM generate_series(1, value) AS r
    CROSS JOIN generate_series(1, 5) AS n;

    INSERT INTO payment (
        payment_id, order_id, payment_type, status,
        transaction_id, transaction_timestamp, amount
    )
    SELECT
        exts.uuid_generate_v4(),
        o.order_id,
        (enum_range(NULL::payment_type))[
            1 + FLOOR(
                RANDOM() * CARDINALITY(enum_range(NULL::payment_type))
            )::INT
        ],
        'успех',
        'tx_' || v_batch || '_' || r || '_' || n,
        o.order_timestamp + INTERVAL '5 minutes',
        o.total_amount
    FROM generate_series(1, value) AS r
    CROSS JOIN generate_series(1, 5) AS n
    JOIN orders o
        ON o.order_id = v_orders[(r - 1) * 5 + n];

    WITH generated AS MATERIALIZED (
        SELECT
            r,
            n,
            CASE
                WHEN n = 1 THEN 'блюдо'::entity_type
                WHEN n = 2 THEN 'ресторан'::entity_type
                WHEN n = 3 THEN 'заказ'::entity_type
                ELSE (enum_range(NULL::entity_type))[
                    1 + FLOOR(
                        RANDOM() * CARDINALITY(enum_range(NULL::entity_type))
                    )::INT
                ]
            END AS kind
        FROM generate_series(1, value) AS r
        CROSS JOIN generate_series(1, 5) AS n
    )
    INSERT INTO review (
        review_id, client_id, review_timestamp,
        entity_id, entity_type, order_id,
        description, photo_url, rating
    )
    SELECT
        exts.uuid_generate_v4(),
        o.client_id,
        o.order_timestamp + INTERVAL '1 hour',
        CASE
            WHEN g.kind = 'заказ' THEN o.order_id
            WHEN g.kind = 'ресторан' THEN o.restaurant_id
            ELSE v_products[(g.r - 1) * 5 + g.n]
        END,
        g.kind,
        o.order_id,
        'Отзыв ' || v_batch || '-' || g.r || '-' || g.n,
        NULL,
        (1 + FLOOR(RANDOM() * 5))::NUMERIC(3,2)
    FROM generated g
    JOIN orders o
        ON o.order_id = v_orders[(g.r - 1) * 5 + g.n];

    WITH months AS (
        SELECT GENERATE_SERIES(
            v_first_month::TIMESTAMP,
            DATE_TRUNC('month', CURRENT_DATE),
            INTERVAL '1 month'
        )::DATE AS month_start
    ),
    monthly AS (
        SELECT
            c.courier_id,
            m.month_start,
            COUNT(o.order_id) AS delivery_count,
            COALESCE(SUM(o.commission), 0) AS commission_sum
        FROM courier c
        CROSS JOIN months m
        LEFT JOIN orders o
            ON o.courier_id = c.courier_id
            AND o.status = 'доставлен'
            AND o.order_timestamp >= m.month_start
            AND o.order_timestamp < m.month_start + INTERVAL '1 month'
        WHERE c.courier_id = ANY(v_couriers)
        GROUP BY c.courier_id, m.month_start
    ),
    previous_month AS (
        SELECT
            *,
            LAG(delivery_count, 1, 0) OVER (
                PARTITION BY courier_id
                ORDER BY month_start
            ) AS previous_deliveries
        FROM monthly
    ),
    calculated AS (
        SELECT
            *,
            CASE
                WHEN previous_deliveries <= 150 THEN 0.1
                WHEN previous_deliveries <= 250 THEN 0.2
                WHEN previous_deliveries <= 500 THEN 0.3
                ELSE 0.5
            END::NUMERIC(1,1) AS coefficient_used
        FROM previous_month
    )
    INSERT INTO courier_pay (
        year, month, courier_id,
        amount, coefficient_used
    )
    SELECT
        EXTRACT(YEAR FROM month_start)::SMALLINT,
        EXTRACT(MONTH FROM month_start)::SMALLINT,
        courier_id,
        ROUND(commission_sum * coefficient_used, 2),
        coefficient_used
    FROM calculated;

    WITH stats AS (
        SELECT
            c.courier_id,
            COUNT(o.order_id) AS deliveries
        FROM courier c
        LEFT JOIN orders o
            ON o.courier_id = c.courier_id
            AND o.status = 'доставлен'
            AND o.order_timestamp >= DATE_TRUNC('month', CURRENT_DATE)
            AND o.order_timestamp < DATE_TRUNC('month', CURRENT_DATE)
                + INTERVAL '1 month'
        WHERE c.courier_id = ANY(v_couriers)
            AND c.status <> 'уволен'
        GROUP BY c.courier_id
    )
    UPDATE courier c
    SET coefficient = CASE
        WHEN s.deliveries <= 150 THEN 0.1
        WHEN s.deliveries <= 250 THEN 0.2
        WHEN s.deliveries <= 500 THEN 0.3
        ELSE 0.5
    END
    FROM stats s
    WHERE c.courier_id = s.courier_id;
END;
$$;
