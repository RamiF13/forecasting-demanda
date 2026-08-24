SELECT store_nbr, city, "state", "type", cluster 
FROM {{source('raw','stores')}}