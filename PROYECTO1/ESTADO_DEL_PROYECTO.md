# Estado Actual del Proyecto 1 (SG-Food)

Este documento es una bitácora para que tú y tu compañero/a sepan exactamente dónde nos quedamos y cómo retomar el trabajo cuando reciban los datos.

## 🎯 ¿Qué hemos logrado hasta ahora?
Hemos montado toda la infraestructura técnica (el esqueleto) requerida para el flujo moderno de datos, adelantando todo el trabajo que no dependía del dataset:

1. **Infraestructura Dockerizada:** Tenemos un `docker-compose.yml` que levanta PostgreSQL y Apache Airflow de forma automática. Creamos un `Dockerfile` personalizado para instalar las librerías `dbt-postgres` y `pandas` dentro del entorno de Airflow.
2. **PostgreSQL (Data Warehouse):** Creamos el script `sql/01_init_schemas.sql` que crea los esquemas base que pide el proyecto (`raw`, `staging` y `marts`).
3. **Proyecto dbt Core:** Inicializamos dbt en la carpeta `dbt_sgfood`. Configuramos el `dbt_project.yml` y el `profiles.yml` para conectarse de forma nativa a tu contenedor PostgreSQL.
4. **Orquestación con Apache Airflow:** Creamos el DAG principal `dags/etl_sgfood_dag.py`. Ya orquesta las 3 tareas secuenciales (Extracción Python ➔ dbt run ➔ dbt test) usando funciones simuladas (dummies) para comprobar que la lógica de dependencias funciona.
5. **Script Python:** Dejamos un cascarón base en `scripts/etl_extraction.py` con la estructura de lectura y carga hacia la base de datos usando `pandas`.

---

## ⏸️ ¿Por qué pausamos aquí?
Hemos llegado al límite técnico de lo que se puede construir "a ciegas". 
Para programar la lógica real de extracción (Python), la limpieza de texto y el modelo dimensional en estrella (Dimensiones y Hechos con dbt), necesitamos conocer los nombres exactos de las columnas, las tablas y la naturaleza de los datos que proveerá el auxiliar.

---

## 🚀 Guía: ¿Cómo retomar cuando les entreguen los datos?

Cuando reciban el archivo (CSV o volcado de BD), sigan este plan de acción:

### 1. Iniciar el entorno de trabajo
Abran una terminal en esta carpeta (`Proyecto1`) y ejecuten:
```bash
docker-compose up -d
```
Verifiquen que Airflow carga bien entrando a `http://localhost:8081`.

### 2. Actualizar el script de Python (Fase de Extracción)
Abran `scripts/etl_extraction.py`. Reemplacen el código de ejemplo por el código real que lea el archivo que les pasaron. Asegúrense de que el script haga el *insert* de esos datos hacia una o varias tablas dentro del esquema `raw` de su PostgreSQL.

### 3. Configurar las "Sources" en dbt
Una vez los datos crudos estén en PostgreSQL, vayan a `dbt_sgfood/models/staging/` y creen un archivo `sources.yml`. Ahí deben declarar las tablas crudas que Python acaba de subir para que dbt las reconozca.

### 4. Construir el Modelo Analítico (Transformación)
Esta es la fase de SQL puro dentro de dbt:
- Creen vistas en la carpeta `staging` (`stg_ventas.sql`, etc.) para limpiar nombres de columnas y hacer conversiones de tipos de datos.
- Creen el **modelo dimensional** (Esquema Estrella) en la carpeta `marts`. Creen las tablas de dimensiones (`dim_productos.sql`, `dim_tiempo.sql`) y la tabla de hechos (`fact_ventas.sql`) usando `SELECT` y relacionándolas con `{{ ref('...') }}`.

### 5. Configurar pruebas de calidad
Abran el archivo `tests` o los `.yml` de los modelos y configuren pruebas automáticas (`unique`, `not_null`, `relationships`) para garantizar la calidad de los datos analíticos.

### 6. Conectar los cables finales en Airflow
Por último, abran el DAG `dags/etl_sgfood_dag.py`. Sustituyan los comandos "dummy" que pusimos por las ejecuciones reales:
- Configuren el `PythonOperator` para que llame su script real.
- Sustituyan los `echo` en los `BashOperator` por los comandos reales de dbt (`dbt run --profiles-dir .` y `dbt test --profiles-dir .`).

¡Ejecuten el DAG y habrán finalizado el proyecto!
