/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 07: Consultas Analíticas de Ejemplo
  
  Descripción : Consultas de análisis que demuestran el uso del modelo
                 estrella para responder preguntas de negocio.
  Motor       : SQL Server 2019+
  Esquema     : dbo
  Autor       : Estudiante — Módulo II, Tarea I
  Fecha       : 2026-05-05
==========================================================================
*/

USE NorthwindDW;
GO

SET NOCOUNT ON;
GO

-- =====================================================================
-- CONSULTA 1: Ventas totales por año y trimestre
-- Pregunta: ¿Cuál es la tendencia de ventas por periodo?
-- =====================================================================
PRINT '=== CONSULTA 1: Ventas Totales por Año y Trimestre ===';

SELECT
    t.Anio,
    t.Trimestre,
    COUNT(DISTINCT f.OrderID)               AS TotalOrdenes,
    SUM(f.Cantidad)                         AS UnidadesVendidas,
    SUM(f.MontoVenta)                       AS VentasTotales,
    SUM(f.FleteProrrateado)                 AS FleteTotalProrrateado
FROM dbo.Fact_Ventas        AS f
INNER JOIN dbo.Dim_Tiempo   AS t ON f.SK_Tiempo = t.SK_Tiempo
GROUP BY t.Anio, t.Trimestre
ORDER BY t.Anio, t.Trimestre;
GO

-- =====================================================================
-- CONSULTA 2: Top 10 productos más vendidos (por monto)
-- Pregunta: ¿Cuáles son los productos estrella?
-- =====================================================================
PRINT '=== CONSULTA 2: Top 10 Productos por Monto de Venta ===';

SELECT TOP 10
    p.NombreProducto,
    p.NombreCategoria,
    SUM(f.Cantidad)                         AS UnidadesVendidas,
    SUM(f.MontoVenta)                       AS VentasTotales,
    AVG(f.Descuento) * 100                  AS DescuentoPromedioPct
FROM dbo.Fact_Ventas            AS f
INNER JOIN dbo.Dim_Producto     AS p ON f.SK_Producto = p.SK_Producto
GROUP BY p.NombreProducto, p.NombreCategoria
ORDER BY VentasTotales DESC;
GO

-- =====================================================================
-- CONSULTA 3: Ventas por categoría de producto
-- Pregunta: ¿Qué categorías generan más ingresos?
-- =====================================================================
PRINT '=== CONSULTA 3: Ventas por Categoría de Producto ===';

SELECT
    p.NombreCategoria,
    COUNT(DISTINCT f.OrderID)               AS TotalOrdenes,
    SUM(f.Cantidad)                         AS UnidadesVendidas,
    SUM(f.MontoVenta)                       AS VentasTotales,
    CAST(
        SUM(f.MontoVenta) * 100.0 / 
        SUM(SUM(f.MontoVenta)) OVER()
    AS DECIMAL(5,2))                        AS PorcentajeDelTotal
FROM dbo.Fact_Ventas            AS f
INNER JOIN dbo.Dim_Producto     AS p ON f.SK_Producto = p.SK_Producto
GROUP BY p.NombreCategoria
ORDER BY VentasTotales DESC;
GO

-- =====================================================================
-- CONSULTA 4: Ranking de empleados por ventas
-- Pregunta: ¿Qué empleados generan más ingresos?
-- =====================================================================
PRINT '=== CONSULTA 4: Ranking de Empleados por Ventas ===';

SELECT
    e.NombreCompleto,
    e.Titulo,
    e.NombreSupervisor,
    COUNT(DISTINCT f.OrderID)               AS TotalOrdenes,
    SUM(f.MontoVenta)                       AS VentasTotales,
    RANK() OVER(ORDER BY SUM(f.MontoVenta) DESC) AS Ranking
FROM dbo.Fact_Ventas            AS f
INNER JOIN dbo.Dim_Empleado     AS e ON f.SK_Empleado = e.SK_Empleado
GROUP BY e.NombreCompleto, e.Titulo, e.NombreSupervisor
ORDER BY Ranking;
GO

-- =====================================================================
-- CONSULTA 5: Ventas por país del cliente
-- Pregunta: ¿Cuáles son los mercados más importantes?
-- =====================================================================
PRINT '=== CONSULTA 5: Ventas por País del Cliente ===';

SELECT
    c.Pais,
    COUNT(DISTINCT c.SK_Cliente)            AS TotalClientes,
    COUNT(DISTINCT f.OrderID)               AS TotalOrdenes,
    SUM(f.MontoVenta)                       AS VentasTotales,
    SUM(f.MontoVenta) / COUNT(DISTINCT f.OrderID) AS TicketPromedio
FROM dbo.Fact_Ventas            AS f
INNER JOIN dbo.Dim_Cliente      AS c ON f.SK_Cliente = c.SK_Cliente
GROUP BY c.Pais
ORDER BY VentasTotales DESC;
GO

-- =====================================================================
-- CONSULTA 6: Análisis de flete por transportista
-- Pregunta: ¿Cómo se distribuye el costo de flete?
-- =====================================================================
PRINT '=== CONSULTA 6: Flete por Transportista ===';

SELECT
    tr.NombreCompania                       AS Transportista,
    COUNT(DISTINCT f.OrderID)               AS TotalEnvios,
    SUM(f.FleteProrrateado)                 AS FleteTotalProrrateado,
    SUM(f.FleteProrrateado) / COUNT(DISTINCT f.OrderID) AS FletePromedioPorOrden
FROM dbo.Fact_Ventas                AS f
INNER JOIN dbo.Dim_Transportista    AS tr ON f.SK_Transportista = tr.SK_Transportista
GROUP BY tr.NombreCompania
ORDER BY FleteTotalProrrateado DESC;
GO

-- =====================================================================
-- CONSULTA 7: Ventas mensuales con variación mes a mes
-- Pregunta: ¿Cómo evolucionan las ventas mes a mes?
-- =====================================================================
PRINT '=== CONSULTA 7: Ventas Mensuales con Variación ===';

WITH VentasMensuales AS (
    SELECT
        t.Anio,
        t.Mes,
        t.NombreMes,
        SUM(f.MontoVenta)                   AS VentasMes
    FROM dbo.Fact_Ventas        AS f
    INNER JOIN dbo.Dim_Tiempo   AS t ON f.SK_Tiempo = t.SK_Tiempo
    GROUP BY t.Anio, t.Mes, t.NombreMes
)
SELECT
    Anio,
    Mes,
    NombreMes,
    VentasMes,
    LAG(VentasMes) OVER(ORDER BY Anio, Mes)     AS VentasMesAnterior,
    CASE
        WHEN LAG(VentasMes) OVER(ORDER BY Anio, Mes) > 0
        THEN CAST(
            ((VentasMes - LAG(VentasMes) OVER(ORDER BY Anio, Mes))
             / LAG(VentasMes) OVER(ORDER BY Anio, Mes)) * 100
        AS DECIMAL(8,2))
        ELSE NULL
    END                                         AS VariacionPct
FROM VentasMensuales
ORDER BY Anio, Mes;
GO

-- =====================================================================
-- CONSULTA 8: Análisis de descuentos por categoría
-- Pregunta: ¿Qué categorías otorgan más descuentos?
-- =====================================================================
PRINT '=== CONSULTA 8: Descuentos por Categoría ===';

SELECT
    p.NombreCategoria,
    COUNT(*)                                    AS TotalLineas,
    SUM(CASE WHEN f.Descuento > 0 THEN 1 ELSE 0 END) AS LineasConDescuento,
    CAST(
        SUM(CASE WHEN f.Descuento > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    AS DECIMAL(5,2))                            AS PctConDescuento,
    AVG(f.Descuento) * 100                      AS DescuentoPromedioPct,
    SUM(f.PrecioUnitario * f.Cantidad) - SUM(f.MontoVenta) AS MontoDescuentoTotal
FROM dbo.Fact_Ventas            AS f
INNER JOIN dbo.Dim_Producto     AS p ON f.SK_Producto = p.SK_Producto
GROUP BY p.NombreCategoria
ORDER BY MontoDescuentoTotal DESC;
GO

-- =====================================================================
-- CONSULTA 9: Top 5 clientes por país (ventana por partición)
-- Pregunta: ¿Quiénes son los mejores clientes en cada mercado?
-- =====================================================================
PRINT '=== CONSULTA 9: Top 5 Clientes por País ===';

;WITH ClientesPorPais AS (
    SELECT
        c.Pais,
        c.NombreCompania,
        SUM(f.MontoVenta)                       AS VentasTotales,
        ROW_NUMBER() OVER(
            PARTITION BY c.Pais 
            ORDER BY SUM(f.MontoVenta) DESC
        )                                       AS RankEnPais
    FROM dbo.Fact_Ventas        AS f
    INNER JOIN dbo.Dim_Cliente  AS c ON f.SK_Cliente = c.SK_Cliente
    GROUP BY c.Pais, c.NombreCompania
)
SELECT Pais, NombreCompania, VentasTotales, RankEnPais
FROM ClientesPorPais
WHERE RankEnPais <= 5
ORDER BY Pais, RankEnPais;
GO

-- =====================================================================
-- CONSULTA 10: Análisis de Pareto (ABC) de Productos
-- Pregunta: ¿Qué productos concentran el mayor porcentaje (80%) de las ventas?
-- =====================================================================
PRINT '=== CONSULTA 10: Análisis de Pareto de Productos ===';

WITH VentasPorProducto AS (
    SELECT 
        p.NombreProducto,
        SUM(f.MontoVenta) AS Ventas
    FROM dbo.Fact_Ventas AS f
    INNER JOIN dbo.Dim_Producto AS p ON f.SK_Producto = p.SK_Producto
    GROUP BY p.NombreProducto
),
VentasAcumuladas AS (
    SELECT 
        NombreProducto,
        Ventas,
        SUM(Ventas) OVER(ORDER BY Ventas DESC) AS VentasAcumuladas,
        SUM(Ventas) OVER() AS TotalVentasGlobal
    FROM VentasPorProducto
)
SELECT 
    NombreProducto,
    Ventas,
    CAST((Ventas / TotalVentasGlobal) * 100 AS DECIMAL(5,2)) AS PorcentajeIndividual,
    CAST((VentasAcumuladas / TotalVentasGlobal) * 100 AS DECIMAL(5,2)) AS PorcentajeAcumulado,
    CASE 
        WHEN (VentasAcumuladas / TotalVentasGlobal) <= 0.80 THEN 'A (Top 80%)'
        WHEN (VentasAcumuladas / TotalVentasGlobal) <= 0.95 THEN 'B (Siguiente 15%)'
        ELSE 'C (Último 5%)'
    END AS ClasificacionABC
FROM VentasAcumuladas
ORDER BY Ventas DESC;
GO

-- =====================================================================
-- CONSULTA 11: Rendimiento de Proveedores por Volumen de Ventas
-- Pregunta: ¿Qué proveedores nos suministran los productos más rentables?
-- =====================================================================
PRINT '=== CONSULTA 11: Rendimiento de Proveedores ===';

SELECT
    p.NombreProveedor,
    p.PaisProveedor,
    COUNT(DISTINCT p.SK_Producto)           AS ProductosSuministrados,
    SUM(f.Cantidad)                         AS UnidadesVendidas,
    SUM(f.MontoVenta)                       AS VentasGeneradas
FROM dbo.Fact_Ventas            AS f
INNER JOIN dbo.Dim_Producto     AS p ON f.SK_Producto = p.SK_Producto
GROUP BY p.NombreProveedor, p.PaisProveedor
ORDER BY VentasGeneradas DESC;
GO

-- =====================================================================
-- CONSULTA 12: Ventas por Día de la Semana (Estacionalidad Semanal)
-- Pregunta: ¿Cuáles son los días de mayor actividad comercial?
-- =====================================================================
PRINT '=== CONSULTA 12: Ventas por Día de la Semana ===';

SELECT
    t.DiaSemana,
    t.NombreDiaSemana,
    COUNT(DISTINCT f.OrderID)               AS TotalOrdenes,
    SUM(f.MontoVenta)                       AS VentasTotales,
    SUM(f.MontoVenta) / COUNT(DISTINCT f.OrderID) AS TicketPromedioDiario
FROM dbo.Fact_Ventas        AS f
INNER JOIN dbo.Dim_Tiempo   AS t ON f.SK_Tiempo = t.SK_Tiempo
GROUP BY t.DiaSemana, t.NombreDiaSemana
ORDER BY t.DiaSemana;
GO

-- =====================================================================
-- CONSULTA 13: Resumen ejecutivo del Data Warehouse
-- =====================================================================
PRINT '=== CONSULTA 13: Resumen Ejecutivo del DW ===';

SELECT
    (SELECT COUNT(*) FROM dbo.Dim_Producto)       AS TotalProductos,
    (SELECT COUNT(*) FROM dbo.Dim_Cliente)         AS TotalClientes,
    (SELECT COUNT(*) FROM dbo.Dim_Empleado)        AS TotalEmpleados,
    (SELECT COUNT(*) FROM dbo.Dim_Transportista)   AS TotalTransportistas,
    (SELECT COUNT(*) FROM dbo.Dim_Tiempo)          AS DiasEnDimTiempo,
    (SELECT COUNT(*) FROM dbo.Fact_Ventas)         AS TotalLineasVenta,
    (SELECT COUNT(DISTINCT OrderID) FROM dbo.Fact_Ventas) AS TotalOrdenes,
    (SELECT SUM(MontoVenta) FROM dbo.Fact_Ventas)  AS VentasTotalesGlobal,
    (SELECT SUM(FleteProrrateado) FROM dbo.Fact_Ventas) AS FleteTotalGlobal;
GO

PRINT '=============================================';
PRINT '>> Consultas analíticas ejecutadas.';
PRINT '=============================================';
GO
