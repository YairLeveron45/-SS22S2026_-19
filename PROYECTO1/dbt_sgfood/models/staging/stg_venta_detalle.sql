select id_detalle, id_venta, id_producto, cantidad, precio_unitario,
descuento, subtotal from {{ source('sgfood', 'venta_detalle') }}
