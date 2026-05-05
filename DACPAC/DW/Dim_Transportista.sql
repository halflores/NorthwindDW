CREATE TABLE [dbo].[Dim_Transportista] (
    [SK_Transportista] INT            IDENTITY (1, 1) NOT NULL,
    [ShipperID]        INT            NOT NULL,
    [NombreCompania]   NVARCHAR (40)  NOT NULL,
    [Telefono]         NVARCHAR (24)  NULL,
    CONSTRAINT [PK_Dim_Transportista] PRIMARY KEY CLUSTERED ([SK_Transportista] ASC),
    CONSTRAINT [UQ_Dim_Transportista_NatKey] UNIQUE NONCLUSTERED ([ShipperID] ASC)
);
