# Evidencias

Capturas de pantalla de la consola de BigQuery y de Data Studio. Cada fila indica el archivo
esperado, qué debe verse y el criterio de la rúbrica que respalda. Guardar las imágenes en esta
carpeta con el nombre indicado.

En consultas de BigQuery, la captura debe mostrar a la vez el texto de la consulta y el resultado.
En comparaciones de rendimiento, debe mostrar la pestaña **Información del trabajo**.

## Dataset y calidad (rúbrica 1.1)

| Archivo | Qué mostrar | Origen |
|---|---|---|
| `01_volumen_tabla_publica.png` | Registros y tamaño de las tablas `tlc_yellow_trips_*` | `sql/01` bloque 1 |
| `02_conteo_2022.png` | `COUNT(*)` de 2022 con "0 B procesados" | `sql/01` bloque 2 |
| `03_esquema.png` | Columnas, tipos y nulabilidad | `sql/01` bloque 3 |
| `04_calidad_datos.png` | Problemas de calidad con su porcentaje | `sql/01` bloque 5 |
| `05_duplicados.png` | Registros, llaves distintas y duplicados | `sql/01` bloque 9 |

## Transformación, partición y clustering (rúbrica 1.2 y 1.3)

| Archivo | Qué mostrar | Origen |
|---|---|---|
| `06_tabla_viajes_detalles.png` | Pestaña **Detalles** de `viajes`: "Particionada por MONTH en pickup_date", "Agrupada por pickup_location_id, dropoff_location_id", "Filtro de partición obligatorio" | Explorador → `viajes` |
| `07_particiones.png` | Una partición por mes con sus filas | `sql/02` bloque 4 |
| `08_ddl_tablas.png` | DDL de `viajes` (con PARTITION BY/CLUSTER BY) y de `viajes_estandar` (sin ellos) | `sql/02` bloque 6 |
| `09_conciliacion.png` | Registros de origen, limpios y % conservado | `sql/02` bloque 7 |
| `10_eda_descriptivas.png` | Métricas descriptivas | `sql/03` E1 |
| `11_eda_temporal.png` | Tendencia mensual con variación % | `sql/03` E5 |
| `12_eda_pivot_hora_dia.png` | PIVOT hora x día | `sql/03` E6 |
| `13_eda_rutas_qualify.png` | Top 3 rutas por borough con QUALIFY | `sql/03` E17 |
| `13b_huecos_captura.png` | Horas y días con falla de captura de la fuente | `sql/03` E19 y E20 |

## Comparación estándar contra optimizada (rúbrica 1.3 y 2.5)

| Archivo | Qué mostrar | Origen |
|---|---|---|
| `14_s0_select_estrella.png` | Estimación del validador para `SELECT * ... LIMIT 10` | `sql/04` S0 |
| `15_s0_columnas.png` | Estimación del validador con solo tres columnas | `sql/04` S0-columnas |
| `16_s1_estandar.png` / `17_s1_optimizada.png` | Información del trabajo de S1 en cada tabla | `sql/04` S1 |
| `18_s2_estandar.png` / `19_s2_optimizada.png` | Información del trabajo de S2 en cada tabla | `sql/04` S2 |
| `20_s3_publica.png` / `21_s3_estandar.png` / `22_s3_optimizada.png` | Información del trabajo de S3 en las tres tablas | `sql/04` S3 |
| `23_resumen_comparacion.png` | Tabla de reducción de bytes por escenario | `sql/04` R2 |

## BigQuery ML (rúbrica 1.4, 1.5, 1.6, 2.3 y 2.4)

| Archivo | Qué mostrar | Origen |
|---|---|---|
| `24_ml_split_demanda.png` | Filas y fechas por conjunto (entrenamiento, validación, prueba) | `bqml/01` A.1 |
| `25_ml_control_rezagos.png` | Control de rezagos con 0 incorrectos | `bqml/01` A.2 |
| `26_ml_balance_clases.png` | Balance de clases de `ml_propinas` | `bqml/01` B.1 |
| `27_ml_justificacion_variables.png` | Tasa de "sin propina" por categoría | `bqml/01` B.2 |
| `28_modelo_lineal_entrenamiento.png` | Pestaña **Entrenamiento** de `reg_demanda_lineal_v2` (pérdida por iteración) | Explorador → modelo |
| `29_modelo_boosted_evaluacion.png` | Pestaña **Evaluación** de `reg_demanda_boosted_v2` | Explorador → modelo |
| `30_modelo_clf_evaluacion.png` | Pestaña **Evaluación** de `clf_propina_boosted` (curva ROC y matriz) | Explorador → modelo |
| `31_comparacion_regresion.png` | Evaluación frente a prueba por modelo | `bqml/04` 8a |
| `32_fuga_split.png` | Brecha del split aleatorio frente al temporal | `bqml/04` 8b |
| `33_comparacion_clasificacion.png` | Métricas por modelo, incluido el modelo con fuga | `bqml/04` 8c |
| `34_matriz_confusion.png` | `ML.CONFUSION_MATRIX` en noviembre | `bqml/04` sección 4 |
| `35_importancia_variables.png` | Importancia por ganancia | `bqml/04` sección 6 |
| `36_metricas_por_umbral.png` | Precisión, recall y F1 con umbral 0.5 y con Youden | `bqml/05` 3a |
| `37_mape_pronostico.png` | Error porcentual diario por serie | `bqml/05` 1b |
| `38_viajes_hipoteticos.png` | Probabilidades de los viajes nuevos | `bqml/05` sección 4 |

## Informe visual (rúbrica 2.2)

| Archivo | Qué mostrar |
|---|---|
| `39_dashboard_exploracion.png` | Página 1 completa |
| `40_dashboard_optimizacion.png` | Página 2 completa |
| `41_dashboard_pronostico.png` | Página 3 con la comparación real frente a predicciones |
| `42_dashboard_propinas.png` | Página 4 con la curva ROC y la matriz de confusión |
