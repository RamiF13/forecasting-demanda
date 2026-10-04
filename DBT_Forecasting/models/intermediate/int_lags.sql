WITH base AS (
    SELECT
        panel."date",
        panel.store_number,
        panel.family,
        CASE
            WHEN wd.work_day THEN panel.sales
            ELSE NULL
        END AS sales_lag
    FROM {{ref('int_train_full')}} AS panel
    LEFT JOIN {{ref('int_work_day')}} AS wd
        ON panel.date = wd.date
        AND panel.store_number = wd.store_number
        AND panel.family = wd.family
)
SELECT 
    "date",
    store_number,
    family,
    LAG(sales_lag, 7) OVER(
        PARTITION BY store_number, family
        ORDER BY "date"
    ) AS lag_7,
    LAG(sales_lag, 14) OVER(
        PARTITION BY store_number, family
        ORDER BY "date"
    ) AS lag_14,
    LAG(sales_lag, 21) OVER(
        PARTITION BY store_number, family
        ORDER BY "date"
    ) AS lag_21,
    LAG(sales_lag, 28) OVER(
        PARTITION BY store_number, family
        ORDER BY "date"
    ) AS lag_28
FROM base