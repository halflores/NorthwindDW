CREATE TABLE [dbo].[Dim_Producto] (
    [SK_Producto]          INT            IDENTITY (1, 1) NOT NULL,
    [ProductID]            INT            NOT NULL,
    [NombreProducto]       NVARCHAR (40)  NOT NULL,
    [NombreCategoria]      NVARCHAR (15)  NULL,
    [DescripcionCategoria] NVARCHAR (MAX) NULL,
    [NombreProveedor]      NVARCHAR (40)  NULL,
    [PaisProveedor]        NVARCHAR (15)  NULL,
    [CantidadPorUnidad]    NVARCHAR (20)  NULL,
    [PrecioUnitario]       MONEY          NULL,
    [Descontinuado]        BIT            NOT NULL DEFAULT 0,
    [Version]              INT            DEFAULT 1 NOT NULL,
    [FechaInicio]          DATETIME       DEFAULT GETDATE() NOT NULL,
    [FechaFin]             DATETIME       NULL,
    [EsActual]             BIT            DEFAULT 1 NOT NULL,
    [Origen_Version]       BINARY(8)      NULL,
    CONSTRAINT [PK_Dim_Producto] PRIMARY KEY CLUSTERED ([SK_Producto] ASC)
);
