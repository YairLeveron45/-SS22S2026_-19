# Tarea #1 - Limpieza y análisis inicial de datos con Python y Pandas

## Grupo 19



- Johan Moises Cardona Rosales - 202201405
- Estiben Yair Lopez Leveron - 202204578

## Dataset utilizado

`dataset_sucio.csv` — 5000 registros de clientes, con las columnas:
`id_cliente, nombre, genero, fecha_registro, gasto_q, ciudad, categoria`

## Descripción del proceso de limpieza

El dataset original presentaba los siguientes problemas de calidad:

- **100 filas duplicadas** (mismo `id_cliente` repetido).
- **Valores faltantes**: 60 en `genero`, 505 en `gasto_q`, 157 en `ciudad`.
- **`genero`** con variantes inconsistentes (`' m '`, `'M'`, `'f'`, `'F'`, espacios en blanco).
- **`ciudad`** y **`categoria`** con mezcla de mayúsculas/minúsculas y espacios extra (ej. `'Antigua'`, `'  ANTIGUA'`, `'antigua '`).
- **`fecha_registro`** en dos formatos distintos (`AAAA-MM-DD` y `DD/MM/AAAA`).
- **`gasto_q`** guardado como texto, con separador decimal mixto (punto y coma).
- **`nombre`** con espacios extra al inicio, final o dobles espacios internos.

Se aplicaron los siguientes pasos:

1. **Eliminación de duplicados** por `id_cliente`, conservando el primer registro.
2. **Tratamiento de vacíos**: `genero` y `ciudad` se rellenaron con `'No especificado'`; `gasto_q` se rellenó con la mediana de la columna tras convertirla a numérico.
3. **Estandarización**: nombres sin espacios extra y en formato título; género unificado a M/F; ciudad y categoría normalizadas (sin espacios, capitalización consistente); fechas unificadas a un solo formato; gasto convertido a valor numérico con punto decimal.
4. **Comparación antes/después** mediante tablas pivote de gasto promedio por ciudad y categoría.
5. **Visualizaciones** del dataset ya limpio.
6. **Exportación** del dataset limpio como `dataset_limpio.csv`.

## Capturas de pantalla

### Estado original del dataset (exploración inicial)

![alt text](image.png)

![alt text](image-1.png)

### Eliminación de duplicados

![alt text](image-2.png)

### Tratamiento de valores vacíos

![alt text](image-3.png)

### Estandarización de valores y formatos

![alt text](image-4.png)

![alt text](image-5.png)


### Tabla pivote - ANTES de la limpieza

![alt text](image-6.png)

![alt text](image-7.png)

### Tabla pivote - DESPUÉS de la limpieza

![alt text](image-12.png)

### Visualización 1 - Distribución del gasto

![alt text](image-8.png)

### Visualización 2 - Gasto por categoría

![alt text](image-10.png)

### Visualización 3 - Clientes por ciudad

![alt text](image-11.png)

## Interpretación de los resultados

El dataset pasó de 5000 a 4900 registros (se eliminaron 100 duplicados por id_cliente), y se corrigieron 722 celdas vacías en total (60 en genero, 505 en gasto_q, 157 en ciudad). Sin este paso, cualquier conteo, promedio o suma calculado directamente sobre los datos originales habría estado sesgado: los duplicados inflan artificialmente las métricas de volumen (por ejemplo, el conteo de clientes por ciudad), y los vacíos en gasto_q habrían obligado a Pandas a excluir esas filas de los cálculos numéricos sin que quedara evidencia de cuántos datos se estaban perdiendo.


**¿Por qué cambia la tabla pivote?**

En la tabla "antes", cada ciudad y categoría escrita de forma distinta (Antigua, ANTIGUA, antigua , antigua) se trata como un grupo independiente, así que el promedio de gasto de una misma ciudad queda repartido en 3 o 4 filas distintas en vez de una sola. Esto no solo hace la tabla más difícil de leer: distorsiona el promedio real, porque cada variante se calcula con una muestra más pequeña y menos representativa que la ciudad completa. Al estandarizar texto (quitar espacios, unificar mayúsculas/minúsculas) y convertir gasto_q de texto con separador decimal mixto a un valor numérico único, la tabla "después" agrupa correctamente cada ciudad y categoría en una sola fila/columna, con un promedio calculado sobre todos sus registros reales. Esto convierte la tabla en una herramienta confiable para comparar el gasto entre segmentos, algo imposible de garantizar con los datos originales.

**Lo que muestran las visualizaciones**

El histograma de gasto_q confirma que, una vez el campo es numérico y sin vacíos, la mayoría de clientes gasta en un rango bajo-medio, sin una concentración anómala que hubiera sido difícil de detectar mientras la columna seguía siendo texto.
El boxplot por categoría permite comparar el rango de gasto entre Retail, Services, Education y Food sobre las mismas cuatro categorías reales, en vez de las más de una decena de variantes de texto que existían antes de estandarizar.
El conteo de clientes por ciudad muestra que Guatemala, Antigua y Quetzaltenango concentran la mayor cantidad de clientes, un resultado que antes de la limpieza habría estado repartido entre varias grafías de la misma ciudad, subestimando su peso real.