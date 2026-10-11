# Estado del proyecto SG-Food

El flujo dejó de ser simulado: Python extrae la base transaccional entregada,
carga siete tablas raw y un catálogo CSV derivado; dbt transforma staging,
intermediate y marts; Airflow ejecuta pruebas, validación y documentación.

Consultar README.md para ejecutar y docs/VALIDACION.md para resultados de verificación.

Pendientes de entrega:
- Confirmar si el catálogo CSV derivado cumple la exigencia de archivos delimitados
  o si el auxiliar proporcionará una fuente CSV independiente.
- Proveer datos reales de inventario si se requiere ese análisis.
- Publicación en GitHub y entrega oficial cuando corresponda.
