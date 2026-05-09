/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 08b: ETL Incremental con SCD Tipo 2 (MERGE)
  
  Descripción : Versión actualizada del SP maestro para implementar:
                1. SCD Tipo 2 en Dimensiones (Guarda Historial).
                2. Carga Incremental usando ROWVERSION.
==========================================================================
*/

USE NorthwindDW;
GO

IF OBJECT_ID('dbo.sp_ETL_CargaIncremental', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ETL_CargaIncremental;
GO

CREATE PROCEDURE dbo.sp_ETL_CargaIncremental
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @InicioGlobal DATETIME = GETDATE();
    DECLARE @UltimoRV BINARY(8);
    DECLARE @NuevoRV BINARY(8);

    PRINT 'Iniciando Carga Incremental y SCD Tipo 2...';

    -- ===================================================================
    -- DIM_PRODUCTO: Carga Incremental + SCD Tipo 2 usando MERGE
    -- ===================================================================
    -- 1. Obtener el último RowVersion procesado
    SELECT @UltimoRV = UltimoRowVersion FROM dbo.Carga_Control WHERE TablaOrigen = 'Products';

    -- 2. Guardar el RowVersion más alto actual en el OLTP para esta iteración
    SELECT @NuevoRV = MAX(VersionFila) FROM Northwind.dbo.Products;

    -- 3. Inserción SCD Tipo 2 (MERGE indirecto o con CTE)
    -- Para SCD Tipo 2, si un registro cambia, caducamos el viejo e insertamos el nuevo.
    -- Los registros nuevos simplemente se insertan.
    IF @NuevoRV > @UltimoRV
    BEGIN
        -- Usamos una tabla temporal para los deltas
        SELECT 
            p.ProductID, p.ProductName, c.CategoryName, c.[Description],
            s.CompanyName AS NombreProveedor, s.Country AS PaisProveedor,
            p.QuantityPerUnit, p.UnitPrice, p.Discontinued, p.VersionFila
        INTO #DeltaProducts
        FROM Northwind.dbo.Products p
        LEFT JOIN Northwind.dbo.Categories c ON p.CategoryID = c.CategoryID
        LEFT JOIN Northwind.dbo.Suppliers s ON p.SupplierID = s.SupplierID
        WHERE p.VersionFila > @UltimoRV;

        -- A. CADUCAR LOS EXISTENTES (UPDATE EsActual = 0)
        UPDATE dw
        SET 
            dw.EsActual = 0,
            dw.FechaFin = GETDATE()
        FROM dbo.Dim_Producto dw
        INNER JOIN #DeltaProducts delta ON dw.ProductID = delta.ProductID
        WHERE dw.EsActual = 1;

        -- B. INSERTAR LAS NUEVAS VERSIONES O NUEVOS PRODUCTOS
        INSERT INTO dbo.Dim_Producto (
            ProductID, NombreProducto, NombreCategoria, DescripcionCategoria,
            NombreProveedor, PaisProveedor, CantidadPorUnidad, PrecioUnitario,
            Descontinuado, Version, FechaInicio, FechaFin, EsActual, Origen_Version
        )
        SELECT 
            delta.ProductID, delta.ProductName, delta.CategoryName, delta.Description,
            delta.NombreProveedor, delta.PaisProveedor, delta.QuantityPerUnit, delta.UnitPrice,
            delta.Discontinued,
            ISNULL((SELECT MAX(Version) FROM dbo.Dim_Producto d WHERE d.ProductID = delta.ProductID), 0) + 1,
            GETDATE(), NULL, 1, delta.VersionFila
        FROM #DeltaProducts delta;

        -- 4. Actualizar la tabla de control
        UPDATE dbo.Carga_Control SET UltimoRowVersion = @NuevoRV, FechaActualizacion = GETDATE()
        WHERE TablaOrigen = 'Products';
        
        DROP TABLE #DeltaProducts;
        PRINT 'Dim_Producto: Cambios procesados exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'Dim_Producto: No hay cambios nuevos.';
    END

    -- ===================================================================
    -- DIM_CLIENTE: Carga Incremental + SCD Tipo 2 usando MERGE
    -- ===================================================================
    -- 1. Obtener el último RowVersion procesado
    SELECT @UltimoRV = UltimoRowVersion FROM dbo.Carga_Control WHERE TablaOrigen = 'Customers';

    -- 2. Guardar el RowVersion más alto actual en el OLTP
    SELECT @NuevoRV = MAX(VersionFila) FROM Northwind.dbo.Customers;

    IF @NuevoRV > @UltimoRV
    BEGIN
        -- Usamos una tabla temporal para los deltas
        SELECT 
            CustomerID, CompanyName, ContactName, ContactTitle, 
            City, Region, Country, PostalCode, VersionFila
        INTO #DeltaCustomers
        FROM Northwind.dbo.Customers
        WHERE VersionFila > @UltimoRV;

        -- A. CADUCAR LOS EXISTENTES (UPDATE EsActual = 0)
        UPDATE dw
        SET 
            dw.EsActual = 0,
            dw.FechaFin = GETDATE()
        FROM dbo.Dim_Cliente dw
        INNER JOIN #DeltaCustomers delta ON dw.CustomerID = delta.CustomerID
        WHERE dw.EsActual = 1;

        -- B. INSERTAR LAS NUEVAS VERSIONES O NUEVOS CLIENTES
        INSERT INTO dbo.Dim_Cliente (
            CustomerID, NombreCompania, NombreContacto, TituloContacto,
            Ciudad, Region, Pais, CodigoPostal,
            Version, FechaInicio, FechaFin, EsActual, Origen_Version
        )
        SELECT 
            delta.CustomerID, delta.CompanyName, delta.ContactName, delta.ContactTitle,
            delta.City, delta.Region, delta.Country, delta.PostalCode,
            ISNULL((SELECT MAX(Version) FROM dbo.Dim_Cliente d WHERE d.CustomerID = delta.CustomerID), 0) + 1,
            GETDATE(), NULL, 1, delta.VersionFila
        FROM #DeltaCustomers delta;

        -- 4. Actualizar tabla de control
        UPDATE dbo.Carga_Control SET UltimoRowVersion = @NuevoRV, FechaActualizacion = GETDATE()
        WHERE TablaOrigen = 'Customers';
        
        DROP TABLE #DeltaCustomers;
        PRINT 'Dim_Cliente: Cambios procesados exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'Dim_Cliente: No hay cambios nuevos.';
    END

    -- ===================================================================
    -- DIM_EMPLEADO: Carga Incremental + SCD Tipo 2 usando MERGE
    -- ===================================================================
    SELECT @UltimoRV = UltimoRowVersion FROM dbo.Carga_Control WHERE TablaOrigen = 'Employees';
    SELECT @NuevoRV = MAX(VersionFila) FROM Northwind.dbo.Employees;

    IF @NuevoRV > @UltimoRV
    BEGIN
        SELECT 
            e.EmployeeID,
            e.FirstName + N' ' + e.LastName AS NombreCompleto,
            e.Title AS Titulo,
            e.HireDate AS FechaContratacion,
            e.City AS Ciudad,
            e.Country AS Pais,
            CASE WHEN e.ReportsTo IS NOT NULL THEN sup.FirstName + N' ' + sup.LastName ELSE NULL END AS NombreSupervisor,
            e.VersionFila
        INTO #DeltaEmployees
        FROM Northwind.dbo.Employees e
        LEFT JOIN Northwind.dbo.Employees sup ON e.ReportsTo = sup.EmployeeID
        WHERE e.VersionFila > @UltimoRV;

        -- A. CADUCAR LOS EXISTENTES
        UPDATE dw
        SET dw.EsActual = 0, dw.FechaFin = GETDATE()
        FROM dbo.Dim_Empleado dw
        INNER JOIN #DeltaEmployees delta ON dw.EmployeeID = delta.EmployeeID
        WHERE dw.EsActual = 1;

        -- B. INSERTAR LAS NUEVAS VERSIONES
        INSERT INTO dbo.Dim_Empleado (
            EmployeeID, NombreCompleto, Titulo, FechaContratacion, 
            Ciudad, Pais, NombreSupervisor,
            Version, FechaInicio, FechaFin, EsActual, Origen_Version
        )
        SELECT 
            delta.EmployeeID, delta.NombreCompleto, delta.Titulo, delta.FechaContratacion,
            delta.Ciudad, delta.Pais, delta.NombreSupervisor,
            ISNULL((SELECT MAX(Version) FROM dbo.Dim_Empleado d WHERE d.EmployeeID = delta.EmployeeID), 0) + 1,
            GETDATE(), NULL, 1, delta.VersionFila
        FROM #DeltaEmployees delta;

        UPDATE dbo.Carga_Control SET UltimoRowVersion = @NuevoRV, FechaActualizacion = GETDATE() WHERE TablaOrigen = 'Employees';
        DROP TABLE #DeltaEmployees;
        PRINT 'Dim_Empleado: Cambios procesados exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'Dim_Empleado: No hay cambios nuevos.';
    END

    -- ===================================================================
    -- DIM_TRANSPORTISTA: Carga Incremental + SCD Tipo 2
    -- ===================================================================
    SELECT @UltimoRV = UltimoRowVersion FROM dbo.Carga_Control WHERE TablaOrigen = 'Shippers';
    SELECT @NuevoRV = MAX(VersionFila) FROM Northwind.dbo.Shippers;

    IF @NuevoRV > @UltimoRV
    BEGIN
        SELECT ShipperID, CompanyName, Phone, VersionFila
        INTO #DeltaShippers
        FROM Northwind.dbo.Shippers
        WHERE VersionFila > @UltimoRV;

        -- A. CADUCAR LOS EXISTENTES
        UPDATE dw
        SET dw.EsActual = 0, dw.FechaFin = GETDATE()
        FROM dbo.Dim_Transportista dw
        INNER JOIN #DeltaShippers delta ON dw.ShipperID = delta.ShipperID
        WHERE dw.EsActual = 1;

        -- B. INSERTAR LAS NUEVAS VERSIONES
        INSERT INTO dbo.Dim_Transportista (
            ShipperID, NombreCompania, Telefono,
            Version, FechaInicio, FechaFin, EsActual, Origen_Version
        )
        SELECT 
            delta.ShipperID, delta.CompanyName, delta.Phone,
            ISNULL((SELECT MAX(Version) FROM dbo.Dim_Transportista d WHERE d.ShipperID = delta.ShipperID), 0) + 1,
            GETDATE(), NULL, 1, delta.VersionFila
        FROM #DeltaShippers delta;

        UPDATE dbo.Carga_Control SET UltimoRowVersion = @NuevoRV, FechaActualizacion = GETDATE() WHERE TablaOrigen = 'Shippers';
        DROP TABLE #DeltaShippers;
        PRINT 'Dim_Transportista: Cambios procesados exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'Dim_Transportista: No hay cambios nuevos.';
    END
    
    PRINT 'Proceso Incremental finalizado.';
END
GO

-- =====================================================================
-- PARTE 4: ACTUALIZAR EL SQL SERVER AGENT JOB
-- Cambia el paso del Job existente para que ejecute este nuevo SP.
-- =====================================================================
USE msdb;
GO

EXEC msdb.dbo.sp_update_jobstep
    @job_name   = N'Job_ETL_NorthwindDW',
    @step_id    = 1,
    @command    = N'EXEC NorthwindDW.dbo.sp_ETL_CargaIncremental;';
GO

PRINT '>> Job actualizado para usar el ETL Incremental.';
GO
