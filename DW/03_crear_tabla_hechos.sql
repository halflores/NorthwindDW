/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 03: Creación de la Tabla de Hechos (Fact_Ventas)
  
  Descripción : Crea la tabla de hechos central del modelo estrella.
                 Granularidad: una fila por cada línea de detalle de orden.
  Motor       : SQL Server 2019+
  Esquema     : dbo
  Autor       : Estudiante — Módulo II, Tarea I
  Fecha       : 2026-05-05
==========================================================================

  MÉTRICAS DISPONIBLES:
  ---------------------
  - MontoVenta   = PrecioUnitario × Cantidad × (1 - Descuento)
  - FleteProrrateado = Freight de la orden prorrateado proporcionalmente
                       al monto de cada línea respecto al subtotal de la orden.
  
  FÓRMULA DEL PRORRATEO DE FLETE:
  --------------------------------
  Para cada línea de detalle (OrderID, ProductID):
  
    FleteProrrateado = Orders.Freight 
                       × ( MontoLineaActual / SubtotalOrden )
  
  Donde:
    MontoLineaActual = UnitPrice × Quantity × (1 - Discount)
    SubtotalOrden    = SUM(UnitPrice × Quantity × (1 - Discount)) 
                       para todas las líneas del mismo OrderID
  
  Esto garantiza que SUM(FleteProrrateado) por OrderID = Orders.Freight
==========================================================================
*/

USE NorthwindDW;
GO

SET NOCOUNT ON;
GO

-- =====================================================================
-- Eliminar tabla si existe
-- =====================================================================
IF OBJECT_ID('dbo.Fact_Ventas', 'U') IS NOT NULL
    DROP TABLE dbo.Fact_Ventas;
GO

-- =====================================================================
-- TABLA DE HECHOS: Fact_Ventas
-- =====================================================================
CREATE TABLE dbo.Fact_Ventas (
    -- Surrogate Key
    FactVentaID             INT IDENTITY(1,1)   NOT NULL,

    -- Foreign Keys a Dimensiones (Surrogate Keys)
    SK_Producto             INT                 NOT NULL,
    SK_Cliente              INT                 NOT NULL,
    SK_Empleado             INT                 NOT NULL,
    SK_Tiempo               INT                 NOT NULL,
    SK_Transportista        INT                 NOT NULL,

    -- Degenerate Dimension (clave de la orden original)
    OrderID                 INT                 NOT NULL,

    -- Medidas / Métricas
    PrecioUnitario          MONEY               NOT NULL,   -- Precio al momento de la venta
    Cantidad                SMALLINT            NOT NULL,   -- Unidades vendidas
    Descuento               REAL                NOT NULL,   -- % descuento (0.00 a 1.00)
    MontoVenta              MONEY               NOT NULL,   -- = PrecioUnitario × Cantidad × (1 - Descuento)
    FleteProrrateado        MONEY               NOT NULL,   -- Flete distribuido proporcionalmente

    -- Constraints
    CONSTRAINT PK_Fact_Ventas PRIMARY KEY CLUSTERED (FactVentaID),

    CONSTRAINT FK_Fact_Producto FOREIGN KEY (SK_Producto)
        REFERENCES dbo.Dim_Producto (SK_Producto),

    CONSTRAINT FK_Fact_Cliente FOREIGN KEY (SK_Cliente)
        REFERENCES dbo.Dim_Cliente (SK_Cliente),

    CONSTRAINT FK_Fact_Empleado FOREIGN KEY (SK_Empleado)
        REFERENCES dbo.Dim_Empleado (SK_Empleado),

    CONSTRAINT FK_Fact_Tiempo FOREIGN KEY (SK_Tiempo)
        REFERENCES dbo.Dim_Tiempo (SK_Tiempo),

    CONSTRAINT FK_Fact_Transportista FOREIGN KEY (SK_Transportista)
        REFERENCES dbo.Dim_Transportista (SK_Transportista)
);
GO

-- =====================================================================
-- ÍNDICES para optimizar consultas analíticas (star join)
-- =====================================================================
CREATE NONCLUSTERED INDEX IX_Fact_Ventas_Producto
    ON dbo.Fact_Ventas (SK_Producto);

CREATE NONCLUSTERED INDEX IX_Fact_Ventas_Cliente
    ON dbo.Fact_Ventas (SK_Cliente);

CREATE NONCLUSTERED INDEX IX_Fact_Ventas_Empleado
    ON dbo.Fact_Ventas (SK_Empleado);

CREATE NONCLUSTERED INDEX IX_Fact_Ventas_Tiempo
    ON dbo.Fact_Ventas (SK_Tiempo);

CREATE NONCLUSTERED INDEX IX_Fact_Ventas_Transportista
    ON dbo.Fact_Ventas (SK_Transportista);

CREATE NONCLUSTERED INDEX IX_Fact_Ventas_OrderID
    ON dbo.Fact_Ventas (OrderID);
GO

PRINT '>> Fact_Ventas creada con índices.';
GO
