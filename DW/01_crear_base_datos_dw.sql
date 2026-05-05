/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 01: Creación de la Base de Datos NorthwindDW
  
  Descripción : Crea la base de datos destino para el Data Warehouse.
  Motor       : SQL Server 2019+
  Esquema     : dbo (esquema único)
  Autor       : Estudiante — Módulo II, Tarea I
  Fecha       : 2026-05-05
==========================================================================
*/

SET NOCOUNT ON;
GO

USE master;
GO

-- -----------------------------------------------------------------------
-- Eliminar la base de datos si ya existe (para re-ejecución idempotente)
-- -----------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'NorthwindDW')
BEGIN
    ALTER DATABASE NorthwindDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE NorthwindDW;
END
GO

-- -----------------------------------------------------------------------
-- Crear la base de datos NorthwindDW
-- -----------------------------------------------------------------------
CREATE DATABASE NorthwindDW;
GO

-- -----------------------------------------------------------------------
-- Configuración inicial
-- -----------------------------------------------------------------------
USE NorthwindDW;
GO

-- Formato de fecha: mes/día/año (coherente con datos Northwind originales)
SET DATEFORMAT mdy;
GO

PRINT '>> Base de datos NorthwindDW creada correctamente.';
GO
