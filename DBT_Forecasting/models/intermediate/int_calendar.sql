SELECT 
    DISTINCT "date",
    EXTRACT(MONTH FROM "date") AS month_number,
    EXTRACT(DAY FROM "date") AS day_of_month,
    TRIM(TO_CHAR("date", 'Day')) AS week_day
FROM {{ref('int_train_full')}}