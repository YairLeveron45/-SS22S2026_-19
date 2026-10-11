-- Script DDL: Inicialización del Data Warehouse
-- Base de datos: dw_sgfood

-- 1. Esquema RAW (Capa Bronce): Aterrizaje de datos crudos
CREATE SCHEMA IF NOT EXISTS raw;

-- 2. Esquema STAGING (Capa Plata): Datos limpios (Gestionado por dbt)
CREATE SCHEMA IF NOT EXISTS staging;

-- 3. Esquema MARTS (Capa Oro): Modelos dimensionales / Esquema estrella (Gestionado por dbt)
CREATE SCHEMA IF NOT EXISTS marts;

-- Python crea las tablas raw con los tipos de la fuente transaccional.
-- dbt materializa staging y marts; 02_modelo_dimensional.sql aplica PK/FK
-- después de dbt run y de las pruebas de calidad.
