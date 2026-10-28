-- Controles pendientes: solo lectura de tablas existentes. Sin entrenamiento.
SELECT 'A1_split_demanda' AS control, TO_JSON_STRING(resultado) AS resultado
FROM (
SELECT
  conjunto,
  COUNT(*) AS filas,
  COUNTIF(viajes IS NULL) AS filas_sin_dato,
  COUNTIF(es_estimado) AS filas_estimadas,
  MIN(fecha) AS desde,
  MAX(fecha) AS hasta,
  ROUND(AVG(viajes), 1) AS viajes_hora_promedio,
  COUNTIF(es_eval) AS filas_eval
FROM nyc_taxi_2022.ml_demanda_horaria
GROUP BY conjunto
ORDER BY desde
) AS resultado
UNION ALL
SELECT 'A2_control_rezagos' AS control, TO_JSON_STRING(resultado) AS resultado
FROM (
SELECT
  COUNT(*) AS filas_comparadas,
  COUNTIF(a.viajes_lag_24h != b.viajes) AS rezagos_incorrectos
FROM nyc_taxi_2022.ml_demanda_horaria AS a
JOIN nyc_taxi_2022.ml_demanda_horaria AS b
  ON b.borough = a.borough
 AND b.hora = DATETIME_SUB(a.hora, INTERVAL 24 HOUR)
) AS resultado
UNION ALL
SELECT 'B1_split_propinas' AS control, TO_JSON_STRING(resultado) AS resultado
FROM (
SELECT
  conjunto,
  COUNT(*) AS viajes,
  SUM(sin_propina) AS viajes_sin_propina,
  ROUND(100 * AVG(sin_propina), 2) AS pct_sin_propina
FROM nyc_taxi_2022.ml_propinas
GROUP BY conjunto
ORDER BY conjunto
) AS resultado
UNION ALL
SELECT 'C1_comparacion_split' AS control, TO_JSON_STRING(resultado) AS resultado
FROM (
SELECT
  modelo,
  split,
  ROUND(MAX(IF(conjunto != 'prueba noviembre', rmse, NULL)), 2) AS rmse_reportado_al_entrenar,
  ROUND(MAX(IF(conjunto = 'prueba noviembre', rmse, NULL)), 2) AS rmse_real_noviembre,
  ROUND(100 * (MAX(IF(conjunto = 'prueba noviembre', rmse, NULL))
             / MAX(IF(conjunto != 'prueba noviembre', rmse, NULL)) - 1), 1) AS brecha_pct
FROM nyc_taxi_2022.ml_metricas_regresion
WHERE modelo IN ('reg_demanda_lineal_v2', 'reg_demanda_lineal_aleatorio')
GROUP BY modelo, split
) AS resultado
UNION ALL
SELECT 'C2_comparacion_fuga_variable' AS control, TO_JSON_STRING(resultado) AS resultado
FROM (
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
ORDER BY auc_evaluacion DESC
) AS resultado
ORDER BY control, resultado;