SELECT store_nbr as store_number,
city,
"state",
"type",
cluster 
FROM {{source('raw','stores')}}