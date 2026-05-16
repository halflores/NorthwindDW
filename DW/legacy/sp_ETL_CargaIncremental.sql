/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 08b: ETL Incremental con SCD Tipo 2 (MERGE)
  
  Descripción : Versión actualizada del SP maestro para implementar:
                1. SCD Tipo 2 en Dimensiones (Guarda Historial).
                2. Carga Incremental usando ROWVERSION.
==========================================================================
*/



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
    
    -- ===================================================================
    -- FACT_VENTAS: Carga Incremental (Append-Only con Asientos de Reverso)
    -- ===================================================================
    DECLARE @UltimoRV_Orders BINARY(8);
    DECLARE @UltimoRV_OrderDetails BINARY(8);
    DECLARE @NuevoRV_Orders BINARY(8);
    DECLARE @NuevoRV_OrderDetails BINARY(8);

    SELECT @UltimoRV_Orders = UltimoRowVersion FROM dbo.Carga_Control WHERE TablaOrigen = 'Orders';
    SELECT @UltimoRV_OrderDetails = UltimoRowVersion FROM dbo.Carga_Control WHERE TablaOrigen = 'Order Details';
    
    SELECT @NuevoRV_Orders = ISNULL(MAX(VersionFila), 0x0) FROM Northwind.dbo.Orders;
    SELECT @NuevoRV_OrderDetails = ISNULL(MAX(VersionFila), 0x0) FROM Northwind.dbo.[Order Details];

    IF @NuevoRV_Orders > @UltimoRV_Orders OR @NuevoRV_OrderDetails > @UltimoRV_OrderDetails
    BEGIN
        -- 1. Extraer los deltas (Nuevos o Modificados)
        -- A. Identificar qué OrderIDs han sido afectados
        SELECT DISTINCT OrderID INTO #AffectedOrders
        FROM Northwind.dbo.Orders WHERE VersionFila > @UltimoRV_Orders
        UNION
        SELECT DISTINCT OrderID
        FROM Northwind.dbo.[Order Details] WHERE VersionFila > @UltimoRV_OrderDetails;

        -- B. Calcular el subtotal de las ordenes afectadas (para el prorrateo de flete)
        SELECT 
            od.OrderID,
            SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS SubtotalOrden
        INTO #OrderSubtotals
        FROM Northwind.dbo.[Order Details] od
        INNER JOIN #AffectedOrders ao ON od.OrderID = ao.OrderID
        GROUP BY od.OrderID;

        -- C. Obtener el detalle completo fresco de esas órdenes
        SELECT 
            od.OrderID,
            od.ProductID,
            o.CustomerID,
            o.EmployeeID,
            CONVERT(INT, CONVERT(VARCHAR(8), o.OrderDate, 112)) AS SK_Tiempo,
            o.ShipVia AS ShipperID,
            od.UnitPrice AS PrecioUnitario,
            od.Quantity AS Cantidad,
            od.Discount AS Descuento,
            (od.UnitPrice * od.Quantity * (1 - od.Discount)) AS MontoLinea,
            CASE WHEN os.SubtotalOrden = 0 THEN 0 
                 ELSE o.Freight * ((od.UnitPrice * od.Quantity * (1 - od.Discount)) / os.SubtotalOrden)
            END AS FleteProrrateado
        INTO #NuevosHechos
        FROM Northwind.dbo.[Order Details] od
        INNER JOIN Northwind.dbo.Orders o ON od.OrderID = o.OrderID
        INNER JOIN #AffectedOrders ao ON od.OrderID = ao.OrderID
        INNER JOIN #OrderSubtotals os ON od.OrderID = os.OrderID;

        -- Cruzamos con Dimensiones
        SELECT 
            ISNULL(dp.SK_Producto, -1) AS SK_Producto,
            ISNULL(dc.SK_Cliente, -1) AS SK_Cliente,
            ISNULL(de.SK_Empleado, -1) AS SK_Empleado,
            nh.SK_Tiempo,
            ISNULL(dt.SK_Transportista, -1) AS SK_Transportista,
            nh.OrderID, nh.ProductID, nh.PrecioUnitario, nh.Cantidad, nh.Descuento,
            nh.MontoLinea AS MontoVenta, nh.FleteProrrateado
        INTO #HechosTransformados
        FROM #NuevosHechos nh
        LEFT JOIN dbo.Dim_Producto dp ON nh.ProductID = dp.ProductID AND dp.EsActual = 1
        LEFT JOIN dbo.Dim_Cliente dc ON nh.CustomerID = dc.CustomerID AND dc.EsActual = 1
        LEFT JOIN dbo.Dim_Empleado de ON nh.EmployeeID = de.EmployeeID AND de.EsActual = 1
        LEFT JOIN dbo.Dim_Transportista dt ON nh.ShipperID = dt.ShipperID AND dt.EsActual = 1;

        -- FASE 1: UPSERT (Reversos y Nuevas Inserciones)
        -- 1.A. Identificar líneas que ya existían (Actualizaciones)
        SELECT 
            fv.OrderID, dp.ProductID, fv.SK_Producto, fv.SK_Cliente, fv.SK_Empleado, fv.SK_Tiempo, fv.SK_Transportista,
            fv.PrecioUnitario, SUM(fv.Cantidad) AS CantidadNeta, fv.Descuento,
            SUM(fv.MontoVenta) AS MontoVentaNeto, SUM(fv.FleteProrrateado) AS FleteNeto
        INTO #SaldosExistentes
        FROM dbo.Fact_Ventas fv
        INNER JOIN dbo.Dim_Producto dp ON fv.SK_Producto = dp.SK_Producto
        INNER JOIN #HechosTransformados ht ON fv.OrderID = ht.OrderID AND dp.ProductID = ht.ProductID
        GROUP BY 
            fv.OrderID, dp.ProductID, fv.SK_Producto, fv.SK_Cliente, fv.SK_Empleado, fv.SK_Tiempo, fv.SK_Transportista,
            fv.PrecioUnitario, fv.Descuento
        HAVING SUM(fv.Cantidad) > 0;

        -- 1.B. Insertar REVERSOS
        INSERT INTO dbo.Fact_Ventas (
            SK_Producto, SK_Cliente, SK_Empleado, SK_Tiempo, SK_Transportista, OrderID, PrecioUnitario, Cantidad, Descuento, MontoVenta, FleteProrrateado, TipoTransaccion
        )
        SELECT 
            SK_Producto, SK_Cliente, SK_Empleado, SK_Tiempo, SK_Transportista, OrderID, PrecioUnitario, 
            -CantidadNeta, Descuento, -MontoVentaNeto, -FleteNeto, 'Reverso por Actualización'
        FROM #SaldosExistentes;

        -- 1.C. Insertar NUEVO ESTADO
        INSERT INTO dbo.Fact_Ventas (
            SK_Producto, SK_Cliente, SK_Empleado, SK_Tiempo, SK_Transportista, OrderID, PrecioUnitario, Cantidad, Descuento, MontoVenta, FleteProrrateado, TipoTransaccion
        )
        SELECT 
            ht.SK_Producto, ht.SK_Cliente, ht.SK_Empleado, ht.SK_Tiempo, ht.SK_Transportista, ht.OrderID, ht.PrecioUnitario, ht.Cantidad, ht.Descuento, ht.MontoVenta, ht.FleteProrrateado, 'Nueva Versión'
        FROM #HechosTransformados ht
        INNER JOIN #SaldosExistentes se ON ht.OrderID = se.OrderID AND ht.ProductID = se.ProductID;

        -- 1.D. Insertar NUEVAS
        INSERT INTO dbo.Fact_Ventas (
            SK_Producto, SK_Cliente, SK_Empleado, SK_Tiempo, SK_Transportista, OrderID, PrecioUnitario, Cantidad, Descuento, MontoVenta, FleteProrrateado, TipoTransaccion
        )
        SELECT 
            ht.SK_Producto, ht.SK_Cliente, ht.SK_Empleado, ht.SK_Tiempo, ht.SK_Transportista, ht.OrderID, ht.PrecioUnitario, ht.Cantidad, ht.Descuento, ht.MontoVenta, ht.FleteProrrateado, 'Venta Original'
        FROM #HechosTransformados ht
        LEFT JOIN #SaldosExistentes se ON ht.OrderID = se.OrderID AND ht.ProductID = se.ProductID
        WHERE se.OrderID IS NULL;

        DROP TABLE #AffectedOrders; DROP TABLE #OrderSubtotals; DROP TABLE #NuevosHechos; DROP TABLE #HechosTransformados; DROP TABLE #SaldosExistentes;

        UPDATE dbo.Carga_Control SET UltimoRowVersion = @NuevoRV_Orders, FechaActualizacion = GETDATE() WHERE TablaOrigen = 'Orders';
        UPDATE dbo.Carga_Control SET UltimoRowVersion = @NuevoRV_OrderDetails, FechaActualizacion = GETDATE() WHERE TablaOrigen = 'Order Details';

        PRINT 'Fact_Ventas: Inserciones y Actualizaciones procesadas.';
    END
    ELSE
    BEGIN
        PRINT 'Fact_Ventas: No hay órdenes nuevas ni modificadas.';
    END

    -- ===================================================================
    -- FASE 2: RECONCILIACIÓN DE BORRADOS FÍSICOS (Hard Deletes)
    -- ===================================================================
    PRINT 'Iniciando Reconciliación de Borrados...';
    
    SELECT 
        fv.OrderID, dp.ProductID, fv.SK_Producto, fv.SK_Cliente, fv.SK_Empleado, fv.SK_Tiempo, fv.SK_Transportista,
        fv.PrecioUnitario, fv.Descuento, SUM(fv.Cantidad) AS CantidadNeta, SUM(fv.MontoVenta) AS MontoVentaNeto, SUM(fv.FleteProrrateado) AS FleteNeto
    INTO #SaldosDW
    FROM dbo.Fact_Ventas fv
    INNER JOIN dbo.Dim_Producto dp ON fv.SK_Producto = dp.SK_Producto
    GROUP BY 
        fv.OrderID, dp.ProductID, fv.SK_Producto, fv.SK_Cliente, fv.SK_Empleado, fv.SK_Tiempo, fv.SK_Transportista,
        fv.PrecioUnitario, fv.Descuento
    HAVING SUM(fv.Cantidad) > 0;

    SELECT dw.* INTO #Borrados
    FROM #SaldosDW dw
    LEFT JOIN Northwind.dbo.[Order Details] od ON dw.OrderID = od.OrderID AND dw.ProductID = od.ProductID
    WHERE od.OrderID IS NULL;

    IF EXISTS (SELECT 1 FROM #Borrados)
    BEGIN
        INSERT INTO dbo.Fact_Ventas (
            SK_Producto, SK_Cliente, SK_Empleado, SK_Tiempo, SK_Transportista, OrderID, PrecioUnitario, Cantidad, Descuento, MontoVenta, FleteProrrateado, TipoTransaccion
        )
        SELECT 
            SK_Producto, SK_Cliente, SK_Empleado, SK_Tiempo, SK_Transportista, OrderID, PrecioUnitario, -CantidadNeta, Descuento, -MontoVentaNeto, -FleteNeto, 'Reverso por Borrado'
        FROM #Borrados;
        
        PRINT 'Fact_Ventas: Borrados reconciliados exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'Fact_Ventas: No se detectaron ventas eliminadas.';
    END

    DROP TABLE #SaldosDW; DROP TABLE #Borrados;    
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
