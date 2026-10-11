select d.*, v.fecha, v.id_cliente, v.id_sucursal, v.canal, v.metodo_pago, v.estado,
round(d.cantidad * d.precio_unitario, 2) as importe_bruto,
d.subtotal as importe_neto,
round(d.cantidad * p.costo_base, 2) as costo_estimado
from {{ ref('stg_venta_detalle') }} d
join {{ ref('stg_venta') }} v using (id_venta)
join {{ ref('stg_producto') }} p using (id_producto)
