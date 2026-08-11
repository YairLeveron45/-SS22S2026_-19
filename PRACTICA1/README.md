# Práctica 1: ETL con Python y SQL Server

**Curso:** Seminario de Sistemas 2 - Universidad San Carlos de Guatemala
**Repositorio:** SS22S2026_#19
**Carpeta:** Practica1

## Descripción del Proyecto

Este proyecto implementa un proceso ETL (Extracción, Transformación y Carga) desarrollado en Python para integrar y estandarizar datos provenientes de múltiples fuentes heterogéneas (registros de vuelos). Los datos procesados se cargan en un modelo multidimensional diseñado en Microsoft SQL Server, el cual permite la ejecución de consultas analíticas para facilitar la toma de decisiones empresariales.

## Tecnologías y Herramientas Utilizadas

- **Lenguaje de Programación:** Python 3.10+
- **Motor de Base de Datos:** Microsoft SQL Server
- **Librerías principales:** `pandas`, `pyodbc`, `sqlalchemy`, `datetime`

## Diseño del Modelo Multidimensional

> *Nota para el estudiante: Inserta aquí tu diagrama relacional/dimensional y completa la explicación.*

El modelo de datos implementado sigue un enfoque [dimensional (estrella/copo de nieve) o relacional] para optimizar las consultas.

**Entidades principales:**

- **Tabla de Hechos:** `[Nombre de tu tabla de hechos]`
- **Tablas de Dimensiones:** `[Lista de tus dimensiones, ej: DimTiempo, DimUbicacion, DimPasajero]`

![Diagrama del Modelo de Datos](ruta/a/tu/imagen_diagrama.png)

## Descripción del Proceso ETL

1. **Extracción (Extract):**
   Se conectan y leen los datos desde las diferentes fuentes de origen utilizando `pandas`.
2. **Transformación (Transform):**
   Se realizan procesos de limpieza de datos, tales como:
   - Manejo de valores nulos o inconsistentes.
   - Homologación de formatos de fechas y texto.
   - Estandarización de registros dispersos.
3. **Carga (Load):**
   Se utiliza `pyodbc` y/o `sqlalchemy` para establecer la conexión a SQL Server e insertar la data procesada dentro del modelo multidimensional creado previamente.

## Pasos de Ejecución

Sigue estos pasos para reproducir el funcionamiento del proyecto de forma local:

1. **Clonar el repositorio:**

   ```bash
   git clone https://github.com/tu-usuario/SS22S2026_#grupo.git
   cd SS22S2026_#grupo/Practica1
   ```
2. **Preparar la Base de Datos:**

   - Abre SQL Server Management Studio (SSMS) u otro cliente.
   - Ejecuta el script de creación de base de datos (`script_db.sql`) para generar las tablas y relaciones.
3. **Configurar el entorno de Python:**

   - Se recomienda usar un entorno virtual.

   ```bash
   pip install pandas pyodbc sqlalchemy
   ```

   - Actualiza la cadena de conexión (`connection string`) dentro del código Python con el nombre de tu servidor local de SQL Server.
4. **Ejecutar el proceso ETL:**

   ```bash
   python script_etl.py
   ```
5. **Validar Resultados:**

   - Ejecuta el archivo `consultas_analiticas.sql` en SQL Server para observar los resultados de la carga y los indicadores generados.

## Resultados e Indicadores

A través de las consultas analíticas se ha logrado comprobar la integridad de los datos cargados y extraer información valiosa, como por ejemplo:

- **Total de vuelos registrados:** `[Resultado]`
- **Destinos más frecuentes (Top 5):** `[Resultado]`
- **Distribución por género:** `[Resultado]`

*(Opcional: Si hiciste visualizaciones con Power BI o Matplotlib, puedes incluir capturas de pantalla aquí)*

## Integrantes del Grupo

- Estiben Yair Lopez Leveron
- Johan Moises Cardona Rosales
