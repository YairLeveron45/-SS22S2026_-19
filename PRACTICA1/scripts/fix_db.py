import sqlalchemy
import urllib

server = 'localhost,1433'
database = 'DW_Vuelos'
username = 'sa'
password = 'Practica1_SS2_2026!'

params = urllib.parse.quote_plus(
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={server};"
    f"DATABASE={database};"
    f"UID={username};"
    f"PWD={password}"
)
import os
engine = sqlalchemy.create_engine(f"mssql+pyodbc:///?odbc_connect={params}")

# Leer el archivo SQL usando ruta absoluta basada en la ubicación del script actual
base_dir = os.path.dirname(os.path.abspath(__file__))
sql_path = os.path.join(base_dir, '..', 'db', 'script_db.sql')

with open(sql_path, 'r', encoding='utf-8') as file:
    sql_script = file.read()

# Dividir por 'GO' ya que sqlalchemy no soporta GO nativamente
commands = sql_script.split('GO')

with engine.connect() as conn:
    for cmd in commands:
        if cmd.strip():
            try:
                conn.execute(sqlalchemy.text(cmd))
                conn.commit()
            except Exception as e:
                print("Error ejecutando:", cmd)
                print("Mensaje:", e)

print(" Base de datos restaurada correctamente.")
