
SELECT valores_distintos
FROM(
    SELECT COUNT(DISTINCT conteo) AS valores_distintos
    FROM(
        SELECT COUNT(*) AS conteo
        FROM {{ ref('int_train_full')}}
        GROUP BY store_number, family
    ) AS conteos_por_combinacion
) AS resultado
WHERE valores_distintos <> 1