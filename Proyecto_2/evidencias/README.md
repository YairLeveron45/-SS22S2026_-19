# Evidencias del Proyecto 2

**Durante la calificación:** usar la [guía de presentación](../docs/GUIA_CALIFICACION.md)
para encontrar rápidamente el script, la explicación y la evidencia de cada criterio.

Inventario conciliado con los archivos existentes al **27 de octubre de 2026**.
El enunciado pide evidencias de consultas, registros, optimización e informe visual;
**no exige 42 capturas ni los nombres de archivo de la lista anterior**. Esa lista era
una propuesta interna. Una captura combinada puede respaldar varios puntos.

## Cobertura de los entregables

| Punto | Evidencia disponible | Alcance |
|---|---|---|
| Dataset público y volumen | [Detalles de origen](01b_detalles_tabla_publica.png), [esquema](03_esquema.png) | 36,256,539 filas, tamaño y tipos; sustituye las capturas propuestas 01 y 02 para acreditar volumen. No demuestra un `COUNT(*)` con 0 B. |
| Calidad y transformaciones | [Control de calidad](04_calidad_datos.png), [trabajo ejecutado](04b_calidad_informacion_trabajo.png), [esquema limpio](03b_esquema_viajes.png) | Conteos por regla, tipos finales y consumo de la consulta. Los filtros están en `sql/02`. |
| Tabla derivada, particiones y clustering | [Detalles de viajes](06_tabla_viajes_detalles.png) | 35,332,160 filas, 11 particiones mensuales, filtro obligatorio y columnas de clustering. Sustituye la necesidad de otra imagen para mostrar esa configuración; no muestra filas por cada mes ni el DDL de ambas tablas. |
| Comparación estándar frente a optimizada | Trabajos S1–S3 enlazados abajo y [tabla resumen](23_resumen_comparacion.png) | SQL original, bytes, duración y comparación en las tres variantes. El resumen es la vista previa de métricas guardadas, no la salida de R2 con porcentajes calculados. |
| Consultas y hallazgos exploratorios | [Dashboard exploratorio](39_dashboard_exploracion.png) y scripts comentados `sql/03` | Serie temporal, mapa de calor, zonas, pagos y flujos. Cubre varias visualizaciones en una imagen; no equivale a capturar individualmente todas las consultas E1–E20. |
| Entrenamiento e hiperparámetros | [Lineal](28_modelo_lineal_entrenamiento.png), [configuración boosted](29b_modelo_boosted_configuracion.png), [entrenamiento boosted](29c_modelo_boosted_entrenamiento.png), [configuración del clasificador](30b_modelo_clf_configuracion.png) | Existencia de modelos, configuración, split e iteraciones. |
| Evaluación y comparación de modelos | [Evaluación de demanda](29_modelo_boosted_evaluacion.png), [evaluación de clasificación](30_modelo_clf_evaluacion.png), [métricas de regresión](31_comparacion_regresion.png), [métricas de clasificación](33_comparacion_clasificacion.png) | Evaluación existente y vistas previas de las tablas de métricas. |
| Conteos por conjunto, balance y control de rezagos | [Captura combinada](24_26_32_controles_resultados.png), [TSV](controles_documentacion.tsv), [JSON](controles_documentacion.json) | A1, A2 y B1 sustituyen los archivos propuestos 24, 25 y 26. El conteo de propinas muestra enero–octubre y noviembre, no el desglose del split aleatorio interno del modelo. |
| Comparaciones de fuga por split y por variable | Misma captura combinada y exportaciones | C1 sustituye el archivo propuesto 32; C2 muestra el modelo de demostración con fuga frente a los válidos. La alineación de rezagos y las brechas de métricas no prueban por sí solas ausencia de toda fuga. |
| Predicciones y rolling forecast | [Predicciones de demanda](37b_predicciones_demanda.png), [predicciones de propinas](38b_predicciones_propina.png), [dashboard de demanda](41_dashboard_pronostico.png) | Filas almacenadas y comparación entre modelos sobre noviembre, reservado como prueba. |
| Matriz, importancia y error de pronóstico | [Dashboard de propinas](42_dashboard_propinas.png), [dashboard de demanda](41_dashboard_pronostico.png) | Respaldo visual combinado de los puntos propuestos 34, 35 y 37; no reemplaza exportaciones de todas sus filas o métricas por umbral. |
| Informe visual | Las cuatro páginas enlazadas abajo y el enlace publicado en el README principal | Más de tres visualizaciones exploratorias y comparación de predicciones de varios modelos. |

## Trabajos de optimización

| Escenario | Estándar | Optimizada | Pública |
|---|---|---|---|
| S1: partición | [Trabajo S1](16_s1_estandar.png) | [Trabajo S1 optimizado](17_s1_optimizada.png) | No aplica |
| S2: clustering | [Trabajo S2](18_s2_estandar.png) | [Trabajo S2 optimizado](19_s2_optimizada.png) | No aplica |
| S3: combinación | [Trabajo S3](21_s3_estandar.png) | [Trabajo S3 optimizado](22_s3_optimizada.png) | [Trabajo público](20_s3_publica.png) |

Estas capturas se recuperaron del historial sin repetir las consultas. Sus tablas
temporales de resultados figuraban como vencidas. Las estadísticas originales y la
tabla persistente `comparacion_consultas` siguen disponibles en las capturas.

## Informe visual

- [Exploración](39_dashboard_exploracion.png).
- [Optimización](40_dashboard_optimizacion.png).
- [Pronóstico de demanda](41_dashboard_pronostico.png).
- [Clasificación de propinas](42_dashboard_propinas.png).

## Resultados específicos sin evidencia adjunta suficiente

El README técnico cubre los temas del enunciado. Los siguientes respaldos todavía
faltan para verificar ciertos resultados numéricos o diagnósticos que allí se afirman;
no deben presentarse como resultados comprobados por las imágenes actuales:

| Resultado reportado | Qué falta | Consulta de referencia |
|---|---|---|
| Un duplicado exacto eliminado | Resultado del conteo de llaves duplicadas | `sql/01`, bloque 9 |
| Detalle mensual de particiones | Filas y tamaño de cada partición; la captura actual solo muestra configuración y total de particiones | `sql/02`, bloque 4 |
| Descriptivas, variaciones mensuales y rutas específicas | Salidas que respalden los valores no visibles en el dashboard | `sql/03`, E1, E5 y E17 |
| Diagnóstico de huecos por proveedor y hora | Resultados de las consultas que sustentan las fallas de captura | `sql/03`, E19 y E20 |
| Tasas por categoría usadas para justificar variables | Resultado por proveedor, tarifa y borough; los gráficos de importancia muestran otro tipo de evidencia | `bqml/01`, B.2 |
| Métricas con umbral de Youden frente a 0.5 | Resultados por modelo y criterio; la imagen del dashboard no acredita toda la tabla de umbrales del README | `bqml/05`, 3a |
| Probabilidades de los tres viajes hipotéticos | Salida de `ML.PREDICT` para esos escenarios. La captura de `ml_pred_propina` corresponde a viajes reales de noviembre | `bqml/05`, sección 4 |

Las capturas propuestas de `SELECT *` frente a columnas (14 y 15), del DDL (08)
y de conciliación (09) son respaldos adicionales del procedimiento. Sus nombres
no son entregables independientes exigidos por el enunciado. Los volúmenes de origen
y destino ya se muestran en los detalles de las tablas.

No hace falta volver a entrenar modelos para completar estas evidencias. Primero
deben recuperarse resultados guardados o vistas previas existentes. Cualquier nueva
consulta que pueda generar cobros requiere autorización del usuario.

## Ejecuciones autorizadas para documentación

| Ejecución | Consumo registrado | Respaldo |
|---|---|---|
| Control de calidad del origen | 3.13 GB procesados y facturados | [Información del trabajo](04b_calidad_informacion_trabajo.png) |
| Cinco controles de solo lectura agrupados en `bqml/06` | 18.94 MB procesados, 40 MB facturados, 607 ms | [Información del trabajo](24b_controles_informacion_trabajo.png) |

No se entrenaron modelos para tomar estas evidencias. El TSV se copió de los
resultados de BigQuery; el JSON se estructuró a partir de ese mismo TSV. La cifra
de bytes facturados es consumo técnico; el cargo monetario final se consulta en
Facturación de GCP.
