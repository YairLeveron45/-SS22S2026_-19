"""Preparar credenciales locales. Se ejecuta al instalar, no en cada DAG."""
from pathlib import Path
import secrets

# __file__ es este script; parents[1] apunta a PROYECTO1 aunque la terminal
# esté en otra carpeta. Así siempre se crea el mismo .env.
target = Path(__file__).resolve().parents[1] / '.env'
if target.exists():
    # Conservar valores evita perder acceso a bases ya inicializadas con ellos.
    raise SystemExit('Se conserva el archivo .env existente.')
keys = ('SOURCE_PASSWORD', 'DW_PASSWORD', 'AIRFLOW_DB_PASSWORD', 'AIRFLOW_ADMIN_PASSWORD', 'AIRFLOW_SECRET_KEY')
# token_hex(24) genera 24 bytes aleatorios representados por 48 caracteres.
# Compose lee este archivo; el script no configura usuarios en PostgreSQL.
target.write_text(''.join(f'{key}={secrets.token_hex(24)}\n' for key in keys), encoding='utf-8')
print('Credenciales generadas en .env, ignorado por Git.')
