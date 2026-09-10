# Plan de Trabajo: Práctica 2 - Diseño de Dashboard y KPIs con Power BI

Este documento es una guía paso a paso para completar la Práctica 2, asegurando que se cumplan todos los entregables y requisitos de la rúbrica de calificación.

## Fase 1: Preparación y Conexión (15 pts)

- [X] **Verificar Base de Datos:** Asegurarse de que el motor de base de datos SQL Server esté ejecutándose y la base de datos de la Práctica 1 esté lista.
- [X] **Abrir Power BI Desktop:** Crear un nuevo archivo `.pbix`.
- [X] **Conectar a SQL Server:**
  - Ir a `Obtener datos` -> `SQL Server`.
  - Ingresar las credenciales y el nombre del servidor/base de datos.
  - Importar las tablas necesarias (Hechos y Dimensiones).
- [X] **Modelado Tabular:**
  - Ir a la vista de "Modelo" en Power BI.
  - Crear relaciones coherentes entre la tabla de hechos y las tablas de dimensiones (esquema estrella o copo de nieve).
  - Configurar las cardinalidades correctas (1 a muchos, etc.).
- [ ] **Crear Jerarquías:**
  - Identificar al menos una dimensión que soporte jerarquías (ej. Dimensión de Fecha: Año -> Trimestre -> Mes, o Dimensión de Ubicación: País -> Departamento -> Municipio).
  - Crear la jerarquía funcional en la vista de datos o modelo.

## Fase 2: Cálculos DAX y KPIs (25 pts)

- [ ] **Medida DAX 1:** Crear la primera medida funcional (ej. Total de Ventas, Total de Estudiantes, etc.).
- [ ] **Medida DAX 2:** Crear la segunda medida funcional.
- [ ] **Medida DAX 3:** Crear la tercera medida funcional (se recomienda una medida de tiempo, como YTD o crecimiento % M-o-M).
- [ ] **KPI con Indicador Visual:**
  - Definir un objetivo analítico.
  - Crear el KPI usando la visualización de KPI integrada en Power BI, o usando una regla de formato condicional (semáforo) en una tabla/tarjeta.

## Fase 3: Diseño del Dashboard (35 pts)

- [ ] **Visualización 1:** Crear una gráfica interactiva (ej. Gráfico de barras o columnas).
- [ ] **Visualización 2:** Crear una segunda gráfica (ej. Gráfico de líneas para tendencias en el tiempo).
- [ ] **Visualización 3:** Crear una tercera gráfica o elemento visual.
- [ ] **Filtros y Segmentadores:** Añadir al menos un *Slicer* (segmentador de datos) que interactúe con todas las visualizaciones (ej. Segmentador por Año o Categoría).
- [ ] **Diseño y Estética:**
  - Ordenar los elementos de manera lógica (KPIs arriba, detalles abajo).
  - (Opcional) Agregar botones de navegación o paneles personalizados para mejorar la experiencia.
- [ ] **Prueba de Interactividad:** Hacer clic en los gráficos y usar los filtros para asegurar que todo responde correctamente.

## Fase 4: Documentación e Informe Técnico (15 pts)

- [ ] **Redactar README.md / Informe PDF:**
  - **Introducción:** Breve descripción del dashboard.
  - **Diseño del Modelo:** Explicar las tablas importadas y cómo están relacionadas (Esquema).
  - **Medidas DAX:** Listar las 3 medidas DAX creadas y explicar qué calculan.
  - **Interpretación de KPIs:** Explicar el KPI creado, cuál es la meta y qué significa si está en rojo, amarillo o verde.
  - **Decisiones de Diseño:** Justificar por qué se eligieron esas gráficas en el dashboard.
- [ ] **Capturas de Pantalla:** Tomar capturas claras del dashboard terminado y agregarlas al informe o carpeta.

## Fase 5: Gestión y Entregables (10 pts)

- [ ] **Guardar Archivo Power BI:** Guardar el progreso final en el archivo `.pbix`.
- [ ] **Preparar Estructura de Carpetas:** Asegurar que en el repositorio de GitHub exista la ruta `SS22S2026_#carnet/Practica2`.
- [ ] **Subir Archivos al Repositorio:**
  - `archivo.pbix`
  - `README.md` o informe en `PDF`
  - Carpeta con las capturas de pantalla (o embebidas en el README).
- [ ] **Revisión Final:** Comprobar que el repositorio cumple con los lineamientos antes de la fecha límite (Semana 7).
