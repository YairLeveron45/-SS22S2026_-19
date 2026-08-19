-- =======================================================
-- Script de Creación de Base de Datos - Modelo Multidimensional
-- Práctica 1 - Seminario de Sistemas 2
-- Integrantes: Estiben Yair Lopez Leveron, Johan Moises Cardona Rosales
-- =======================================================

-- 1. Crear la base de datos (Opcional, si no la han creado manual)
-- CREATE DATABASE DW_Vuelos;
-- GO
-- USE DW_Vuelos;
-- GO

-- =======================================================
-- ELIMINACIÓN DE TABLAS (Por si necesitan volver a ejecutar el script)
-- =======================================================
IF OBJECT_ID('Fact_Vuelos', 'U') IS NOT NULL DROP TABLE Fact_Vuelos;
IF OBJECT_ID('Dim_Pasajero', 'U') IS NOT NULL DROP TABLE Dim_Pasajero;
IF OBJECT_ID('Dim_Aerolinea', 'U') IS NOT NULL DROP TABLE Dim_Aerolinea;
IF OBJECT_ID('Dim_DetalleVuelo', 'U') IS NOT NULL DROP TABLE Dim_DetalleVuelo;
IF OBJECT_ID('Dim_Transaccion', 'U') IS NOT NULL DROP TABLE Dim_Transaccion;
GO

-- =======================================================
-- CREACIÓN DE DIMENSIONES
-- =======================================================

-- Dimensión Pasajero
CREATE TABLE Dim_Pasajero (
    id_pasajero VARCHAR(100) PRIMARY KEY,
    genero VARCHAR(20),
    edad INT,
    nacionalidad VARCHAR(10)
);
GO

-- Dimensión Aerolínea
CREATE TABLE Dim_Aerolinea (
    codigo_aerolinea VARCHAR(10) PRIMARY KEY,
    nombre_aerolinea VARCHAR(100)
);
GO

-- Dimensión Detalles del Vuelo (Información descriptiva del vuelo)
CREATE TABLE Dim_DetalleVuelo (
    id_detalle INT IDENTITY(1,1) PRIMARY KEY,
    numero_vuelo VARCHAR(20),
    tipo_avion VARCHAR(20),
    clase_cabina VARCHAR(50),
    asiento VARCHAR(10),
    estado_vuelo VARCHAR(20)
);
GO

-- Dimensión Transacción (Información de la venta)
CREATE TABLE Dim_Transaccion (
    id_transaccion INT IDENTITY(1,1) PRIMARY KEY,
    canal_venta VARCHAR(50),
    metodo_pago VARCHAR(50),
    moneda_original VARCHAR(10),
    precio_original DECIMAL(10,2)
);
GO

-- =======================================================
-- CREACIÓN DE TABLA DE HECHOS
-- =======================================================

CREATE TABLE Fact_Vuelos (
    id_registro INT PRIMARY KEY, -- Corresponde al record_id del CSV
    
    -- Llaves Foráneas hacia las dimensiones
    codigo_aerolinea VARCHAR(10),
    id_pasajero VARCHAR(100),
    id_detalle INT,
    id_transaccion INT,
    
    -- Atributos degenerados (Fechas y ubicaciones directas)
    fecha_reserva DATETIME,
    fecha_salida DATETIME,
    fecha_llegada DATETIME,
    aeropuerto_origen VARCHAR(10),
    aeropuerto_destino VARCHAR(10),
    
    -- Métricas (Hechos numéricos)
    duracion_min INT,
    retraso_min INT,
    precio_usd DECIMAL(10,2),
    equipaje_total INT,
    equipaje_documentado INT,

    -- Restricciones de Llave Foránea
    CONSTRAINT FK_Fact_Aerolinea FOREIGN KEY (codigo_aerolinea) REFERENCES Dim_Aerolinea(codigo_aerolinea),
    CONSTRAINT FK_Fact_Pasajero FOREIGN KEY (id_pasajero) REFERENCES Dim_Pasajero(id_pasajero),
    CONSTRAINT FK_Fact_Detalle FOREIGN KEY (id_detalle) REFERENCES Dim_DetalleVuelo(id_detalle),
    CONSTRAINT FK_Fact_Transaccion FOREIGN KEY (id_transaccion) REFERENCES Dim_Transaccion(id_transaccion)
);
GO

-- =======================================================
-- CONSULTAS DE VERIFICACIÓN (Ejecutar después de la carga ETL)
-- =======================================================
/*
SELECT COUNT(*) AS Total_Registros FROM Fact_Vuelos;
SELECT COUNT(*) AS Total_Pasajeros FROM Dim_Pasajero;
*/
