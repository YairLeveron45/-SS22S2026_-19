-- Script DDL: Inicialización del Data Warehouse
-- Base de datos: dw_sgfood

-- 1. Esquema RAW (Capa Bronce): Aterrizaje de datos crudos
CREATE SCHEMA IF NOT EXISTS raw;

-- 2. Esquema STAGING (Capa Plata): Datos limpios (Gestionado por dbt)
CREATE SCHEMA IF NOT EXISTS staging;

-- 3. Esquema MARTS (Capa Oro): Modelos dimensionales / Esquema estrella (Gestionado por dbt)
CREATE SCHEMA IF NOT EXISTS marts;

-- (Opcional) Más adelante agregaremos los CREATE TABLE para el esquema raw
-- una vez que conozcamos el formato exacto de los datos fuente.
