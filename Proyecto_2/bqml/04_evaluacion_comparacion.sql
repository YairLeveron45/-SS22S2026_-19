-- =============================================================================
-- bqml/04_evaluacion_comparacion.sql: métricas, iteraciones, importancia de
-- variables y selección de modelos.
--
-- Cada modelo se evalúa en dos conjuntos:
--   evaluación  el split que usó al entrenar (validación sep-oct en los modelos
--               de demanda, 20 % aleatorio en los de propina); se usa para
--               elegir el modelo.
--   prueba      noviembre, nunca visto. Se reporta como estimación final; no se
--               usa para elegir, porque eso filtraría la prueba a la selección.
--
-- Ejecutar el archivo completo. Las tablas ml_* alimentan el dashboard.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Métricas de regresión: MAE, RMSE, error absoluto mediano y R².
--    Incluye el baseline ingenuo "misma hora de la semana anterior": un modelo
--    solo vale la pena si le gana a esa regla trivial.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_metricas_regresion AS
SELECT 'reg_demanda_lineal_v1' AS modelo, 'LINEAR_REG' AS algoritmo, 'CUSTOM temporal' AS split, 'validacion sep-oct' AS conjunto,
  mean_absolute_error AS mae, SQRT(mean_squared_error) AS rmse, median_absolute_error AS medae, r2_score AS r2
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_lineal_v1)
UNION ALL
SELECT 'reg_demanda_lineal_v1', 'LINEAR_REG', 'CUSTOM temporal', 'prueba noviembre',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_lineal_v1,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba' AND NOT es_estimado))
UNION ALL
SELECT 'reg_demanda_lineal_v2', 'LINEAR_REG', 'CUSTOM temporal', 'validacion sep-oct',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_lineal_v2)
UNION ALL
SELECT 'reg_demanda_lineal_v2', 'LINEAR_REG', 'CUSTOM temporal', 'prueba noviembre',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_lineal_v2,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba' AND NOT es_estimado))
UNION ALL
SELECT 'reg_demanda_boosted_v1', 'BOOSTED_TREE_REGRESSOR', 'CUSTOM temporal', 'validacion sep-oct',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_boosted_v1)
UNION ALL
SELECT 'reg_demanda_boosted_v1', 'BOOSTED_TREE_REGRESSOR', 'CUSTOM temporal', 'prueba noviembre',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_boosted_v1,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba' AND NOT es_estimado))
UNION ALL
SELECT 'reg_demanda_boosted_v2', 'BOOSTED_TREE_REGRESSOR', 'CUSTOM temporal', 'validacion sep-oct',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_boosted_v2)
UNION ALL
SELECT 'reg_demanda_boosted_v2', 'BOOSTED_TREE_REGRESSOR', 'CUSTOM temporal', 'prueba noviembre',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_boosted_v2,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba' AND NOT es_estimado))
UNION ALL
SELECT 'reg_demanda_lineal_aleatorio', 'LINEAR_REG', 'RANDOM 20 %', 'evaluacion aleatoria 20%',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_lineal_aleatorio)
UNION ALL
SELECT 'reg_demanda_lineal_aleatorio', 'LINEAR_REG', 'RANDOM 20 %', 'prueba noviembre',
  mean_absolute_error, SQRT(mean_squared_error), median_absolute_error, r2_score
FROM ML.EVALUATE(MODEL nyc_taxi_2022.reg_demanda_lineal_aleatorio,
  (SELECT * FROM nyc_taxi_2022.ml_demanda_horaria WHERE conjunto = 'prueba' AND NOT es_estimado))
UNION ALL
SELECT
  'ingenuo_semana_anterior',
  'BASELINE',
  'sin entrenamiento',
  IF(conjunto = 'validacion', 'validacion sep-oct', 'prueba noviembre'),
  AVG(ABS(viajes - viajes_lag_168h)),
  SQRT(AVG(POW(viajes - viajes_lag_168h, 2))),
  CAST(APPROX_QUANTILES(ABS(viajes - viajes_lag_168h), 2)[OFFSET(1)] AS FLOAT64),
  1 - SUM(POW(viajes - viajes_lag_168h, 2)) / SUM(POW(viajes - media_conjunto, 2))
FROM (
  SELECT conjunto, viajes, viajes_lag_168h, AVG(viajes) OVER (PARTITION BY conjunto) AS media_conjunto
  FROM nyc_taxi_2022.ml_demanda_horaria
  WHERE conjunto IN ('validacion', 'prueba')
    AND viajes IS NOT NULL
    AND viajes_lag_168h IS NOT NULL
    AND NOT es_estimado
)
GROUP BY conjunto;

-- -----------------------------------------------------------------------------
-- 2. Métricas de clasificación: precisión, recall, F1, accuracy, log loss y
--    ROC-AUC (clase positiva = sin propina, umbral 0.5).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_metricas_clasificacion AS
SELECT 'clf_propina_logistica_v1' AS modelo, 'LOGISTIC_REG' AS algoritmo, 'evaluacion aleatoria 20%' AS conjunto,
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_logistica_v1)
UNION ALL
SELECT 'clf_propina_logistica_v1', 'LOGISTIC_REG', 'prueba noviembre',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_logistica_v1,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'clf_propina_logistica_v2', 'LOGISTIC_REG', 'evaluacion aleatoria 20%',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_logistica_v2)
UNION ALL
SELECT 'clf_propina_logistica_v2', 'LOGISTIC_REG', 'prueba noviembre',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_logistica_v2,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'clf_propina_boosted', 'BOOSTED_TREE_CLASSIFIER', 'evaluacion aleatoria 20%',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_boosted)
UNION ALL
SELECT 'clf_propina_boosted', 'BOOSTED_TREE_CLASSIFIER', 'prueba noviembre',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_boosted,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'clf_propina_con_fuga', 'LOGISTIC_REG (fuga)', 'evaluacion aleatoria 20%',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_con_fuga)
UNION ALL
SELECT 'clf_propina_con_fuga', 'LOGISTIC_REG (fuga)', 'prueba noviembre',
  precision, recall, f1_score, accuracy, log_loss, roc_auc
FROM ML.EVALUATE(MODEL nyc_taxi_2022.clf_propina_con_fuga,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'));

-- -----------------------------------------------------------------------------
-- 3. Curvas ROC en evaluación (para elegir el umbral) y en prueba (para el
--    dashboard).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_curva_roc AS
SELECT 'clf_propina_logistica_v1' AS modelo, 'evaluacion' AS conjunto,
  threshold, false_positive_rate AS fpr, recall AS tpr,
  true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_logistica_v1)
UNION ALL
SELECT 'clf_propina_logistica_v1', 'prueba',
  threshold, false_positive_rate, recall, true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_logistica_v1,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'clf_propina_logistica_v2', 'evaluacion',
  threshold, false_positive_rate, recall, true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_logistica_v2)
UNION ALL
SELECT 'clf_propina_logistica_v2', 'prueba',
  threshold, false_positive_rate, recall, true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_logistica_v2,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'clf_propina_boosted', 'evaluacion',
  threshold, false_positive_rate, recall, true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_boosted)
UNION ALL
SELECT 'clf_propina_boosted', 'prueba',
  threshold, false_positive_rate, recall, true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_boosted,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'))
UNION ALL
SELECT 'clf_propina_con_fuga', 'prueba',
  threshold, false_positive_rate, recall, true_positives, false_positives, true_negatives, false_negatives
FROM ML.ROC_CURVE(MODEL nyc_taxi_2022.clf_propina_con_fuga,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'));

-- -----------------------------------------------------------------------------
-- 4. Matriz de confusión con umbral 0.5 en noviembre (evidencia directa de
--    BigQuery ML). La matriz con el umbral óptimo se calcula en
--    05_predicciones.sql.
-- -----------------------------------------------------------------------------
SELECT *
FROM ML.CONFUSION_MATRIX(MODEL nyc_taxi_2022.clf_propina_logistica_v2,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'));

SELECT *
FROM ML.CONFUSION_MATRIX(MODEL nyc_taxi_2022.clf_propina_boosted,
  (SELECT * FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'prueba'));

-- -----------------------------------------------------------------------------
-- 5. Iteraciones de entrenamiento: pérdida en entrenamiento y evaluación por
--    iteración. Muestra la convergencia y si la parada temprana cortó antes.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_iteraciones AS
SELECT 'reg_demanda_lineal_v1' AS modelo, training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.reg_demanda_lineal_v1)
UNION ALL
SELECT 'reg_demanda_lineal_v2', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.reg_demanda_lineal_v2)
UNION ALL
SELECT 'reg_demanda_boosted_v1', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.reg_demanda_boosted_v1)
UNION ALL
SELECT 'reg_demanda_boosted_v2', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.reg_demanda_boosted_v2)
UNION ALL
SELECT 'reg_demanda_lineal_aleatorio', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.reg_demanda_lineal_aleatorio)
UNION ALL
SELECT 'clf_propina_logistica_v1', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.clf_propina_logistica_v1)
UNION ALL
SELECT 'clf_propina_logistica_v2', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.clf_propina_logistica_v2)
UNION ALL
SELECT 'clf_propina_boosted', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.clf_propina_boosted)
UNION ALL
SELECT 'clf_propina_con_fuga', training_run, iteration, loss, eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL nyc_taxi_2022.clf_propina_con_fuga);

-- Resumen: iteraciones ejecutadas y pérdida final por modelo.
SELECT
  modelo,
  COUNT(*) AS iteraciones,
  ROUND(ARRAY_AGG(loss IGNORE NULLS ORDER BY iteration DESC LIMIT 1)[SAFE_OFFSET(0)], 4) AS loss_final,
  ROUND(ARRAY_AGG(eval_loss IGNORE NULLS ORDER BY iteration DESC LIMIT 1)[SAFE_OFFSET(0)], 4) AS eval_loss_final,
  ROUND(SUM(duration_ms) / 1000, 1) AS segundos
FROM nyc_taxi_2022.ml_iteraciones
GROUP BY modelo
ORDER BY modelo;

-- -----------------------------------------------------------------------------
-- 6. Importancia de variables de los modelos de árboles (ganancia = mejora
--    promedio de la pérdida aportada por los cortes en esa variable).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_importancia_variables AS
SELECT 'reg_demanda_boosted_v1' AS modelo, feature, importance_weight, importance_gain, importance_cover
FROM ML.FEATURE_IMPORTANCE(MODEL nyc_taxi_2022.reg_demanda_boosted_v1)
UNION ALL
SELECT 'reg_demanda_boosted_v2', feature, importance_weight, importance_gain, importance_cover
FROM ML.FEATURE_IMPORTANCE(MODEL nyc_taxi_2022.reg_demanda_boosted_v2)
UNION ALL
SELECT 'clf_propina_boosted', feature, importance_weight, importance_gain, importance_cover
FROM ML.FEATURE_IMPORTANCE(MODEL nyc_taxi_2022.clf_propina_boosted);

SELECT modelo, feature, ROUND(importance_gain, 2) AS ganancia
FROM nyc_taxi_2022.ml_importancia_variables
ORDER BY modelo, importance_gain DESC;

-- -----------------------------------------------------------------------------
-- 7. Pesos de los modelos lineales (variables estandarizadas, comparables entre
--    sí).
-- -----------------------------------------------------------------------------
-- 7a. Variables numéricas del modelo lineal de demanda.
SELECT processed_input AS variable, ROUND(weight, 4) AS peso
FROM ML.WEIGHTS(MODEL nyc_taxi_2022.reg_demanda_lineal_v2, STRUCT(TRUE AS standardize))
WHERE weight IS NOT NULL
ORDER BY ABS(weight) DESC;

-- 7b. Categorías de la logística v2: un peso positivo aumenta la probabilidad
--     de que el viaje termine sin propina.
SELECT w.processed_input AS variable, cw.category AS categoria, ROUND(cw.weight, 4) AS peso
FROM ML.WEIGHTS(MODEL nyc_taxi_2022.clf_propina_logistica_v2, STRUCT(TRUE AS standardize)) AS w,
UNNEST(w.category_weights) AS cw
WHERE w.processed_input IN ('proveedor', 'tipo_dia', 'ruta_borough', 'codigo_tarifa', 'distancia_decil')
ORDER BY variable, peso DESC;

-- -----------------------------------------------------------------------------
-- 8. Comparación y selección.
-- -----------------------------------------------------------------------------
-- 8a. Demanda: evaluación frente a prueba por modelo. El modelo final es el de
--     menor RMSE en validación (sep-oct), siempre que supere al baseline.
SELECT
  modelo,
  algoritmo,
  split,
  ROUND(MAX(IF(conjunto != 'prueba noviembre', rmse, NULL)), 2) AS rmse_evaluacion,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', rmse, NULL)), 2) AS rmse_prueba,
  ROUND(MAX(IF(conjunto != 'prueba noviembre', mae, NULL)), 2) AS mae_evaluacion,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', mae, NULL)), 2) AS mae_prueba,
  ROUND(MAX(IF(conjunto != 'prueba noviembre', r2, NULL)), 4) AS r2_evaluacion,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', r2, NULL)), 4) AS r2_prueba
FROM nyc_taxi_2022.ml_metricas_regresion
GROUP BY modelo, algoritmo, split
ORDER BY rmse_evaluacion;

-- 8b. Fuga por split: el split aleatorio evalúa sobre días ya vistos. La brecha
--     entre su error de evaluación y su error real en noviembre se compara con
--     la del split temporal.
SELECT
  modelo,
  split,
  ROUND(MAX(IF(conjunto != 'prueba noviembre', rmse, NULL)), 2) AS rmse_reportado_al_entrenar,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', rmse, NULL)), 2) AS rmse_real_noviembre,
  ROUND(100 * (MAX(IF(conjunto = 'prueba noviembre', rmse, NULL))
             / MAX(IF(conjunto != 'prueba noviembre', rmse, NULL)) - 1), 1) AS brecha_pct
FROM nyc_taxi_2022.ml_metricas_regresion
WHERE modelo IN ('reg_demanda_lineal_v2', 'reg_demanda_lineal_aleatorio')
GROUP BY modelo, split;

-- 8c. Propinas: evaluación frente a prueba por modelo. El modelo final es el de
--     mayor ROC-AUC en la evaluación aleatoria; el F1 de la clase minoritaria
--     desempata.
SELECT
  modelo,
  algoritmo,
  ROUND(MAX(IF(conjunto = 'evaluacion aleatoria 20%', roc_auc, NULL)), 4) AS auc_evaluacion,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', roc_auc, NULL)), 4) AS auc_prueba,
  ROUND(MAX(IF(conjunto = 'evaluacion aleatoria 20%', f1_score, NULL)), 4) AS f1_evaluacion,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', f1_score, NULL)), 4) AS f1_prueba,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', precision, NULL)), 4) AS precision_prueba,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', recall, NULL)), 4) AS recall_prueba,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', log_loss, NULL)), 4) AS log_loss_prueba
FROM nyc_taxi_2022.ml_metricas_clasificacion
GROUP BY modelo, algoritmo
ORDER BY auc_evaluacion DESC;

-- 8d. Umbral de decisión por modelo según el índice de Youden (TPR - FPR),
--     calculado sobre la evaluación y no sobre noviembre.
SELECT
  modelo,
  ROUND(threshold, 4) AS umbral,
  ROUND(tpr, 4) AS tpr,
  ROUND(fpr, 4) AS fpr,
  ROUND(tpr - fpr, 4) AS youden_j
FROM nyc_taxi_2022.ml_curva_roc
WHERE conjunto = 'evaluacion'
QUALIFY ROW_NUMBER() OVER (PARTITION BY modelo ORDER BY tpr - fpr DESC) = 1
ORDER BY modelo;
