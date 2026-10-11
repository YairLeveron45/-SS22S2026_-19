select id_sucursal, trim(nombre) as nombre, trim(ciudad) as ciudad,
trim(departamento) as departamento from {{ source('sgfood', 'sucursal') }}
