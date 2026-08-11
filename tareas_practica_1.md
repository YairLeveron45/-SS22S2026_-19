# Lista de Tareas - Práctica 1: ETL con Python y SQL Server

## 1. Configuración del Entorno y Repositorio
- [ ] Instalar Python (versión 3.10 o superior) y Microsoft SQL Server.
- [ ] Crear repositorio en GitHub con el nombre `SS22S2026_#grupo` (reemplaza `#grupo` por tu número).
- [ ] Crear la carpeta principal `Practica1` dentro del repositorio.

## 2. Base de Datos y Modelado (SQL Server)
- [ ] Diseñar el modelo de datos multidimensional o relacional (diagrama de entidades, atributos y relaciones).
- [ ] Desarrollar script SQL para crear las tablas, estructuras y relaciones de la base de datos.
- [ ] Ejecutar el script en SQL Server para preparar la base destino.

## 3. Proceso ETL (Python)
- [ ] Instalar librerías necesarias: `pandas`, `pyodbc`, `sqlalchemy`, `datetime`.
- [ ] **Extracción**: Programar la lectura de datos desde los archivos fuente proporcionados.
- [ ] **Transformación**: Programar la limpieza, homologación y estandarización de los datos extraídos.
- [ ] **Carga**: Conectar a SQL Server y cargar los datos transformados en las tablas destino.
- [ ] *(Recomendado)* Añadir manejo de excepciones y registro de errores en el código Python.

## 4. Consultas y Validación Analítica (SQL Server)
- [ ] Desarrollar un archivo de script con consultas SQL analíticas.
- [ ] Validar la correcta carga de datos con conteos básicos.
- [ ] Generar indicadores relevantes (Ej. Número de vuelos, Top 5 de destinos más frecuentes, distribución por género).
- [ ] *(Recomendado)* Optimizar las consultas SQL para mejorar el rendimiento.

## 5. Documentación
- [ ] Elaborar la **Documentación Técnica** (en formato PDF o un archivo `README.md` robusto) que contenga:
  - [ ] Descripción detallada del proceso ETL.
  - [ ] Explicación y diagrama del diseño del modelo multidimensional.
  - [ ] Pasos para la ejecución de los scripts.
  - [ ] Resultados obtenidos.
- [ ] *(Recomendado)* Crear visualizaciones básicas con Power BI, Tableau o Python (Matplotlib).

## 6. Entrega Final
- [ ] Asegurar que todos los entregables (Script ETL, Script Base de Datos, Diagrama, Script Consultas, Documentación) estén ordenados en la carpeta `Practica1`.
- [ ] Subir todos los archivos al repositorio en GitHub.
- [ ] Realizar la entrega oficial en la plataforma UEDI (Fecha límite: Semana 5).
