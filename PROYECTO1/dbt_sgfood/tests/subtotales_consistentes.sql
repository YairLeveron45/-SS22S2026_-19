select * from {{ ref('stg_venta_detalle') }}
where abs(subtotal - round(cantidad * precio_unitario * (1-descuento), 2)) > 0.01
or cantidad <= 0 or precio_unitario < 0 or descuento < 0 or descuento > 1
