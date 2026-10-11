-- DDL equivalente al modelo construido por dbt. Ejecutar DESPUÉS de dbt run.
-- IF NOT EXISTS permite documentar el modelo sin reemplazar sus datos.
CREATE TABLE IF NOT EXISTS marts.dim_producto (
 id_producto integer, sku varchar(20), nombre varchar(150), id_categoria integer,
 id_marca integer, unidad_medida varchar(30), costo_base numeric(12,2),
 precio_lista numeric(12,2), activo boolean, categoria varchar(100), marca varchar(100)
);
CREATE TABLE IF NOT EXISTS marts.dim_cliente (
 id_cliente integer, nit varchar(20), nombre varchar(150), tipo_cliente varchar(40),
 municipio varchar(100), departamento varchar(100), fecha_alta date
);
CREATE TABLE IF NOT EXISTS marts.dim_sucursal (
 id_sucursal integer, nombre varchar(100), ciudad varchar(100), departamento varchar(100)
);
CREATE TABLE IF NOT EXISTS marts.dim_tiempo (
 id_tiempo integer, fecha date, anio integer, trimestre integer, mes integer,
 dia integer, dia_semana integer
);
CREATE TABLE IF NOT EXISTS marts.fact_ventas (
 id_detalle bigint, id_venta bigint, id_tiempo integer, id_producto integer,
 id_cliente integer, id_sucursal integer, canal varchar(30), metodo_pago varchar(30),
 estado varchar(20), cantidad integer, precio_unitario numeric(12,2),
 descuento numeric(5,4), importe_bruto numeric, importe_neto numeric(14,2),
 importe_descuento numeric, costo_estimado numeric, margen_estimado numeric
);
-- Validar y aplicar claves reales, no solamente pruebas dbt.
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='marts.dim_producto'::regclass AND contype='p') THEN
  ALTER TABLE marts.dim_producto ADD PRIMARY KEY(id_producto);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='marts.dim_cliente'::regclass AND contype='p') THEN
  ALTER TABLE marts.dim_cliente ADD PRIMARY KEY(id_cliente);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='marts.dim_sucursal'::regclass AND contype='p') THEN
  ALTER TABLE marts.dim_sucursal ADD PRIMARY KEY(id_sucursal);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='marts.dim_tiempo'::regclass AND contype='p') THEN
  ALTER TABLE marts.dim_tiempo ADD PRIMARY KEY(id_tiempo);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='marts.fact_ventas'::regclass AND contype='p') THEN
  ALTER TABLE marts.fact_ventas ADD PRIMARY KEY(id_detalle);
 END IF;
END $$;
ALTER TABLE marts.fact_ventas DROP CONSTRAINT IF EXISTS fk_producto;
ALTER TABLE marts.fact_ventas DROP CONSTRAINT IF EXISTS fk_cliente;
ALTER TABLE marts.fact_ventas DROP CONSTRAINT IF EXISTS fk_sucursal;
ALTER TABLE marts.fact_ventas DROP CONSTRAINT IF EXISTS fk_tiempo;
ALTER TABLE marts.fact_ventas ADD CONSTRAINT fk_producto FOREIGN KEY(id_producto) REFERENCES marts.dim_producto;
ALTER TABLE marts.fact_ventas ADD CONSTRAINT fk_cliente FOREIGN KEY(id_cliente) REFERENCES marts.dim_cliente;
ALTER TABLE marts.fact_ventas ADD CONSTRAINT fk_sucursal FOREIGN KEY(id_sucursal) REFERENCES marts.dim_sucursal;
ALTER TABLE marts.fact_ventas ADD CONSTRAINT fk_tiempo FOREIGN KEY(id_tiempo) REFERENCES marts.dim_tiempo;
ALTER TABLE marts.fact_ventas ALTER COLUMN id_producto SET NOT NULL;
ALTER TABLE marts.fact_ventas ALTER COLUMN id_cliente SET NOT NULL;
ALTER TABLE marts.fact_ventas ALTER COLUMN id_sucursal SET NOT NULL;
ALTER TABLE marts.fact_ventas ALTER COLUMN id_tiempo SET NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fact_ventas_tiempo ON marts.fact_ventas(id_tiempo);
CREATE INDEX IF NOT EXISTS idx_fact_ventas_producto ON marts.fact_ventas(id_producto);
