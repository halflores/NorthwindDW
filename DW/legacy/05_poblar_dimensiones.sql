/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 05: Poblar Dimensiones desde el OLTP (Northwind)
  
  Descripción : ETL simple que extrae datos de la BD transaccional
                 Northwind y los carga en las dimensiones del DW.
                 
  Prerequisitos: 
    - La BD "Northwind" debe existir y estar poblada.
    - Las tablas de dimensiones deben estar creadas (Script 02).
    - Dim_Tiempo ya debe estar poblada (Script 04).
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
-- LIMPIAR dimensiones (excepto Dim_Tiempo que ya fue poblada)
-- Primero limpiamos la tabla de hechos para evitar conflictos de FK
-- =====================================================================
IF OBJECT_ID('dbo.Fact_Ventas', 'U') IS NOT NULL
    DELETE FROM dbo.Fact_Ventas;

DELETE FROM dbo.Dim_Producto;
DELETE FROM dbo.Dim_Cliente;
DELETE FROM dbo.Dim_Empleado;
DELETE FROM dbo.Dim_Transportista;
GO

-- =====================================================================
-- 1. POBLAR Dim_Producto
--    JOIN: Products → Categories (CategoryID)
--          Products → Suppliers  (SupplierID)
-- =====================================================================
SET IDENTITY_INSERT dbo.Dim_Producto OFF;

INSERT INTO dbo.Dim_Producto (
    ProductID,
    NombreProducto,
    NombreCategoria,
    DescripcionCategoria,
    NombreProveedor,
    PaisProveedor,
    CantidadPorUnidad,
    PrecioUnitario,
    Descontinuado
)
SELECT
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    c.[Description],
    s.CompanyName,
    s.Country,
    p.QuantityPerUnit,
    p.UnitPrice,
    p.Discontinued
FROM Northwind.dbo.Products       AS p
LEFT JOIN Northwind.dbo.Categories AS c ON p.CategoryID  = c.CategoryID
LEFT JOIN Northwind.dbo.Suppliers  AS s ON p.SupplierID  = s.SupplierID;

DECLARE @CntProd INT = @@ROWCOUNT;
PRINT '>> Dim_Producto: ' + CAST(@CntProd AS VARCHAR(10)) + ' registros insertados.';
GO

-- =====================================================================
-- 2. POBLAR Dim_Cliente
--    Fuente directa: Customers
-- =====================================================================
INSERT INTO dbo.Dim_Cliente (
    CustomerID,
    NombreCompania,
    NombreContacto,
    TituloContacto,
    Ciudad,
    Region,
    Pais,
    CodigoPostal
)
SELECT
    CustomerID,
    CompanyName,
    ContactName,
    ContactTitle,
    City,
    Region,
    Country,
    PostalCode
FROM Northwind.dbo.Customers;

DECLARE @CntCli INT = @@ROWCOUNT;
PRINT '>> Dim_Cliente: ' + CAST(@CntCli AS VARCHAR(10)) + ' registros insertados.';
GO

-- =====================================================================
-- 3. POBLAR Dim_Empleado
--    Self-join para obtener el nombre del supervisor (ReportsTo)
-- =====================================================================
INSERT INTO dbo.Dim_Empleado (
    EmployeeID,
    NombreCompleto,
    Titulo,
    FechaContratacion,
    Ciudad,
    Pais,
    NombreSupervisor
)
SELECT
    e.EmployeeID,
    e.FirstName + N' ' + e.LastName              AS NombreCompleto,
    e.Title,
    e.HireDate,
    e.City,
    e.Country,
    -- Self-join: obtener nombre del supervisor
    CASE
        WHEN e.ReportsTo IS NOT NULL
        THEN sup.FirstName + N' ' + sup.LastName
        ELSE NULL
    END                                           AS NombreSupervisor
FROM Northwind.dbo.Employees       AS e
LEFT JOIN Northwind.dbo.Employees  AS sup ON e.ReportsTo = sup.EmployeeID;

DECLARE @CntEmp INT = @@ROWCOUNT;
PRINT '>> Dim_Empleado: ' + CAST(@CntEmp AS VARCHAR(10)) + ' registros insertados.';
GO

-- =====================================================================
-- 4. POBLAR Dim_Transportista
--    Fuente directa: Shippers
-- =====================================================================
INSERT INTO dbo.Dim_Transportista (
    ShipperID,
    NombreCompania,
    Telefono
)
SELECT
    ShipperID,
    CompanyName,
    Phone
FROM Northwind.dbo.Shippers;

DECLARE @CntShip INT = @@ROWCOUNT;
PRINT '>> Dim_Transportista: ' + CAST(@CntShip AS VARCHAR(10)) + ' registros insertados.';
GO

-- =====================================================================
-- RESUMEN
-- =====================================================================
PRINT '=============================================';
PRINT '>> Todas las dimensiones pobladas exitosamente.';
PRINT '=============================================';
GO
