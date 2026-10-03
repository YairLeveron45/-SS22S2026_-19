from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

# Importamos la función de extracción desde nuestros scripts
# import sys
# sys.path.append('/opt/airflow/scripts')
# from etl_extraction import extract_and_load_data

# Argumentos por defecto del DAG
default_args = {
    'owner': 'sgfood_team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Funciones dummy para probar mientras esperamos los datos
def dummy_extract_load():
    print("Iniciando la extracción y carga (EL) con Python...")
    print("Aquí se conectará a la BD/CSV y cargará en Postgres (esquema raw).")
    print("Completado.")

with DAG(
    'sgfood_etl_pipeline',
    default_args=default_args,
    description='Pipeline ELT para SG-Food usando Python, dbt y Postgres',
    schedule_interval=timedelta(days=1), # Se ejecuta diariamente
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=['sgfood', 'elt'],
) as dag:

    # 1. Tarea de Extracción y Carga (Python)
    extract_load_task = PythonOperator(
        task_id='extract_and_load_raw',
        python_callable=dummy_extract_load, 
        # python_callable=extract_and_load_data # Lo cambiaremos cuando programemos el script real
    )

    # 2. Tarea de Transformación (dbt run)
    dbt_run_task = BashOperator(
        task_id='dbt_run_models',
        # Usamos bash para ejecutar dbt dentro del contenedor
        bash_command='cd /opt/airflow/dbt_sgfood && echo "Ejecutando dbt run..."' 
        # El comando real será: bash_command='cd /opt/airflow/dbt_sgfood && dbt run --profiles-dir .'
    )

    # 3. Tarea de Pruebas de Calidad (dbt test)
    dbt_test_task = BashOperator(
        task_id='dbt_test_quality',
        bash_command='cd /opt/airflow/dbt_sgfood && echo "Ejecutando dbt test..."'
        # El comando real será: bash_command='cd /opt/airflow/dbt_sgfood && dbt test --profiles-dir .'
    )

    # Definir el orden lógico de ejecución (Dependencias)
    extract_load_task >> dbt_run_task >> dbt_test_task
