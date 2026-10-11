select id_venta, fecha::date as fecha, id_cliente, id_sucursal,
upper(trim(canal)) as canal, upper(trim(metodo_pago)) as metodo_pago,
upper(trim(estado)) as estado from {{ source('sgfood', 'venta') }}
