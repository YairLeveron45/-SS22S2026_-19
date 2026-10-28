# Guía de ejecución

Pasos para reproducir el proyecto en la consola de BigQuery y capturar las evidencias. Los
resultados de referencia de cada script están en el [README](../README.md).

## Requisitos

- Un proyecto de Google Cloud con la API de BigQuery habilitada. El proyecto se ejecutó con
  facturación activa. En modo sandbox (sin facturación), las tablas expiran a los 60 días y algunos
  modelos `BOOSTED_TREE_*` pueden estar restringidos.
- Permisos para crear datasets, tablas y modelos (rol Propietario o BigQuery Admin del proyecto).
- Consumo medido:
  - el README original reporta ~65 GB para consultas y creación de tablas, y cerca de 6 GB
    lógicos de almacenamiento. Estas cifras no acreditan saldo gratuito disponible ni ausencia
    de cobros; el usuario indicó que no dispone de cuota gratuita. El costo real se revisa en
    Facturación de GCP;
  - **los tres modelos `BOOSTED_TREE_*` facturaron ~106 GB de entrenamiento**, porque BigQuery
    cobra su cómputo y no el tamaño de la tabla. La estimación del validador no lo anticipa.
    Antes de correr `bqml/02` y `bqml/03` en una cuenta con facturación, revisar la tarifa de
    BigQuery ML y configurar un presupuesto con alertas.

## Configuración de la consola

1. Abrir <https://console.cloud.google.com/bigquery> y seleccionar el proyecto en la barra superior.
2. **Más → Configuración de consultas** → desmarcar **Usar resultados almacenados en caché**.
   Es obligatorio para `sql/04_comparacion_rendimiento.sql` y recomendable para todo lo demás.
3. Dejar la ubicación de procesamiento en automática. El dataset se crea en `US`.

Los scripts escriben las tablas como `nyc_taxi_2022.<tabla>`, sin ID de proyecto: BigQuery usa el
proyecto activo. No hay que editar nada antes de ejecutar.

## Orden de ejecución

| Paso | Archivo | Cómo ejecutarlo | Crea |
|---|---|---|---|
| 1 | `sql/00_configuracion.sql` | Archivo completo | dataset `nyc_taxi_2022`, tabla `zonas` |
| 2 | `sql/01_exploracion_calidad.sql` | Bloque por bloque | — (solo consultas) |
| 3 | `sql/02_transformacion_tablas.sql` | Archivo completo | `viajes`, `viajes_estandar`, `vw_viajes` |
| 4 | `sql/03_analisis_exploratorio.sql` | Consulta por consulta | — |
| 5 | `sql/04_comparacion_rendimiento.sql` | Consulta por consulta, **caché desactivada**; R1 y R2 al final | `comparacion_consultas` |
| 6 | `sql/05_tablas_dashboard.sql` | Archivo completo | `dash_*` |
| 7 | `bqml/01_preparacion_datos_ml.sql` | Archivo completo | `ml_demanda_horaria`, `ml_propinas` |
| 8 | `bqml/02_modelos_demanda.sql` | Archivo completo (~30 min; **ver costo de boosted tree**) | 5 modelos `reg_demanda_*` |
| 9 | `bqml/03_modelos_propina.sql` | Archivo completo (~25 min; **ver costo de boosted tree**) | 4 modelos `clf_propina_*` |
| 10 | `bqml/04_evaluacion_comparacion.sql` | Archivo completo | `ml_metricas_*`, `ml_curva_roc`, `ml_iteraciones`, `ml_importancia_variables` |
| 11 | `bqml/05_predicciones.sql` | Archivo completo | `ml_pronostico_*`, `ml_pred_propina*`, `ml_matriz_confusion`, `ml_viajes_hipoteticos` |
| 12 | `bqml/06_controles_documentacion.sql` | Consulta completa, después de crear las tablas de métricas; solo lectura | 13 filas de controles de conjuntos, rezagos y comparación de fuga |
| 13 | Data Studio (antes Looker Studio) | Seguir [GUIA_DASHBOARD.md](GUIA_DASHBOARD.md) | Informe visual |

Para ejecutar un bloque: seleccionar el texto de la consulta en el editor y pulsar **Ejecutar**.
La consola corre solo la selección. Al ejecutar un archivo completo, la consola lo trata como
script y muestra un resultado por sentencia (**Ver resultados**).

No es necesario repetir este orden para revisar la documentación entregada. Los resultados
de `bqml/06` ya están exportados en [TSV](../evidencias/controles_documentacion.tsv) y
[JSON](../evidencias/controles_documentacion.json). Su ejecución autorizada procesó 18.94 MB
y registró 40 MB facturados; la consulta de calidad autorizada registró 3.13 GB. Una nueva
ejecución puede generar otro consumo y requiere autorización del usuario.

## Evidencias

La lista de capturas, con nombre de archivo y criterio de la rúbrica, está en
[evidencias/README.md](../evidencias/README.md). Las capturas van en la carpeta `evidencias/`.

## De dónde sale cada resultado del README

| Resultado | Fuente |
|---|---|
| Volumen, esquema y calidad del dataset | `sql/01` bloques 1–9 |
| Registros limpios y particiones | `sql/02` bloques 4–7 |
| Hallazgos exploratorios | `sql/03` E1–E20 |
| Comparación estándar frente a optimizada | `sql/04` R2 (tabla `comparacion_consultas`) |
| Métricas de regresión y selección | `bqml/04` consultas 8a y 8b |
| Métricas de clasificación, umbral y selección | `bqml/04` 8c–8d y `bqml/05` 3a |
| Importancia de variables y pesos | `bqml/04` secciones 6 y 7 |
| Pronóstico rodante y error diario | `bqml/05` 1 y 1b |
| Viajes hipotéticos | `bqml/05` sección 4 |

## Solución de problemas

| Mensaje o síntoma | Causa y solución |
|---|---|
| `Cannot query over table 'viajes' without a filter over column(s) 'pickup_date'` | La tabla exige filtro de partición. Agregar `WHERE pickup_date BETWEEN '2022-01-01' AND '2022-11-30'` (o el rango deseado). |
| `Dataset ... was not found in location ...` | El dataset quedó en otra región. Borrarlo y volver a correr `00_configuracion.sql`, que lo crea en `US`. |
| `Unrecognized name: <columna>` en la tabla pública | Comparar con el esquema real del bloque 3 de `01` y ajustar el nombre en el script. |
| Error al crear un modelo `BOOSTED_TREE_*` | Algunas cuentas sandbox restringen estos modelos. Requieren facturación activa (ver el costo en [Requisitos](#requisitos)). |
| R1 de `04` devuelve 0 filas | Las consultas se corrieron con caché, hace más de 30 días o con otro usuario. Volver a correr S1–S3 con la caché desactivada. |
| Los bytes facturados de una consulta optimizada marcan 10 MB | Es el mínimo facturable por tabla. La comparación usa los **bytes procesados**. |
| VS Code marca errores de sintaxis en los `.sql` | La extensión SQL del editor usa otro dialecto (MySQL/Oracle) y no reconoce `CREATE OR REPLACE TABLE`, `QUALIFY` ni BigQuery ML. La sintaxis válida es la de BigQuery. |
