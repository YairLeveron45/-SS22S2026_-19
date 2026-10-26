-- =============================================================================
-- 03_analisis_exploratorio.sql: métricas descriptivas, distribuciones y patrones.
--
-- Ejecutar cada consulta por separado. Todas filtran pickup_date (requisito de la
-- tabla particionada). Las consultas que no necesitan nombres de zona leen
-- directamente viajes en lugar de vw_viajes para no hacer el JOIN con zonas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- E1. Métricas descriptivas de las variables numéricas.
-- UNNEST convierte cada viaje en seis pares (variable, valor) para calcular las
-- mismas estadísticas en una sola pasada.
-- -----------------------------------------------------------------------------
WITH valores AS (
  SELECT m.variable, m.valor
  FROM nyc_taxi_2022.viajes AS v,
  UNNEST([
    STRUCT('distancia_mi' AS variable, v.trip_distance AS valor),
    STRUCT('duracion_min' AS variable, v.duracion_min AS valor),
    STRUCT('velocidad_mph' AS variable, v.velocidad_mph AS valor),
    STRUCT('tarifa_usd' AS variable, v.fare_amount AS valor),
    STRUCT('propina_usd' AS variable, v.tip_amount AS valor),
    STRUCT('total_usd' AS variable, v.total_amount AS valor)
  ]) AS m
  WHERE v.pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
)
SELECT
  variable,
  COUNT(*) AS n,
  ROUND(AVG(valor), 2) AS media,
  ROUND(STDDEV(valor), 2) AS desv_estandar,
  ROUND(MIN(valor), 2) AS minimo,
  ROUND(APPROX_QUANTILES(valor, 4)[OFFSET(1)], 2) AS p25,
  ROUND(APPROX_QUANTILES(valor, 4)[OFFSET(2)], 2) AS mediana,
  ROUND(APPROX_QUANTILES(valor, 4)[OFFSET(3)], 2) AS p75,
  ROUND(APPROX_QUANTILES(valor, 100)[OFFSET(95)], 2) AS p95,
  ROUND(MAX(valor), 2) AS maximo
FROM valores
GROUP BY variable
ORDER BY variable;

-- -----------------------------------------------------------------------------
-- E2. Distribución por tipo de pago y propina asociada.
-- La propina solo queda registrada en pagos con tarjeta; en efectivo aparece 0.
-- -----------------------------------------------------------------------------
SELECT
  tipo_pago,
  COUNT(*) AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_viajes,
  ROUND(AVG(total_amount), 2) AS total_promedio,
  ROUND(AVG(tip_amount), 2) AS propina_promedio,
  ROUND(100 * COUNTIF(tip_amount > 0) / COUNT(*), 1) AS pct_con_propina
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY tipo_pago
ORDER BY viajes DESC;

-- -----------------------------------------------------------------------------
-- E3. Distribución por tipo de tarifa.
-- -----------------------------------------------------------------------------
SELECT
  tipo_tarifa,
  COUNT(*) AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_viajes,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY tipo_tarifa
ORDER BY viajes DESC;

-- -----------------------------------------------------------------------------
-- E4. Distribución por número de pasajeros (NULL = dato no capturado).
-- -----------------------------------------------------------------------------
SELECT
  COALESCE(CAST(passenger_count AS STRING), 'Sin dato') AS pasajeros,
  COUNT(*) AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_viajes,
  ROUND(AVG(total_amount), 2) AS total_promedio
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY pasajeros
ORDER BY pasajeros;

-- -----------------------------------------------------------------------------
-- E5. Tendencia mensual con variación porcentual respecto al mes anterior (LAG).
-- -----------------------------------------------------------------------------
WITH mensual AS (
  SELECT
    DATE_TRUNC(pickup_date, MONTH) AS mes,
    COUNT(*) AS viajes,
    SUM(total_amount) AS ingreso,
    AVG(total_amount) AS ticket_promedio,
    AVG(trip_distance) AS distancia_promedio
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY mes
)
SELECT
  mes,
  viajes,
  ROUND(100 * SAFE_DIVIDE(viajes - LAG(viajes) OVER (ORDER BY mes), LAG(viajes) OVER (ORDER BY mes)), 1) AS var_viajes_pct,
  ROUND(ingreso, 0) AS ingreso,
  ROUND(100 * SAFE_DIVIDE(ingreso - LAG(ingreso) OVER (ORDER BY mes), LAG(ingreso) OVER (ORDER BY mes)), 1) AS var_ingreso_pct,
  ROUND(ticket_promedio, 2) AS ticket_promedio,
  ROUND(distancia_promedio, 2) AS distancia_promedio
FROM mensual
ORDER BY mes;

-- -----------------------------------------------------------------------------
-- E6. Patrón hora x día de la semana (base del mapa de calor). PIVOT pasa los
--     días a columnas.
-- -----------------------------------------------------------------------------
SELECT *
FROM (
  SELECT
    EXTRACT(HOUR FROM pickup_datetime) AS hora,
    CASE EXTRACT(DAYOFWEEK FROM pickup_datetime)
      WHEN 1 THEN 'dom' WHEN 2 THEN 'lun' WHEN 3 THEN 'mar' WHEN 4 THEN 'mie'
      WHEN 5 THEN 'jue' WHEN 6 THEN 'vie' ELSE 'sab'
    END AS dia,
    1 AS viaje
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
)
PIVOT (SUM(viaje) FOR dia IN ('lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'))
ORDER BY hora;

-- -----------------------------------------------------------------------------
-- E7. Perfil horario normalizado: qué porcentaje de los viajes de días laborales
--     y de fin de semana cae en cada hora. Permite comparar las dos curvas
--     aunque los volúmenes totales sean distintos.
-- -----------------------------------------------------------------------------
WITH por_hora AS (
  SELECT
    EXTRACT(HOUR FROM pickup_datetime) AS hora,
    COUNTIF(EXTRACT(DAYOFWEEK FROM pickup_datetime) NOT IN (1, 7)) AS viajes_laborales,
    COUNTIF(EXTRACT(DAYOFWEEK FROM pickup_datetime) IN (1, 7)) AS viajes_fin_semana
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY hora
)
SELECT
  hora,
  ROUND(100 * viajes_laborales / SUM(viajes_laborales) OVER (), 2) AS pct_laborales,
  ROUND(100 * viajes_fin_semana / SUM(viajes_fin_semana) OVER (), 2) AS pct_fin_semana
FROM por_hora
ORDER BY hora;

-- -----------------------------------------------------------------------------
-- E8. Serie diaria con promedio móvil de 7 días (tendencia sin el ciclo semanal).
-- -----------------------------------------------------------------------------
WITH diario AS (
  SELECT pickup_date AS fecha, COUNT(*) AS viajes, SUM(total_amount) AS ingreso
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY fecha
)
SELECT
  fecha,
  viajes,
  ROUND(AVG(viajes) OVER (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS media_movil_7d,
  ROUND(ingreso, 0) AS ingreso
FROM diario
ORDER BY fecha;

-- -----------------------------------------------------------------------------
-- E9. Días atípicos: los 10 días más por debajo de su media centrada de 7 días
--     (feriados, tormentas, eventos). E19 distingue los eventos reales de las
--     fallas de captura de la fuente.
-- -----------------------------------------------------------------------------
WITH diario AS (
  SELECT pickup_date AS fecha, COUNT(*) AS viajes
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY fecha
),
con_media AS (
  SELECT
    fecha,
    viajes,
    AVG(viajes) OVER (ORDER BY fecha ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING) AS media_centrada_7d
  FROM diario
)
SELECT
  fecha,
  FORMAT_DATE('%A', fecha) AS dia,
  viajes,
  ROUND(media_centrada_7d, 0) AS media_centrada_7d,
  ROUND(100 * (viajes / media_centrada_7d - 1), 1) AS desviacion_pct
FROM con_media
ORDER BY desviacion_pct
LIMIT 10;

-- -----------------------------------------------------------------------------
-- E10. Top 10 zonas de recogida: participación, ingreso y distancia.
-- -----------------------------------------------------------------------------
SELECT
  pickup_location_id,
  zona_origen,
  borough_origen,
  COUNT(*) AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_viajes,
  ROUND(SUM(total_amount), 0) AS ingreso,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY pickup_location_id, zona_origen, borough_origen
ORDER BY viajes DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- E11. Matriz origen-destino por borough. PIVOT pasa los boroughs de destino a
--      columnas.
-- -----------------------------------------------------------------------------
SELECT *
FROM (
  SELECT borough_origen, borough_destino, 1 AS viaje
  FROM nyc_taxi_2022.vw_viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
)
PIVOT (SUM(viaje) FOR borough_destino IN (
  'Manhattan' AS manhattan,
  'Queens' AS queens,
  'Brooklyn' AS brooklyn,
  'Bronx' AS bronx,
  'Staten Island' AS staten_island,
  'EWR' AS newark,
  'Desconocido' AS desconocido,
  'Fuera de NYC' AS fuera_de_nyc
))
ORDER BY borough_origen;

-- -----------------------------------------------------------------------------
-- E12. Aeropuertos frente al resto: volumen, distancia, ingreso y propina.
-- -----------------------------------------------------------------------------
SELECT
  CASE
    WHEN '132' IN (pickup_location_id, dropoff_location_id) THEN 'JFK'
    WHEN '138' IN (pickup_location_id, dropoff_location_id) THEN 'LaGuardia'
    WHEN '1' IN (pickup_location_id, dropoff_location_id) THEN 'Newark'
    ELSE 'Sin aeropuerto'
  END AS segmento,
  COUNT(*) AS viajes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_viajes,
  ROUND(100 * SUM(total_amount) / SUM(SUM(total_amount)) OVER (), 2) AS pct_ingreso,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio,
  ROUND(AVG(duracion_min), 1) AS duracion_promedio,
  ROUND(AVG(total_amount), 2) AS total_promedio,
  ROUND(100 * AVG(IF(payment_type = 1, SAFE_DIVIDE(tip_amount, total_amount - tip_amount), NULL)), 1) AS pct_propina_tarjeta,
  ROUND(100 * COUNTIF(rate_code_id = 2) / COUNT(*), 1) AS pct_tarifa_fija_jfk
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
GROUP BY segmento
ORDER BY viajes DESC;

-- -----------------------------------------------------------------------------
-- E13. Propinas en pagos con tarjeta según la distancia del viaje.
-- -----------------------------------------------------------------------------
SELECT
  CASE
    WHEN trip_distance < 1 THEN '1) menos de 1 mi'
    WHEN trip_distance < 2 THEN '2) 1-2 mi'
    WHEN trip_distance < 5 THEN '3) 2-5 mi'
    WHEN trip_distance < 10 THEN '4) 5-10 mi'
    ELSE '5) 10 mi o más'
  END AS rango_distancia,
  COUNT(*) AS viajes_tarjeta,
  ROUND(AVG(tip_amount), 2) AS propina_promedio,
  ROUND(100 * AVG(SAFE_DIVIDE(tip_amount, total_amount - tip_amount)), 1) AS pct_propina_promedio,
  ROUND(100 * COUNTIF(tip_amount = 0) / COUNT(*), 1) AS pct_sin_propina
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND payment_type = 1
GROUP BY rango_distancia
ORDER BY rango_distancia;

-- -----------------------------------------------------------------------------
-- E14. Propinas con tarjeta por proveedor del taxímetro. Cada proveedor muestra
--      su propia pantalla de pago con montos sugeridos distintos.
-- -----------------------------------------------------------------------------
SELECT
  vendor_id,
  COUNT(*) AS viajes_tarjeta,
  ROUND(100 * AVG(SAFE_DIVIDE(tip_amount, total_amount - tip_amount)), 1) AS pct_propina_promedio,
  ROUND(100 * APPROX_QUANTILES(SAFE_DIVIDE(tip_amount, total_amount - tip_amount), 100)[OFFSET(50)], 1) AS pct_propina_mediana,
  ROUND(100 * COUNTIF(tip_amount = 0) / COUNT(*), 1) AS pct_sin_propina
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND payment_type = 1
GROUP BY vendor_id
ORDER BY vendor_id;

-- -----------------------------------------------------------------------------
-- E15. Propinas con tarjeta por hora del día.
-- -----------------------------------------------------------------------------
SELECT
  EXTRACT(HOUR FROM pickup_datetime) AS hora,
  COUNT(*) AS viajes_tarjeta,
  ROUND(100 * AVG(SAFE_DIVIDE(tip_amount, total_amount - tip_amount)), 1) AS pct_propina_promedio,
  ROUND(100 * COUNTIF(tip_amount = 0) / COUNT(*), 1) AS pct_sin_propina
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND payment_type = 1
GROUP BY hora
ORDER BY hora;

-- -----------------------------------------------------------------------------
-- E16. Congestión: velocidad por hora en viajes internos de Manhattan en días
--      laborales.
-- -----------------------------------------------------------------------------
SELECT
  hora_recogida,
  COUNT(*) AS viajes,
  ROUND(AVG(velocidad_mph), 1) AS velocidad_promedio,
  ROUND(APPROX_QUANTILES(velocidad_mph, 100)[OFFSET(50)], 1) AS velocidad_mediana,
  ROUND(AVG(SAFE_DIVIDE(duracion_min, trip_distance)), 2) AS minutos_por_milla
FROM nyc_taxi_2022.vw_viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  AND borough_origen = 'Manhattan'
  AND borough_destino = 'Manhattan'
  AND NOT es_fin_semana
GROUP BY hora_recogida
ORDER BY hora_recogida;

-- -----------------------------------------------------------------------------
-- E17. Las 3 rutas (zona a zona) de mayor ingreso en cada borough de origen.
-- -----------------------------------------------------------------------------
WITH rutas AS (
  SELECT
    borough_origen,
    zona_origen,
    zona_destino,
    COUNT(*) AS viajes,
    ROUND(SUM(total_amount), 0) AS ingreso,
    ROUND(AVG(total_amount), 2) AS ticket_promedio
  FROM nyc_taxi_2022.vw_viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
    AND borough_origen IN ('Manhattan', 'Queens', 'Brooklyn', 'Bronx')
  GROUP BY borough_origen, zona_origen, zona_destino
)
SELECT
  *,
  RANK() OVER (PARTITION BY borough_origen ORDER BY ingreso DESC) AS ranking
FROM rutas
WHERE TRUE
QUALIFY ranking <= 3
ORDER BY borough_origen, ranking;

-- -----------------------------------------------------------------------------
-- E18. Correlaciones entre variables económicas y de viaje.
-- -----------------------------------------------------------------------------
SELECT
  ROUND(CORR(trip_distance, fare_amount), 3) AS corr_distancia_tarifa,
  ROUND(CORR(duracion_min, fare_amount), 3) AS corr_duracion_tarifa,
  ROUND(CORR(trip_distance, duracion_min), 3) AS corr_distancia_duracion,
  ROUND(CORR(velocidad_mph, fare_amount), 3) AS corr_velocidad_tarifa,
  ROUND(CORR(IF(payment_type = 1, fare_amount, NULL), IF(payment_type = 1, tip_amount, NULL)), 3) AS corr_tarifa_propina_tarjeta
FROM nyc_taxi_2022.viajes
WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30';

-- -----------------------------------------------------------------------------
-- E19. ¿Las caídas de E9 son eventos reales o fallas de captura? Se compara cada
--      hora con la misma hora de 1 y 2 semanas antes y después. Una hora con
--      menos del 25 % de lo esperado es anómala.
--      29-ene (06-15 h) coincide con una ventisca: caída real, se conserva.
--      17-sep 15 h a 18-sep 23 h: la fuente pierde ~95 % de los registros durante
--      33 horas seguidas sin causa externa. Se trata como dato faltante en el
--      modelo de demanda (bqml/01).
-- -----------------------------------------------------------------------------
WITH horas AS (
  SELECT DATETIME_TRUNC(pickup_datetime, HOUR) AS hora, COUNT(*) AS viajes
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
  GROUP BY hora
),
con_referencia AS (
  SELECT
    h.hora,
    h.viajes,
    (SELECT AVG(r.viajes)
     FROM horas AS r
     WHERE r.hora IN (DATETIME_SUB(h.hora, INTERVAL 14 DAY), DATETIME_SUB(h.hora, INTERVAL 7 DAY),
                      DATETIME_ADD(h.hora, INTERVAL 7 DAY), DATETIME_ADD(h.hora, INTERVAL 14 DAY))) AS referencia
  FROM horas AS h
)
SELECT
  DATE(hora) AS fecha,
  COUNT(*) AS horas_anomalas,
  MIN(hora) AS desde,
  MAX(hora) AS hasta,
  SUM(viajes) AS viajes,
  ROUND(SUM(referencia)) AS viajes_esperados
FROM con_referencia
WHERE viajes < 0.25 * referencia
  AND referencia >= 100
GROUP BY fecha
ORDER BY fecha;

-- -----------------------------------------------------------------------------
-- E20. Huecos de un solo proveedor: días en que los viajes de un proveedor caen
--      por debajo del 25 % de su promedio de las 4 semanas previas (mismo día de
--      la semana). Detecta fallas de captura que E19 no ve porque el otro
--      proveedor sigue reportando:
--        10-ago            proveedor 1 (parcial, cae en entrenamiento).
--        18-sep            ambos proveedores (ya visto en E19).
--        14-nov a 20-nov   proveedor 1 completo (cae en el conjunto de prueba).
-- -----------------------------------------------------------------------------
WITH diario AS (
  SELECT pickup_date AS fecha, vendor_id, COUNT(*) AS viajes
  FROM nyc_taxi_2022.viajes
  WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'
    AND vendor_id IN (1, 2)
  GROUP BY fecha, vendor_id
),
grilla AS (
  SELECT fecha, v AS vendor_id
  FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', '2022-11-30')) AS fecha
  CROSS JOIN UNNEST([1, 2]) AS v
),
completo AS (
  SELECT g.fecha, g.vendor_id, COALESCE(d.viajes, 0) AS viajes
  FROM grilla AS g
  LEFT JOIN diario AS d
    ON d.fecha = g.fecha
   AND d.vendor_id = g.vendor_id
),
con_referencia AS (
  SELECT
    *,
    AVG(viajes) OVER (
      PARTITION BY vendor_id, EXTRACT(DAYOFWEEK FROM fecha)
      ORDER BY fecha
      ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING
    ) AS referencia_4sem
  FROM completo
)
SELECT
  vendor_id,
  MIN(fecha) AS desde,
  MAX(fecha) AS hasta,
  COUNT(*) AS dias,
  SUM(viajes) AS viajes,
  ROUND(SUM(referencia_4sem)) AS viajes_esperados
FROM con_referencia
WHERE viajes < 0.25 * referencia_4sem
GROUP BY vendor_id, DATE_TRUNC(fecha, MONTH)
ORDER BY desde;
