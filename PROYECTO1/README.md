# Proyecto 1: Flujo Moderno de Datos (SG-Food)

Este proyecto implementa una solución completa de integración, transformación y modelado analítico de datos (ELT) utilizando Python, Apache Airflow, dbt y PostgreSQL.

## 🏗️ Arquitectura del Sistema
El flujo sigue una arquitectura **ELT**:
1. **Extracción y Carga (Python)**: Extrae datos desde las fuentes (CSVs/BD) y los carga crudos en PostgreSQL.
2. **Data Warehouse (PostgreSQL)**: Almacena los datos estructurados en esquemas lógicos (`raw`, `staging`, `marts`).
3. **Transformación (dbt Core)**: Limpia y modela los datos dentro de PostgreSQL, aplicando pruebas de calidad.
4. **Orquestación (Apache Airflow)**: Coordina la ejecución ordenada y controlada de todo el proceso.

## 🚀 Manual de Instalación y Ejecución (Local con Docker)

Toda la infraestructura se levantará mediante Docker.

### 1. Requisitos
- [Docker](https://www.docker.com/products/docker-desktop/) instalado y corriendo en tu computadora.

### 2. Levantar la infraestructura
Abre una terminal, navega a la carpeta de este proyecto y ejecuta:
```bash
docker-compose up -d
```
Esto levantará PostgreSQL y Apache Airflow en segundo plano.

### 3. Accesos
* **Apache Airflow (UI)**: Visita `http://localhost:8081`
  * **Usuario:** admin
  * **Contraseña:** admin
* **PostgreSQL (Data Warehouse)**:
  * **Host:** `localhost`
  * **Puerto:** `5432`
  * **Usuario:** `sgfood_user`
  * **Contraseña:** `sgfood_password`
  * **Base de datos:** `dw_sgfood`

### 4. Detener la infraestructura
Cuando dejes de trabajar, puedes apagar los contenedores con:
```bash
docker-compose down
```

## 📁 Estructura del Repositorio
* `/dags`: DAGs de Apache Airflow que orquestan el pipeline.
* `/scripts`: Scripts de Python para extracción y limpieza inicial.
* `/sql`: DDL del Data Warehouse (creación de esquemas y tablas).
* `/dbt_sgfood`: Proyecto dbt con modelos analíticos (staging y marts).
