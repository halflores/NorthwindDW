CREATE TABLE [dbo].[Fact_Ventas] (
    [FactVentaID]      INT       IDENTITY (1, 1) NOT NULL,
    [SK_Producto]      INT       NOT NULL,
    [SK_Cliente]       INT       NOT NULL,
    [SK_Empleado]      INT       NOT NULL,
    [SK_Tiempo]        INT       NOT NULL,
    [SK_Transportista] INT       NOT NULL,
    [OrderID]          INT       NOT NULL,
    [PrecioUnitario]   MONEY     NOT NULL,
    [Cantidad]         SMALLINT  NOT NULL,
    [Descuento]        REAL      NOT NULL,
    [MontoVenta]       MONEY         NOT NULL,
    [FleteProrrateado] MONEY         NOT NULL,
    [TipoTransaccion]  NVARCHAR (30) DEFAULT ('Venta Original') NOT NULL,
    CONSTRAINT [PK_Fact_Ventas] PRIMARY KEY CLUSTERED ([FactVentaID] ASC),
    CONSTRAINT [FK_Fact_Producto] FOREIGN KEY ([SK_Producto])
        REFERENCES [dbo].[Dim_Producto] ([SK_Producto]),
    CONSTRAINT [FK_Fact_Cliente] FOREIGN KEY ([SK_Cliente])
        REFERENCES [dbo].[Dim_Cliente] ([SK_Cliente]),
    CONSTRAINT [FK_Fact_Empleado] FOREIGN KEY ([SK_Empleado])
        REFERENCES [dbo].[Dim_Empleado] ([SK_Empleado]),
    CONSTRAINT [FK_Fact_Tiempo] FOREIGN KEY ([SK_Tiempo])
        REFERENCES [dbo].[Dim_Tiempo] ([SK_Tiempo]),
    CONSTRAINT [FK_Fact_Transportista] FOREIGN KEY ([SK_Transportista])
        REFERENCES [dbo].[Dim_Transportista] ([SK_Transportista])
);
