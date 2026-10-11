select id_producto, upper(trim(sku)) as sku, trim(nombre) as nombre,
id_categoria, id_marca, lower(trim(unidad_medida)) as unidad_medida,
costo_base, precio_lista, activo from {{ source('sgfood', 'producto') }}
