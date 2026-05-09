/*
==========================================================================
  NORTHWIND OLTP
  Script 02: Agregar ROWVERSION para Carga Incremental
  
  Descripción : Agrega la columna VersionFila (ROWVERSION) a las tablas 
                principales para soportar la extracción de deltas (cambios)
                hacia el Data Warehouse.
==========================================================================
*/

USE Northwind;
GO

PRINT 'Agregando VersionFila (ROWVERSION) a las tablas OLTP...';

-- 1. Tabla Products
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Products]') AND name = 'VersionFila')
BEGIN
    ALTER TABLE [dbo].[Products] ADD VersionFila ROWVERSION NOT NULL;
    PRINT '-> VersionFila agregada a Products';
END

-- 2. Tabla Customers
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Customers]') AND name = 'VersionFila')
BEGIN
    ALTER TABLE [dbo].[Customers] ADD VersionFila ROWVERSION NOT NULL;
    PRINT '-> VersionFila agregada a Customers';
END

-- 3. Tabla Employees
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Employees]') AND name = 'VersionFila')
BEGIN
    ALTER TABLE [dbo].[Employees] ADD VersionFila ROWVERSION NOT NULL;
    PRINT '-> VersionFila agregada a Employees';
END

-- 4. Tabla Shippers
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Shippers]') AND name = 'VersionFila')
BEGIN
    ALTER TABLE [dbo].[Shippers] ADD VersionFila ROWVERSION NOT NULL;
    PRINT '-> VersionFila agregada a Shippers';
END

-- 5. Tabla Orders
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orders]') AND name = 'VersionFila')
BEGIN
    ALTER TABLE [dbo].[Orders] ADD VersionFila ROWVERSION NOT NULL;
    PRINT '-> VersionFila agregada a Orders';
END

-- 6. Tabla Order Details
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Order Details]') AND name = 'VersionFila')
BEGIN
    ALTER TABLE [dbo].[Order Details] ADD VersionFila ROWVERSION NOT NULL;
    PRINT '-> VersionFila agregada a Order Details';
END

PRINT 'Completado.';
GO
