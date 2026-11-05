WITH monthly_revenue AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_date)::date AS payment_month,
        SUM(revenue_amount_usd) AS total_revenue
    FROM project.games_payments
    GROUP BY
        user_id,
        DATE_TRUNC('month', payment_date)::date
),

payment_periods AS (
    SELECT
        *,
        
        -- Календарні місяці
        (payment_month - INTERVAL '1 month')::date AS previous_calendar_month,
        (payment_month + INTERVAL '1 month')::date AS next_calendar_month,

        -- Попередня / наступна оплата користувача
        LAG(payment_month) OVER (
            PARTITION BY user_id
            ORDER BY payment_month
        ) AS previous_paid_month,

        LEAD(payment_month) OVER (
            PARTITION BY user_id
            ORDER BY payment_month
        ) AS next_paid_month,

        -- Revenue попереднього платіжного місяця
        LAG(total_revenue) OVER (
            PARTITION BY user_id
            ORDER BY payment_month
        ) AS previous_paid_month_revenue

    FROM monthly_revenue
),

metrics AS (
    SELECT
        *,

        1 AS paid_user,

        -- New MRR / New Paid Users
        CASE
            WHEN previous_paid_month IS NULL
            THEN total_revenue
        END AS new_mrr,

        CASE
            WHEN previous_paid_month IS NULL
            THEN 1
        END AS new_paid_users,

        -- Back from Churn MRR / Users
        CASE
            WHEN previous_paid_month IS NOT NULL
             AND previous_paid_month <> previous_calendar_month
            THEN total_revenue
        END AS back_from_churn_revenue,

        CASE
            WHEN previous_paid_month IS NOT NULL
             AND previous_paid_month <> previous_calendar_month
            THEN 1
        END AS back_from_churn_users,

        -- Expansion MRR
        CASE
            WHEN previous_paid_month = previous_calendar_month
             AND total_revenue > previous_paid_month_revenue
            THEN total_revenue - previous_paid_month_revenue
        END AS expansion_revenue,

        -- Contraction MRR
        CASE
            WHEN previous_paid_month = previous_calendar_month
             AND total_revenue < previous_paid_month_revenue
            THEN total_revenue - previous_paid_month_revenue 
        END AS contraction_revenue,

        -- Churned Revenue
        CASE
            WHEN next_paid_month IS NULL
              OR next_paid_month <> next_calendar_month
            THEN total_revenue
        END AS churned_revenue,

        -- Churned Users
        CASE
            WHEN next_paid_month IS NULL
              OR next_paid_month <> next_calendar_month
            THEN 1
        END AS churned_users,

        -- Churn Month
        CASE
            WHEN next_paid_month IS NULL
              OR next_paid_month <> next_calendar_month
            THEN next_calendar_month
        END AS churn_month

    FROM payment_periods
)

SELECT
    m.*,
    u.language,
    u.game_name,
    u.age
FROM metrics AS m
LEFT JOIN project.games_paid_users AS u
    ON m.user_id = u.user_id;