SELECT
    "date" :: date AS date,
    store_nbr AS store_number,
    transactions
FROM {{source('raw','transactions')}}