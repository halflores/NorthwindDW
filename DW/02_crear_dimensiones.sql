/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 02: Creación de Tablas de Dimensiones
  
  Descripción : Crea las 5 tablas de dimensiones del modelo estrella.
                 - Dim_Producto   (Products + Categories + Suppliers)
                 - Dim_Cliente    (Customers)
                 - Dim_Empleado   (Employees con self-join supervisor)
                 - Dim_Tiempo     (Generada — fechas calendario)
                 - Dim_Transportista (Shippers)
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
-- LIMPIEZA: Eliminar tablas si existen (orden inverso a dependencias)
-- =====================================================================
IF OBJECT_ID('dbo.Fact_Ventas', 'U') IS NOT NULL DROP TABLE dbo.Fact_Ventas;
IF OBJECT_ID('dbo.Dim_Producto', 'U') IS NOT NULL DROP TABLE dbo.Dim_Producto;
IF OBJECT_ID('dbo.Dim_Cliente', 'U') IS NOT NULL DROP TABLE dbo.Dim_Cliente;
IF OBJECT_ID('dbo.Dim_Empleado', 'U') IS NOT NULL DROP TABLE dbo.Dim_Empleado;
IF OBJECT_ID('dbo.Dim_Tiempo', 'U') IS NOT NULL DROP TABLE dbo.Dim_Tiempo;
IF OBJECT_ID('dbo.Dim_Transportista', 'U') IS NOT NULL DROP TABLE dbo.Dim_Transportista;
GO

-- =====================================================================
-- 1. DIMENSION: Dim_Producto
--    Desnormalización de Products + Categories + Suppliers
--    SCD Tipo 1 (se sobrescribe al actualizar)
-- =====================================================================
CREATE TABLE dbo.Dim_Producto (
    SK_Producto             INT IDENTITY(1,1)   NOT NULL,
    ProductID               INT                 NOT NULL,   -- Clave natural
    NombreProducto          NVARCHAR(40)        NOT NULL,
    NombreCategoria         NVARCHAR(15)        NULL,
    DescripcionCategoria    NVARCHAR(MAX)       NULL,
    NombreProveedor         NVARCHAR(40)        NULL,
    PaisProveedor           NVARCHAR(15)        NULL,
    CantidadPorUnidad       NVARCHAR(20)        NULL,
    PrecioUnitario          MONEY               NULL,
    Descontinuado           BIT                 NOT NULL DEFAULT 0,

    CONSTRAINT PK_Dim_Producto PRIMARY KEY CLUSTERED (SK_Producto),
    CONSTRAINT UQ_Dim_Producto_NatKey UNIQUE (ProductID)
);
GO

PRINT '>> Dim_Producto creada.';
GO

-- =====================================================================
-- 2. DIMENSION: Dim_Cliente
--    Desnormalización de Customers
-- =====================================================================
CREATE TABLE dbo.Dim_Cliente (
    SK_Cliente              INT IDENTITY(1,1)   NOT NULL,
    CustomerID              NCHAR(5)            NOT NULL,   -- Clave natural
    NombreCompania          NVARCHAR(40)        NOT NULL,
    NombreContacto          NVARCHAR(30)        NULL,
    TituloContacto          NVARCHAR(30)        NULL,
    Ciudad                  NVARCHAR(15)        NULL,
    Region                  NVARCHAR(15)        NULL,
    Pais                    NVARCHAR(15)        NULL,
    CodigoPostal            NVARCHAR(10)        NULL,

    CONSTRAINT PK_Dim_Cliente PRIMARY KEY CLUSTERED (SK_Cliente),
    CONSTRAINT UQ_Dim_Cliente_NatKey UNIQUE (CustomerID)
);
GO

PRINT '>> Dim_Cliente creada.';
GO

-- =====================================================================
-- 3. DIMENSION: Dim_Empleado
--    Desnormalización de Employees con jerarquía de supervisor
-- =====================================================================
CREATE TABLE dbo.Dim_Empleado (
    SK_Empleado             INT IDENTITY(1,1)   NOT NULL,
    EmployeeID              INT                 NOT NULL,   -- Clave natural
    NombreCompleto          NVARCHAR(40)        NOT NULL,   -- FirstName + LastName
    Titulo                  NVARCHAR(30)        NULL,
    FechaContratacion       DATETIME            NULL,
    Ciudad                  NVARCHAR(15)        NULL,
    Pais                    NVARCHAR(15)        NULL,
    NombreSupervisor        NVARCHAR(40)        NULL,       -- Self-join a ReportsTo

    CONSTRAINT PK_Dim_Empleado PRIMARY KEY CLUSTERED (SK_Empleado),
    CONSTRAINT UQ_Dim_Empleado_NatKey UNIQUE (EmployeeID)
);
GO

PRINT '>> Dim_Empleado creada.';
GO

-- =====================================================================
-- 4. DIMENSION: Dim_Tiempo
--    Dimensión de fecha generada (no depende del OLTP)
--    SK_Tiempo usa formato entero YYYYMMDD para búsquedas rápidas
-- =====================================================================
CREATE TABLE dbo.Dim_Tiempo (
    SK_Tiempo               INT                 NOT NULL,   -- Formato YYYYMMDD
    Fecha                   DATE                NOT NULL,
    Anio                    INT                 NOT NULL,
    Trimestre               INT                 NOT NULL,   -- 1-4
    Mes                     INT                 NOT NULL,   -- 1-12
    NombreMes               NVARCHAR(20)        NOT NULL,
    Dia                     INT                 NOT NULL,   -- 1-31
    DiaSemana               INT                 NOT NULL,   -- 1=Domingo .. 7=Sábado
    NombreDiaSemana         NVARCHAR(20)        NOT NULL,
    Semana                  INT                 NOT NULL,   -- Semana del año (1-53)

    CONSTRAINT PK_Dim_Tiempo PRIMARY KEY CLUSTERED (SK_Tiempo)
);
GO

PRINT '>> Dim_Tiempo creada.';
GO

-- =====================================================================
-- 5. DIMENSION: Dim_Transportista
--    Directamente desde Shippers
-- =====================================================================
CREATE TABLE dbo.Dim_Transportista (
    SK_Transportista        INT IDENTITY(1,1)   NOT NULL,
    ShipperID               INT                 NOT NULL,   -- Clave natural
    NombreCompania          NVARCHAR(40)        NOT NULL,
    Telefono                NVARCHAR(24)        NULL,

    CONSTRAINT PK_Dim_Transportista PRIMARY KEY CLUSTERED (SK_Transportista),
    CONSTRAINT UQ_Dim_Transportista_NatKey UNIQUE (ShipperID)
);
GO

PRINT '>> Dim_Transportista creada.';
GO

PRINT '=============================================';
PRINT '>> Todas las dimensiones creadas exitosamente.';
PRINT '=============================================';
GO
