-- =============================================================================
-- 01_exploracion_calidad.sql: conexión, estructura y calidad del dataset público.
-- Tabla: bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022
--
-- Ejecutar cada bloque por separado (seleccionar la consulta y ejecutar) y
-- capturar su resultado. Los bloques 1 a 3 leen solo metadatos y procesan 0 B.
-- Los bloques 4 a 9 recorren la tabla completa en las columnas que usan.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Volumen y tamaño de las tablas de taxi amarillo (metadatos, sin costo).
-- -----------------------------------------------------------------------------
SELECT
  table_id,
  row_count AS registros,
  ROUND(size_bytes / POW(1024, 3), 2) AS tamano_gb,
  TIMESTAMP_MILLIS(last_modified_time) AS ultima_modificacion
FROM `bigquery-public-data.new_york_taxi_trips.__TABLES__`
WHERE table_id LIKE 'tlc_yellow_trips_%'
ORDER BY table_id;

-- -----------------------------------------------------------------------------
-- 2. Conteo exacto de 2022. COUNT(*) sin filtros se responde con metadatos.
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS total_registros
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- -----------------------------------------------------------------------------
-- 3. Esquema: tipo y nulabilidad de cada columna. Las dos últimas columnas
--    muestran si la tabla pública ya tiene partición o clustering.
-- -----------------------------------------------------------------------------
SELECT
  column_name,
  data_type,
  is_nullable,
  is_partitioning_column,
  clustering_ordinal_position
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'tlc_yellow_trips_2022'
ORDER BY ordinal_position;

-- -----------------------------------------------------------------------------
-- 4. Completitud: nulos por columna y rango de fechas de recogida.
-- -----------------------------------------------------------------------------
SELECT
  COUNT(*) AS registros,
  COUNTIF(vendor_id IS NULL) AS nulos_vendor_id,
  COUNTIF(pickup_datetime IS NULL) AS nulos_pickup_datetime,
  COUNTIF(dropoff_datetime IS NULL) AS nulos_dropoff_datetime,
  COUNTIF(passenger_count IS NULL) AS nulos_passenger_count,
  COUNTIF(trip_distance IS NULL) AS nulos_trip_distance,
  COUNTIF(rate_code IS NULL) AS nulos_rate_code,
  COUNTIF(payment_type IS NULL) AS nulos_payment_type,
  COUNTIF(fare_amount IS NULL) AS nulos_fare_amount,
  COUNTIF(tip_amount IS NULL) AS nulos_tip_amount,
  COUNTIF(tolls_amount IS NULL) AS nulos_tolls_amount,
  COUNTIF(total_amount IS NULL) AS nulos_total_amount,
  COUNTIF(pickup_location_id IS NULL) AS nulos_pickup_location_id,
  COUNTIF(dropoff_location_id IS NULL) AS nulos_dropoff_location_id,
  MIN(pickup_datetime) AS primera_recogida,
  MAX(pickup_datetime) AS ultima_recogida
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- -----------------------------------------------------------------------------
-- 5. Calidad: registros que violan reglas de negocio. UNPIVOT convierte los
--    contadores en filas para leerlos como tabla. Estas reglas son las que
--    aplica la limpieza de 02_transformacion_tablas.sql. El período válido es
--    enero a noviembre de 2022 (ver bloque 7).
-- -----------------------------------------------------------------------------
WITH chequeos AS (
  SELECT
    COUNT(*) AS total,
    COUNTIF(pickup_datetime < '2022-01-01' OR pickup_datetime >= '2022-12-01') AS fecha_fuera_del_periodo,
    COUNTIF(dropoff_datetime <= pickup_datetime) AS duracion_cero_o_negativa,
    COUNTIF(DATETIME_DIFF(CAST(dropoff_datetime AS DATETIME), CAST(pickup_datetime AS DATETIME), MINUTE) > 180) AS duracion_mayor_3_horas,
    COUNTIF(trip_distance <= 0) AS distancia_cero_o_negativa,
    COUNTIF(trip_distance > 100) AS distancia_mayor_100_millas,
    COUNTIF(fare_amount <= 0) AS tarifa_cero_o_negativa,
    COUNTIF(fare_amount > 1000) AS tarifa_mayor_1000,
    COUNTIF(total_amount <= 0) AS total_cero_o_negativo,
    COUNTIF(tip_amount < 0) AS propina_negativa,
    COUNTIF(passenger_count IS NULL) AS pasajeros_nulo,
    COUNTIF(passenger_count = 0) AS pasajeros_cero,
    COUNTIF(passenger_count > 6) AS pasajeros_mayor_6,
    COUNTIF(CAST(pickup_location_id AS STRING) IN ('264', '265')) AS zona_origen_desconocida
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
)
SELECT
  problema,
  registros_afectados,
  ROUND(100 * registros_afectados / total, 3) AS pct_del_total
FROM chequeos
UNPIVOT (registros_afectados FOR problema IN (
  fecha_fuera_del_periodo, duracion_cero_o_negativa, duracion_mayor_3_horas,
  distancia_cero_o_negativa, distancia_mayor_100_millas, tarifa_cero_o_negativa,
  tarifa_mayor_1000, total_cero_o_negativo, propina_negativa, pasajeros_nulo,
  pasajeros_cero, pasajeros_mayor_6, zona_origen_desconocida
))
ORDER BY registros_afectados DESC;

-- -----------------------------------------------------------------------------
-- 6. Valores de los campos codificados (diccionario de la TLC):
--    vendor_id 1 = Creative Mobile Technologies, 2 = VeriFone.
--    rate_code 1 estándar, 2 JFK, 3 Newark, 4 Nassau/Westchester, 5 negociada,
--              6 grupal, 99 desconocido.
--    payment_type 1 tarjeta, 2 efectivo, 3 sin cargo, 4 disputa, 5 desconocido,
--                 6 anulado.
-- -----------------------------------------------------------------------------
SELECT 'vendor_id' AS campo, CAST(vendor_id AS STRING) AS codigo, COUNT(*) AS registros
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY 2
UNION ALL
SELECT 'rate_code', CAST(rate_code AS STRING), COUNT(*)
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY 2
UNION ALL
SELECT 'payment_type', CAST(payment_type AS STRING), COUNT(*)
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY 2
ORDER BY campo, registros DESC;

-- -----------------------------------------------------------------------------
-- 7. Distribución por año-mes de recogida: detecta fechas ajenas al período que
--    llegan dentro de los archivos mensuales. También muestra que la tabla cubre
--    enero a noviembre de 2022: diciembre solo tiene registros sueltos con fecha
--    errónea, porque su archivo no fue cargado.
-- -----------------------------------------------------------------------------
SELECT
  FORMAT_DATE('%Y-%m', DATE(pickup_datetime)) AS anio_mes,
  COUNT(*) AS registros
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY anio_mes
ORDER BY anio_mes;

-- -----------------------------------------------------------------------------
-- 8. Valores extremos: percentiles 1, 50 y 99 frente a mínimo y máximo.
--    Una distancia o tarifa máxima muy lejos del p99 indica errores de captura.
-- -----------------------------------------------------------------------------
WITH valores AS (
  SELECT m.variable, m.valor
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` AS t,
  UNNEST([
    STRUCT('trip_distance' AS variable, CAST(t.trip_distance AS FLOAT64) AS valor),
    STRUCT('fare_amount' AS variable, CAST(t.fare_amount AS FLOAT64) AS valor),
    STRUCT('tip_amount' AS variable, CAST(t.tip_amount AS FLOAT64) AS valor),
    STRUCT('total_amount' AS variable, CAST(t.total_amount AS FLOAT64) AS valor)
  ]) AS m
),
resumen AS (
  SELECT
    variable,
    MIN(valor) AS minimo,
    MAX(valor) AS maximo,
    APPROX_QUANTILES(valor, 100) AS q
  FROM valores
  GROUP BY variable
)
SELECT
  variable,
  minimo,
  q[OFFSET(1)] AS p01,
  q[OFFSET(50)] AS mediana,
  q[OFFSET(99)] AS p99,
  maximo
FROM resumen
ORDER BY variable;

-- -----------------------------------------------------------------------------
-- 9. Duplicados exactos según la llave del viaje (misma llave que trip_id en la
--    tabla derivada).
-- -----------------------------------------------------------------------------
WITH llaves AS (
  SELECT
    COUNT(*) AS registros,
    COUNT(DISTINCT FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(
      vendor_id, pickup_datetime, dropoff_datetime, pickup_location_id,
      dropoff_location_id, trip_distance, total_amount
    )))) AS llaves_distintas
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
)
SELECT
  registros,
  llaves_distintas,
  registros - llaves_distintas AS duplicados
FROM llaves;
