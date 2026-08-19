# Modelo Multidimensional (Esquema Estrella)

![Diagrama Entidad-Relación](docs/E-R%20vuelos.png)

## Explicación del Esquema Estrella

El modelo de datos está diseñado bajo un enfoque dimensional puro (**Esquema Estrella**), el cual es el estándar de oro para el diseño de bases de datos analíticas (Data Warehouses) e Inteligencia de Negocios.

1. **Tabla de Hechos (`Fact_Vuelos`):** 
   Se ubica en el centro del esquema. Almacena los eventos cuantitativos a nivel de grano (cada registro es un boleto/vuelo). Contiene métricas calculables (`duracion_min`, `retraso_min`, `precio_usd`, `equipaje_total`) y atributos degenerados que no requieren una dimensión propia (fechas y aeropuertos). Finalmente, posee las llaves foráneas que se conectan a cada una de las dimensiones.

2. **Tablas de Dimensiones:**
   Rodean a la tabla de hechos y almacenan el "contexto" de los eventos. Sirven para filtrar, agrupar y etiquetar los datos en los reportes:
   * **`Dim_Aerolinea`:** Catálogo de aerolíneas usando el estándar de códigos IATA de 2 letras (ej. AA para American Airlines).
   * **`Dim_Pasajero`:** Datos demográficos del cliente (género homologado, edad, nacionalidad).
   * **`Dim_DetalleVuelo`:** Contexto operativo del vuelo (número de vuelo, tipo de avión, clase de cabina, asiento asignado y estado operativo).
   * **`Dim_Transaccion`:** Contexto comercial de la compra (canal de venta, método de pago, moneda original).

## Limpieza e Integridad Referencial
Para garantizar que las consultas analíticas (`GROUP BY`, uniones) no pierdan información ni se rompan por datos faltantes en el CSV original, el proceso ETL estandariza los valores nulos (`NaN` de Pandas) insertando las etiquetas explícitas `'DESCONOCIDO'` o `'ND'`. Esto permite que los reportes de BI identifiquen visualmente aquellos registros sin origen definido, en lugar de omitirlos o mostrar un error del sistema.
