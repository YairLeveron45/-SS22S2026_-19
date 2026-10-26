-- =============================================================================
-- Proyecto 2 · Seminario de Sistemas 2 · 2S2026 · Grupo 19
-- 00_configuracion.sql: dataset de trabajo y dimensión de zonas.
--
-- Ejecutar el archivo completo con el proyecto propio seleccionado en la consola.
-- Las tablas se escriben como nyc_taxi_2022.<tabla>: BigQuery completa el nombre
-- con el proyecto activo, así que los scripts no dependen del ID del proyecto.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Dataset de trabajo.
-- El dataset público está en la multi-región US y una consulta no puede leer de
-- una región y escribir en otra, por eso el dataset propio también va en US.
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS nyc_taxi_2022
OPTIONS (
  location = 'US',
  description = 'Proyecto 2 SS2: tablas derivadas de NYC Yellow Taxi 2022, modelos BigQuery ML y tablas del dashboard'
);

-- -----------------------------------------------------------------------------
-- 2. Dimensión de zonas TLC.
-- taxi_zone_geom trae cada zona oficial con su borough y su polígono.
--   - Se agrupa por zone_id y los polígonos se unen con ST_UNION_AGG: el shapefile
--     de la TLC parte algunas zonas en varios polígonos y, sin este paso, el JOIN
--     con los viajes duplicaría filas.
--   - taxi_zone_geom trae 260 de las 263 zonas: las zonas 57, 104 y 105 vienen
--     fusionadas con los polígonos de 56 (Corona) y 103 (islas de la bahía). Se
--     agregan sin polígono, con su nombre y borough del catálogo oficial de la TLC,
--     junto con los códigos 264 y 265, que aparecen en los viajes pero tampoco
--     tienen polígono (zona desconocida y destino fuera de NYC).
--   - La geometría se conserva para el mapa de Looker Studio.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE nyc_taxi_2022.zonas
OPTIONS (description = 'Zonas TLC: id, nombre, borough y polígono')
AS
WITH oficiales AS (
  SELECT
    CAST(zone_id AS STRING) AS zone_id,
    ANY_VALUE(zone_name) AS zone_name,
    ANY_VALUE(borough) AS borough,
    ST_UNION_AGG(zone_geom) AS zone_geom
  FROM `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom`
  GROUP BY 1
),
sin_poligono AS (
  SELECT '57' AS zone_id, 'Corona' AS zone_name, 'Queens' AS borough, CAST(NULL AS GEOGRAPHY) AS zone_geom
  UNION ALL
  SELECT '104', "Governor's Island/Ellis Island/Liberty Island", 'Manhattan', CAST(NULL AS GEOGRAPHY)
  UNION ALL
  SELECT '105', "Governor's Island/Ellis Island/Liberty Island", 'Manhattan', CAST(NULL AS GEOGRAPHY)
  UNION ALL
  SELECT '264', 'Desconocida', 'Desconocido', CAST(NULL AS GEOGRAPHY)
  UNION ALL
  SELECT '265', 'Fuera de NYC', 'Fuera de NYC', CAST(NULL AS GEOGRAPHY)
)
SELECT * FROM oficiales
UNION ALL
SELECT * FROM sin_poligono
WHERE zone_id NOT IN (SELECT zone_id FROM oficiales);

-- -----------------------------------------------------------------------------
-- 3. Validación: una fila por zona (zonas = ids_distintos) y zonas por borough.
-- -----------------------------------------------------------------------------
SELECT
  borough,
  COUNT(*) AS zonas,
  COUNT(DISTINCT zone_id) AS ids_distintos
FROM nyc_taxi_2022.zonas
GROUP BY borough
ORDER BY zonas DESC;
