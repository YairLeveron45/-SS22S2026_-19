select * from {{ ref('stg_venta') }}
where estado is null or estado not in ('COMPLETADA', 'ANULADA', 'PENDIENTE')
