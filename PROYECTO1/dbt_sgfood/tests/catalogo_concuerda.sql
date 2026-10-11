select coalesce(p.id_producto, c.id_producto) as id_producto
from {{ ref('stg_producto') }} p
full join {{ ref('stg_catalogo_csv') }} c using (id_producto)
where p.id_producto is null or c.id_producto is null
or p.sku is distinct from c.sku
or p.precio_lista is distinct from c.precio_lista
or p.costo_base is distinct from c.costo_base
