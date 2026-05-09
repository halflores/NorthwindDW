CREATE TABLE [dbo].[Dim_Transportista] (
    [SK_Transportista] INT            IDENTITY (1, 1) NOT NULL,
    [ShipperID]        INT            NOT NULL,
    [NombreCompania]   NVARCHAR (40)  NOT NULL,
    [Telefono]         NVARCHAR (24)  NULL,
    [Version]          INT            DEFAULT 1 NOT NULL,
    [FechaInicio]      DATETIME       DEFAULT GETDATE() NOT NULL,
    [FechaFin]         DATETIME       NULL,
    [EsActual]         BIT            DEFAULT 1 NOT NULL,
    [Origen_Version]   BINARY(8)      NULL,
    CONSTRAINT [PK_Dim_Transportista] PRIMARY KEY CLUSTERED ([SK_Transportista] ASC)
);
