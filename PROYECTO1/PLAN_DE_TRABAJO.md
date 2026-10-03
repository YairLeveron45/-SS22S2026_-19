# Plan de Trabajo - Proyecto 1: SG-Food

Este documento detalla los pasos a seguir para implementar el flujo moderno de datos con Python, Apache Airflow, dbt y PostgreSQL.

## Fase 1: Entorno de Trabajo y Datos (Preparación)
- [x] Configurar el entorno local (Python, PostgreSQL, Apache Airflow, dbt-core, dbt-postgres).
- [ ] Generar o buscar los datasets de prueba para SG-Food (Ventas, Productos, Clientes, Inventario).
- [x] Inicializar la estructura de carpetas (`scripts`, `dags`, `sql`, etc.).

## Fase 2: Modelado DDL y Carga Cruda (PostgreSQL + Python)
- [ ] Diseñar el diagrama Entidad-Relación (Esquema Estrella).
- [x] Crear la base de datos `dw_sgfood` y el esquema `raw` en PostgreSQL (Script DDL listo).
- [ ] Desarrollar scripts de Python para extraer datos (CSV/BD) y cargarlos en el esquema `raw` (Esqueleto listo, falta lógica real).

## Fase 3: Transformación Analítica (dbt Core)
- [x] Inicializar el proyecto dbt (`dbt init dbt_sgfood`).
- [x] Configurar la conexión a PostgreSQL en `profiles.yml`.
- [ ] Definir fuentes de datos en `models/staging/sources.yml`.
- [ ] Crear modelos de staging (`stg_...`) para limpieza básica.
- [ ] Crear modelos analíticos (Dimensiones y Hechos) en el esquema `marts`.
- [ ] Configurar pruebas de calidad (`tests`) en dbt.

## Fase 4: Orquestación (Apache Airflow)
- [x] Crear el DAG principal en la carpeta `dags/`.
- [x] Definir tarea de extracción y carga (Python).
- [x] Definir tarea de ejecución de dbt (`dbt run`).
- [x] Definir tarea de pruebas de dbt (`dbt test`).
- [x] Configurar las dependencias lógicas del pipeline.

## Fase 5: Validación y Entrega Final
- [ ] Crear scripts de validación en SQL (consultas analíticas).
- [ ] Redactar la documentación oficial en el `README.md` (Integrantes, arquitectura, dependencias, modelo relacional, manual de ejecución).
- [ ] Validar la estructura de entrega requerida.
- [ ] Subir cambios finales al repositorio en GitHub.
