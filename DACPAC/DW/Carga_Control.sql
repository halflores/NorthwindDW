CREATE TABLE [dbo].[Carga_Control] (
    [TablaOrigen]         NVARCHAR (50) NOT NULL,
    [UltimoRowVersion]    BINARY (8)    DEFAULT (0x0000000000000000) NOT NULL,
    [FechaActualizacion]  DATETIME      DEFAULT GETDATE() NOT NULL,
    CONSTRAINT [PK_Carga_Control] PRIMARY KEY CLUSTERED ([TablaOrigen] ASC)
);
