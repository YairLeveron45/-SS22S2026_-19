# Guía del informe visual en Data Studio (antes Looker Studio)

El informe tiene cuatro páginas: exploración, optimización, pronóstico de demanda y clasificación
de propinas. Se conecta a las tablas `dash_*`, `comparacion_consultas` y `ml_*`, que son pequeñas
y ya están agregadas. **No conectar el informe a `viajes`**: esa tabla exige filtro de partición y
cada gráfico la recorrería completa.

## 1. Crear el informe y las fuentes de datos

1. Abrir <https://lookerstudio.google.com> → **Crear → Informe**.
2. **Agregar datos → BigQuery → Mis proyectos →** proyecto → `nyc_taxi_2022` → `dash_diario` →
   **Agregar**.
3. Repetir desde **Recurso → Administrar fuentes de datos agregadas → Agregar una fuente de datos**
   para cada tabla:

   | Página | Tablas |
   |---|---|
   | Exploración | `dash_diario`, `dash_hora_semana`, `dash_zonas`, `dash_pagos_mensual`, `dash_origen_destino` |
   | Optimización | `comparacion_consultas` |
   | Pronóstico de demanda | `ml_pronostico_demanda`, `ml_pronostico_error_diario`, `ml_metricas_regresion`, `ml_iteraciones` |
   | Propinas | `ml_metricas_clasificacion`, `ml_curva_roc`, `ml_matriz_confusion`, `ml_importancia_variables`, `ml_pred_propina_diaria` |

4. Verificar en cada fuente que las credenciales sean las **del propietario** (opción por defecto).
   Así, quien abra el enlace ve los datos sin necesitar acceso a BigQuery.

## 2. Campos calculados

Las tablas guardan sumas y conteos para que los promedios se calculen bien al agrupar. En cada
fuente: **Recurso → Administrar fuentes de datos agregadas → Editar → Agregar un campo**.

| Fuente | Campo | Fórmula | Formato |
|---|---|---|---|
| `dash_diario` | Ticket promedio | `SUM(ingreso_total) / SUM(viajes)` | Moneda USD |
| `dash_diario` | Tarifa promedio | `SUM(suma_tarifa) / SUM(viajes)` | Moneda USD |
| `dash_diario` | Distancia promedio | `SUM(suma_distancia) / SUM(viajes)` | Número |
| `dash_diario` | Duración promedio | `SUM(suma_duracion) / SUM(viajes)` | Número |
| `dash_diario` | % propina (tarjeta) | `SUM(suma_pct_propina_tarjeta) / SUM(viajes_tarjeta_con_pct)` | Porcentaje |
| `dash_diario` | % viajes con propina | `SUM(viajes_tarjeta_con_propina) / SUM(viajes_tarjeta)` | Porcentaje |
| `dash_hora_semana` | Velocidad promedio | `SUM(suma_velocidad) / SUM(viajes)` | Número |
| `dash_zonas` | % propina (tarjeta) | `SUM(suma_pct_propina_tarjeta) / SUM(viajes_tarjeta_con_pct)` | Porcentaje |

En `ml_pronostico_demanda`, cambiar el tipo del campo `hora` a **Fecha y hora → Fecha, hora y
minuto** (o **Fecha y hora**) para que la serie temporal sea horaria.

## 3. Página 1: Exploración

| # | Gráfico | Fuente | Configuración |
|---|---|---|---|
| 1 | Control de rango de fechas | `dash_diario` | Dimensión `fecha`. Período predeterminado: 1 ene – 30 nov 2022 (la tabla pública no trae diciembre). |
| 2 | Control de lista desplegable | `dash_diario` | Dimensión `borough`. |
| 3 | Cuatro tarjetas de resultados | `dash_diario` | `viajes`, `ingreso_total`, Ticket promedio, % propina (tarjeta). |
| 4 | Serie temporal | `dash_diario` | Dimensión `fecha`, métrica `viajes`, desglose `borough`. En Estilo, activar línea de tendencia si se desea. |
| 5 | Tabla dinámica con mapa de calor | `dash_hora_semana` | Fila `hora` (orden ascendente), columna `nombre_dia`, métrica `viajes`. Estilo → mapa de calor. |
| 6 | Barras horizontales | `dash_zonas` | Dimensión `zona`, métrica `viajes_origen`, orden descendente, 10 barras. |
| 7 | Google Maps → mapa relleno | `dash_zonas` | Campo geoespacial `zone_geom`, color por `viajes_origen`, información sobre la herramienta `zona`. |
| 8 | Barras apiladas al 100 % | `dash_pagos_mensual` | Dimensión `mes`, desglose `tipo_pago`, métrica `viajes`. |
| 9 | Tabla dinámica | `dash_origen_destino` | Fila `borough_origen`, columna `borough_destino`, métrica `viajes`, mapa de calor. |

Los gráficos 4 a 9 son las visualizaciones exploratorias; el enunciado exige al menos 3. Debajo de
cada uno conviene agregar un cuadro de texto con el hallazgo que muestra (sección 7 del README).

## 4. Página 2: Optimización

| # | Gráfico | Fuente | Configuración |
|---|---|---|---|
| 1 | Barras | `comparacion_consultas` | Dimensión `consulta`, métrica `mb_procesados` (SUM), orden por `consulta`. |
| 2 | Tabla | `comparacion_consultas` | `escenario`, `version`, `mb_procesados`, `mb_facturados`, `total_slot_ms`, `duracion_ms`. |
| 3 | Texto | — | Qué aísla cada escenario (S1 partición, S2 clustering, S3 combinado) y la reducción obtenida. |

## 5. Página 3: Pronóstico de demanda (rolling forecast)

| # | Gráfico | Fuente | Configuración |
|---|---|---|---|
| 1 | Control de lista | `ml_pronostico_demanda` | Dimensión `borough`. Valor predeterminado: Manhattan. |
| 2 | Control de lista (selección múltiple) | `ml_pronostico_demanda` | Dimensión `serie`. Predeterminado: Real, Baseline, el mejor lineal y el mejor boosted. |
| 3 | Serie temporal horaria | `ml_pronostico_demanda` | Dimensión `hora`, métrica `viajes` (SUM), desglose `serie`. Período: 1–30 nov 2022. Es la comparación de predicciones que pide el enunciado. La serie Real queda vacía del 14 al 20 de noviembre (falla de captura del proveedor 1): agregar un cuadro de texto que lo explique. |
| 4 | Serie temporal diaria | `ml_pronostico_demanda` | Dimensión `fecha`, métrica `viajes` (SUM), desglose `serie`. Muestra el comportamiento en Veterans Day (11-nov) y Thanksgiving (24-nov). |
| 5 | Tabla con formato condicional | `ml_metricas_regresion` | `modelo`, `conjunto`, `rmse`, `mae`, `r2`. Escala de color en `rmse`. |
| 6 | Barras | `ml_pronostico_error_diario` | Dimensión `serie`, métrica `error_abs_pct` (AVG). Título: error porcentual diario medio. |
| 7 | Gráfico de líneas | `ml_iteraciones` | Dimensión `iteration`, métricas `loss` y `eval_loss`, control de lista por `modelo`. Muestra la convergencia por iteración. |

## 6. Página 4: Clasificación de propinas

| # | Gráfico | Fuente | Configuración |
|---|---|---|---|
| 1 | Tabla con formato condicional | `ml_metricas_clasificacion` | `modelo`, `conjunto`, `roc_auc`, `precision`, `recall`, `f1_score`, `log_loss`. Incluye el modelo con fuga como referencia. |
| 2 | Dispersión (curva ROC) | `ml_curva_roc` | Filtro `conjunto = prueba`. Dimensión `threshold`, métrica X `fpr`, métrica Y `tpr`. Control de lista por `modelo`. |
| 3 | Tabla dinámica (matriz de confusión) | `ml_matriz_confusion` | Fila `clase_real`, columna `clase_predicha`, métrica `viajes`. Controles de lista por `modelo` y `criterio`. |
| 4 | Barras horizontales | `ml_importancia_variables` | Filtro `modelo = clf_propina_boosted`. Dimensión `feature`, métrica `importance_gain`, 15 barras. |
| 5 | Serie temporal | `ml_pred_propina_diaria` | Dimensión `fecha`, métricas `tasa_real_sin_propina` y `prob_media_pronosticada`. Control de lista por `modelo`. |

## 7. Compartir y documentar

1. **Compartir → Administrar el acceso → Cualquier persona que tenga el vínculo → Lector**.
2. Registrar o actualizar el enlace en el encabezado y en la sección 9 del [README](../README.md).
3. Capturar cada página en `evidencias/` (nombres en [evidencias/README.md](../evidencias/README.md)).
