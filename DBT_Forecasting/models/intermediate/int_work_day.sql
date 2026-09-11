SELECT 
    panel.date,
    panel.store_number,
    panel.family,
    BOOL_AND(
        CASE
            WHEN holidays.type IS NULL THEN TRUE
            WHEN holidays.type IN ('Work Day', 'Event','Additional') THEN TRUE
            WHEN holidays.type = 'Holiday' AND holidays.transferred = TRUE THEN TRUE
            ELSE FALSE
        END
    ) AS work_day
FROM {{ref('int_train_full')}} AS panel
LEFT JOIN {{ref('stg_stores')}} AS stores
    ON panel.store_number = stores.store_number
LEFT JOIN {{ref('stg_holidays_events')}} AS holidays
     ON ( holidays.date = panel.date
    AND (
        holidays.locale = 'National'
        OR (holidays.locale = 'Regional' AND holidays.locale_name = stores.state)
        OR (holidays.locale = 'Local' AND holidays.locale_name = stores.city)
    )
)
GROUP BY panel.date, panel.store_number, panel.family