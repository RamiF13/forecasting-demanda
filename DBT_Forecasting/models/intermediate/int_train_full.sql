SELECT date, store_number, family, sales, onpromotion
FROM {{ ref('stg_train')}}

UNION ALL
SELECT date, store_number, family, sales, onpromotion
FROM {{ ref('int_train')}}
