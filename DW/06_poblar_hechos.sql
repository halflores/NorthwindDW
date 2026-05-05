/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 06: Poblar Tabla de Hechos (Fact_Ventas)
  
  Descripción : ETL que carga la tabla de hechos desde el OLTP.
                 Realiza lookup de Surrogate Keys en cada dimensión.
                 
  Prerequisitos:
    - Northwind (OLTP) debe existir y estar poblada.
    - Todas las dimensiones deben estar pobladas (Scripts 04 y 05).
  Motor       : SQL Server 2019+
  Esquema     : dbo
  Autor       : Estudiante — Módulo II, Tarea I
  Fecha       : 2026-05-05

  FÓRMULA DEL PRORRATEO DE FLETE:
  --------------------------------
  El flete (Orders.Freight) se registra a nivel de orden completa.
  Para distribuirlo a nivel de línea de detalle, se prroratea
  proporcionalmente al monto de cada línea:
  
    FleteProrrateado = Orders.Freight 
                       × ( MontoLineaActual / SubtotalOrden )
  
  Donde:
    MontoLineaActual = OD.UnitPrice × OD.Quantity × (1 - OD.Discount)
    SubtotalOrden    = SUM(OD.UnitPrice × OD.Quantity × (1 - OD.Discount))
                       para todas las líneas del mismo OrderID

  Esto garantiza que:
    SUM(FleteProrrateado) agrupado por OrderID ≈ Orders.Freight
    (con mínima diferencia por redondeo de punto flotante)
==========================================================================
*/

USE NorthwindDW;
GO

SET NOCOUNT ON;
GO

-- =====================================================================
-- Limpiar tabla de hechos
-- =====================================================================
DELETE FROM dbo.Fact_Ventas;
GO

-- =====================================================================
-- PASO 1: Calcular subtotales por orden (para prorrateo del flete)
-- =====================================================================
;WITH SubtotalesOrden AS (
    SELECT
        od.OrderID,
        SUM(
            CONVERT(MONEY, od.UnitPrice * od.Quantity * (1 - od.Discount))
        ) AS SubtotalOrden
    FROM Northwind.dbo.[Order Details] AS od
    GROUP BY od.OrderID
),

-- =====================================================================
-- PASO 2: Calcular monto por línea y flete prorrateado
-- =====================================================================
LineasDetalle AS (
    SELECT
        od.OrderID,
        od.ProductID,
        od.UnitPrice,
        od.Quantity,
        od.Discount,
        -- MontoVenta de esta línea
        CONVERT(MONEY, od.UnitPrice * od.Quantity * (1 - od.Discount))
            AS MontoVenta,
        -- Flete prorrateado proporcionalmente
        -- Fórmula: Freight × (MontoLinea / SubtotalOrden)
        CASE
            WHEN so.SubtotalOrden > 0
            THEN CONVERT(MONEY,
                    ISNULL(o.Freight, 0)
                    * (CONVERT(MONEY, od.UnitPrice * od.Quantity * (1 - od.Discount))
                       / so.SubtotalOrden)
                 )
            ELSE 0
        END AS FleteProrrateado,
        o.OrderDate,
        o.CustomerID,
        o.EmployeeID,
        o.ShipVia
    FROM Northwind.dbo.[Order Details] AS od
    INNER JOIN Northwind.dbo.Orders    AS o  ON od.OrderID = o.OrderID
    INNER JOIN SubtotalesOrden         AS so ON od.OrderID = so.OrderID
)

-- =====================================================================
-- PASO 3: INSERT con lookup de Surrogate Keys
-- =====================================================================
INSERT INTO dbo.Fact_Ventas (
    SK_Producto,
    SK_Cliente,
    SK_Empleado,
    SK_Tiempo,
    SK_Transportista,
    OrderID,
    PrecioUnitario,
    Cantidad,
    Descuento,
    MontoVenta,
    FleteProrrateado
)
SELECT
    -- Lookup Surrogate Keys en cada dimensión
    dp.SK_Producto,
    dc.SK_Cliente,
    de.SK_Empleado,
    dt.SK_Tiempo,
    dtr.SK_Transportista,

    -- Degenerate dimension
    ld.OrderID,

    -- Métricas
    ld.UnitPrice,
    ld.Quantity,
    ld.Discount,
    ld.MontoVenta,
    ld.FleteProrrateado

FROM LineasDetalle AS ld

-- Lookup: Dim_Producto (por ProductID)
INNER JOIN dbo.Dim_Producto AS dp
    ON ld.ProductID = dp.ProductID

-- Lookup: Dim_Cliente (por CustomerID)
INNER JOIN dbo.Dim_Cliente AS dc
    ON ld.CustomerID = dc.CustomerID

-- Lookup: Dim_Empleado (por EmployeeID)
INNER JOIN dbo.Dim_Empleado AS de
    ON ld.EmployeeID = de.EmployeeID

-- Lookup: Dim_Tiempo (por OrderDate → formato YYYYMMDD)
INNER JOIN dbo.Dim_Tiempo AS dt
    ON dt.SK_Tiempo = YEAR(ld.OrderDate) * 10000
                    + MONTH(ld.OrderDate) * 100
                    + DAY(ld.OrderDate)

-- Lookup: Dim_Transportista (por ShipVia = ShipperID)
INNER JOIN dbo.Dim_Transportista AS dtr
    ON ld.ShipVia = dtr.ShipperID;

DECLARE @CntFact INT = @@ROWCOUNT;
PRINT '>> Fact_Ventas: ' + CAST(@CntFact AS VARCHAR(10)) + ' registros insertados.';
GO

-- =====================================================================
-- VERIFICACIÓN: Comparar conteo con OLTP
-- =====================================================================
DECLARE @OltpCount INT = (SELECT COUNT(*) FROM Northwind.dbo.[Order Details]);
DECLARE @DwCount   INT = (SELECT COUNT(*) FROM dbo.Fact_Ventas);

PRINT '>> Registros en OLTP [Order Details]: ' + CAST(@OltpCount AS VARCHAR(10));
PRINT '>> Registros en DW   [Fact_Ventas]:   ' + CAST(@DwCount AS VARCHAR(10));

IF @OltpCount = @DwCount
    PRINT '>> ✓ Conteo coincide. Carga exitosa.';
ELSE
    PRINT '>> ✗ ADVERTENCIA: Diferencia en conteo. Revisar datos faltantes.';
GO

-- =====================================================================
-- VERIFICACIÓN: Validar prorrateo de flete
-- Mostrar top 5 órdenes comparando flete original vs. suma prorrateada
-- =====================================================================
PRINT '>> Verificación de prorrateo de flete (top 5 órdenes):';

SELECT TOP 5
    f.OrderID,
    o.Freight                               AS Flete_Original,
    SUM(f.FleteProrrateado)                 AS Flete_Prorrateado_Sum,
    o.Freight - SUM(f.FleteProrrateado)     AS Diferencia_Redondeo
FROM dbo.Fact_Ventas AS f
INNER JOIN Northwind.dbo.Orders AS o ON f.OrderID = o.OrderID
GROUP BY f.OrderID, o.Freight
ORDER BY ABS(o.Freight - SUM(f.FleteProrrateado)) DESC;
GO

PRINT '=============================================';
PRINT '>> Tabla de hechos poblada exitosamente.';
PRINT '=============================================';
GO
