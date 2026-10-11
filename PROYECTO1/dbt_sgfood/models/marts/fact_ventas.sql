select id_detalle, id_venta, to_char(fecha,'YYYYMMDD')::integer as id_tiempo,
id_producto, id_cliente, id_sucursal, canal, metodo_pago, estado,
cantidad, precio_unitario, descuento, importe_bruto, importe_neto,
importe_bruto - importe_neto as importe_descuento,
costo_estimado, importe_neto - costo_estimado as margen_estimado
from {{ ref('int_ventas') }}
