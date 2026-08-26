SELECT
    id,
    "date" :: date AS date,
    store_nbr AS store_number,
    family,
    onpromotion
FROM {{source('raw','test')}}