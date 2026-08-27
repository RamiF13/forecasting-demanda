
SELECT 
    christmas."date" :: date AS date,
    combinations.store_number,
    combinations.family,
    0:: DOUBLE PRECISION AS sales,
    0:: BIGINT AS onpromotion
FROM (VALUES('2013-12-25'), ('2014-12-25'), ('2015-12-25'), ('2016-12-25')) AS christmas(date)
CROSS JOIN (
    SELECT DISTINCT store_number, family
    FROM staging.stg_train
) AS combinations 

