"""Aplicar claves físicas y conciliar conteos/importes entre raw y marts."""
import logging
from pathlib import Path
from etl_extraction import connect

def validate_warehouse():
    """Fallar si los resultados analíticos pierden filas o cambian ingresos."""
    # El contexto de psycopg2 confirma si termina bien y revierte si hay error.
    with connect('DW') as connection, connection.cursor() as cursor:
        ddl = Path(__file__).resolve().parents[1] / 'sql' / '02_modelo_dimensional.sql'
        cursor.execute(ddl.read_text(encoding='utf-8'))
        # Cuatro subconsultas devuelven una sola fila con los valores a comparar.
        # COALESCE convierte una suma sin filas en cero, para poder compararla.
        cursor.execute("""SELECT
            (SELECT count(*) FROM raw.venta_detalle),
            (SELECT count(*) FROM marts.fact_ventas),
            (SELECT coalesce(sum(d.subtotal),0) FROM raw.venta_detalle d
             JOIN raw.venta v USING(id_venta) WHERE upper(trim(v.estado))='COMPLETADA'),
            (SELECT coalesce(sum(importe_neto),0) FROM marts.fact_ventas WHERE estado='COMPLETADA')""")
        raw_count, fact_count, raw_amount, fact_amount = cursor.fetchone()
        # Comparar todos los detalles, pero ingresos solo de ventas COMPLETADA.
        if raw_count != fact_count or raw_amount != fact_amount or not fact_count:
            raise ValueError('Conteos o importes distintos entre raw y marts.')
        result = {'detalles': fact_count, 'importe_completadas': str(fact_amount)}
        # str conserva el importe decimal en un resultado serializable por Airflow.
        logging.info('Validación aprobada: %s', result)
        return result

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    validate_warehouse()
