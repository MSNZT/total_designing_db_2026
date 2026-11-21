CREATE OR REPLACE VIEW how_much_money AS
WITH RECURSIVE
bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(order_timestamp))::DATE AS first_month,
        DATE_TRUNC('month', MAX(order_timestamp))::DATE AS last_month
    FROM orders
    WHERE status = 'доставлен'
),
months AS (
    SELECT first_month AS month_start
    FROM bounds
    WHERE first_month IS NOT NULL
    UNION ALL
    SELECT (m.month_start + INTERVAL '1 month')::DATE
    FROM months m
    JOIN bounds b ON m.month_start < b.last_month
),
order_totals AS (
    SELECT
        DATE_TRUNC('month', order_timestamp)::DATE AS month_start,
        SUM(order_amount) AS sum_no_commission,
        SUM(total_amount) AS sum_with_commission
    FROM orders
    WHERE status = 'доставлен'
    GROUP BY 1
),
salary_totals AS (
    SELECT
        MAKE_DATE(year, month, 1) AS month_start,
        SUM(amount) AS courier_pay
    FROM courier_pay
    GROUP BY 1
),
monthly AS (
    SELECT
        m.month_start,
        COALESCE(o.sum_no_commission, 0) AS sum_no_commission,
        COALESCE(o.sum_with_commission, 0) AS sum_with_commission,
        COALESCE(o.sum_with_commission, 0)
            - COALESCE(o.sum_no_commission, 0) AS commission,
        COALESCE(s.courier_pay, 0) AS courier_pay
    FROM months m
    LEFT JOIN order_totals o ON o.month_start = m.month_start
    LEFT JOIN salary_totals s ON s.month_start = m.month_start
),
result AS (
    SELECT
        *,
        LAG(commission) OVER (
            ORDER BY month_start
        ) AS prev_commission
    FROM monthly
)
SELECT
    TO_CHAR(month_start, 'YYYY-MM') AS year_month,
    sum_no_commission,
    sum_with_commission,
    commission,
    prev_commission,
    commission - prev_commission AS commission_diff,
    courier_pay,
    commission - courier_pay AS net_profit
FROM result;
