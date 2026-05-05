CREATE TABLE [dbo].[Dim_Cliente] (
    [SK_Cliente]      INT            IDENTITY (1, 1) NOT NULL,
    [CustomerID]      NCHAR (5)      NOT NULL,
    [NombreCompania]  NVARCHAR (40)  NOT NULL,
    [NombreContacto]  NVARCHAR (30)  NULL,
    [TituloContacto]  NVARCHAR (30)  NULL,
    [Ciudad]          NVARCHAR (15)  NULL,
    [Region]          NVARCHAR (15)  NULL,
    [Pais]            NVARCHAR (15)  NULL,
    [CodigoPostal]    NVARCHAR (10)  NULL,
    CONSTRAINT [PK_Dim_Cliente] PRIMARY KEY CLUSTERED ([SK_Cliente] ASC),
    CONSTRAINT [UQ_Dim_Cliente_NatKey] UNIQUE NONCLUSTERED ([CustomerID] ASC)
);
