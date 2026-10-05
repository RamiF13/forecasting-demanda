# Decisiones

## Horizonte de pronóstico y supuestos de inventario

**Horizonte: 10 días**

Se deriva del caso de uso, no de la competencia. Los supuestos del gerente ficticio:

- **R (ciclo de revisión) = 7 días.** El gerente revisa el stock y hace el pedido una vez por semana.
- **L (lead time) = 3 días.** Demora del proveedor entre que se hace el pedido y que llega la mercadería.

El horizonte cubre el **período de protección R + L = 10 días**: el stock que se pide hoy tiene que alcanzar desde que llega (día 3) hasta que llegue el siguiente pedido (día 10), porque recién en la próxima revisión se puede corregir un faltante. Cubrir solo el lead time dejaría un hueco entre pedidos.

Ambos parámetros son supuestos ficticios explícitos del caso de uso, no datos del dataset. Van a ser configurables, no constantes hardcodeadas.

**Referencia:** la competencia original de Kaggle pedía un horizonte de 16 días (`test.csv` va del 2017-08-16 al 2017-08-31). No condiciona la decisión, se documenta como contexto.
**Nota:** si eventualmente se sube una predicción a Kaggle como chequeo externo opcional (fuera del pipeline principal), esa entrega sí debe cubrir los 16 días que pide la competencia. Es independiente del horizonte de diseño de 10 días.

## Tratamiento de series con ceros crónicos

**Hallazgo:** de las 1782 series (tienda x familia), 173 tienen más del 90% de sus días con venta cero. No están repartidas al azar: se concentran en familias de baja rotación.

| Familia | Series con 90%+ ceros |
|---|---|
| BOOKS | 52 |
| BABY CARE | 43 |
| LAWN AND GARDEN | 16 |
| SCHOOL AND OFFICE SUPPLIES | 14 |
| LADIESWEAR | 14 |
| HOME APPLIANCES | 4 |
| Resto (cola de familias con 1-3) | ~30 |

**Decisión:** las 173 series se excluyen del entrenamiento del modelo de ML. Una serie que es 90%+ ceros no tiene un patrón aprendible, y meterla ensucia las métricas globales sin aportar valor. El modelo principal se concentra en las ~1600 series con señal real.

**Importante:** excluidas del *entrenamiento* no significa excluidas del *output*. El gerente puede pedir reposición de esas familias igual. Para ellas, la sugerencia sale de una regla simple (promedio histórico o mínimo de reposición), no del modelo. El pipeline cubre las 1782 series, modeladas de dos formas distintas.

**Fuera de alcance:** existen métodos específicos para modelar demanda intermitente (Croston), cuales no se priorizaron en este proyecto. El caso de uso está centrado en reposición eficiente de las familias de alta rotación, que concentran el volumen de negocio del gerente ficticio. Invertir el mismo esfuerzo de un segundo modelo en familias que casi no se venden no aporta valor proporcional. Se menciona como posible extensión futura.

## Ventana de validación temporal

En series temporales no se puede mezclar entrenamiento y evaluación al azar: si el modelo ve datos posteriores a lo que predice, hay filtración de información (predice el pasado sabiendo el futuro). La validación tiene que respetar la cronología.

**Esquema elegido: walk-forward (ventana expansiva).**

Se entrena con todos los datos hasta una fecha de corte, se predice el tramo siguiente (10 días, el horizonte definido), se evalúa el error, y se avanza el corte. Cada evaluación usa solo datos anteriores al período que predice.

**Cobertura estacional.** Los cortes se ubican en distintas épocas del año a lo largo del período (2013-2017), no en un solo momento. Así se verifica que el modelo generaliza a cualquier mes o estación, y no que acertó bien en un único período que resultó fácil.

**Test final reservado.** Los últimos meses de 2017 se apartan como conjunto de test intocable. Se evalúan una sola vez, al final del proyecto, y no se reajusta el modelo después de mirarlos. Los cortes intermedios sirven para elegir y afinar el modelo; el test final mide el desempeño real sobre datos nunca vistos.

**Descartado:** sacar meses sueltos del medio de la serie como validación. Rompe la cronología (el modelo entrenaría con datos posteriores al hueco) y además parte las features de lags y medias móviles alrededor del agujero.

## Métrica de evaluación

**Métrica principal: WMAPE (Weighted Mean Absolute Percentage Error).**

Se elige WMAPE por tres razones, todas ligadas a las características del dataset:

- **Robusta a los ceros.** MAPE clásico divide por el valor real de cada día, y explota cuando ese valor es cero, algo frecuente incluso en las series que no se excluyeron. WMAPE suma los errores absolutos y los divide por la suma total de ventas reales, que nunca es cero, así que no se rompe.
- **Comparable entre escalas.** Las familias tienen volúmenes muy distintos (GROCERY vende miles, SEAFOOD vende decenas). Un error absoluto medio (MAE) estaría dominado por las familias grandes. WMAPE da un porcentaje interpretable y comparable entre series de cualquier escala.
- **Estándar del rubro.** Es la métrica habitual en forecasting de demanda retail.

Se descartan MAPE (explota con ceros), MAE y RMSE (sensibles a la escala, un error de 8 unidades pesa igual en una familia que vende 10 que en una que vende 5000).

**Métrica de control: bias (sesgo del pronóstico).**

WMAPE mide la magnitud del error, no su dirección. Un modelo puede tener buen WMAPE y aun así quedarse corto de forma sistemática. De hecho, WMAPE por sí sola puede premiar a un modelo que subestima, porque predecir bajo reduce el error absoluto en series con muchos ceros.

Como criterio de negocio se prioriza la disponibilidad: es preferible pasarse (sobrestock, con su costo de inventario) antes que quedarse corto (quiebre y venta perdida). Por eso se mide el bias como control: la suma de los errores con signo. Un bias negativo indica que el modelo subestima de forma sistemática, lo que hay que evitar.

El modelo se elige por WMAPE; el bias verifica que el modelo elegido no viole la preferencia de disponibilidad. No se usa una segunda métrica de magnitud (MAE, RMSE) porque medirían lo mismo que WMAPE con peores propiedades ante ceros; bias no es redundante porque mide dirección, no tamaño.

## Baselines

Antes de entrenar cualquier modelo de ML, se definen baselines triviales. Su función no es competir, sino dar una vara de referencia: un WMAPE del modelo final solo significa algo comparado contra lo que se obtiene sin ningún modelo. Si el pipeline con features y ML no supera a una regla trivial por un margen que justifique su complejidad, el modelo no se justifica.

**Baseline 0 (naive simple):** predecir que las ventas de mañana serán iguales a las de hoy. El más básico posible.

**Baseline 1 (naive estacional):** predecir que las ventas de un día serán iguales a las del mismo día de la semana anterior. Captura la estacionalidad semanal, fuerte en retail. Es la vara principal que el modelo debe superar.

Ambos se miden con WMAPE, igual que el modelo, para que la comparación sea directa. La progresión naive simple -> naive estacional -> modelo de ML permite mostrar que cada capa de sofisticación aporta una mejora medible.

## Supuestos de inventario

El pronóstico de demanda no es directamente una cantidad a pedir. Para traducir uno en otro se declaran supuestos explícitos del caso ficticio, todos configurables:

| Parámetro | Valor por defecto | ¿Qué es? |
|---|---|---|
| R (ciclo de revisión) | 7 días | Cada cuánto el gerente revisa el stock y pide |
| L (lead time) | 3 días | Demora del proveedor entre pedido y entrega |
| Nivel de servicio | 95% | Probabilidad objetivo de no quedar sin stock durante el período de protección |

**Nivel de servicio configurable.** Se deja como parámetro para que la decisión de riesgo quede en manos del gerente, no cableada en el código. El 95% es el estándar de retail de consumo. Un nivel más alto reduce el riesgo de quiebre pero aumenta el stock de seguridad (más capital inmovilizado); uno más bajo, lo inverso. El sistema mostrará cómo cambia la cantidad sugerida entre 90%, 95% y 99% (análisis de sensibilidad).

**¿Cómo entra en el cálculo?** El nivel de servicio se traduce en un factor z (95% -> z ≈ 1.65, 99% -> z ≈ 2.33), que multiplica la desviación del error de pronóstico para dar el stock de seguridad. Cuanto más alto el nivel de servicio, más grande el z, más colchón.

**Conexión con el modelo.** La desviación que alimenta el stock de seguridad no es la de la demanda, sino la del error de pronóstico del modelo (sus residuos en backtesting). Un modelo más preciso genera menos stock de seguridad a igual nivel de servicio, es decir, menos capital inmovilizado. Ahí se traduce la calidad del forecast en valor de negocio.

**Stock actual.** No se simula: es un input del usuario. En la interfaz, el gerente informa cuánto stock tiene, y el sistema calcula cuánto pedir. Así se evita fabricar una tabla de inventario ficticia y se refleja el flujo real de una consulta de reposición sin integración con ERP.

## Objetivo final verificable

Cada 7 días, un pipeline orquestado corre de punta a punta sin intervención manual y publica, para las 1782 combinaciones tienda × familia (1609 con modelo de ML, 173 de baja rotación con regla simple), la demanda proyectada a 10 días y la cantidad sugerida de reposición bajo supuestos explícitos de lead time y nivel de servicio, con WMAPE mejor que naive estacional validado en backtesting temporal, consultable en una interfaz web desplegada (a definir en el punto 9 del roadmap)


## Carga cruda (capa raw)

### Destino
Los siete CSV se cargan en PostgreSQL 17, corriendo en un contenedor Docker con volumen persistente. La versión se fija de forma explícita (postgres:17) para que el entorno sea reproducible en el tiempo.

Se descartó SQLite pese a su simplicidad, porque bloquea el archivo completo en cada escritura (un solo escritor a la vez), lo que genera conflictos con la orquestación en paralelo prevista para el hito 10 (Airflow). PostgreSQL maneja escrituras concurrentes sin ese problema. Como beneficio secundario, incorpora Docker y Postgres al stack, ambos estándar en entornos de datos reales.

### Origen de los datos
Los CSV crudos no se versionan en el repositorio: train.csv pesa ~116 MB, por encima del límite de 100 MB por archivo de GitHub. Se obtienen mediante la API de Kaggle; el procedimiento se documenta en el README. La exclusión es por tamaño: son datos públicos de Kaggle, sin restricción de licencia que impida compartirlos.

### Principio de la capa cruda
La capa raw es copia fiel del origen: no se transforma, ni limpia nada. Las fechas se guardan como texto tal como vienen en el CSV; la conversión a tipos de fecha es trabajo de la capa de staging. Esto preserva la capacidad de auditar contra la fuente y evita enterrar errores de transformación en la carga.

### Reproducibilidad
El script se puede reejecutar sin efectos colaterales: cada tabla se recrea desde cero (if_exists='replace'), dejando siempre un estado idéntico al CSV, sin duplicados ni residuos de corridas previas.

### Rendimiento
La carga masiva usa el comando COPY nativo de PostgreSQL en lugar de inserciones fila por fila. La estructura de cada tabla se crea con to_sql sobre un DataFrame vacío (para inferir tipos), y los datos se cargan por COPY desde un buffer en memoria. Con COPY, la carga de train (3M de filas) pasa de demorar minutos a tomar ~16 segundos.

### Credenciales
Las credenciales de conexión viven en un archivo .env excluido del repositorio, nunca hardcodeadas en el código.

## Capa de staging con DBT

### ¿Qué se hizo?: 
Se creó una capa de staging con DBT (materializada como vistas) que toma las 7 tablas crudas del schema public y produce 7 modelos stg_* en el schema staging. Las transformaciones aplicadas son de limpieza estructural únicamente: casteo de tipos (date de texto a tipo fecha real) y renombrado de columnas (dcoilwtico a oil_price, store_nbr a store_number).

### Decisión: 
Qué transforma staging y qué no. La capa de staging se limita a limpieza estructural (tipos y nombres). Deliberadamente NO hace imputación ni relleno de huecos: por ejemplo, los 43 nulos de oil_price y las fechas faltantes de fin de semana quedan sin tocar. El motivo es que la imputación es una decisión de modelado, no de limpieza, y mezclarla en staging rompería la trazabilidad. Staging debe ser una imagen fiel de la fuente, con los tipos corregidos: cualquiera que compare una tabla cruda con su stg_ correspondiente debe ver los mismos datos, solo que bien tipados y nombrados. El relleno de huecos (forward fill del oil, reindexado del calendario), donde es una decisión explícita y documentada.

### Decisión:
incluir los artefactos de Kaggle. Se construyeron modelos de staging y tests también para test y sample_submission, que son artefactos del formato de competencia de Kaggle y no datos operativos del caso de uso. Se los mantuvo para dejar abierta la opción de generar una submission de Kaggle más adelante, sin tener que volver a tocar la capa de staging.

### Tests: 
se declararon 32 tests de calidad de datos sobre los modelos de staging usando tests genéricos de DBT (not_null, unique) y dbt_utils.unique_combination_of_columns para las claves primarias compuestas. Los tests codifican las claves y restricciones halladas en la auditoría del hito 2 (por ejemplo, la PK compuesta date + store_number + family de stg_train). Nota: oil_price no lleva test not_null porque sus 43 nulos son esperados y forman parte de la fuente.

## Correciones

### Se eliminó la columna id de stg_train.
Originalmente se mantuvo en staging como parte de la limpieza estructural sin cuestionarla. Al diseñar la reconstrucción del calendario en el hito 6 (agregar filas para los 4 días de Navidad ausentes), se identificó que id no tiene forma de generarse con un valor coherente para esas filas sintéticas: es un correlativo de fila propio del CSV de origen. No cumplía ninguna función y complicaba la construcción de filas nuevas. A diferencia de stg_test y stg_sample_submission, donde id sí se mantiene porque es la clave para emparejar predicciones con filas al armar una submission de Kaggle.

## Feature "work_day", día laborable por tienda

Se construyó la feature work_day (booleana) en el modelo int_work_day, que indica si una tienda operó comercialmente en una fecha dada. Responde únicamente la pregunta "¿abrieron las tiendas?".

Fuente y cruce. La feature surge de cruzar el panel (int_train_full) con stg_holidays_events, usando stg_stores como puente para resolver la geografía. El match con un feriado depende de su locale: los National aplican a todas las tiendas, los Regional solo a las tiendas cuyo state coincide con el locale_name, los Local solo a las tiendas cuya city coincide. Se verificó que todos los locale_name de feriados Local y Regional matchean contra city y state de stores respectivamente (ningún feriado queda huérfano).

Lógica de cierre por tipo de feriado. Un día NO se trabaja (false) solo si hay un feriado que implica cierre real. La clasificación por type:

Holiday con transferred = false -> cierra
Holiday con transferred = true -> NO cierra (el feriado se trasladó a otra fecha, el día original quedó laborable)
Transfer, Bridge -> cierran
Work Day, Event -> NO cierran (son días laborables pese a figurar en la tabla de feriados)
Additional -> NO cierra

Decisión sobre Additional. Los Additional son días marcados alrededor de un feriado principal ("Navidad-4" a "Navidad-1", "Navidad+1" y vísperas del Día de la Madre o Año Nuevo). Aunque figuran en el calendario oficial de feriados, para un supermercado son días de alta actividad comercial, no de cierre (la semana previa a Navidad es usualmente un pico de ventas).

Colapso de múltiples feriados. Como un mismo día-tienda puede tener varios feriados simultáneos (un National y un Local), se agrupa por date, store_number, family y se colapsa con BOOL_AND sobre la condición de "día trabajado". El día se considera trabajado solo si todos los feriados aplicables son laborables, si al menos uno implica cierre, el día no se trabaja.

## Features de calendario: int_calendar

Se creó el modelo int_calendar, una tabla de dimensión de fecha con una fila por cada día (1688 filas, correspondientes a las fechas distintas del panel).
Contiene features derivadas de la fecha:

month_number: número de mes (1-12), captura estacionalidad anual.
day_of_month: día del mes (1-31), captura posibles efectos de cobro.
week_day: nombre del día de la semana en inglés (Monday-Sunday), captura el patrón semanal de compra.

### Granularidad
El modelo "int_calendar" tiene granularidad de fecha (una fila por día). Las features de calendario dependen únicamente de la fecha, no de la tienda ni la familia, así que calcularlas una sola vez por día (sobre las fechas distintas, no sobre las 3M de filas del panel) evita recalcular lo mismo 1782 veces. Se une al panel por fecha en el ensamblado final del hito.

### Decisión:
Se descartó la feature de estación. Se evaluó incluir una feature de estación del año y se descartó por dos razones: es redundante con month_number (la estación se deriva del mes), y porque Ecuador, al estar sobre la línea ecuatorial, no tiene estaciones marcadas como lo son en otras latitudes. Imponer las cuatro estaciones clásicas sería una categoría que no corresponde a la realidad del país al cual pertenece este modelo.

Nota sobre week_day. Se guarda como texto (nombre del día) en lugar de número. El nombre se limpia con TRIM para eliminar el padding de espacios que agrega TO_CHAR en Postgres. El tratamamiento de la misma en el modelo se tratará en la etapa del modelado.

## Feature onpromotion

Se analizó la columna onpromotion del panel para decidir si requería alguna transformación. La columna es un conteo, indica cuántos ítems de esa familia estaban en promoción ese día en esa tienda. Toma valores desde 0 hasta 741, con promedio 2.6 y con el 80% de las filas en 0 (2.396.687 de 3.008.016).

Es una distribución fuertemente sesgada: un pico enorme en cero y una cola larga de valores altos, concentrados en familias de alta rotación con muchas promociones.

### Decisión
Se deja la columna cruda, sin transformar. El tratamiento del sesgo corresponde a la etapa de modelado, del mismo modo que el encoding de las variables categóricas. La capa intermedia conserva el dato limpio y crudo; cómo se transforma para el algoritmo se decide según el modelo elegido.

## Feature de petróleo: int_oil

Se creó el modelo int_oil, que expone el precio diario del petróleo (oil_price_filled) con una fila por cada fecha del período (1688), sin nulos. El petróleo es una variable exógena relevante para Ecuador, país productor de petróleo, donde el precio del crudo afecta la economía y el consumo.

### Problema a resolver
La tabla cruda de oil tiene dos tipos de huecos: 43 nulos en fechas que existen, y fechas directamente faltantes (los fines de semana y feriados de mercado, cuando el petróleo no cotiza). Como el panel de ventas tiene todas las fechas (las tiendas abren igual los fines de semana), se busca asignar un valor a cada día.

### Método de imputación:
Se utilizó el método forward fill. Los huecos se rellenan con el último precio conocido (last observation carried forward), un precio persiste hasta que cambia: si el viernes cerró en 93.12 y el fin de semana no cotiza, el precio sigue siendo 93.12. Se descartaron las alternativas: rellenar con cero (implicaría que el petróleo pasó a valer nada), con la media (metería un valor que no existió en ese momento) y la interpolación (usaría el valor del día siguiente, es decir información del futuro, lo que introduce leakage). El forward fill solo mira hacia atrás, nunca al futuro, así que es seguro para un pipeline predictivo.

### Borde inicial
Se decidió utilizar backward fill. El forward fill no puede llenar el primer día si ya es nulo (no hay valor anterior que arrastrar). El 1 de enero de 2013 era nulo, así que ese único caso se rellena con el primer precio conocido de la serie (backward fill). Es aceptable porque es el borde más antiguo del dataset: no hay nada anterior que predecir, así que no genera leakage.

### Implementación
Se parte de int_calendar (todas las fechas) con un LEFT join a oil (trae el precio donde existe, nulo donde no). El forward fill se resuelve con dos window functions: un conteo acumulado de valores no nulos que agrupa cada hueco con su último precio conocido, y un MAX por grupo que reparte ese precio a las filas nulas del grupo. El borde inicial se tapa con un COALESCE contra el primer precio no nulo de la serie. Se verificó que el resultado no tiene ningún nulo en las 1688 fechas.

## Features de lags: int_lags

Se creó el modelo int_lags, con una fila por fecha, tienda y familia (3.008.016 filas, igual al panel). Expone cuatro features: lag_7, lag_14, lag_21 y lag_28, que son las ventas de la misma tienda y familia 7, 14, 21 y 28 días antes.

### Cálculo

Se usa la window function LAG con PARTITION BY store_number, family y ORDER BY date, de modo que cada una de las 1782 series se recorre por separado. LAG corre posiciones, no días: "7 filas atrás" equivale a "7 días atrás" ya que el panel está balanceado (una fila por día en cada serie).

### Decisión: qué lags son válidos

El horizonte de predicción es de 10 días. Un lag menor al horizonte usaría ventas que todavía no ocurrieron al momento de predecir los días más lejanos (por ejemplo, para predecir el día 10 con lag_7 haría falta la venta del día 3, desconocida). Con un único modelo para todo el horizonte, el lag mínimo válido es 10.

Entre los lags válidos se eligieron múltiplos de 7, para que el lag caiga en el mismo día de la semana que el día a predecir (el patrón semanal es el más fuerte en la venta de un supermercado). Varias semanas hacia atrás (14, 21, 28) dan robustez ante semanas atípicas y permiten captar tendencia.

lag_7 se calcula pero solo es válido para predicciones a 7 días o menos; su uso se define más adelante en el proyecto.

### Decisión: días cerrados como nulo

Antes de calcular los lags, la venta de los días en que la tienda estuvo cerrada (work_day = false) se reemplaza por nulo. Si no, el valor 0 de un día cerrado llegaría al lag como si fuera una caída real de la demanda. Se eligió anular en lugar de agregar una columna con el work_day del día rezagado por dos motivos: los días cerrados son muy pocos para que el modelo aprenda a interpretar esa combinación, y las medias móviles que se calculen después ignoran los nulos, mientras que un 0 las contaminaría.


### Tests

Se testean unicidad de la combinación de las columnas date, store_number, family, y not_null en esas tres columnas. Los lags no llevan not_null ya que cuentan nulos esperados al inicio de cada serie y en los días que vienen de un cierre.

### Medias móviles: avg_7 y avg_28

Se agregaron a int_lags dos medias móviles de las ventas: avg_7 y avg_28, el promedio de 7 y 28 días de la misma tienda y familia. Se calculan con AVG como window function, con el mismo PARTITION BY store_number, family y ORDER BY date que los lags, y un marco de ventana explícito (ROWS BETWEEN ... PRECEDING AND 10 PRECEDING).

### Decisiones:
#### La ventana termina 10 días atrás

Por la misma regla del horizonte que los lags: el día más reciente que puede entrar en el promedio es el de 10 días antes. Una media móvil "de los últimos 7 días" que termine en el día anterior incluiría ventas que todavía no ocurrieron al predecir los días más lejanos. Por eso avg_7 promedia de 16 a 10 días atrás, y avg_28 de 37 a 10 días atrás (el inicio se calcula como 10 + tamaño de la ventana - 1).

#### Ventanas de semanas completas

Se eligieron 7 y 28 días porque contienen semanas completas, con la misma cantidad de cada día de la semana. Una ventana de 30 días incluiría algunos días de la semana más veces que otros y sesgaría el promedio. Tener una ventana corta y una larga permite al modelo ver tanto el nivel reciente como la tendencia (si la de 7 está por encima o por debajo de la de 28).

Se descartó una media anual: el primer año de cada serie tendría promedios parciales, y su valor casi no varía, por lo que aporta poco frente a month_number y la propia identidad de la serie.

#### Promediar la venta limpia

Se promedia la venta con los días cerrados en nulo, la misma columna base de los lags. AVG ignora los nulos, así que un día cerrado no baja el promedio con un 0 que no representa demanda.

### Ventanas incompletas al inicio

Cuando no hay suficiente historia para llenar la ventana, AVG promedia los valores disponibles en lugar de devolver nulo. En los primeros días de cada serie, avg_28 es en realidad el promedio de pocos días. Se decidió no corregirlo en esta capa, y más adelante, excluir del entrenamiento los primeros 37 días del período (65.934 filas, 2,2% del panel), donde la ventana de 28 días no está completa.

Las medias móviles no llevan not_null: tienen nulos legítimos en los primeros 10 días de cada serie. Sí llevan un test de rango (mínimo 0), ya que las ventas nunca son negativas.