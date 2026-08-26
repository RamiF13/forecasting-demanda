SELECT
    "date" :: date AS date,
    "type",
    locale,
    locale_name,
    description,
    transferred
FROM {{source('raw','holidays_events')}}