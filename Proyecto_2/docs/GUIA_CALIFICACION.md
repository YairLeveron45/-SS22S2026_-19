# Guía para presentar el Proyecto 2

Usa esta guía como recorrido durante la calificación. Los enlaces abren el documento,
script o captura correspondiente. Las capturas muestran ejecuciones realizadas; abrir
estos archivos locales no ejecuta consultas en GCP.

## 1. Preparar lo que vas a mostrar

1. Abrir el [README principal](../README.md): contiene la documentación técnica y los integrantes.
2. Abrir esta guía en vista previa de Markdown para usar sus enlaces.
3. Tener disponible el [dashboard](https://datastudio.google.com/u/0/reporting/7e3040a1-201a-4595-bf1e-fa6a5c6af4a0/page/yY7BG).
   Ya existen capturas locales de sus cuatro páginas. Abrir el dashboard puede activar
   lecturas en BigQuery; no hace falta refrescar datos para mostrar las capturas.
4. Si solicitan una demostración en BigQuery, seleccionar el proyecto
   `ss2-proyecto2-512805`, dataset `nyc_taxi_2022`, región `US`.

## 2. Recorrido según la rúbrica

Los puntos de esta tabla son los máximos del enunciado; no representan una nota obtenida.

| Orden y criterio | Puntos | Qué explicar | Qué abrir |
|---|---:|---|---|
| 1.1 Dataset | 8 | La unidad es un viaje. La fuente tiene 36,256,539 filas y la tabla limpia 35,332,160; supera el millón requerido. El análisis se limita a enero–noviembre. | README §2; [origen](../evidencias/01b_detalles_tabla_publica.png), [esquema](../evidencias/03_esquema.png), [calidad](../evidencias/04_calidad_datos.png) |
| 1.2 SQL y transformaciones | 8 | Limpieza de fechas, montos, duración, distancia y pasajeros; conversiones de tipos, variables derivadas, agregaciones y ventanas. | README §5; [transformaciones](../sql/02_transformacion_tablas.sql), [consultas E1–E20](../sql/03_analisis_exploratorio.sql) |
| 1.3 Optimización | 12 | Partición mensual por `pickup_date`, clustering por origen y destino, y comparación con una copia estándar. | README §6; [configuración de viajes](../evidencias/06_tabla_viajes_detalles.png), [comparación guardada](../evidencias/23_resumen_comparacion.png) |
| 1.4 Modelos de ML | 8 | Dos problemas: regresión de demanda y clasificación de viajes con tarjeta sin propina. Hay nueve modelos; dos son demostraciones de control. | README §8.1–8.2; [modelos de demanda](../bqml/02_modelos_demanda.sql), [modelos de propinas](../bqml/03_modelos_propina.sql) |
| 1.5 Métricas e hiperparámetros | 12 | Comparar algoritmos, regularización, iteraciones y profundidad. Seleccionar con validación, sin usar noviembre para decidir. | README §8.1–8.2; [configuración boosted](../evidencias/29b_modelo_boosted_configuracion.png), [métricas de regresión](../evidencias/31_comparacion_regresion.png), [métricas de clasificación](../evidencias/33_comparacion_clasificacion.png) |
| 1.6 Separación y data leakage | 12 | Demanda: split temporal `CUSTOM`. Propinas: `RANDOM` con fracción 0.2 y prueba temporal aparte. Excluir información posterior al momento de predicción. | README §8.4 y §16.4; [preparación](../bqml/01_preparacion_datos_ml.sql), [controles ejecutados](../evidencias/24_26_32_controles_resultados.png), [resultados exportados](../evidencias/controles_documentacion.json) |
| 2.1 Patrones y tendencias | 10 | Diferencias por hora y día, concentración en Manhattan y participación de aeropuertos en ingresos. Distinguir patrones de errores de captura. | README §7; [dashboard exploratorio](../evidencias/39_dashboard_exploracion.png) |
| 2.2 Visualizaciones y predicciones | 10 | Mostrar al menos tres visualizaciones exploratorias y el rolling forecast de varios modelos frente a datos reales y baseline. | README §9; [exploración](../evidencias/39_dashboard_exploracion.png), [demanda](../evidencias/41_dashboard_pronostico.png), [clasificación](../evidencias/42_dashboard_propinas.png) |
| 2.3 Ingeniería de características | 10 | Justificar rezagos, promedios de historia, feriados, perfil horario, deciles e imputación. Las variables deben estar disponibles al predecir. | README §5.2 y §8.3; [preparación](../bqml/01_preparacion_datos_ml.sql), `TRANSFORM` en [logística](../bqml/03_modelos_propina.sql) |
| 2.4 Entrada, salida y objetivo | 5 | Demanda: salida `viajes` por hora y borough. Propinas: salida `sin_propina`, clase positiva 1. Explicar entradas y momento de predicción de cada problema. | Tablas de variables del README §8.1 y §8.2; `input_label_cols` en los scripts de modelos |
| 2.5 Estándar frente a optimizada | 5 | Comparar exactamente el mismo escenario sobre `viajes_estandar` y `viajes`; separar bytes, tiempo de slot y duración. | README §6.2–6.3; [S1 estándar](../evidencias/16_s1_estandar.png), [S1 optimizada](../evidencias/17_s1_optimizada.png), [resumen](../evidencias/23_resumen_comparacion.png) |

## 3. Archivos clave por pregunta

| Si preguntan… | Respuesta y respaldo |
|---|---|
| ¿Cómo está construido el proyecto? | [Arquitectura con logos](imagenes/arquitectura.png), README §3. |
| ¿Dónde está la limpieza? | [sql/02](../sql/02_transformacion_tablas.sql). Los problemas detectados están en [calidad](../evidencias/04_calidad_datos.png). |
| ¿Dónde demuestran partición y clustering? | [Detalles de viajes](../evidencias/06_tabla_viajes_detalles.png). |
| ¿Qué optimiza cada escenario? | S1: fecha; S2: zona sobre todo el período; S3: fecha y zona. [SQL de comparación](../sql/04_comparacion_rendimiento.sql). |
| ¿Cuánto redujeron la lectura? | Resultados reportados y respaldados por los trabajos: S1 90.2 %, S2 83.1 %, S3 98.9 % frente a la estándar. README §6.3. |
| ¿Cuál es el modelo de demanda elegido? | `reg_demanda_boosted_v2`: RMSE de validación 223.97; RMSE de prueba 309.44, frente a 495.11 del baseline. README §8.1. |
| ¿Cuál es el clasificador elegido? | `clf_propina_logistica_v2`: AUC de evaluación 0.6881 y prueba 0.6879. Su precisión es baja; no presentarlo como un predictor perfecto. README §8.2. |
| ¿Dónde están los conteos y el control de rezagos? | [JSON de controles](../evidencias/controles_documentacion.json): A1, A2 y B1. A2 compara 31,968 filas y obtiene 0 rezagos desalineados. |
| ¿Dónde se comparan los ejemplos de fuga? | Mismo JSON: C1 compara splits; C2 incluye `clf_propina_con_fuga`. README §8.4 y §16.4. |
| ¿Dónde están las predicciones? | [Demanda](../evidencias/37b_predicciones_demanda.png), [propinas](../evidencias/38b_predicciones_propina.png), [script](../bqml/05_predicciones.sql) y dashboard. |
| ¿Cómo funciona el rolling forecast? | Cada día de noviembre usa historia disponible hasta el día anterior; el origen avanza diariamente y el horizonte es el día siguiente. README §8.5. |
| ¿Cómo se reproduce? | [Guía de ejecución](GUIA_EJECUCION.md). No ejecutar todo para buscar una captura. |
| ¿Qué consumo tuvieron los controles documentales? | Calidad: 3.13 GB; cinco controles: 18.94 MB procesados y 40 MB facturados. Información de trabajos en README §16.3–16.4. No confundir bytes con dólares. |

## 4. Distinguir los archivos de controles

El nombre `24_26_32_controles_resultados.png` es una captura combinada, no tres
imágenes faltantes. Se interpreta junto con [el TSV](../evidencias/controles_documentacion.tsv)
o [el JSON](../evidencias/controles_documentacion.json):

| Código | Contenido |
|---|---|
| `A1_split_demanda` | Filas, fechas, datos faltantes y estimados por conjunto de demanda |
| `A2_control_rezagos` | Comparación del rezago de 24 horas con la fila histórica correspondiente |
| `B1_split_propinas` | Tamaño y balance de clases de enero–octubre y de noviembre |
| `C1_comparacion_split` | Métricas almacenadas de split aleatorio frente a temporal |
| `C2_comparacion_fuga_variable` | Métricas almacenadas del modelo con fuga frente a modelos válidos |

Los cinco controles se agruparon en [bqml/06](../bqml/06_controles_documentacion.sql).
No entrenan modelos. El conjunto de enero–octubre de propinas incluye las filas que
BigQuery ML separa internamente para evaluación; B1 no cuenta ese split interno por separado.

## 5. Límites que conviene explicar

- Los dos modelos de demostración (`reg_demanda_lineal_aleatorio` y
  `clf_propina_con_fuga`) son controles, no los modelos finales seleccionados.
- Un control de rezagos con cero errores verifica alineación; no prueba por sí solo
  ausencia de toda fuga de información. Una diferencia de métricas entre meses tampoco
  demuestra por sí sola fuga.
- En demanda, las horas estimadas de la semana incompleta de noviembre no se usan como
  objetivos de evaluación. Las limitaciones de origen están documentadas en README §12.
- Las capturas de evaluación del modelo muestran su conjunto de evaluación. Las tablas
  de métricas distinguen evaluación y prueba de noviembre.
- Las predicciones de viajes reales de noviembre son sobre datos reservados de prueba.
  Los tres viajes hipotéticos son otro ejemplo: su SQL está implementado, pero sus
  probabilidades reportadas todavía no tienen una salida adjunta que las respalde.
- Algunas cifras específicas del README conservan respaldo pendiente. Consultar
  [«Resultados específicos sin evidencia adjunta suficiente»](../evidencias/README.md#resultados-específicos-sin-evidencia-adjunta-suficiente).
  No afirmar que todo valor fue verificado solo porque su script existe.

## 6. Antes de entregar

- Confirmar que el README identifica correctamente a los dos integrantes.
- Confirmar que GitHub contiene las imágenes, los scripts y las exportaciones locales.
- Confirmar que el dashboard mantiene acceso de lectura para quien evalúa.
- Mostrar primero los resultados y después abrir el SQL que los produce.
- Si se pide ejecutar algo en vivo, revisar el procesamiento estimado y el posible costo.
  Las autorizaciones anteriores no autorizan repetir entrenamientos ni consultas diferentes.
