# Evidencia de validación SG-Food

Verificado el **11 de octubre de 2026**, en el entorno Docker local.

## Ejecuciones completas

| Ejecución | Resultado |
|---|---|
| `airflow dags test sgfood_etl_pipeline 2026-10-11` | success |
| Scheduler, run `validation_scheduler_20261011` | success |
| Programada, run `scheduled__2026-10-10T00:00:00+00:00` | success |

Las cinco tareas terminaron en success en las ejecuciones del scheduler:
extracción/carga, dbt run, dbt test, validación analítica y documentación dbt.
Las recargas mantuvieron conteos e importes: no se acumularon duplicados.
Horario del DAG: diario a medianoche UTC (18:00 en Guatemala).

## Datos cargados y modelos

| Tabla raw | Registros |
|---|---:|
| sucursal | 6 |
| categoria | 8 |
| marca | 10 |
| producto | 80 |
| cliente | 250 |
| venta | 1,200 |
| venta_detalle | 3,209 |
| catalogo_csv | 80 |

dbt construyó 16 modelos: 8 staging, 2 intermediate y 6 marts.
`fact_ventas` contiene 3,209 detalles. `dim_tiempo` contiene 243 fechas,
del 2026-01-01 al 2026-08-31. El agregado mensual contiene 48 filas.

## Pruebas y conciliación

- dbt: **PASS=46, WARN=0, ERROR=0, SKIP=0**.
- Airflow no reportó errores de importación del DAG.
- `python -m pip check` dentro de Airflow: sin dependencias rotas.
- Aplicadas y verificadas la PK de hechos y sus cuatro FK hacia dimensiones.
- Consultas de `sql/03_consultas_analiticas.sql` ejecutadas con `ON_ERROR_STOP=1`.

| Estado | Ventas | Detalles | Importe |
|---|---:|---:|---:|
| COMPLETADA | 1,129 | 3,014 | 780,201.72 |
| ANULADA | 48 | 139 | 41,769.16 |
| PENDIENTE | 23 | 56 | 16,481.19 |

Conteo raw = conteo hechos = 3,209.
Importe raw = importe hechos = 838,452.07.
Ingresos completados raw = ingresos completados marts = 780,201.72.
Los ingresos analíticos excluyen registros anulados y pendientes.

## Seguridad y límites

El archivo `.env` está ignorado y no está versionado. La auditoría de archivos
candidatos de Git no encontró los valores de credenciales locales ni los patrones
de tokens/claves privadas revisados. Esa auditoría no sustituye un detector completo
de secretos. Los logs detallados, credenciales y artefactos dbt se mantienen locales.

El catálogo CSV es una exportación de la fuente SQL proporcionada; no una fuente
independiente. El dataset no contiene inventarios. El alcance funcional probado
es ventas, y los costos/márgenes son estimaciones con costos actuales del catálogo.
No se publicaron cambios en GitHub durante esta implementación.
