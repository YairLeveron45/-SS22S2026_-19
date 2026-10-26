-- =============================================================================
-- bqml/01_preparacion_datos_ml.sql: datasets limpios para los modelos.
--
-- Problema A (regresión): pronosticar con un día de anticipación cuántos viajes
--   inician en cada borough durante cada hora. Tabla ml_demanda_horaria.
-- Problema B (clasificación): estimar, al momento del pago con tarjeta, la
--   probabilidad de que el viaje termine sin propina. Tabla ml_propinas.
--
-- Ejecutar el archivo completo; al final hay consultas de control.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A. ml_demanda_horaria
-- Una fila por hora y borough (Manhattan, Queens, Brooklyn, Bronx). Staten Island
-- y EWR quedan fuera porque casi todas sus horas tienen 0 o 1 viajes.
--
-- Momento de la predicción: al cierre del día D-1 se pronostican las 24 horas del
-- día D. Por eso todas las variables de historia usan datos de al menos 24 horas
-- antes. Un rezago de 1 hora no existiría en ese momento y sería fuga de datos.
--
-- Split temporal (columna conjunto). La tabla pública solo trae enero a noviembre
-- de 2022 (diciembre no fue cargado), así que la prueba es noviembre:
--   descartado     2022-01-01 a 2022-01-28  sin historia suficiente para los rezagos
--   entrenamiento  2022-01-29 a 2022-08-31
--   validacion     2022-09-01 a 2022-10-31  es_eval = TRUE (split CUSTOM)
--   prueba         2022-11-01 a 2022-11-30  nunca entra al entrenamiento ni a la
--                                           selección del modelo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_demanda_horaria AS
WITH conteos AS (
  SELECT
    DATETIME_TRUNC(pickup_datetime, HOUR) AS hora,
    borough_origen AS borough,
    COUNT(*) AS viajes,
    COUNTIF(vendor_id = 2) AS viajes_proveedor_2
  FROM nyc_taxi_2022.vw_viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
    AND borough_origen IN ('Manhattan', 'Queens', 'Brooklyn', 'Bronx')
  GROUP BY hora, borough
),
-- Grilla completa con una fila por hora aunque no haya viajes. Así LAG(viajes, 24)
-- es exactamente "la misma hora del día anterior".
grilla AS (
  SELECT DATETIME(d, TIME(h, 0, 0)) AS hora, b AS borough
  FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', '2022-11-30')) AS d
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 23)) AS h
  CROSS JOIN UNNEST(['Manhattan', 'Queens', 'Brooklyn', 'Bronx']) AS b
),
base AS (
  SELECT
    g.hora,
    g.borough,
    COALESCE(c.viajes, 0) AS viajes_registrados,
    COALESCE(c.viajes_proveedor_2, 0) AS viajes_proveedor_2
  FROM grilla AS g
  LEFT JOIN conteos AS c
    ON c.hora = g.hora
   AND c.borough = g.borough
),
-- Proporción total / proveedor 2 por borough y hora del día en las 4 semanas
-- previas al hueco de noviembre (ver abajo).
factor_proveedor AS (
  SELECT
    borough,
    EXTRACT(HOUR FROM hora) AS hora_dia,
    SAFE_DIVIDE(SUM(viajes_registrados), SUM(viajes_proveedor_2)) AS factor
  FROM base
  WHERE DATE(hora) BETWEEN '2022-10-17' AND '2022-11-13'
  GROUP BY borough, hora_dia
),
-- Fallas de captura de la fuente (ver E19 y E20 en sql/03):
--   - 17-sep 15:00 a 18-sep 23:00 (validación): faltan ~95 % de los registros de
--     ambos proveedores. No hay de dónde estimarlos: quedan NULL, no se entrena ni
--     evalúa contra ellos y los rezagos que dependen de ellos quedan nulos.
--   - 14-nov a 20-nov (prueba): faltan casi todos los viajes del proveedor 1 (~28 %
--     del total). La demanda se estima con los viajes del proveedor 2 por la
--     proporción habitual de su borough y hora. La estimación solo alimenta los
--     rezagos de los días siguientes: esas filas se marcan es_estimado y nunca se
--     usan como objetivo de evaluación.
--   - 10-ago (entrenamiento) también pierde parte del proveedor 1. Es 1 de 215 días
--     y se conserva: corregirlo exigiría reentrenar los modelos (ver README).
serie AS (
  SELECT
    b.hora,
    b.borough,
    CASE
      WHEN b.hora BETWEEN DATETIME '2022-09-17 15:00:00' AND DATETIME '2022-09-18 23:00:00'
        THEN NULL
      WHEN DATE(b.hora) BETWEEN '2022-11-14' AND '2022-11-20'
        THEN CAST(ROUND(b.viajes_proveedor_2 * COALESCE(f.factor, 1)) AS INT64)
      ELSE b.viajes_registrados
    END AS viajes,
    DATE(b.hora) BETWEEN '2022-11-14' AND '2022-11-20' AS es_estimado
  FROM base AS b
  LEFT JOIN factor_proveedor AS f
    ON f.borough = b.borough
   AND f.hora_dia = EXTRACT(HOUR FROM b.hora)
),
-- El total de un día con horas faltantes también queda NULL.
totales_diarios AS (
  SELECT
    borough,
    DATE(hora) AS fecha,
    IF(COUNTIF(viajes IS NULL) > 0, NULL, SUM(viajes)) AS viajes_dia
  FROM serie
  GROUP BY borough, fecha
),
-- Feriados federales de EE. UU. de enero a noviembre de 2022 (fecha observada)
-- y Año Nuevo.
feriados AS (
  SELECT fecha
  FROM UNNEST([
    DATE '2022-01-01', DATE '2022-01-17', DATE '2022-02-21', DATE '2022-05-30',
    DATE '2022-06-20', DATE '2022-07-04', DATE '2022-09-05', DATE '2022-10-10',
    DATE '2022-11-11', DATE '2022-11-24'
  ]) AS fecha
),
variables AS (
  SELECT
    s.hora,
    DATE(s.hora) AS fecha,
    s.borough,
    s.viajes,
    s.es_estimado,
    EXTRACT(HOUR FROM s.hora) AS hora_dia,
    EXTRACT(DAYOFWEEK FROM s.hora) AS dia_semana,
    EXTRACT(DAYOFWEEK FROM s.hora) IN (1, 7) AS es_fin_semana,
    DATE(s.hora) IN (SELECT fecha FROM feriados) AS es_feriado,
    LAG(s.viajes, 24) OVER por_borough AS viajes_lag_24h,
    LAG(s.viajes, 48) OVER por_borough AS viajes_lag_48h,
    LAG(s.viajes, 168) OVER por_borough AS viajes_lag_168h,
    -- Promedio de la misma hora en los 7 días previos (excluye el día actual).
    AVG(s.viajes) OVER (
      PARTITION BY s.borough, EXTRACT(HOUR FROM s.hora)
      ORDER BY s.hora
      ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
    ) AS prom_misma_hora_7d,
    -- Promedio del mismo día de la semana y hora en las 4 semanas previas.
    AVG(s.viajes) OVER (
      PARTITION BY s.borough, EXTRACT(HOUR FROM s.hora), EXTRACT(DAYOFWEEK FROM s.hora)
      ORDER BY s.hora
      ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING
    ) AS prom_mismo_dia_hora_4sem,
    t.viajes_dia AS viajes_dia_anterior
  FROM serie AS s
  LEFT JOIN totales_diarios AS t
    ON t.borough = s.borough
   AND t.fecha = DATE_SUB(DATE(s.hora), INTERVAL 1 DAY)
  WINDOW por_borough AS (PARTITION BY s.borough ORDER BY s.hora)
)
SELECT
  *,
  -- Cruce borough x tipo de día x hora para el modelo lineal, que no aprende
  -- interacciones por sí solo: el pico matutino existe en días laborales de
  -- Manhattan, no en los fines de semana del Bronx.
  CONCAT(
    borough, '_',
    IF(es_fin_semana OR es_feriado, 'descanso', 'laboral'), '_',
    CAST(hora_dia AS STRING)
  ) AS perfil_horario,
  CASE
    WHEN fecha < '2022-01-29' THEN 'descartado'
    WHEN fecha < '2022-09-01' THEN 'entrenamiento'
    WHEN fecha < '2022-11-01' THEN 'validacion'
    ELSE 'prueba'
  END AS conjunto,
  fecha BETWEEN '2022-09-01' AND '2022-10-31' AS es_eval
FROM variables;

-- -----------------------------------------------------------------------------
-- A.1 Control: filas y rango de fechas por conjunto.
-- -----------------------------------------------------------------------------
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
ORDER BY desde;

-- -----------------------------------------------------------------------------
-- A.2 Control de fuga: cada viajes_lag_24h debe coincidir con los viajes reales
--     de 24 horas antes. Resultado esperado: 0 rezagos incorrectos.
-- -----------------------------------------------------------------------------
SELECT
  COUNT(*) AS filas_comparadas,
  COUNTIF(a.viajes_lag_24h != b.viajes) AS rezagos_incorrectos
FROM nyc_taxi_2022.ml_demanda_horaria AS a
JOIN nyc_taxi_2022.ml_demanda_horaria AS b
  ON b.borough = a.borough
 AND b.hora = DATETIME_SUB(a.hora, INTERVAL 24 HOUR);

-- -----------------------------------------------------------------------------
-- A.3 Justificación de variables: correlación de cada variable de historia con
--     el objetivo, calculada solo con entrenamiento.
-- -----------------------------------------------------------------------------
SELECT
  ROUND(CORR(viajes, viajes_lag_24h), 3) AS corr_lag_24h,
  ROUND(CORR(viajes, viajes_lag_48h), 3) AS corr_lag_48h,
  ROUND(CORR(viajes, viajes_lag_168h), 3) AS corr_lag_168h,
  ROUND(CORR(viajes, prom_misma_hora_7d), 3) AS corr_prom_misma_hora_7d,
  ROUND(CORR(viajes, prom_mismo_dia_hora_4sem), 3) AS corr_prom_mismo_dia_hora_4sem,
  ROUND(CORR(viajes, viajes_dia_anterior), 3) AS corr_viajes_dia_anterior
FROM nyc_taxi_2022.ml_demanda_horaria
WHERE conjunto = 'entrenamiento';

-- -----------------------------------------------------------------------------
-- B. ml_propinas
-- Población: viajes pagados con tarjeta. La propina en efectivo no se registra,
-- así que en efectivo "propina = 0" no significa que no hubo propina.
-- Etiqueta: sin_propina = 1 si tip_amount = 0.
-- Variables: solo las conocidas al momento del pago, antes de que el pasajero
-- elija la propina (recorrido, tarifa, peajes, hora, zonas, proveedor).
-- Excluidas: tip_amount (define la etiqueta), total_amount (contiene la propina),
-- pct_propina (se calcula con la propina) y payment_type (constante tras el filtro).
-- Muestra determinística del 3 % por hash de trip_id: reproducible y suficiente
-- para entrenar sin procesar toda la tabla en cada CREATE MODEL.
-- Split: enero-octubre se entrena con split RANDOM (data_split_eval_fraction).
-- Noviembre queda como prueba temporal.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.ml_propinas AS
SELECT
  trip_id,
  pickup_date AS fecha,
  IF(tip_amount = 0, 1, 0) AS sin_propina,
  hora_recogida AS hora_dia,
  dia_semana,
  es_fin_semana,
  borough_origen,
  borough_destino,
  pickup_location_id AS zona_origen,
  dropoff_location_id AS zona_destino,
  es_aeropuerto,
  CAST(vendor_id AS STRING) AS proveedor,
  CAST(rate_code_id AS STRING) AS codigo_tarifa,
  passenger_count AS pasajeros,
  trip_distance AS distancia_mi,
  duracion_min,
  velocidad_mph,
  fare_amount AS tarifa,
  tolls_amount AS peajes,
  ROUND(SAFE_DIVIDE(fare_amount, trip_distance), 2) AS tarifa_por_milla,
  -- Columna de control usada SOLO por clf_propina_con_fuga para demostrar la
  -- fuga: el total incluye la propina, por eso ningún modelo válido la usa.
  total_amount AS fuga_total_con_propina,
  IF(pickup_date < '2022-11-01', 'entrenamiento', 'prueba') AS conjunto
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND payment_type = 1
  AND borough_origen NOT IN ('Desconocido', 'Fuera de NYC')
  AND ABS(MOD(trip_id, 1000)) < 30;

-- -----------------------------------------------------------------------------
-- B.1 Control: tamaño y balance de clases por conjunto.
-- -----------------------------------------------------------------------------
SELECT
  conjunto,
  COUNT(*) AS viajes,
  SUM(sin_propina) AS viajes_sin_propina,
  ROUND(100 * AVG(sin_propina), 2) AS pct_sin_propina
FROM nyc_taxi_2022.ml_propinas
GROUP BY conjunto
ORDER BY conjunto;

-- -----------------------------------------------------------------------------
-- B.2 Justificación de variables categóricas: tasa de "sin propina" por valor
--     (solo entrenamiento, para no mirar el conjunto de prueba).
-- -----------------------------------------------------------------------------
SELECT 'proveedor' AS variable, proveedor AS valor, COUNT(*) AS viajes,
       ROUND(100 * AVG(sin_propina), 2) AS pct_sin_propina
FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'entrenamiento' GROUP BY 2
UNION ALL
SELECT 'codigo_tarifa', codigo_tarifa, COUNT(*), ROUND(100 * AVG(sin_propina), 2)
FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'entrenamiento' GROUP BY 2
UNION ALL
SELECT 'borough_origen', borough_origen, COUNT(*), ROUND(100 * AVG(sin_propina), 2)
FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'entrenamiento' GROUP BY 2
UNION ALL
SELECT 'es_aeropuerto', CAST(es_aeropuerto AS STRING), COUNT(*), ROUND(100 * AVG(sin_propina), 2)
FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'entrenamiento' GROUP BY 2
UNION ALL
SELECT 'tipo_dia', IF(es_fin_semana, 'fin de semana', 'entre semana'), COUNT(*), ROUND(100 * AVG(sin_propina), 2)
FROM nyc_taxi_2022.ml_propinas WHERE conjunto = 'entrenamiento' GROUP BY 2
ORDER BY variable, pct_sin_propina DESC;

-- -----------------------------------------------------------------------------
-- B.3 Justificación de variables numéricas: correlación con la etiqueta (solo
--     entrenamiento).
-- -----------------------------------------------------------------------------
SELECT
  ROUND(CORR(distancia_mi, sin_propina), 3) AS corr_distancia,
  ROUND(CORR(duracion_min, sin_propina), 3) AS corr_duracion,
  ROUND(CORR(velocidad_mph, sin_propina), 3) AS corr_velocidad,
  ROUND(CORR(tarifa, sin_propina), 3) AS corr_tarifa,
  ROUND(CORR(tarifa_por_milla, sin_propina), 3) AS corr_tarifa_por_milla,
  ROUND(CORR(peajes, sin_propina), 3) AS corr_peajes,
  ROUND(CORR(pasajeros, sin_propina), 3) AS corr_pasajeros,
  ROUND(CORR(hora_dia, sin_propina), 3) AS corr_hora
FROM nyc_taxi_2022.ml_propinas
WHERE conjunto = 'entrenamiento';
