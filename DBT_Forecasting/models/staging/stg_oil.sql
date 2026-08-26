SELECT 
    "date" :: date AS date,
    dcoilwtico AS oil_price
FROM {{source('raw','oil')}}