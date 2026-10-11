select id_producto, upper(trim(sku)) as sku, precio_lista, costo_base
from {{ source('sgfood', 'catalogo_csv') }}
