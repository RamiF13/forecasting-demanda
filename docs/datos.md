# Auditoría de datos

## holidays_events.csv
- PK: (date, description). date sola no alcanza (312 valores para 350 filas). 
  (date, locale_name) tampoco alcanza (343 combinaciones).
- 38 fechas se repiten → join directo por date contra train sería uno-a-muchos.
- type mezcla días laborables (Work Day) y no laborables (Holiday, Bridge). 
  transferred=True invierte el sentido de una fila.