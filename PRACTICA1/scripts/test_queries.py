import pandas as pd
from sqlalchemy import create_engine
import urllib

# Conexión
server = 'localhost,1433'
database = 'DW_Vuelos'
username = 'sa'
password = 'Practica1_SS2_2026!'

try:
    params = urllib.parse.quote_plus(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password}"
    )
    engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")

    # Leer archivo de consultas
    with open('consultas.sql', 'r', encoding='utf-8') as f:
        sql = f.read()

    # Extraer las consultas individuales (separadas por GO o punto y coma)
    # Por simplicidad, las ejecutaremos una por una
    queries = [
        ("Total Fact_Vuelos", "SELECT COUNT(*) AS Total_Registros_Fact_Vuelos FROM Fact_Vuelos;"),
        ("Total Aerolineas", "SELECT COUNT(*) AS Total_Aerolineas FROM Dim_Aerolinea;"),
        ("Total Pasajeros", "SELECT COUNT(*) AS Total_Pasajeros FROM Dim_Pasajero;"),
        ("Total DetallesVuelo", "SELECT COUNT(*) AS Total_DetallesVuelo FROM Dim_DetalleVuelo;"),
        ("Total Transacciones", "SELECT COUNT(*) AS Total_Transacciones FROM Dim_Transaccion;"),
        ("Top 5 Destinos", "SELECT TOP 5 aeropuerto_destino AS Destino, COUNT(*) AS Numero_Vuelos FROM Fact_Vuelos GROUP BY aeropuerto_destino ORDER BY Numero_Vuelos DESC;"),
        ("Genero", "SELECT p.genero AS Genero, COUNT(DISTINCT f.id_pasajero) AS Cantidad_Pasajeros FROM Fact_Vuelos f INNER JOIN Dim_Pasajero p ON f.id_pasajero = p.id_pasajero GROUP BY p.genero ORDER BY Cantidad_Pasajeros DESC;"),
        ("Ingresos USD", "SELECT a.nombre_aerolinea AS Aerolinea, SUM(f.precio_usd) AS Total_Ingresos_USD FROM Fact_Vuelos f INNER JOIN Dim_Aerolinea a ON f.codigo_aerolinea = a.codigo_aerolinea GROUP BY a.nombre_aerolinea ORDER BY Total_Ingresos_USD DESC;"),
        ("Retraso Min", "SELECT a.nombre_aerolinea AS Aerolinea, AVG(f.retraso_min) AS Promedio_Retraso_Min FROM Fact_Vuelos f INNER JOIN Dim_Aerolinea a ON f.codigo_aerolinea = a.codigo_aerolinea GROUP BY a.nombre_aerolinea ORDER BY Promedio_Retraso_Min DESC;"),
        ("Canal Venta", "SELECT t.canal_venta AS Canal_Venta, COUNT(*) AS Total_Vuelos FROM Fact_Vuelos f INNER JOIN Dim_Transaccion t ON f.id_transaccion = t.id_transaccion GROUP BY t.canal_venta ORDER BY Total_Vuelos DESC;")
    ]

    for name, q in queries:
        print(f"\n--- {name} ---")
        try:
            df = pd.read_sql(q, con=engine)
            print(df.to_string())
        except Exception as e:
            print(f"Error en consulta {name}: {e}")

except Exception as e:
    print(f"Error de conexión: {e}")
