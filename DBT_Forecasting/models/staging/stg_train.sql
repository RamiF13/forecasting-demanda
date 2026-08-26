SELECT
    id,
    "date" :: date AS date,
    store_nbr as store_number,
    family,
    sales,
    onpromotion
FROM {{source('raw','train')}}