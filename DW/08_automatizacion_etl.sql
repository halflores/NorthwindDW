/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 08: Automatización ETL con SQL Server Agent Job
  
  Descripción : Implementa la automatización completa del proceso ETL:
                 1. Tabla de log/auditoría (ETL_Log)
                 2. Stored Procedure maestro (sp_ETL_CargaCompleta)
                 3. SQL Server Agent Job (Job_ETL_NorthwindDW)
  
  Patrón de Integración:
  ──────────────────────
  • Dirección  : UNIDIRECCIONAL (OLTP → DW, nunca al revés)
  • Mecanismo  : PULL — El DW extrae datos del OLTP.
                 El SP corre en NorthwindDW y consulta Northwind.dbo.*
  • Tipo carga : Full Refresh (TRUNCATE + INSERT) por simplicidad
  • Frecuencia : Cada 1 minuto (configurable en el schedule del Job)
  
  Prerequisitos:
    - BD Northwind (OLTP) poblada
    - BD NorthwindDW con tablas creadas (Scripts 01-03)
    - Dim_Tiempo poblada (Script 04)
    - SQL Server Agent activo (no disponible en SQL Server Express)
  
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
-- PARTE 1: TABLA DE LOG / AUDITORÍA ETL
-- Registra cada ejecución del proceso ETL con estado, duración y errores.
-- =====================================================================
IF OBJECT_ID('dbo.ETL_Log', 'U') IS NOT NULL
    DROP TABLE dbo.ETL_Log;
GO

CREATE TABLE dbo.ETL_Log (
    LogID                   INT IDENTITY(1,1)   NOT NULL,
    FechaEjecucion          DATETIME            NOT NULL DEFAULT GETDATE(),
    Paso                    NVARCHAR(100)       NOT NULL,
    RegistrosAfectados      INT                 NULL,
    Estado                  NVARCHAR(20)        NOT NULL,   -- 'EXITO', 'ERROR', 'INICIO', 'FIN'
    Mensaje                 NVARCHAR(MAX)       NULL,
    DuracionSegundos        INT                 NULL,

    CONSTRAINT PK_ETL_Log PRIMARY KEY CLUSTERED (LogID)
);
GO

PRINT '>> Tabla ETL_Log creada.';
GO

-- =====================================================================
-- PARTE 2: STORED PROCEDURE MAESTRO — sp_ETL_CargaCompleta
--
-- Orquesta la carga completa del DW en el siguiente orden:
--   1. Registrar inicio
--   2. Cargar Dim_Producto    (TRUNCATE + INSERT desde OLTP)
--   3. Cargar Dim_Cliente     (TRUNCATE + INSERT desde OLTP)
--   4. Cargar Dim_Empleado    (TRUNCATE + INSERT desde OLTP)
--   5. Cargar Dim_Transportista (TRUNCATE + INSERT desde OLTP)
--   6. Cargar Fact_Ventas     (DELETE + INSERT con prorrateo de flete)
--   7. Registrar fin exitoso
--
-- PATRÓN: PULL — Este SP se ejecuta en NorthwindDW y "jala" datos
--         del OLTP mediante SELECT FROM Northwind.dbo.*
--
-- Nota: Fact_Ventas usa DELETE en lugar de TRUNCATE porque TRUNCATE
--       no es permitido en tablas referenciadas por FK constraints.
-- =====================================================================
IF OBJECT_ID('dbo.sp_ETL_CargaCompleta', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ETL_CargaCompleta;
GO

CREATE PROCEDURE dbo.sp_ETL_CargaCompleta
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InicioGlobal   DATETIME = GETDATE();
    DECLARE @InicioPaso     DATETIME;
    DECLARE @Filas          INT;
    DECLARE @ErrorMsg       NVARCHAR(MAX);

    -- -----------------------------------------------------------------
    -- PASO 1: Registrar inicio del proceso ETL
    -- -----------------------------------------------------------------
    INSERT INTO dbo.ETL_Log (Paso, Estado, Mensaje)
    VALUES ('INICIO_ETL', 'INICIO', 'Proceso ETL iniciado.');

    BEGIN TRY

        -- =============================================================
        -- PASO 2: Cargar Dim_Producto
        -- PULL: SELECT FROM Northwind.dbo.Products + Categories + Suppliers
        -- =============================================================
        SET @InicioPaso = GETDATE();

        -- No se puede TRUNCATE Dim_Producto si Fact_Ventas tiene FK.
        -- Primero eliminar hechos, luego dimensiones.
        DELETE FROM dbo.Fact_Ventas;
        
        DELETE FROM dbo.Dim_Producto;

        SET IDENTITY_INSERT dbo.Dim_Producto OFF;

        INSERT INTO dbo.Dim_Producto (
            ProductID, NombreProducto, NombreCategoria,
            DescripcionCategoria, NombreProveedor, PaisProveedor,
            CantidadPorUnidad, PrecioUnitario, Descontinuado
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
        FROM Northwind.dbo.Products        AS p
        LEFT JOIN Northwind.dbo.Categories AS c ON p.CategoryID = c.CategoryID
        LEFT JOIN Northwind.dbo.Suppliers  AS s ON p.SupplierID = s.SupplierID;

        SET @Filas = @@ROWCOUNT;

        INSERT INTO dbo.ETL_Log (Paso, RegistrosAfectados, Estado, Mensaje, DuracionSegundos)
        VALUES ('Dim_Producto', @Filas, 'EXITO',
                'Dimensión Producto cargada correctamente.',
                DATEDIFF(SECOND, @InicioPaso, GETDATE()));

        -- =============================================================
        -- PASO 3: Cargar Dim_Cliente
        -- PULL: SELECT FROM Northwind.dbo.Customers
        -- =============================================================
        SET @InicioPaso = GETDATE();

        DELETE FROM dbo.Dim_Cliente;

        INSERT INTO dbo.Dim_Cliente (
            CustomerID, NombreCompania, NombreContacto,
            TituloContacto, Ciudad, Region, Pais, CodigoPostal
        )
        SELECT
            CustomerID, CompanyName, ContactName,
            ContactTitle, City, Region, Country, PostalCode
        FROM Northwind.dbo.Customers;

        SET @Filas = @@ROWCOUNT;

        INSERT INTO dbo.ETL_Log (Paso, RegistrosAfectados, Estado, Mensaje, DuracionSegundos)
        VALUES ('Dim_Cliente', @Filas, 'EXITO',
                'Dimensión Cliente cargada correctamente.',
                DATEDIFF(SECOND, @InicioPaso, GETDATE()));

        -- =============================================================
        -- PASO 4: Cargar Dim_Empleado
        -- PULL: SELECT FROM Northwind.dbo.Employees (con self-join)
        -- =============================================================
        SET @InicioPaso = GETDATE();

        DELETE FROM dbo.Dim_Empleado;

        INSERT INTO dbo.Dim_Empleado (
            EmployeeID, NombreCompleto, Titulo,
            FechaContratacion, Ciudad, Pais, NombreSupervisor
        )
        SELECT
            e.EmployeeID,
            e.FirstName + N' ' + e.LastName,
            e.Title,
            e.HireDate,
            e.City,
            e.Country,
            CASE
                WHEN e.ReportsTo IS NOT NULL
                THEN sup.FirstName + N' ' + sup.LastName
                ELSE NULL
            END
        FROM Northwind.dbo.Employees       AS e
        LEFT JOIN Northwind.dbo.Employees  AS sup ON e.ReportsTo = sup.EmployeeID;

        SET @Filas = @@ROWCOUNT;

        INSERT INTO dbo.ETL_Log (Paso, RegistrosAfectados, Estado, Mensaje, DuracionSegundos)
        VALUES ('Dim_Empleado', @Filas, 'EXITO',
                'Dimensión Empleado cargada correctamente.',
                DATEDIFF(SECOND, @InicioPaso, GETDATE()));

        -- =============================================================
        -- PASO 5: Cargar Dim_Transportista
        -- PULL: SELECT FROM Northwind.dbo.Shippers
        -- =============================================================
        SET @InicioPaso = GETDATE();

        DELETE FROM dbo.Dim_Transportista;

        INSERT INTO dbo.Dim_Transportista (
            ShipperID, NombreCompania, Telefono
        )
        SELECT
            ShipperID, CompanyName, Phone
        FROM Northwind.dbo.Shippers;

        SET @Filas = @@ROWCOUNT;

        INSERT INTO dbo.ETL_Log (Paso, RegistrosAfectados, Estado, Mensaje, DuracionSegundos)
        VALUES ('Dim_Transportista', @Filas, 'EXITO',
                'Dimensión Transportista cargada correctamente.',
                DATEDIFF(SECOND, @InicioPaso, GETDATE()));

        -- =============================================================
        -- PASO 6: Cargar Fact_Ventas
        -- PULL: SELECT FROM Northwind.dbo.[Order Details] + Orders
        --
        -- FÓRMULA DEL PRORRATEO DE FLETE:
        --   FleteProrrateado = Orders.Freight
        --                      × (MontoLineaActual / SubtotalOrden)
        -- Donde:
        --   MontoLineaActual = UnitPrice × Quantity × (1 - Discount)
        --   SubtotalOrden = SUM(MontoLineaActual) para el mismo OrderID
        -- =============================================================
        SET @InicioPaso = GETDATE();

        -- Fact_Ventas ya fue vaciada en PASO 2 para liberar FK.
        -- Si por alguna razón quedaron registros, limpiar de nuevo:
        DELETE FROM dbo.Fact_Ventas;

        ;WITH SubtotalesOrden AS (
            SELECT
                od.OrderID,
                SUM(CONVERT(MONEY, od.UnitPrice * od.Quantity * (1 - od.Discount)))
                    AS SubtotalOrden
            FROM Northwind.dbo.[Order Details] AS od
            GROUP BY od.OrderID
        ),
        LineasDetalle AS (
            SELECT
                od.OrderID,
                od.ProductID,
                od.UnitPrice,
                od.Quantity,
                od.Discount,
                CONVERT(MONEY, od.UnitPrice * od.Quantity * (1 - od.Discount))
                    AS MontoVenta,
                -- Prorrateo: Freight × (MontoLinea / SubtotalOrden)
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
        INSERT INTO dbo.Fact_Ventas (
            SK_Producto, SK_Cliente, SK_Empleado,
            SK_Tiempo, SK_Transportista, OrderID,
            PrecioUnitario, Cantidad, Descuento,
            MontoVenta, FleteProrrateado
        )
        SELECT
            dp.SK_Producto,
            dc.SK_Cliente,
            de.SK_Empleado,
            dt.SK_Tiempo,
            dtr.SK_Transportista,
            ld.OrderID,
            ld.UnitPrice,
            ld.Quantity,
            ld.Discount,
            ld.MontoVenta,
            ld.FleteProrrateado
        FROM LineasDetalle AS ld
        INNER JOIN dbo.Dim_Producto       AS dp  ON ld.ProductID  = dp.ProductID
        INNER JOIN dbo.Dim_Cliente        AS dc  ON ld.CustomerID = dc.CustomerID
        INNER JOIN dbo.Dim_Empleado       AS de  ON ld.EmployeeID = de.EmployeeID
        INNER JOIN dbo.Dim_Tiempo         AS dt  ON dt.SK_Tiempo  = YEAR(ld.OrderDate) * 10000
                                                                   + MONTH(ld.OrderDate) * 100
                                                                   + DAY(ld.OrderDate)
        INNER JOIN dbo.Dim_Transportista  AS dtr ON ld.ShipVia    = dtr.ShipperID;

        SET @Filas = @@ROWCOUNT;

        INSERT INTO dbo.ETL_Log (Paso, RegistrosAfectados, Estado, Mensaje, DuracionSegundos)
        VALUES ('Fact_Ventas', @Filas, 'EXITO',
                'Tabla de hechos cargada con prorrateo de flete.',
                DATEDIFF(SECOND, @InicioPaso, GETDATE()));

        -- =============================================================
        -- PASO 7: Registrar fin exitoso
        -- =============================================================
        INSERT INTO dbo.ETL_Log (Paso, Estado, Mensaje, DuracionSegundos)
        VALUES ('FIN_ETL', 'EXITO',
                'Proceso ETL completado exitosamente.',
                DATEDIFF(SECOND, @InicioGlobal, GETDATE()));

        PRINT '>> ETL completado exitosamente en '
              + CAST(DATEDIFF(SECOND, @InicioGlobal, GETDATE()) AS VARCHAR(10))
              + ' segundos.';

    END TRY
    BEGIN CATCH

        -- =============================================================
        -- MANEJO DE ERRORES: Registrar en ETL_Log
        -- =============================================================
        SET @ErrorMsg = N'Error ' + CAST(ERROR_NUMBER() AS NVARCHAR(10))
                      + N': ' + ERROR_MESSAGE()
                      + N' | Línea: ' + CAST(ERROR_LINE() AS NVARCHAR(10))
                      + N' | Procedimiento: ' + ISNULL(ERROR_PROCEDURE(), N'N/A');

        INSERT INTO dbo.ETL_Log (Paso, Estado, Mensaje, DuracionSegundos)
        VALUES ('ERROR_ETL', 'ERROR', @ErrorMsg,
                DATEDIFF(SECOND, @InicioGlobal, GETDATE()));

        PRINT '>> ERROR en ETL: ' + @ErrorMsg;

        -- Re-lanzar el error para que SQL Agent lo registre también
        THROW;

    END CATCH;
END;
GO

PRINT '>> Stored Procedure sp_ETL_CargaCompleta creado.';
GO

-- =====================================================================
-- PARTE 3: SQL SERVER AGENT JOB — Job_ETL_NorthwindDW
--
-- Crea un Job en SQL Server Agent que ejecuta el SP cada 1 minuto.
--
-- NOTA: Requiere permisos de sysadmin o SQLAgentOperatorRole.
--       SQL Server Express NO soporta Agent.
-- =====================================================================

USE msdb;
GO

-- -----------------------------------------------------------------
-- Eliminar Job si ya existe (para re-ejecución idempotente)
-- -----------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Job_ETL_NorthwindDW')
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = N'Job_ETL_NorthwindDW',
        @delete_unused_schedule = 1;
END
GO

-- -----------------------------------------------------------------
-- Crear el Job
-- -----------------------------------------------------------------
DECLARE @jobId BINARY(16);

EXEC msdb.dbo.sp_add_job
    @job_name           = N'Job_ETL_NorthwindDW',
    @enabled            = 1,
    @description        = N'Carga ETL automática del Data Warehouse NorthwindDW. Patrón PULL: extrae datos del OLTP Northwind cada 1 minuto.',
    @category_name      = N'[Uncategorized (Local)]',
    @owner_login_name   = N'sa',
    @job_id             = @jobId OUTPUT;

PRINT '>> Job creado: Job_ETL_NorthwindDW';

-- -----------------------------------------------------------------
-- Agregar Step 1: Ejecutar el SP de carga
-- -----------------------------------------------------------------
EXEC msdb.dbo.sp_add_jobstep
    @job_id             = @jobId,
    @step_name          = N'Ejecutar_sp_ETL_CargaCompleta',
    @step_id            = 1,
    @subsystem          = N'TSQL',
    @command            = N'EXEC dbo.sp_ETL_CargaCompleta;',
    @database_name      = N'NorthwindDW',
    @on_success_action  = 1,   -- Quit with success
    @on_fail_action     = 2,   -- Quit with failure
    @retry_attempts     = 0,
    @retry_interval     = 0;

PRINT '>> Step agregado: Ejecutar_sp_ETL_CargaCompleta';

-- -----------------------------------------------------------------
-- Agregar Schedule: Cada 1 minuto, 24/7
--
-- freq_type = 4          → Diario
-- freq_interval = 1      → Cada 1 día
-- freq_subday_type = 4   → Minutos
-- freq_subday_interval = 1 → Cada 1 minuto
-- active_start_time = 0  → Desde las 00:00:00
-- active_end_time = 235959 → Hasta las 23:59:59
-- -----------------------------------------------------------------
EXEC msdb.dbo.sp_add_jobschedule
    @job_id                 = @jobId,
    @name                   = N'Schedule_Cada_1_Minuto',
    @enabled                = 1,
    @freq_type              = 4,        -- Diario
    @freq_interval          = 1,        -- Cada 1 día
    @freq_subday_type       = 4,        -- En minutos
    @freq_subday_interval   = 1,        -- Cada 1 minuto
    @active_start_date      = 20260101, -- Desde 2026-01-01
    @active_end_date        = 99991231, -- Sin fecha de fin
    @active_start_time      = 0,        -- 00:00:00
    @active_end_time        = 235959;   -- 23:59:59

PRINT '>> Schedule agregado: Cada 1 minuto';

-- -----------------------------------------------------------------
-- Asignar el Job al servidor local
-- -----------------------------------------------------------------
EXEC msdb.dbo.sp_add_jobserver
    @job_id         = @jobId,
    @server_name    = N'(LOCAL)';

PRINT '>> Job asignado al servidor local.';
GO

-- =====================================================================
-- VERIFICACIÓN FINAL
-- =====================================================================
USE NorthwindDW;
GO

PRINT '=====================================================================';
PRINT '>> AUTOMATIZACIÓN ETL CONFIGURADA:';
PRINT '>>   - Tabla de log:    dbo.ETL_Log';
PRINT '>>   - Stored Procedure: dbo.sp_ETL_CargaCompleta';
PRINT '>>   - Agent Job:       Job_ETL_NorthwindDW (cada 1 minuto)';
PRINT '>>   - Patrón:          PULL unidireccional (OLTP → DW)';
PRINT '=====================================================================';
PRINT '';
PRINT '>> Para ejecutar manualmente el ETL:';
PRINT '>>   EXEC dbo.sp_ETL_CargaCompleta;';
PRINT '';
PRINT '>> Para ver el historial de ejecuciones:';
PRINT '>>   SELECT * FROM dbo.ETL_Log ORDER BY LogID DESC;';
PRINT '';
PRINT '>> Para iniciar el Job manualmente:';
PRINT '>>   EXEC msdb.dbo.sp_start_job @job_name = N''Job_ETL_NorthwindDW'';';
PRINT '';
PRINT '>> Para detener el schedule (sin eliminar el Job):';
PRINT '>>   EXEC msdb.dbo.sp_update_job @job_name = N''Job_ETL_NorthwindDW'', @enabled = 0;';
GO
