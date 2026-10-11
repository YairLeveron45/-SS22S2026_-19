"""Orquestación: describe qué ejecutar y en qué orden; Airflow lo programa."""
from datetime import datetime, timedelta
import sys
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

sys.path.insert(0, '/opt/airflow/scripts')
# Esta ruta existe dentro del contenedor gracias a los volúmenes de Compose.
from etl_extraction import extract_and_load_data
from validate_warehouse import validate_warehouse

with DAG('sgfood_etl_pipeline', start_date=datetime(2026, 1, 1),
         schedule='@daily', catchup=False, max_active_runs=1,
         default_args={'owner': 'sgfood_team', 'retries': 1,
                       'retry_delay': timedelta(minutes=1)}, tags=['sgfood', 'elt']) as dag:
    # catchup=False evita ejecutar todos los días pasados desde start_date.
    # max_active_runs=1 evita dos ejecuciones simultáneas de este DAG.
    # PythonOperator llama funciones; BashOperator ejecuta comandos del contenedor.
    load = PythonOperator(task_id='extract_and_load_raw', python_callable=extract_and_load_data)
    run = BashOperator(task_id='dbt_run_models',
        bash_command='cd /opt/airflow/dbt_sgfood && dbt run --profiles-dir .')
    test = BashOperator(task_id='dbt_test_quality',
        bash_command='cd /opt/airflow/dbt_sgfood && dbt test --profiles-dir .')
    validate = PythonOperator(task_id='validate_analytics', python_callable=validate_warehouse)
    docs = BashOperator(task_id='dbt_generate_docs',
        bash_command='cd /opt/airflow/dbt_sgfood && dbt docs generate --profiles-dir .')
    # >> establece dependencias, no pasa datos de una función a otra.
    # La comunicación entre tareas se hace mediante las tablas de PostgreSQL.
    # Con la regla predeterminada, una tarea requiere éxito de su predecesora.
    load >> run >> test >> validate >> docs
