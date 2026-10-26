-- =============================================================================
-- 05_tablas_dashboard.sql: tablas agregadas para Looker Studio.
--
-- Ejecutar el archivo completo. El dashboard se conecta a estas tablas pequeñas
-- y no a viajes. Así cada interacción del reporte lee KB en lugar de GB, y no
-- choca con require_partition_filter.
--
-- Las tablas guardan sumas y conteos, no promedios: un promedio de promedios
-- sería incorrecto al agrupar en el reporte. Los promedios se crean como campos
-- calculados en Looker Studio (ver docs/GUIA_DASHBOARD.md).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. dash_diario: serie diaria por borough de origen.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.dash_diario AS
SELECT
  pickup_date AS fecha,
  borough_origen AS borough,
  COUNT(*) AS viajes,
  SUM(total_amount) AS ingreso_total,
  SUM(fare_amount) AS suma_tarifa,
  SUM(trip_distance) AS suma_distancia,
  SUM(duracion_min) AS suma_duracion,
  COUNTIF(payment_type = 1) AS viajes_tarjeta,
  COUNTIF(payment_type = 1 AND tip_amount > 0) AS viajes_tarjeta_con_propina,
  SUM(IF(payment_type = 1, pct_propina, NULL)) AS suma_pct_propina_tarjeta,
  COUNTIF(payment_type = 1 AND pct_propina IS NOT NULL) AS viajes_tarjeta_con_pct
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY fecha, borough;

-- -----------------------------------------------------------------------------
-- 2. dash_hora_semana: mapa de calor hora x día de la semana. nombre_dia lleva
--    un prefijo numérico para que Looker Studio ordene de lunes a domingo.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.dash_hora_semana AS
SELECT
  EXTRACT(DAYOFWEEK FROM pickup_datetime) AS dia_semana,
  CASE EXTRACT(DAYOFWEEK FROM pickup_datetime)
    WHEN 2 THEN '1 Lunes' WHEN 3 THEN '2 Martes' WHEN 4 THEN '3 Miércoles'
    WHEN 5 THEN '4 Jueves' WHEN 6 THEN '5 Viernes' WHEN 7 THEN '6 Sábado'
    ELSE '7 Domingo'
  END AS nombre_dia,
  EXTRACT(HOUR FROM pickup_datetime) AS hora,
  COUNT(*) AS viajes,
  SUM(total_amount) AS ingreso_total,
  SUM(velocidad_mph) AS suma_velocidad
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY dia_semana, nombre_dia, hora;

-- -----------------------------------------------------------------------------
-- 3. dash_zonas: indicadores por zona con su polígono, para el mapa coroplético
--    y el ranking de zonas.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.dash_zonas AS
WITH origen AS (
  SELECT
    pickup_location_id AS zone_id,
    COUNT(*) AS viajes_origen,
    SUM(total_amount) AS ingreso_origen,
    SUM(IF(payment_type = 1, pct_propina, NULL)) AS suma_pct_propina_tarjeta,
    COUNTIF(payment_type = 1 AND pct_propina IS NOT NULL) AS viajes_tarjeta_con_pct
  FROM nyc_taxi_2022.vw_viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY zone_id
),
destino AS (
  SELECT
    dropoff_location_id AS zone_id,
    COUNT(*) AS viajes_destino
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY zone_id
)
SELECT
  z.zone_id,
  z.zone_name AS zona,
  z.borough,
  z.zone_geom,
  COALESCE(o.viajes_origen, 0) AS viajes_origen,
  COALESCE(o.ingreso_origen, 0) AS ingreso_origen,
  o.suma_pct_propina_tarjeta,
  COALESCE(o.viajes_tarjeta_con_pct, 0) AS viajes_tarjeta_con_pct,
  COALESCE(d.viajes_destino, 0) AS viajes_destino
FROM nyc_taxi_2022.zonas AS z
LEFT JOIN origen AS o ON o.zone_id = z.zone_id
LEFT JOIN destino AS d ON d.zone_id = z.zone_id;

-- -----------------------------------------------------------------------------
-- 4. dash_pagos_mensual: mezcla de tipos de pago por mes.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.dash_pagos_mensual AS
SELECT
  DATE_TRUNC(pickup_date, MONTH) AS mes,
  tipo_pago,
  COUNT(*) AS viajes,
  SUM(total_amount) AS ingreso_total,
  SUM(tip_amount) AS propinas
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY mes, tipo_pago;

-- -----------------------------------------------------------------------------
-- 5. dash_origen_destino: flujos entre boroughs para una tabla dinámica.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.dash_origen_destino AS
SELECT
  borough_origen,
  borough_destino,
  COUNT(*) AS viajes,
  SUM(total_amount) AS ingreso_total
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY borough_origen, borough_destino;

-- -----------------------------------------------------------------------------
-- 6. Validación: filas por tabla del dashboard.
-- -----------------------------------------------------------------------------
SELECT 'dash_diario' AS tabla, COUNT(*) AS filas FROM nyc_taxi_2022.dash_diario
UNION ALL SELECT 'dash_hora_semana', COUNT(*) FROM nyc_taxi_2022.dash_hora_semana
UNION ALL SELECT 'dash_zonas', COUNT(*) FROM nyc_taxi_2022.dash_zonas
UNION ALL SELECT 'dash_pagos_mensual', COUNT(*) FROM nyc_taxi_2022.dash_pagos_mensual
UNION ALL SELECT 'dash_origen_destino', COUNT(*) FROM nyc_taxi_2022.dash_origen_destino;
