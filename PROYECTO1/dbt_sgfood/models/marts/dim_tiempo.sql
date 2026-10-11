with limites as (
select min(fecha) as inicio, max(fecha) as fin from {{ ref('stg_venta') }}
), fechas as (
select generate_series(inicio, fin, interval '1 day')::date as fecha from limites
)
select to_char(fecha, 'YYYYMMDD')::integer as id_tiempo, fecha,
extract(year from fecha)::integer as anio,
extract(quarter from fecha)::integer as trimestre,
extract(month from fecha)::integer as mes,
extract(day from fecha)::integer as dia,
extract(isodow from fecha)::integer as dia_semana
from fechas
