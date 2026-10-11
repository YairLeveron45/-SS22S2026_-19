select 1 as error
where (select count(*) from {{ source('sgfood','venta_detalle') }})
    <> (select count(*) from {{ ref('fact_ventas') }})
or (select coalesce(sum(subtotal),0) from {{ source('sgfood','venta_detalle') }})
    <> (select coalesce(sum(importe_neto),0) from {{ ref('fact_ventas') }})
