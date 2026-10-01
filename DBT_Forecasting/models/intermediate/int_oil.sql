WITH oil_calendar AS (
    SELECT cal."date", oil.oil_price
    FROM {{ref('int_calendar')}} AS cal
    LEFT JOIN {{ref('stg_oil')}} AS oil ON cal.date = oil.date
),
groups AS (
    SELECT
        "date",
        oil_price,
        COUNT(oil_price) OVER (ORDER BY "date") AS groups
    FROM oil_calendar
),
fill AS (
    SELECT
        "date",
        oil_price,
        MAX(oil_price) OVER (PARTITION BY groups) AS oil_price_no_nulls
    FROM groups
)
SELECT
    "date",
    COALESCE(
        oil_price_no_nulls,
        (SELECT oil_price FROM {{ref('stg_oil')}} WHERE oil_price IS NOT NULL ORDER BY "date" LIMIT 1)
    ) AS oil_price_filled
FROM fill
ORDER BY "date"