select id_cliente, trim(nit) as nit, trim(nombre) as nombre,
upper(trim(tipo_cliente)) as tipo_cliente, trim(municipio) as municipio,
trim(departamento) as departamento, fecha_alta from {{ source('sgfood', 'cliente') }}
