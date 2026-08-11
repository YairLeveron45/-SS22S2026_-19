-- =======================================================
-- Consultas Analíticas y de Validación - Práctica 1
-- =======================================================
USE DW_Vuelos;
GO

-- ==========================================
-- 1. Consultas de Validación de Carga
-- ==========================================
-- Verificar la cantidad total de registros en la tabla de hechos (debe coincidir con los registros del CSV original)
SELECT COUNT(*) AS Total_Registros_Fact_Vuelos FROM Fact_Vuelos;

-- Verificar la cantidad de registros en cada dimensión
SELECT COUNT(*) AS Total_Aerolineas FROM Dim_Aerolinea;
SELECT COUNT(*) AS Total_Pasajeros FROM Dim_Pasajero;
SELECT COUNT(*) AS Total_DetallesVuelo FROM Dim_DetalleVuelo;
SELECT COUNT(*) AS Total_Transacciones FROM Dim_Transaccion;

-- ==========================================
-- 2. Consultas Analíticas (Indicadores de Negocio)
-- ==========================================

-- A. Top 5 Destinos más frecuentes
SELECT TOP 5 
    aeropuerto_destino AS Destino, 
    COUNT(*) AS Numero_Vuelos
FROM Fact_Vuelos
GROUP BY aeropuerto_destino
ORDER BY Numero_Vuelos DESC;

-- B. Distribución de pasajeros por género
SELECT 
    p.genero AS Genero, 
    COUNT(DISTINCT f.id_pasajero) AS Cantidad_Pasajeros
FROM Fact_Vuelos f
INNER JOIN Dim_Pasajero p ON f.id_pasajero = p.id_pasajero
GROUP BY p.genero
ORDER BY Cantidad_Pasajeros DESC;

-- C. Total de ingresos en USD por Aerolínea
SELECT 
    a.nombre_aerolinea AS Aerolinea, 
    SUM(f.precio_usd) AS Total_Ingresos_USD
FROM Fact_Vuelos f
INNER JOIN Dim_Aerolinea a ON f.codigo_aerolinea = a.codigo_aerolinea
GROUP BY a.nombre_aerolinea
ORDER BY Total_Ingresos_USD DESC;

-- D. Promedio de retraso en minutos por Aerolínea
SELECT 
    a.nombre_aerolinea AS Aerolinea, 
    AVG(f.retraso_min) AS Promedio_Retraso_Min
FROM Fact_Vuelos f
INNER JOIN Dim_Aerolinea a ON f.codigo_aerolinea = a.codigo_aerolinea
GROUP BY a.nombre_aerolinea
ORDER BY Promedio_Retraso_Min DESC;

-- E. Cantidad de Vuelos por Canal de Venta
SELECT 
    t.canal_venta AS Canal_Venta, 
    COUNT(*) AS Total_Vuelos
FROM Fact_Vuelos f
INNER JOIN Dim_Transaccion t ON f.id_transaccion = t.id_transaccion
GROUP BY t.canal_venta
ORDER BY Total_Vuelos DESC;

-- F. Promedio de Edad de Pasajeros por Clase de Cabina
-- Útil para saber el perfil demográfico según el tipo de boleto que compran
SELECT 
    d.clase_cabina AS Clase_Cabina,
    AVG(p.edad) AS Promedio_Edad
FROM Fact_Vuelos f
INNER JOIN Dim_DetalleVuelo d ON f.id_detalle = d.id_detalle
INNER JOIN Dim_Pasajero p ON f.id_pasajero = p.id_pasajero
GROUP BY d.clase_cabina
ORDER BY Promedio_Edad DESC;

-- G. Top 5 Nacionalidades con más vuelos
-- Muestra de qué países provienen los clientes más frecuentes
SELECT TOP 5
    p.nacionalidad AS Nacionalidad,
    COUNT(*) AS Total_Vuelos
FROM Fact_Vuelos f
INNER JOIN Dim_Pasajero p ON f.id_pasajero = p.id_pasajero
WHERE p.nacionalidad != 'ND'
GROUP BY p.nacionalidad
ORDER BY Total_Vuelos DESC;

-- H. Eficiencia Operativa: Vuelos por Estado
-- Para ver cuántos vuelos salieron a tiempo, cuántos se retrasaron y cuántos se cancelaron
SELECT 
    d.estado_vuelo AS Estado_Del_Vuelo,
    COUNT(*) AS Cantidad_Vuelos
FROM Fact_Vuelos f
INNER JOIN Dim_DetalleVuelo d ON f.id_detalle = d.id_detalle
GROUP BY d.estado_vuelo
ORDER BY Cantidad_Vuelos DESC;
