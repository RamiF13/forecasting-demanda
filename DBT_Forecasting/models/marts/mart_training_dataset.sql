
SELECT
    panel."date",
    panel.store_number,
    panel.family,
    panel.sales,
    panel.onpromotion,
    wd.work_day,
    lags.lag_7,
    lags.lag_14,
    lags.lag_21,
    lags.lag_28,
    lags.avg_7,
    lags.avg_28,
    calendar.month_number,
    calendar.day_of_month,
    calendar.week_day,
    oil.oil_price_filled
        FROM {{ref('int_train_full')}} AS panel
    LEFT JOIN {{ref('int_work_day')}} AS wd
        ON panel."date" = wd."date"
        AND panel.store_number = wd.store_number
        AND panel.family = wd.family
    LEFT JOIN {{ref('int_lags')}} AS lags
        ON panel."date" = lags."date"
        AND panel.store_number = lags.store_number
        AND panel.family = lags.family
    LEFT JOIN {{ref('int_calendar')}} AS calendar
        ON panel."date" = calendar."date"
    LEFT JOIN {{ref('int_oil')}} as oil
        ON panel."date" = oil."date"
