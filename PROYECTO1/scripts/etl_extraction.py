"""Copiar un snapshot de la fuente a raw y cargar un catálogo CSV derivado.

La limpieza de negocio se hace después en dbt. Ver docs/GUIA_DE_ESTUDIO.md.
"""
import csv
import logging
import os
from pathlib import Path
import psycopg2
from psycopg2 import sql

TABLES = ('sucursal', 'categoria', 'marca', 'producto', 'cliente', 'venta', 'venta_detalle')
LOG = logging.getLogger(__name__)

def connect(prefix):
    """SOURCE conecta al origen; DW conecta al destino, usando el entorno."""
    # Docker Compose inyecta estas variables. Python no lee .env directamente.
    return psycopg2.connect(host=os.environ[f'{prefix}_HOST'], port=5432,
        dbname=os.environ[f'{prefix}_DB'], user=os.environ[f'{prefix}_USER'],
        password=os.environ[f'{prefix}_PASSWORD'])

def extract_and_load_data():
    """Recargar todas las tablas raw; confirmar juntas o revertir ante un error."""
    export_dir = Path(os.environ.get('EXPORT_DIR', '/opt/airflow/exports'))
    export_dir.mkdir(parents=True, exist_ok=True)
    source = warehouse = None
    counts = {}
    try:
        source, warehouse = connect('SOURCE'), connect('DW')
        # Todas las consultas ven la misma versión de los datos de origen,
        # aunque otra sesión cambie ventas durante la extracción.
        source.set_session(isolation_level='REPEATABLE READ', readonly=True)
        with source.cursor() as src, warehouse.cursor() as dst:
            # Bloqueo compartido por los cargadores que usan esta misma clave.
            # Se libera al confirmar o revertir la transacción del destino.
            dst.execute("SELECT pg_advisory_xact_lock(7982026)")
            dst.execute('CREATE SCHEMA IF NOT EXISTS raw')
            for table in TABLES:
                src.execute(sql.SQL('SELECT * FROM oltp_sgfood.{}').format(sql.Identifier(table)))
                rows = src.fetchall()
                # fetchall trae la tabla completa a memoria: suficiente para
                # este dataset; a mayor escala se leería por lotes.
                columns = [c.name for c in src.description]
                # Consultar metadatos para reconstruir nombres y tipos en raw.
                # No se copian automáticamente PK/FK del origen.
                src.execute("""SELECT column_name, data_type, character_maximum_length,
                    numeric_precision, numeric_scale FROM information_schema.columns
                    WHERE table_schema='oltp_sgfood' AND table_name=%s ORDER BY ordinal_position""", (table,))
                definitions = []
                for name, dtype, length, precision, scale in src.fetchall():
                    if dtype == 'character varying':
                        dtype = f'varchar({length})'
                    elif dtype == 'numeric':
                        dtype = f'numeric({precision},{scale})'
                    if not (dtype in ('integer', 'bigint', 'date', 'boolean') or dtype.startswith(('varchar(', 'numeric('))):
                        raise ValueError(f'Tipo no soportado en {table}.{name}')
                    definitions.append(sql.SQL('{} {}').format(sql.Identifier(name), sql.SQL(dtype)))
                dst.execute(sql.SQL('CREATE TABLE IF NOT EXISTS raw.{} ({})').format(
                    sql.Identifier(table), sql.SQL(', ').join(definitions)))
                dst.execute(sql.SQL('TRUNCATE raw.{}').format(sql.Identifier(table)))
                # Recarga completa: vaciar e insertar evita acumular duplicados.
                # TRUNCATE también se revierte si falla esta transacción.
                statement = sql.SQL('INSERT INTO raw.{} ({}) VALUES ({})').format(
                    sql.Identifier(table), sql.SQL(', ').join(map(sql.Identifier, columns)),
                    sql.SQL(', ').join(sql.Placeholder() for _ in columns))
                dst.executemany(statement, rows)
                # Identifier protege nombres; Placeholder parametriza valores.
                counts[table] = len(rows)
            # El CSV contiene productos reales de la fuente SQL entregada.
            # Su escritura en disco no se revierte con el rollback de PostgreSQL.
            src.execute('SELECT id_producto, sku, precio_lista, costo_base FROM oltp_sgfood.producto ORDER BY id_producto')
            catalog = export_dir / 'catalogo_productos.csv'
            with catalog.open('w', newline='', encoding='utf-8') as stream:
                writer = csv.writer(stream)
                writer.writerow(('id_producto', 'sku', 'precio_lista', 'costo_base'))
                writer.writerows(src.fetchall())
            dst.execute("""CREATE TABLE IF NOT EXISTS raw.catalogo_csv (
                id_producto integer, sku text, precio_lista numeric(12,2), costo_base numeric(12,2))""")
            dst.execute('TRUNCATE raw.catalogo_csv')
            with catalog.open(newline='', encoding='utf-8') as stream:
                reader = csv.DictReader(stream)
                for row in reader:
                    dst.execute('INSERT INTO raw.catalogo_csv VALUES (%s,%s,%s,%s)',
                        (int(row['id_producto']), row['sku'], row['precio_lista'], row['costo_base']))
            counts['catalogo_csv'] = counts['producto']
            for table, expected in counts.items():
                # Comprobar filas en destino antes de confirmar toda la carga.
                dst.execute(sql.SQL('SELECT count(*) FROM raw.{}').format(sql.Identifier(table)))
                if dst.fetchone()[0] != expected or expected == 0:
                    raise ValueError(f'Conteo inválido para {table}')
            warehouse.commit()
            LOG.info('Carga raw confirmada: %s', counts)
        return counts
    except Exception:
        # Revertir raw y propagar el error: Airflow debe marcar fallo/reintentar.
        if warehouse is not None:
            warehouse.rollback()
        LOG.error('Carga raw revertida por error.')
        raise
    finally:
        # Cerrar conexiones tanto en éxito como en fallo.
        if source is not None:
            source.close()
        if warehouse is not None:
            warehouse.close()

if __name__ == '__main__':
    # Este bloque corre al ejecutar el archivo, no al importarlo desde el DAG.
    logging.basicConfig(level=logging.INFO)
    extract_and_load_data()
