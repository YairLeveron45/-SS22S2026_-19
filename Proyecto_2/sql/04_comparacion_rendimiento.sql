-- =============================================================================
-- 04_comparacion_rendimiento.sql: consultas estándar contra consultas optimizadas.
--
-- Antes de empezar: Más > Configuración de consultas > desmarcar "Usar resultados
-- almacenados en caché". Con la caché activa, una consulta repetida procesa 0 B y
-- no sirve como evidencia.
--
-- Ejecutar cada consulta por separado y capturar la pestaña "Información del
-- trabajo": bytes procesados, bytes facturados, tiempo de ranura y duración.
-- Cada consulta lleva un comentario /* P2-COMP ... */ que el bloque R1 usa para
-- recuperar sus métricas desde INFORMATION_SCHEMA.
--
-- Al leer los resultados:
--   - La estimación previa del validador ya descuenta las particiones podadas,
--     pero no los bloques que descarta el clustering. El efecto del clustering
--     solo aparece en "bytes procesados" después de ejecutar la consulta.
--   - BigQuery factura mínimo 10 MB por tabla consultada, por eso los bytes
--     facturados de una consulta optimizada pueden quedarse en 10 MB.
--   - LIMIT no reduce los bytes leídos (ver S0).
--
-- Escenarios (mismos viajes y tipos en viajes y viajes_estandar):
--   S1  filtro solo por fecha      -> aísla el efecto de la partición
--   S2  filtro solo por zona       -> aísla el efecto del clustering
--   S3  filtro por fecha y zona    -> efecto combinado, incluye la tabla pública
-- =============================================================================

-- -----------------------------------------------------------------------------
-- S0. Mala práctica: SELECT * con LIMIT. NO es necesario ejecutarla. Basta con
--     capturar la estimación del validador: indica que se leería la tabla
--     completa aunque solo se devuelvan 10 filas.
-- -----------------------------------------------------------------------------
SELECT *
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
LIMIT 10;

-- S0-columnas. La misma intención leyendo solo tres columnas (capturar también
-- solo la estimación).
SELECT pickup_datetime, pickup_location_id, total_amount
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
LIMIT 10;

-- -----------------------------------------------------------------------------
-- S1. Partición: viajes e ingresos por día de junio de 2022.
--     La tabla estándar recorre los 12 meses; la optimizada lee solo junio.
-- -----------------------------------------------------------------------------
SELECT /* P2-COMP S1-estandar */
  pickup_date,
  COUNT(*) AS viajes,
  ROUND(SUM(total_amount), 2) AS ingreso
FROM nyc_taxi_2022.viajes_estandar
WHERE pickup_date BETWEEN '2022-06-01' AND '2022-06-30'
GROUP BY pickup_date
ORDER BY pickup_date;

SELECT /* P2-COMP S1-optimizada */
  pickup_date,
  COUNT(*) AS viajes,
  ROUND(SUM(total_amount), 2) AS ingreso
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-06-01' AND '2022-06-30'
GROUP BY pickup_date
ORDER BY pickup_date;

-- -----------------------------------------------------------------------------
-- S2. Clustering: salidas de JFK (zona 132) en todo 2022 por zona de destino.
--     El filtro de fecha cubre el año completo, así que no hay poda de
--     particiones: cualquier reducción viene del clustering.
-- -----------------------------------------------------------------------------
SELECT /* P2-COMP S2-estandar */
  dropoff_location_id,
  COUNT(*) AS viajes,
  ROUND(AVG(total_amount), 2) AS total_promedio
FROM nyc_taxi_2022.viajes_estandar
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND pickup_location_id = '132'
GROUP BY dropoff_location_id
ORDER BY viajes DESC;

SELECT /* P2-COMP S2-optimizada */
  dropoff_location_id,
  COUNT(*) AS viajes,
  ROUND(AVG(total_amount), 2) AS total_promedio
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND pickup_location_id = '132'
GROUP BY dropoff_location_id
ORDER BY viajes DESC;

-- -----------------------------------------------------------------------------
-- S3. Partición + clustering: salidas de JFK en junio de 2022 por zona de destino.
--     La versión pública da conteos algo mayores porque incluye los registros
--     inválidos que la limpieza descarta.
-- -----------------------------------------------------------------------------
SELECT /* P2-COMP S3-publica */
  CAST(dropoff_location_id AS STRING) AS zona_destino,
  COUNT(*) AS viajes,
  ROUND(AVG(CAST(total_amount AS FLOAT64)), 2) AS total_promedio,
  ROUND(AVG(CAST(trip_distance AS FLOAT64)), 2) AS distancia_promedio
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE DATE(pickup_datetime) BETWEEN '2022-06-01' AND '2022-06-30'
  AND CAST(pickup_location_id AS STRING) = '132'
GROUP BY zona_destino
ORDER BY viajes DESC;

SELECT /* P2-COMP S3-estandar */
  dropoff_location_id AS zona_destino,
  COUNT(*) AS viajes,
  ROUND(AVG(total_amount), 2) AS total_promedio,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio
FROM nyc_taxi_2022.viajes_estandar
WHERE pickup_date BETWEEN '2022-06-01' AND '2022-06-30'
  AND pickup_location_id = '132'
GROUP BY zona_destino
ORDER BY viajes DESC;

SELECT /* P2-COMP S3-optimizada */
  dropoff_location_id AS zona_destino,
  COUNT(*) AS viajes,
  ROUND(AVG(total_amount), 2) AS total_promedio,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-06-01' AND '2022-06-30'
  AND pickup_location_id = '132'
GROUP BY zona_destino
ORDER BY viajes DESC;

-- -----------------------------------------------------------------------------
-- R1. Métricas de la última ejecución exitosa y sin caché de cada consulta
--     P2-COMP. Se guardan en una tabla para el dashboard.
--     statement_type = 'SELECT' excluye el trabajo padre cuando el archivo se
--     corre como script completo.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.comparacion_consultas AS
WITH trabajos AS (
  SELECT
    REGEXP_EXTRACT(query, r'P2-COMP ([A-Za-z0-9-]+)') AS consulta,
    creation_time,
    job_id,
    total_bytes_processed,
    total_bytes_billed,
    total_slot_ms,
    TIMESTAMP_DIFF(end_time, start_time, MILLISECOND) AS duracion_ms
  FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER
  WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    AND job_type = 'QUERY'
    AND statement_type = 'SELECT'
    AND state = 'DONE'
    AND error_result IS NULL
    AND cache_hit IS NOT TRUE
    AND query LIKE '%P2-COMP S%'
    AND query NOT LIKE '%INFORMATION_SCHEMA%'
),
ultima AS (
  SELECT *
  FROM trabajos
  WHERE TRUE
  QUALIFY ROW_NUMBER() OVER (PARTITION BY consulta ORDER BY creation_time DESC) = 1
)
SELECT
  consulta,
  SPLIT(consulta, '-')[OFFSET(0)] AS escenario,
  SPLIT(consulta, '-')[OFFSET(1)] AS version,
  job_id,
  creation_time,
  total_bytes_processed,
  ROUND(total_bytes_processed / POW(1024, 2), 2) AS mb_procesados,
  ROUND(total_bytes_billed / POW(1024, 2), 2) AS mb_facturados,
  total_slot_ms,
  duracion_ms
FROM ultima;

-- -----------------------------------------------------------------------------
-- R2. Reducción de bytes procesados frente a la versión estándar de cada
--     escenario (resultado principal de la comparación).
-- -----------------------------------------------------------------------------
SELECT
  o.escenario,
  o.version,
  o.mb_procesados,
  e.mb_procesados AS mb_procesados_estandar,
  ROUND(100 * (1 - SAFE_DIVIDE(o.total_bytes_processed, e.total_bytes_processed)), 1) AS reduccion_bytes_pct,
  o.mb_facturados,
  o.total_slot_ms,
  e.total_slot_ms AS slot_ms_estandar,
  o.duracion_ms
FROM nyc_taxi_2022.comparacion_consultas AS o
LEFT JOIN nyc_taxi_2022.comparacion_consultas AS e
  ON e.escenario = o.escenario
 AND e.version = 'estandar'
ORDER BY o.escenario, o.total_bytes_processed DESC;
