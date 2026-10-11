select id_marca, trim(nombre) as nombre from {{ source('sgfood', 'marca') }}
