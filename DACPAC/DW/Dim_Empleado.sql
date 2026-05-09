CREATE TABLE [dbo].[Dim_Empleado] (
    [SK_Empleado]       INT            IDENTITY (1, 1) NOT NULL,
    [EmployeeID]        INT            NOT NULL,
    [NombreCompleto]    NVARCHAR (40)  NOT NULL,
    [Titulo]            NVARCHAR (30)  NULL,
    [FechaContratacion] DATETIME       NULL,
    [Ciudad]            NVARCHAR (15)  NULL,
    [Pais]              NVARCHAR (15)  NULL,
    [NombreSupervisor]  NVARCHAR (40)  NULL,
    [Version]           INT            DEFAULT 1 NOT NULL,
    [FechaInicio]       DATETIME       DEFAULT GETDATE() NOT NULL,
    [FechaFin]          DATETIME       NULL,
    [EsActual]          BIT            DEFAULT 1 NOT NULL,
    [Origen_Version]    BINARY(8)      NULL,
    CONSTRAINT [PK_Dim_Empleado] PRIMARY KEY CLUSTERED ([SK_Empleado] ASC)
);
