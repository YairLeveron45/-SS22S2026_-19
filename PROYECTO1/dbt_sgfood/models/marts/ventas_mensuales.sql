select t.anio, t.mes, s.id_sucursal, s.nombre as sucursal,
sum(f.cantidad) as unidades, count(distinct f.id_venta) as ventas,
sum(f.importe_neto) as ingreso_neto, sum(f.margen_estimado) as margen_estimado
from {{ ref('fact_ventas') }} f
join {{ ref('dim_tiempo') }} t using (id_tiempo)
join {{ ref('dim_sucursal') }} s using (id_sucursal)
where f.estado = 'COMPLETADA'
group by t.anio, t.mes, s.id_sucursal, s.nombre
