-- =============================================================================
-- bqml/02_modelos_demanda.sql: Problema A, regresión de la demanda horaria.
--
-- Objetivo: pronosticar al cierre del día D-1 los viajes de cada hora del día D
--   por borough, para planificar la oferta de taxis.
-- Variable objetivo (label): viajes = viajes que inician en el borough durante
--   la hora.
-- Variables de entrada: calendario (hora, día, fin de semana, feriado), borough
--   e historia disponible al cierre del día anterior (rezagos de 24 h o más).
-- Split: CUSTOM con es_eval (validación = septiembre y octubre). Noviembre
--   (prueba) no aparece en ninguna consulta de entrenamiento.
--
-- Modelos y diferencias de hiperparámetros:
--   reg_demanda_lineal_v1         LINEAR_REG, 10 iteraciones, sin regularización
--   reg_demanda_lineal_v2         LINEAR_REG, hasta 40 iteraciones, L2 = 1.0,
--                                 parada temprana
--   reg_demanda_boosted_v1        BOOSTED_TREE_REGRESSOR, profundidad 6,
--                                 learn_rate 0.3, 50 rondas
--   reg_demanda_boosted_v2        BOOSTED_TREE_REGRESSOR, profundidad 8,
--                                 learn_rate 0.1, 150 rondas, submuestreo 0.8, L2
--   reg_demanda_lineal_aleatorio  igual que lineal_v2 pero con split RANDOM.
--                                 sirve para demostrar por qué ese split no
--                                 aplica a series de tiempo
--
-- Ejecutar el archivo completo (crea los 5 modelos en secuencia).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A1. Regresión lineal, configuración base.
-- La interacción borough x tipo de día x hora entra como perfil_horario porque
-- el modelo lineal no la aprende solo. BigQuery ML estandariza las variables
-- numéricas y aplica one-hot a las categóricas automáticamente.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.reg_demanda_lineal_v1
OPTIONS (
  model_type = 'LINEAR_REG',
  input_label_cols = ['viajes'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  optimize_strategy = 'BATCH_GRADIENT_DESCENT',
  learn_rate_strategy = 'LINE_SEARCH',
  max_iterations = 10,
  l2_reg = 0.0,
  early_stop = FALSE
) AS
SELECT
  viajes,
  perfil_horario,
  es_feriado,
  viajes_lag_24h,
  viajes_lag_48h,
  viajes_lag_168h,
  prom_misma_hora_7d,
  prom_mismo_dia_hora_4sem,
  viajes_dia_anterior,
  es_eval
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto IN ('entrenamiento', 'validacion')
  AND viajes IS NOT NULL;

-- -----------------------------------------------------------------------------
-- A2. Regresión lineal con más iteraciones, regularización L2 y parada temprana.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.reg_demanda_lineal_v2
OPTIONS (
  model_type = 'LINEAR_REG',
  input_label_cols = ['viajes'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  optimize_strategy = 'BATCH_GRADIENT_DESCENT',
  learn_rate_strategy = 'LINE_SEARCH',
  max_iterations = 40,
  l2_reg = 1.0,
  early_stop = TRUE,
  min_rel_progress = 0.005
) AS
SELECT
  viajes,
  perfil_horario,
  es_feriado,
  viajes_lag_24h,
  viajes_lag_48h,
  viajes_lag_168h,
  prom_misma_hora_7d,
  prom_mismo_dia_hora_4sem,
  viajes_dia_anterior,
  es_eval
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto IN ('entrenamiento', 'validacion')
  AND viajes IS NOT NULL;

-- -----------------------------------------------------------------------------
-- A3. Boosted trees, configuración base.
-- Los árboles aprenden las interacciones directamente, así que reciben hora,
-- día y borough por separado en lugar del perfil cruzado.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.reg_demanda_boosted_v1
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols = ['viajes'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  booster_type = 'GBTREE',
  max_iterations = 50,
  learn_rate = 0.3,
  max_tree_depth = 6,
  subsample = 1.0,
  early_stop = TRUE,
  min_rel_progress = 0.01
) AS
SELECT
  viajes,
  borough,
  hora_dia,
  dia_semana,
  es_fin_semana,
  es_feriado,
  viajes_lag_24h,
  viajes_lag_48h,
  viajes_lag_168h,
  prom_misma_hora_7d,
  prom_mismo_dia_hora_4sem,
  viajes_dia_anterior,
  es_eval
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto IN ('entrenamiento', 'validacion')
  AND viajes IS NOT NULL;

-- -----------------------------------------------------------------------------
-- A4. Boosted trees con árboles más profundos, menor tasa de aprendizaje, más
-- rondas y regularización (submuestreo de filas y columnas, L2, peso mínimo por
-- hoja) para controlar el sobreajuste.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.reg_demanda_boosted_v2
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols = ['viajes'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  booster_type = 'GBTREE',
  max_iterations = 150,
  learn_rate = 0.1,
  max_tree_depth = 8,
  subsample = 0.8,
  colsample_bytree = 0.8,
  l2_reg = 1.0,
  min_tree_child_weight = 5,
  early_stop = TRUE,
  min_rel_progress = 0.001
) AS
SELECT
  viajes,
  borough,
  hora_dia,
  dia_semana,
  es_fin_semana,
  es_feriado,
  viajes_lag_24h,
  viajes_lag_48h,
  viajes_lag_168h,
  prom_misma_hora_7d,
  prom_mismo_dia_hora_4sem,
  viajes_dia_anterior,
  es_eval
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto IN ('entrenamiento', 'validacion')
  AND viajes IS NOT NULL;

-- -----------------------------------------------------------------------------
-- A5. Demostración: mismo modelo que lineal_v2 pero con split RANDOM y
-- data_split_eval_fraction = 0.2. Las horas de evaluación quedan intercaladas con
-- las de entrenamiento, así que el modelo se evalúa sobre días que ya vio. En
-- 04_evaluacion_comparacion.sql se compara su métrica de evaluación con su
-- desempeño real en noviembre.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL nyc_taxi_2022.reg_demanda_lineal_aleatorio
OPTIONS (
  model_type = 'LINEAR_REG',
  input_label_cols = ['viajes'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  optimize_strategy = 'BATCH_GRADIENT_DESCENT',
  learn_rate_strategy = 'LINE_SEARCH',
  max_iterations = 40,
  l2_reg = 1.0,
  early_stop = TRUE,
  min_rel_progress = 0.005
) AS
SELECT
  viajes,
  perfil_horario,
  es_feriado,
  viajes_lag_24h,
  viajes_lag_48h,
  viajes_lag_168h,
  prom_misma_hora_7d,
  prom_mismo_dia_hora_4sem,
  viajes_dia_anterior
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto IN ('entrenamiento', 'validacion')
  AND viajes IS NOT NULL;
