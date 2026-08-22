# Auditoría de datos

Período cubierto por el dataset: 2013-01-01 a 2017-08-15 (1688 días de calendario completo).

## train.csv

Tabla de hechos del proyecto.

- 3.000.888 filas × 6 columnas (id, date, store_nbr, family, sales, onpromotion)
- PK: (date, store_nbr, family). date viene como texto en el CSV, requiere conversión a datetime al cargar
- Rango de fechas: 2013-01-01 a 2017-08-15
- 1782 combinaciones tienda×familia (54 × 33). Panel completo: no hay combinaciones ausentes
- No existe granularidad de SKU. El nivel más fino de producto es family (33 familias)
- 4 días faltantes en el calendario: los 25 de diciembre de 2013, 2014, 2015 y 2016 (tiendas cerradas por Navidad)

Decisión tomada: completar esos 4 días como filas con venta cero, más una feature binaria de "día trabajado". La feature no cubre solo Navidad: también tiene que contemplar los Work Day y Bridge de holidays_events.

## holidays_events.csv

Exógena con fecha.

- 350 filas x 6 columnas (date, type, locale, locale_name, description, transferred)
- PK: (date, description)

Ninguna columna sola puede ser PK: ninguna llega a 350 valores distintos
"description" es texto libre, lo que hace la clave frágil ante cambios de escritura. Se usa por falta de alternativa
38 fechas se repiten. Un join directo por date contra train sería uno-a-muchos y multiplicaría filas de ventas sin avisar
"type" mezcla días laborables y no laborables: Holiday y Bridge son días sin trabajo, Work Day es un día que sí se trabaja
"transferred" = True invierte el sentido de la fila: ese día el feriado no se celebró
El dataset registra cualquier evento que pueda mover ventas, no solo feriados.
### Interesante
Pendiente H6: agregar la tabla a una fila por (date, locale_name) antes de unirla, decidiendo qué hacer cuando hay varios eventos el mismo día.
### Interesante

## stores.csv

Dimensión. Join uno-a-uno contra train.

- 54 filas x 5 columnas (store_nbr, city, state, type, cluster)
- PK: "store_nbr"
- "city" y "state" son las claves de cruce con "locale_name" del csv holidays_events
Verificado: todos los valores de locale_name matchean contra city o state, salvo Ecuador, que corresponde a locale = National

Lógica de cruce de feriados con tiendas:

| locale | Aplica a |
|---|---|
| `National` | Las 54 tiendas |
| `Regional` | Tiendas cuyo state coincide con locale_name |
| `Local` | Tiendas cuya city coincide con locale_name |

## transactions.csv

Segunda tabla de hechos, granularidad date x store_nbr.

- 83.488 filas x 3 columnas (date, store_nbr, transactions)
- PK: (date, store_nbr) 
- El panel no está completo: 54 tiendas × 1688 días darían 91.152 filas. 8 tiendas registran su primera transacción después del 2013-01-01: 46 arrancan el 1 de enero, las otras 8 entre el 4 de enero y el 13 de febrero de 2013
### Verificar
No es utilizable como predictor. La cantidad de transacciones futuras no se conoce al momento de pronosticar (data leakage). Sirve como contexto de negocio.
### Verificar
Pendiente: los ceros iniciales de esas 8 tiendas en train no son demanda cero, son inexistencia. Hay que tratarlos distinto o excluirlos del entrenamiento.

## oil.csv

Exógena macroeconómica.

- 1218 filas x 2 columnas (date, dcoilwtico)
- PK: date 
- 482 fechas del calendario completo están ausentes: fines de semana y feriados bursátiles, cuando el mercado no cotiza
- 43 nulos en dcoilwtico, incluido el primer registro de la serie (2013-01-01)
- Ausencias y nulos son el mismo fenómeno: mercado cerrado. Unos aparecen como fila vacía, otros directamente no aparecen


### Pendiente
Pendiente H6: reindexar contra el calendario completo y aplicar forward fill. El primer valor necesita tratamiento aparte, no hay nada previo que arrastrar.
### Pendiente

Como predictor solo sirve rezagada: el precio del barril del día que se pronostica no se conoce al momento de pronosticar.
Contexto: Ecuador es economía petrolera. El precio del barril funciona como proxy de capacidad de compra del país. Relevante para entender la caída de ventas de 2015-2016.

## test.csv y sample_submission.csv

Artefactos de la competencia de Kaggle.

test.csv son fechas futuras sin la columna objetivo. Existe para que Kaggle evalúe submissions a ciegas
sample_submission.csv es el formato de entrega de la competencia

Ninguno describe el negocio. Único uso posible: test.csv indica qué horizonte asumía la competencia original, como referencia contra el horizonte propio

## Clasificación de los 7 archivos

| Archivo | Categoría |
|---|---|
| `train.csv` | Tabla de hechos |
| `holidays_events.csv` | Exógena |
| `stores.csv` | Dimensión |
| `transactions.csv` | Tabla de hechos (secundaria) |
| `oil.csv` | Exógena |
| `test.csv` | Artefacto de Kaggle |
| `sample_submission.csv` | Artefacto de Kaggle |


## Granularidad del pronóstico

El pronóstico se hace a nivel de  **tienda x familia de producto x día**.

Esta granularidad no es una elección de diseño, es la que impone el dataset utilizado: 
`train.csv` no incluye una columna de producto individual. Su nivel de 
desagregación más fino es `family`, con 33 categorías (BEVERAGES, DAIRY, 
PRODUCE, entre otras.). `store_nbr` identifica cada tienda de forma individual 
(54 tiendas), sin agregación por ciudad ni cluster.

