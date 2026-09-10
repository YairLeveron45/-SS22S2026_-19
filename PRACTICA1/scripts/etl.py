import pandas as pd
from sqlalchemy import create_engine, text
import urllib

# ==========================================
# 1. Parámetros de Conexión
# ------------------------------------------
# Configura las credenciales y el string de conexión (ODBC) para 
# enlazarse a la base de datos SQL Server 'DW_Vuelos'. 
# Utiliza SQLAlchemy para permitir cargas masivas rápidas (fast_executemany).
# ==========================================
server = 'localhost,1433'
database = 'DW_Vuelos'
username = 'sa'
password = 'Practica1_SS2_2026!'

# Crear la cadena de conexión SQLAlchemy
print("Conectando a la base de datos...")
# Usamos ODBC Driver 17 for SQL Server.
params = urllib.parse.quote_plus(
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={server};"
    f"DATABASE={database};"
    f"UID={username};"
    f"PWD={password}"
)
engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}", fast_executemany=True)

# ==========================================
# 2. Extracción (Extract)
# ------------------------------------------
# Lee el archivo CSV origen ('dataset_vuelos_crudo.csv') utilizando pandas 
# y lo carga en la memoria RAM como un DataFrame (df_crudo) para 
# su posterior manipulación.
# ==========================================
print("\n1. Extrayendo datos...")
import os
base_dir = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(base_dir, '..', 'docs', 'dataset_vuelos_crudo.csv')

# EXTRAER: Aquí ocurre la "E" de ETL. Se lee el archivo CSV físico 
# y pandas lo convierte en una tabla estructurada en memoria (un DataFrame).
df_crudo = pd.read_csv(csv_path)

# ==========================================
# 3. Transformación (Transform)
# ------------------------------------------
# Es la fase más extensa (Data Cleansing). Aquí se realizan varias tareas:
# - Limpieza de nulos (NaN): Sustituye campos vacíos por 'DESCONOCIDO', 'ND' o 0.
# - Homologación de formatos: Pasa géneros a mayúsculas y renombra valores.
# - Tipos de dato: Convierte cadenas de texto a formato DateTime o Float.
# - Separación dimensional: Divide el dataset general (df_crudo) en las distintas
#   dimensiones del esquema estrella, eliminando duplicados y renombrando 
#   las columnas para que coincidan con la base de datos.
# ==========================================
print("2. Transformando datos...")

# Limpieza de nulos básicos
df_crudo['cabin_class'] = df_crudo['cabin_class'].fillna('DESCONOCIDO')
df_crudo['seat'] = df_crudo['seat'].fillna('ND')
df_crudo['delay_min'] = df_crudo['delay_min'].fillna(0)
df_crudo['duration_min'] = df_crudo['duration_min'].fillna(0)
df_crudo['aircraft_type'] = df_crudo['aircraft_type'].fillna('DESCONOCIDO')
df_crudo['sales_channel'] = df_crudo['sales_channel'].fillna('DESCONOCIDO')
df_crudo['passenger_age'] = df_crudo['passenger_age'].fillna(0)
df_crudo['passenger_nationality'] = df_crudo['passenger_nationality'].fillna('ND')

# Homologar géneros
# LIMPIEZA/HOMOLOGACIÓN: Estandariza los textos. Primero pasa todo a mayúsculas
# y luego cambia códigos cortos por la palabra completa ('M' a 'Masculino')
df_crudo['passenger_gender'] = df_crudo['passenger_gender'].str.upper()
mapeo_generos = {'M': 'Masculino', 'F': 'Femenino', 'X': 'NoBinario'}
df_crudo['passenger_gender'] = df_crudo['passenger_gender'].replace(mapeo_generos)

# Estandarización de Fechas (convertir de string a datetime de pandas)
df_crudo['departure_datetime'] = pd.to_datetime(df_crudo['departure_datetime'], format='mixed', dayfirst=True)
df_crudo['arrival_datetime'] = pd.to_datetime(df_crudo['arrival_datetime'], format='mixed', dayfirst=True)
df_crudo['booking_datetime'] = pd.to_datetime(df_crudo['booking_datetime'], format='mixed', dayfirst=True)

# Limpiar precios que podrían venir como string con comas (ej. "77,60") en lugar de punto ("77.60")
df_crudo['ticket_price'] = df_crudo['ticket_price'].astype(str).str.replace(',', '.').astype(float)

# PREPARACIÓN DE LAS DIMENSIONES

# Dim_Aerolinea
# SEPARACIÓN DIMENSIONAL: Crea el catálogo de aerolíneas tomando solo dos columnas.
# El drop_duplicates asegura que cada aerolínea aparezca una sola vez, creando un catálogo limpio.
dim_aerolinea = df_crudo[['airline_code', 'airline_name']].dropna(subset=['airline_code'])
dim_aerolinea['airline_name'] = dim_aerolinea['airline_name'].str.upper() # Estandarizar a mayúsculas
dim_aerolinea = dim_aerolinea.drop_duplicates(subset=['airline_code'])
dim_aerolinea = dim_aerolinea.rename(columns={
    'airline_code': 'codigo_aerolinea',
    'airline_name': 'nombre_aerolinea'
})

# Dim_Pasajero
dim_pasajero = df_crudo[['passenger_id', 'passenger_gender', 'passenger_age', 'passenger_nationality']].dropna(subset=['passenger_id'])
dim_pasajero = dim_pasajero.drop_duplicates(subset=['passenger_id'])
dim_pasajero = dim_pasajero.rename(columns={
    'passenger_id': 'id_pasajero',
    'passenger_gender': 'genero',
    'passenger_age': 'edad',
    'passenger_nationality': 'nacionalidad'
})

# Dim_DetalleVuelo
# Para evitar duplicados en la dimensión, sacamos las combinaciones únicas.
dim_detalle = df_crudo[['flight_number', 'aircraft_type', 'cabin_class', 'seat', 'status']].drop_duplicates().reset_index(drop=True)
dim_detalle = dim_detalle.rename(columns={
    'flight_number': 'numero_vuelo',
    'aircraft_type': 'tipo_avion',
    'cabin_class': 'clase_cabina',
    'seat': 'asiento',
    'status': 'estado_vuelo'
})

# Dim_Transaccion
dim_transaccion = df_crudo[['sales_channel', 'payment_method', 'currency', 'ticket_price']].drop_duplicates().reset_index(drop=True)
dim_transaccion = dim_transaccion.rename(columns={
    'sales_channel': 'canal_venta',
    'payment_method': 'metodo_pago',
    'currency': 'moneda_original',
    'ticket_price': 'precio_original'
})

# ==========================================
# 4. Carga (Load)
# ------------------------------------------
# Esta fase inserta los DataFrames limpios en las tablas de SQL Server.
# Primero se limpia la base de datos eliminando registros anteriores para sobreescribir.
# Luego, se cargan las dimensiones para que SQL Server genere sus llaves 
# primarias autoincrementables (IDENTITY). 
# Después, se hace un 'merge' (cruce) con el dataset original para recuperar 
# esos IDs generados y finalmente se inserta todo en la tabla de hechos Fact_Vuelos.
# ==========================================
print("\n3. Limpiando datos existentes (Sobreescribiendo base de datos)...")
try:
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM Fact_Vuelos"))
        conn.execute(text("DELETE FROM Dim_Transaccion"))
        conn.execute(text("DELETE FROM Dim_DetalleVuelo"))
        conn.execute(text("DELETE FROM Dim_Pasajero"))
        conn.execute(text("DELETE FROM Dim_Aerolinea"))
    print("   -> Datos anteriores eliminados con éxito.")
except Exception as e:
    print(f"   -> Advertencia al limpiar datos: {e}")

print("\n4. Cargando dimensiones simples (Dim_Aerolinea, Dim_Pasajero)...")
dim_aerolinea.to_sql('Dim_Aerolinea', con=engine, if_exists='append', index=False)
dim_pasajero.to_sql('Dim_Pasajero', con=engine, if_exists='append', index=False)

print("5. Cargando e insertando Dim_DetalleVuelo (Generando IDs Identity)...")
dim_detalle.to_sql('Dim_DetalleVuelo', con=engine, if_exists='append', index=False)
# ¡MUY IMPORTANTE!: Al insertar, SQL Server le asignó a cada registro un ID autonumérico.
# Esta línea vuelve a descargar la tabla para obtener esos IDs (id_detalle) que Python no conocía.
dim_detalle_db = pd.read_sql("SELECT * FROM Dim_DetalleVuelo", con=engine)

print("6. Cargando e insertando Dim_Transaccion (Generando IDs Identity)...")
dim_transaccion.to_sql('Dim_Transaccion', con=engine, if_exists='append', index=False)
# Recuperamos la tabla desde la BD ya con los id_transaccion asignados
dim_transaccion_db = pd.read_sql("SELECT * FROM Dim_Transaccion", con=engine)

print("\n7. Construyendo la tabla de hechos Fact_Vuelos...")
# Merge para obtener id_detalle relacionando por sus atributos
# CRUCE (MERGE): Cruza los vuelos crudos originales con el catálogo descargado.
# Esto sirve para reemplazar los textos largos por el 'id_detalle' numérico generado en SQL Server.
fact_vuelos = df_crudo.merge(
    dim_detalle_db,
    left_on=['flight_number', 'aircraft_type', 'cabin_class', 'seat', 'status'],
    right_on=['numero_vuelo', 'tipo_avion', 'clase_cabina', 'asiento', 'estado_vuelo'],
    how='left'
)

# Merge para obtener id_transaccion relacionando por sus atributos
fact_vuelos = fact_vuelos.merge(
    dim_transaccion_db,
    left_on=['sales_channel', 'payment_method', 'currency', 'ticket_price'],
    right_on=['canal_venta', 'metodo_pago', 'moneda_original', 'precio_original'],
    how='left'
)

# Seleccionar y renombrar las columnas finales para insertarlas en Fact_Vuelos
fact_final = fact_vuelos[[
    'record_id', 'airline_code', 'passenger_id', 'id_detalle', 'id_transaccion',
    'booking_datetime', 'departure_datetime', 'arrival_datetime',
    'origin_airport', 'destination_airport',
    'duration_min', 'delay_min', 'ticket_price_usd_est', 'bags_total', 'bags_checked'
]].copy()

# Renombrar columnas: 
# Traduce los nombres de las columnas que venían en inglés en el CSV crudo 
# para que coincidan exactamente con los nombres en español que tiene 
# la tabla Fact_Vuelos en la base de datos SQL Server.
fact_final = fact_final.rename(columns={
    'record_id': 'id_registro',
    'airline_code': 'codigo_aerolinea',
    'passenger_id': 'id_pasajero',
    'booking_datetime': 'fecha_reserva',
    'departure_datetime': 'fecha_salida',
    'arrival_datetime': 'fecha_llegada',
    'origin_airport': 'aeropuerto_origen',
    'destination_airport': 'aeropuerto_destino',
    'duration_min': 'duracion_min',
    'delay_min': 'retraso_min',
    'ticket_price_usd_est': 'precio_usd',
    'bags_total': 'equipaje_total',
    'bags_checked': 'equipaje_documentado'
})

print("8. Cargando tabla de hechos (Fact_Vuelos)...")
fact_final.to_sql('Fact_Vuelos', con=engine, if_exists='append', index=False)

print("\n Proceso ETL Finalizado exitosamente. ¡Datos en SQL Server listos para análisis!")
