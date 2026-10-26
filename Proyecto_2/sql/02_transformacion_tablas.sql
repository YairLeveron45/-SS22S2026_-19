-- =============================================================================
-- 02_transformacion_tablas.sql: tabla derivada limpia, particionada y con clustering.
--
-- Ejecutar el archivo completo. Crea:
--   nyc_taxi_2022.viajes            tabla optimizada (partición mensual + clustering)
--   nyc_taxi_2022.viajes_estandar   copia sin optimizar, solo para comparar costos
--   nyc_taxi_2022.vw_viajes         vista con variables derivadas y nombres de zona
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabla optimizada nyc_taxi_2022.viajes
--
-- Partición mensual sobre pickup_date.
--   Con unos 3 millones de viajes por mes, cada partición ocupa cientos de MB.
--   Una partición diaria daría 334 particiones de unos 100 mil viajes (pocos MB),
--   y en particiones tan pequeñas el clustering casi no puede descartar bloques.
--   Los análisis del proyecto filtran por mes, trimestre o período completo.
-- Clustering por pickup_location_id y dropoff_location_id.
--   Dentro de cada mes los datos quedan ordenados por zona de origen y luego por
--   zona de destino, así que un filtro por zona (aeropuertos, rutas) lee solo los
--   bloques que contienen esa zona.
-- require_partition_filter: toda consulta debe filtrar pickup_date, lo que evita
--   recorrer la tabla completa por descuido.
--
-- Limpieza (los conteos de cada regla están en 01_exploracion_calidad.sql):
--   - solo recogidas de enero a noviembre de 2022: la tabla pública no incluye el
--     archivo de diciembre y sus 57 viajes de diciembre son fechas erróneas.
--   - duración entre 1 y 180 minutos.
--   - distancia mayor a 0 y hasta 100 millas.
--   - tarifa mayor a 0 y hasta USD 1,000, total mayor a 0, propina y peajes >= 0.
--   - velocidad promedio de hasta 80 mph (más es imposible dentro de NYC).
--   - pasajeros fuera de 1..6 se guardan como NULL (el conductor no capturó el
--     dato) y el viaje se conserva porque el resto de sus campos es válido.
--   - se eliminan los duplicados exactos según la llave del viaje.
-- Normalización de tipos: montos y distancia pasan a FLOAT64 (8 bytes, contra 16
--   de NUMERIC), los códigos a INT64 y las zonas a STRING. Las conversiones
--   funcionan sin importar si el origen trae texto, entero o decimal.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.viajes
PARTITION BY DATE_TRUNC(pickup_date, MONTH)
CLUSTER BY pickup_location_id, dropoff_location_id
OPTIONS (
  require_partition_filter = TRUE,
  description = 'Viajes de taxi amarillo NYC enero-noviembre 2022 limpios. Partición mensual por pickup_date, clustering por zona de origen y destino.'
)
AS
WITH base AS (
  SELECT
    FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(
      vendor_id, pickup_datetime, dropoff_datetime, pickup_location_id,
      dropoff_location_id, trip_distance, total_amount
    ))) AS trip_id,
    SAFE_CAST(SAFE_CAST(vendor_id AS FLOAT64) AS INT64) AS vendor_id,
    CAST(pickup_datetime AS DATETIME) AS pickup_datetime,
    CAST(dropoff_datetime AS DATETIME) AS dropoff_datetime,
    SAFE_CAST(SAFE_CAST(passenger_count AS FLOAT64) AS INT64) AS passenger_count,
    SAFE_CAST(trip_distance AS FLOAT64) AS trip_distance,
    SAFE_CAST(SAFE_CAST(rate_code AS FLOAT64) AS INT64) AS rate_code_id,
    SAFE_CAST(SAFE_CAST(payment_type AS FLOAT64) AS INT64) AS payment_type,
    SAFE_CAST(fare_amount AS FLOAT64) AS fare_amount,
    SAFE_CAST(tip_amount AS FLOAT64) AS tip_amount,
    SAFE_CAST(tolls_amount AS FLOAT64) AS tolls_amount,
    SAFE_CAST(total_amount AS FLOAT64) AS total_amount,
    CAST(SAFE_CAST(SAFE_CAST(pickup_location_id AS FLOAT64) AS INT64) AS STRING) AS pickup_location_id,
    CAST(SAFE_CAST(SAFE_CAST(dropoff_location_id AS FLOAT64) AS INT64) AS STRING) AS dropoff_location_id
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
  WHERE pickup_datetime >= '2022-01-01'
    AND pickup_datetime < '2022-12-01'
),
con_duracion AS (
  SELECT
    *,
    DATE(pickup_datetime) AS pickup_date,
    DATETIME_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 60 AS duracion_min
  FROM base
)
SELECT
  trip_id,
  vendor_id,
  pickup_datetime,
  dropoff_datetime,
  pickup_date,
  IF(passenger_count BETWEEN 1 AND 6, passenger_count, NULL) AS passenger_count,
  trip_distance,
  ROUND(duracion_min, 2) AS duracion_min,
  ROUND(SAFE_DIVIDE(trip_distance, duracion_min / 60), 2) AS velocidad_mph,
  rate_code_id,
  payment_type,
  fare_amount,
  tip_amount,
  tolls_amount,
  total_amount,
  pickup_location_id,
  dropoff_location_id
FROM con_duracion
WHERE duracion_min BETWEEN 1 AND 180
  AND trip_distance > 0 AND trip_distance <= 100
  AND fare_amount > 0 AND fare_amount <= 1000
  AND total_amount > 0
  AND tip_amount >= 0
  AND tolls_amount >= 0
  AND SAFE_DIVIDE(trip_distance, duracion_min / 60) <= 80
QUALIFY ROW_NUMBER() OVER (PARTITION BY trip_id) = 1;

-- -----------------------------------------------------------------------------
-- 2. Copia sin optimizar para la comparación de rendimiento.
-- Mismos viajes y mismos tipos que viajes, pero sin partición ni clustering.
-- Incluye solo las columnas que usan las consultas de
-- 04_comparacion_rendimiento.sql para no duplicar el almacenamiento completo.
-- La comparación sigue siendo justa porque BigQuery cobra por columna leída.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.viajes_estandar
OPTIONS (description = 'Copia de viajes sin partición ni clustering, solo para comparar bytes procesados')
AS
SELECT
  pickup_date,
  pickup_location_id,
  dropoff_location_id,
  trip_distance,
  fare_amount,
  total_amount
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30';

-- -----------------------------------------------------------------------------
-- 3. Vista de análisis: agrega calendario, zonas, etiquetas y % de propina.
-- La vista no guarda datos: al filtrar pickup_date, el filtro llega a la tabla
-- viajes y se siguen podando particiones.
-- pct_propina = propina / (total - propina), es decir, sobre lo cobrado antes de
-- la propina, que es la base que usa la pantalla de pago del taxi.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW nyc_taxi_2022.vw_viajes
OPTIONS (description = 'Viajes limpios con variables derivadas de calendario, zona, pago y propina')
AS
SELECT
  v.*,
  EXTRACT(HOUR FROM v.pickup_datetime) AS hora_recogida,
  EXTRACT(DAYOFWEEK FROM v.pickup_datetime) AS dia_semana,  -- 1 = domingo ... 7 = sábado
  EXTRACT(MONTH FROM v.pickup_datetime) AS mes,
  EXTRACT(DAYOFWEEK FROM v.pickup_datetime) IN (1, 7) AS es_fin_semana,
  COALESCE(zo.zone_name, 'Desconocida') AS zona_origen,
  COALESCE(zo.borough, 'Desconocido') AS borough_origen,
  COALESCE(zd.zone_name, 'Desconocida') AS zona_destino,
  COALESCE(zd.borough, 'Desconocido') AS borough_destino,
  -- 1 = Newark (EWR), 132 = JFK, 138 = LaGuardia
  COALESCE(
    v.pickup_location_id IN ('1', '132', '138') OR v.dropoff_location_id IN ('1', '132', '138'),
    FALSE
  ) AS es_aeropuerto,
  SAFE_DIVIDE(v.tip_amount, v.total_amount - v.tip_amount) AS pct_propina,
  CASE v.payment_type
    WHEN 1 THEN 'Tarjeta'
    WHEN 2 THEN 'Efectivo'
    WHEN 3 THEN 'Sin cargo'
    WHEN 4 THEN 'Disputa'
    ELSE 'Otro/Desconocido'
  END AS tipo_pago,
  CASE v.rate_code_id
    WHEN 1 THEN 'Estándar'
    WHEN 2 THEN 'JFK tarifa fija'
    WHEN 3 THEN 'Newark'
    WHEN 4 THEN 'Nassau/Westchester'
    WHEN 5 THEN 'Negociada'
    WHEN 6 THEN 'Viaje grupal'
    ELSE 'Desconocido'
  END AS tipo_tarifa
FROM nyc_taxi_2022.viajes AS v
LEFT JOIN nyc_taxi_2022.zonas AS zo ON zo.zone_id = v.pickup_location_id
LEFT JOIN nyc_taxi_2022.zonas AS zd ON zd.zone_id = v.dropoff_location_id;

-- -----------------------------------------------------------------------------
-- 4. Evidencia: una partición por mes, con sus filas y su tamaño.
-- -----------------------------------------------------------------------------
SELECT
  partition_id,
  total_rows AS filas,
  ROUND(total_logical_bytes / POW(1024, 2), 1) AS mb_logicos
FROM nyc_taxi_2022.INFORMATION_SCHEMA.PARTITIONS
WHERE table_name = 'viajes'
ORDER BY partition_id;

-- -----------------------------------------------------------------------------
-- 5. Evidencia: columna de partición y orden del clustering.
-- -----------------------------------------------------------------------------
SELECT
  column_name,
  data_type,
  is_partitioning_column,
  clustering_ordinal_position
FROM nyc_taxi_2022.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'viajes'
ORDER BY ordinal_position;

-- -----------------------------------------------------------------------------
-- 6. Evidencia: DDL de ambas tablas (muestra PARTITION BY y CLUSTER BY).
-- -----------------------------------------------------------------------------
SELECT table_name, ddl
FROM nyc_taxi_2022.INFORMATION_SCHEMA.TABLES
WHERE table_name IN ('viajes', 'viajes_estandar');

-- -----------------------------------------------------------------------------
-- 7. Conciliación: registros de origen frente a registros conservados.
-- -----------------------------------------------------------------------------
SELECT
  origen.registros AS registros_origen,
  limpios.registros AS registros_limpios,
  origen.registros - limpios.registros AS registros_descartados,
  ROUND(100 * limpios.registros / origen.registros, 2) AS pct_conservado
FROM
  (SELECT COUNT(*) AS registros
   FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`) AS origen,
  (SELECT COUNT(*) AS registros
   FROM nyc_taxi_2022.viajes
   WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30') AS limpios;
