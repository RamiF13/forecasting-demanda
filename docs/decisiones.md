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
