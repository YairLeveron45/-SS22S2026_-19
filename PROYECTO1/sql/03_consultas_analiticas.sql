-- Ventas completadas por mes y sucursal.
SELECT * FROM marts.ventas_mensuales ORDER BY anio, mes, id_sucursal;

-- Productos por ingreso neto, excluye ventas canceladas.
SELECT p.sku, p.nombre, p.categoria, p.marca,
       SUM(f.cantidad) AS unidades, SUM(f.importe_neto) AS ingreso_neto
FROM marts.fact_ventas f JOIN marts.dim_producto p USING (id_producto)
WHERE f.estado = 'COMPLETADA'
GROUP BY p.sku, p.nombre, p.categoria, p.marca
ORDER BY ingreso_neto DESC LIMIT 10;

-- Control por estado: los hechos conservan también registros cancelados.
SELECT estado, COUNT(DISTINCT id_venta) AS ventas, COUNT(*) AS detalles,
       SUM(importe_neto) AS importe FROM marts.fact_ventas GROUP BY estado;

-- Reconciliación de conteos y valores.
SELECT (SELECT COUNT(*) FROM raw.venta_detalle) AS raw_detalles,
       (SELECT COUNT(*) FROM marts.fact_ventas) AS fact_detalles,
       (SELECT SUM(subtotal) FROM raw.venta_detalle) AS raw_importe,
       (SELECT SUM(importe_neto) FROM marts.fact_ventas) AS fact_importe;
