
SELECT 
    christmas."date",
    combinations.store_number,
    combinations.family
FROM (VALUES('2013-12-25'), ('2014-12-25'), ('2015-12-25'), ('2016-12-25')) AS christmas("date")
CROSS JOIN (
    SELECT DISTINCT store_number, family
    FROM staging.stg_train
) AS combinations 

