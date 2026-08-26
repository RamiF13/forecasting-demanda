SELECT
    id,
    sales
FROM {{source('raw','sample_submission')}}