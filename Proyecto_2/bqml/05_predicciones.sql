-- =============================================================================
-- bqml/05_predicciones.sql: predicciones sobre registros nuevos.
--
-- 1. Pronóstico rodante (rolling forecast) de demanda para noviembre de 2022.
--    Cada día de noviembre se pronostica con la información real disponible
--    hasta el día anterior (rezagos de 24 h o más), como si el modelo corriera
--    cada noche. El origen del pronóstico avanza un día a la vez y el horizonte
--    es siempre el día siguiente.
-- 2. Probabilidad de viaje sin propina para los viajes de noviembre.
-- 3. Matrices de confusión con umbral 0.5 y con el umbral de Youden.
-- 4. Predicción sobre viajes hipotéticos que no existen en el dataset.
--
-- Ejecutar el archivo completo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Pronóstico de demanda de noviembre en formato largo: una fila por hora,
--    borough y serie (real, baseline y cada modelo). En Looker Studio "serie"
--    se usa como dimensión de desglose para comparar las curvas.
--    Las predicciones negativas se recortan a 0 (no existen viajes negativos).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_pronostico_demanda AS
SELECT 'Real' AS serie, hora, fecha, borough, IF(es_estimado, NULL, CAST(viajes AS FLOAT64)) AS viajes
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto = 'prueba'
UNION ALL
SELECT 'Baseline semana anterior', hora, fecha, borough, CAST(viajes_lag_168h AS FLOAT64)
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto = 'prueba'
UNION ALL
SELECT 'Lineal v1', hora, fecha, borough, GREATEST(predicted_viajes, 0)
FROM ML.PREDICT(MODEL nyc_taxi_2022.reg_demanda_lineal_v1,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'Lineal v2', hora, fecha, borough, GREATEST(predicted_viajes, 0)
FROM ML.PREDICT(MODEL nyc_taxi_2022.reg_demanda_lineal_v2,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'Boosted v1', hora, fecha, borough, GREATEST(predicted_viajes, 0)
FROM ML.PREDICT(MODEL nyc_taxi_2022.reg_demanda_boosted_v1,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'Boosted v2', hora, fecha, borough, GREATEST(predicted_viajes, 0)
FROM ML.PREDICT(MODEL nyc_taxi_2022.reg_demanda_boosted_v2,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba'));

-- 1a. Error diario por serie (suma de las 24 horas y de los 4 boroughs):
--     muestra en qué días falla cada modelo (por ejemplo, Thanksgiving).
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_pronostico_error_diario AS
WITH diario AS (
  SELECT fecha, serie, SUM(viajes) AS viajes
  FROM nyc_taxi_2022.ml_pronostico_demanda
  GROUP BY fecha, serie
)
SELECT
  p.fecha,
  p.serie,
  r.viajes AS viajes_reales,
  ROUND(p.viajes, 0) AS viajes_pronosticados,
  ROUND(p.viajes - r.viajes, 0) AS error,
  ROUND(100 * SAFE_DIVIDE(ABS(p.viajes - r.viajes), r.viajes), 2) AS error_abs_pct
FROM diario AS p
JOIN diario AS r
  ON r.fecha = p.fecha
 AND r.serie = 'Real'
WHERE p.serie != 'Real';

-- 1b. Resumen: error porcentual absoluto medio diario por serie.
SELECT
  serie,
  ROUND(AVG(error_abs_pct), 2) AS mape_diario_pct,
  ROUND(MAX(error_abs_pct), 2) AS peor_dia_pct
FROM nyc_taxi_2022.ml_pronostico_error_diario
GROUP BY serie
ORDER BY mape_diario_pct;

-- -----------------------------------------------------------------------------
-- 2. Predicciones de propina para noviembre con los tres modelos válidos.
--    prob_sin_propina se extrae del arreglo de probabilidades de ML.PREDICT.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_pred_propina AS
SELECT
  'clf_propina_logistica_v1' AS modelo, trip_id, fecha, hora_dia, borough_origen,
  sin_propina AS real, predicted_sin_propina AS predicho_05,
  (SELECT p.prob FROM UNNEST(predicted_sin_propina_probs) AS p WHERE p.label = 1) AS prob_sin_propina
FROM ML.PREDICT(MODEL nyc_taxi_2022.clf_propina_logistica_v1,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT
  'clf_propina_logistica_v2', trip_id, fecha, hora_dia, borough_origen,
  sin_propina, predicted_sin_propina,
  (SELECT p.prob FROM UNNEST(predicted_sin_propina_probs) AS p WHERE p.label = 1)
FROM ML.PREDICT(MODEL nyc_taxi_2022.clf_propina_logistica_v2,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT
  'clf_propina_boosted', trip_id, fecha, hora_dia, borough_origen,
  sin_propina, predicted_sin_propina,
  (SELECT p.prob FROM UNNEST(predicted_sin_propina_probs) AS p WHERE p.label = 1)
FROM ML.PREDICT(MODEL nyc_taxi_2022.clf_propina_boosted,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'));

-- 2a. Serie diaria: tasa real de viajes sin propina frente a la probabilidad
--     media pronosticada por cada modelo. Los modelos con auto_class_weights
--     sobreestiman la probabilidad a propósito (reponderan la clase minoritaria),
--     así que se comparan por la forma de la curva, no por el nivel.
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_pred_propina_diaria AS
SELECT
  fecha,
  modelo,
  COUNT(*) AS viajes,
  AVG(real) AS tasa_real_sin_propina,
  AVG(prob_sin_propina) AS prob_media_pronosticada
FROM nyc_taxi_2022.ml_pred_propina
GROUP BY fecha, modelo;

-- -----------------------------------------------------------------------------
-- 3. Matrices de confusión de noviembre con dos umbrales:
--    - 0.5, el umbral por defecto.
--    - el de Youden, elegido en el conjunto de evaluación (no en noviembre).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_matriz_confusion AS
WITH umbrales AS (
  SELECT modelo, 'umbral 0.5' AS criterio, 0.5 AS umbral
  FROM (SELECT DISTINCT modelo FROM nyc_taxi_2022.ml_pred_propina)
  UNION ALL
  SELECT modelo, 'umbral Youden', threshold
  FROM nyc_taxi_2022.ml_curva_roc
  WHERE conjunto = 'evaluacion'
    AND modelo != 'clf_propina_con_fuga'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY modelo ORDER BY tpr - fpr DESC) = 1
)
SELECT
  p.modelo,
  u.criterio,
  u.umbral,
  IF(p.real = 1, 'Real: sin propina', 'Real: con propina') AS clase_real,
  IF(p.prob_sin_propina >= u.umbral, 'Pred: sin propina', 'Pred: con propina') AS clase_predicha,
  COUNT(*) AS viajes
FROM nyc_taxi_2022.ml_pred_propina AS p
JOIN umbrales AS u
  ON u.modelo = p.modelo
GROUP BY p.modelo, u.criterio, u.umbral, clase_real, clase_predicha;

-- 3a. Precisión, recall y F1 de la clase "sin propina" en cada umbral.
WITH conteos AS (
  SELECT
    modelo,
    criterio,
    umbral,
    SUM(IF(clase_real = 'Real: sin propina' AND clase_predicha = 'Pred: sin propina', viajes, 0)) AS vp,
    SUM(IF(clase_real = 'Real: con propina' AND clase_predicha = 'Pred: sin propina', viajes, 0)) AS fp,
    SUM(IF(clase_real = 'Real: sin propina' AND clase_predicha = 'Pred: con propina', viajes, 0)) AS fn,
    SUM(IF(clase_real = 'Real: con propina' AND clase_predicha = 'Pred: con propina', viajes, 0)) AS vn
  FROM nyc_taxi_2022.ml_matriz_confusion
  GROUP BY modelo, criterio, umbral
)
SELECT
  modelo,
  criterio,
  ROUND(umbral, 4) AS umbral,
  vp, fp, fn, vn,
  ROUND(SAFE_DIVIDE(vp, vp + fp), 4) AS precision_sin_propina,
  ROUND(SAFE_DIVIDE(vp, vp + fn), 4) AS recall_sin_propina,
  ROUND(SAFE_DIVIDE(2 * vp, 2 * vp + fp + fn), 4) AS f1_sin_propina,
  ROUND(SAFE_DIVIDE(vp + vn, vp + fp + fn + vn), 4) AS accuracy
FROM conteos
ORDER BY modelo, criterio;

-- -----------------------------------------------------------------------------
-- 4. Registros nuevos: viajes hipotéticos que no existen en el dataset.
--    Zonas: 79 East Village, 255 Williamsburg (North Side), 132 JFK,
--    161 Midtown Center, 237 Upper East Side South, 236 Upper East Side North.
--    dia_semana: 1 = domingo ... 7 = sábado.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_viajes_hipoteticos AS
SELECT 'Viernes 23 h, East Village a Williamsburg' AS escenario,
  23 AS hora_dia, 6 AS dia_semana, FALSE AS es_fin_semana,
  'Manhattan' AS borough_origen, 'Brooklyn' AS borough_destino,
  '79' AS zona_origen, '255' AS zona_destino, FALSE AS es_aeropuerto,
  '2' AS proveedor, '1' AS codigo_tarifa, 2 AS pasajeros,
  3.2 AS distancia_mi, 16.0 AS duracion_min, 12.0 AS velocidad_mph,
  14.5 AS tarifa, 0.0 AS peajes, 4.53 AS tarifa_por_milla
UNION ALL
SELECT 'Martes 8 h, JFK a Midtown (tarifa fija)',
  8, 3, FALSE,
  'Queens', 'Manhattan',
  '132', '161', TRUE,
  '1', '2', 1,
  17.5, 55.0, 19.09,
  52.0, 6.55, 2.97
UNION ALL
SELECT 'Domingo 14 h, viaje corto en Upper East Side',
  14, 1, TRUE,
  'Manhattan', 'Manhattan',
  '237', '236', FALSE,
  '2', '1', 1,
  1.1, 7.0, 9.43,
  7.0, 0.0, 6.36;

SELECT
  l.escenario,
  ROUND((SELECT p.prob FROM UNNEST(l.predicted_sin_propina_probs) AS p WHERE p.label = 1), 4) AS prob_sin_propina_logistica_v2,
  ROUND((SELECT p.prob FROM UNNEST(b.predicted_sin_propina_probs) AS p WHERE p.label = 1), 4) AS prob_sin_propina_boosted
FROM ML.PREDICT(MODEL nyc_taxi_2022.clf_propina_logistica_v2,
  (SELECT * FROM nyc_taxi_2022.ml_viajes_hipoteticos)) AS l
JOIN ML.PREDICT(MODEL nyc_taxi_2022.clf_propina_boosted,
  (SELECT * FROM nyc_taxi_2022.ml_viajes_hipoteticos)) AS b
  ON b.escenario = l.escenario
ORDER BY l.escenario;
