# Documentación Técnica: Práctica 1 - ETL con Python

**Curso:** Seminario de Sistemas 2
**Integrantes:** Estiben Yair Lopez Leveron 202204578 , 
                      Johan Moises Cardona Rosales 202201405

---

## 1. Descripción General del Proyecto

Este proyecto implementa una solución completa de **Inteligencia de Negocios (BI)** utilizando un proceso ETL (Extracción, Transformación y Carga) desarrollado en Python y un Data Warehouse alojado en Microsoft SQL Server.

El objetivo principal es tomar un conjunto de datos transaccionales heterogéneos y crudos sobre vuelos (`dataset_vuelos_crudo.csv`), limpiarlos, estandarizarlos y cargarlos en un **Modelo Multidimensional (Esquema Estrella)**. Este modelo permite ejecutar consultas analíticas de alto rendimiento para responder preguntas de negocio clave, como destinos más frecuentes, ingresos por aerolínea y eficiencia operativa.

---

## 2. Diseño del Modelo Multidimensional

El Data Warehouse fue diseñado utilizando un **Esquema Estrella (Star Schema)**, el cual es el estándar de la industria para modelos analíticos. Se priorizó la desnormalización en dimensiones para acelerar las lecturas y facilitar las consultas de agregación.

![Diagrama Entidad-Relación](<docs/E-R%20vuelos.png>)

### 2.1. Tabla de Hechos (`Fact_Vuelos`)

Se ubica en el centro del esquema y su **grano** representa un único vuelo/boleto vendido.

* **Métricas (Hechos):** Contiene los datos cuantitativos aditivos y semi-aditivos: `duracion_min`, `retraso_min`, `precio_usd`, `equipaje_total` y `equipaje_documentado`.
* **Atributos Degenerados:** Datos que pertenecen al evento pero no justifican una dimensión separada: fechas de reserva, salida y llegada; y aeropuertos de origen y destino.
* **Llaves Foráneas:** Conectan los hechos con el contexto dimensional (`codigo_aerolinea`, `id_pasajero`, `id_detalle`, `id_transaccion`).

### 2.2. Tablas de Dimensiones

Proporcionan el contexto (el *quién, qué, dónde, cómo*) de los eventos registrados en la tabla de hechos.

* **`Dim_Aerolinea`**: Catálogo de aerolíneas operadoras, utilizando el código estándar IATA.
* **`Dim_Pasajero`**: Información demográfica del cliente (género, edad, nacionalidad).
* **`Dim_DetalleVuelo`**: Contexto puramente operativo del vuelo físico (número de vuelo, tipo de aeronave, clase de cabina, asiento asignado y estado del vuelo).
* **`Dim_Transaccion`**: Información comercial de la venta (canal de venta, método de pago, moneda original).

---

## 3. Descripción del Proceso ETL

El flujo de Extracción, Transformación y Carga se centralizó en el script `etl.py` haciendo uso intensivo de la librería `pandas` para la manipulación en memoria RAM y `sqlalchemy` para la inyección masiva de datos hacia SQL Server.

### Fase 1: Extracción (Extract)

Se extraen los datos desde el archivo de texto plano `dataset_vuelos_crudo.csv` hacia un DataFrame de Pandas (`df_crudo`). En esta etapa los datos se encuentran en su estado primitivo, listos para su manipulación.

```python
print("\n1. Extrayendo datos...")
df_crudo = pd.read_csv('docs/dataset_vuelos_crudo.csv')
```

### Fase 2: Transformación (Transform)

Es la fase de limpieza profunda (Data Cleansing) y estructuración:

1. **Manejo de Nulos e Integridad Referencial:**
   Para garantizar que ninguna consulta analítica futura sufra pérdida de registros al hacer `JOIN`, los valores nulos (NaN) fueron estandarizados utilizando la función `fillna()` de Pandas.

```python
# Ejemplo de estandarización de nulos
df_crudo['cabin_class'] = df_crudo['cabin_class'].fillna('DESCONOCIDO')
df_crudo['seat'] = df_crudo['seat'].fillna('ND')
df_crudo['delay_min'] = df_crudo['delay_min'].fillna(0)
```

2. **Homologación de Datos:**
   La columna de género presentaba variaciones minúsculas y mayúsculas. Se estandarizó todo y se mapeó explícitamente hacia categorías legibles (`Masculino`, `Femenino`, `NoBinario`).

```python
df_crudo['passenger_gender'] = df_crudo['passenger_gender'].str.upper()
mapeo_generos = {'M': 'Masculino', 'F': 'Femenino', 'X': 'NoBinario'}
df_crudo['passenger_gender'] = df_crudo['passenger_gender'].replace(mapeo_generos)
```

3. **Generación de Dimensiones:**
   Se fragmentó el DataFrame original extrayendo columnas específicas para construir los DataFrames de las dimensiones, aplicando `drop_duplicates()` para garantizar la unicidad de los registros maestros.

```python
# Ejemplo de creación de la Dimensión Aerolínea
dim_aerolinea = df_crudo[['airline_code', 'airline_name']].dropna(subset=['airline_code'])
dim_aerolinea['airline_name'] = dim_aerolinea['airline_name'].str.upper()
dim_aerolinea = dim_aerolinea.drop_duplicates(subset=['airline_code'])
```

### Fase 3: Carga (Load)

1. **Carga de Dimensiones y Recuperación de Llaves:**
   Se insertan las dimensiones hacia SQL Server. Como algunas tablas generan sus propios IDs (`IDENTITY`), se leen nuevamente desde la base de datos para recuperar esos IDs recién creados.

```python
dim_detalle.to_sql('Dim_DetalleVuelo', con=engine, if_exists='append', index=False)
dim_detalle_db = pd.read_sql("SELECT * FROM Dim_DetalleVuelo", con=engine)
```

2. **Cruce (Merge) y Carga de Hechos:**
   Se hace un cruce (`merge`) del dataset crudo transformado contra las dimensiones extraídas de SQL para mapear correctamente las llaves foráneas. Finalmente, se inserta en `Fact_Vuelos`.

```python
# Cruzar datos para inyectar el id_detalle autogenerado a los hechos
fact_vuelos = df_crudo.merge(
    dim_detalle_db,
    left_on=['flight_number', 'aircraft_type', 'cabin_class', 'seat', 'status'],
    right_on=['numero_vuelo', 'tipo_avion', 'clase_cabina', 'asiento', 'estado_vuelo'],
    how='left'
)

# Carga masiva final a SQL Server
fact_final.to_sql('Fact_Vuelos', con=engine, if_exists='append', index=False)
```

---

## 4. Pasos de Ejecución

Para replicar y desplegar el proyecto desde cero, siga este flujo:

1. **Requisitos Previos:**

   * Tener Docker instalado y corriendo.
   * Python 3.10 o superior con las dependencias: `pip install pandas sqlalchemy pyodbc`.
2. **Levantar el Motor de Base de Datos:**
   Ejecutar el contenedor de SQL Server a través del archivo Docker Compose.

   ```bash
   docker-compose up -d
   ```
3. **Recreación del Modelo y Limpieza (Opcional/Recomendado):**
   Si la base de datos ya contiene datos de una prueba anterior, se puede limpiar y recrear el modelo vacío (ejecuta el script DDL `script_db.sql` a través de Python):

   ```bash
   python scripts/fix_db.py
   ```
4. **Ejecución del ETL:**
   Extrae, transforma y carga los 10,000 registros del CSV hacia el Data Warehouse.

   ```bash
   python scripts/etl.py
   ```
5. **Validación:**
   Puede ejecutar las consultas de prueba analíticas a través del script de validación provisto:

   ```bash
   python scripts/test_queries.py
   ```

   *(Alternativamente, puede abrir y ejecutar `db/consultas.sql` en su cliente IDE SQL preferido).*

---

## 5. Resultados Obtenidos y Consultas Analíticas

Tras la ejecución del proceso ETL, se logró cargar con éxito el 100% del dataset original (**10,000 registros en la tabla de hechos**) sin violaciones de integridad ni pérdida de datos.

A través del archivo `consultas.sql`, el modelo permite responder de forma inmediata a los siguientes indicadores de negocio:

* **Destinos más solicitados (Top 5):** Permite a las aerolíneas saber qué rutas tienen mayor demanda (ej. SAP, CUN, BCN).
* **Distribución Demográfica (Género y Nacionalidad):** Totalmente estandarizada (Masculino, Femenino, NoBinario).
* **Ingresos Brutos por Aerolínea:** Sumatoria de las ventas en USD, liderada en este corte por Copa Airlines.
* **Indicadores de Eficiencia Operativa:**
  * Promedio de retrasos en minutos clasificado por aerolínea.
  * Conteo de vuelos clasificados por su estado operativo (`ON_TIME`, `DELAYED`, `CANCELLED`).
* **Canales de Venta:** Muestra la preferencia de los usuarios al comprar boletos (Aeropuerto, Web, Agencia, Call Center, App), evidenciando de manera clara los registros cuyo canal fue estandarizado a `'DESCONOCIDO'` por falta de captura en origen, garantizando la visibilidad de la calidad de datos.
