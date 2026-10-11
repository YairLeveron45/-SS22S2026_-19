select p.*, c.nombre as categoria, m.nombre as marca
from {{ ref('stg_producto') }} p
join {{ ref('stg_categoria') }} c using (id_categoria)
join {{ ref('stg_marca') }} m using (id_marca)
