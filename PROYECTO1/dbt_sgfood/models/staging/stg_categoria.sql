select id_categoria, trim(nombre) as nombre from {{ source('sgfood', 'categoria') }}
