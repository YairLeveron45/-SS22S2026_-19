-- =============================================================================
-- bqml/03_modelos_propina.sql: Problema B, clasificación de viajes sin propina.
--
-- Objetivo: estimar, al momento del pago con tarjeta y antes de que el pasajero
--   elija la propina, la probabilidad de que no deje propina.
-- Variable objetivo (label): sin_propina (1 = propina igual a 0).
-- Variables de entrada: hora, tipo de día, zonas y boroughs, aeropuerto,
--   proveedor del taxímetro, código de tarifa, pasajeros, distancia, duración,
--   velocidad, tarifa y peajes.
-- Split: RANDOM con data_split_eval_fraction = 0.2 sobre enero-octubre.
--   BigQuery ML hace un split aleatorio determinístico, así que todos los modelos
--   se evalúan sobre las mismas filas. Noviembre queda como prueba temporal.
--
-- Modelos y diferencias de hiperparámetros:
--   clf_propina_logistica_v1  LOGISTIC_REG sin pesos de clase ni regularización,
--                             15 iteraciones
--   clf_propina_logistica_v2  LOGISTIC_REG con auto_class_weights, L2 = 0.5,
--                             hasta 30 iteraciones
--   clf_propina_boosted       BOOSTED_TREE_CLASSIFIER con auto_class_weights,
--                             profundidad 8, learn_rate 0.2, submuestreo 0.8
--   clf_propina_con_fuga      LOGISTIC_REG que usa el total con propina.
--                             Demostración de fuga, NO es un modelo válido.
--
-- Ejecutar el archivo completo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- B1. Regresión logística base.
-- TRANSFORM define la ingeniería de características dentro del modelo: se guarda
-- con él y se aplica igual en ML.EVALUATE y ML.PREDICT. Las estadísticas de
-- imputación y de deciles se calculan durante el entrenamiento; noviembre no
-- entra en ese cálculo.
--   hora_cat         la hora como categoría: el efecto de la hora no es lineal.
--   tipo_dia         laboral o fin de semana.
--   ruta_borough     cruce origen-destino a nivel borough.
--   pasajeros_imp    pasajeros con la mediana cuando el dato falta.
--   distancia_decil  deciles de distancia: captura la relación no lineal (los
--   duracion_decil   viajes muy cortos se comportan distinto).
--   log_tarifa       reduce la asimetría de la tarifa.
--   con_peaje        indicador de peaje (viajes interborough o aeropuerto).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.clf_propina_logistica_v1
TRANSFORM (
  sin_propina,
  CAST(hora_dia AS STRING) AS hora_cat,
  IF(es_fin_semana, 'fin_semana', 'entre_semana') AS tipo_dia,
  CONCAT(borough_origen, '-', borough_destino) AS ruta_borough,
  zona_origen,
  zona_destino,
  es_aeropuerto,
  proveedor,
  codigo_tarifa,
  ML.IMPUTER(pasajeros, 'median') OVER () AS pasajeros_imp,
  ML.QUANTILE_BUCKETIZE(distancia_mi, 10) OVER () AS distancia_decil,
  ML.QUANTILE_BUCKETIZE(duracion_min, 10) OVER () AS duracion_decil,
  LN(1 + tarifa) AS log_tarifa,
  velocidad_mph,
  peajes > 0 AS con_peaje
)
OPTIONS (
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['sin_propina'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  auto_class_weights = FALSE,
  max_iterations = 15,
  l2_reg = 0.0
) AS
SELECT
  sin_propina, hora_dia, es_fin_semana, borough_origen, borough_destino,
  zona_origen, zona_destino, es_aeropuerto, proveedor, codigo_tarifa,
  pasajeros, distancia_mi, duracion_min, tarifa, velocidad_mph, peajes
FROM nyc_taxi_2022.ml_propinas
WHERE conjunto = 'entrenamiento';

-- -----------------------------------------------------------------------------
-- B2. Regresión logística con pesos de clase y regularización.
-- auto_class_weights pondera cada clase de forma inversa a su frecuencia, para
-- que la clase minoritaria (sin propina) no quede ignorada. L2 reduce el
-- sobreajuste de las cientos de columnas one-hot de las zonas.
-- Usa la misma TRANSFORM que B1.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.clf_propina_logistica_v2
TRANSFORM (
  sin_propina,
  CAST(hora_dia AS STRING) AS hora_cat,
  IF(es_fin_semana, 'fin_semana', 'entre_semana') AS tipo_dia,
  CONCAT(borough_origen, '-', borough_destino) AS ruta_borough,
  zona_origen,
  zona_destino,
  es_aeropuerto,
  proveedor,
  codigo_tarifa,
  ML.IMPUTER(pasajeros, 'median') OVER () AS pasajeros_imp,
  ML.QUANTILE_BUCKETIZE(distancia_mi, 10) OVER () AS distancia_decil,
  ML.QUANTILE_BUCKETIZE(duracion_min, 10) OVER () AS duracion_decil,
  LN(1 + tarifa) AS log_tarifa,
  velocidad_mph,
  peajes > 0 AS con_peaje
)
OPTIONS (
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['sin_propina'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  auto_class_weights = TRUE,
  max_iterations = 30,
  l2_reg = 0.5,
  early_stop = TRUE,
  min_rel_progress = 0.005
) AS
SELECT
  sin_propina, hora_dia, es_fin_semana, borough_origen, borough_destino,
  zona_origen, zona_destino, es_aeropuerto, proveedor, codigo_tarifa,
  pasajeros, distancia_mi, duracion_min, tarifa, velocidad_mph, peajes
FROM nyc_taxi_2022.ml_propinas
WHERE conjunto = 'entrenamiento';

-- -----------------------------------------------------------------------------
-- B3. Boosted trees.
-- Los árboles no necesitan deciles, logaritmos ni cruces: encuentran los cortes
-- y las interacciones por sí solos, así que reciben las variables originales más
-- tarifa_por_milla. Los NULL de pasajeros se manejan de forma nativa.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.clf_propina_boosted
OPTIONS (
  model_type = 'BOOSTED_TREE_CLASSIFIER',
  input_label_cols = ['sin_propina'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  auto_class_weights = TRUE,
  booster_type = 'GBTREE',
  max_iterations = 60,
  learn_rate = 0.2,
  max_tree_depth = 8,
  subsample = 0.8,
  colsample_bytree = 0.8,
  min_tree_child_weight = 10,
  early_stop = TRUE,
  min_rel_progress = 0.005
) AS
SELECT
  sin_propina, hora_dia, dia_semana, es_fin_semana, borough_origen,
  borough_destino, zona_origen, zona_destino, es_aeropuerto, proveedor,
  codigo_tarifa, pasajeros, distancia_mi, duracion_min, velocidad_mph, tarifa,
  peajes, tarifa_por_milla
FROM nyc_taxi_2022.ml_propinas
WHERE conjunto = 'entrenamiento';

-- -----------------------------------------------------------------------------
-- B4. DEMOSTRACIÓN DE FUGA. NO es un modelo válido.
-- fuga_total_con_propina incluye la propina: total - tarifa - peajes deja la
-- propina más los recargos, así que el modelo reconstruye buena parte de la
-- etiqueta. Con solo tres variables su ROC-AUC queda muy por encima del de los
-- modelos válidos: muestra cómo una variable posterior al evento infla las
-- métricas. En producción ese dato no existe antes de que el pasajero elija la
-- propina.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.clf_propina_con_fuga
OPTIONS (
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['sin_propina'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  max_iterations = 15
) AS
SELECT
  sin_propina,
  tarifa,
  peajes,
  fuga_total_con_propina
FROM nyc_taxi_2022.ml_propinas
WHERE conjunto = 'entrenamiento';
