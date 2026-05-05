CREATE TABLE [dbo].[Dim_Empleado] (
    [SK_Empleado]       INT            IDENTITY (1, 1) NOT NULL,
    [EmployeeID]        INT            NOT NULL,
    [NombreCompleto]    NVARCHAR (40)  NOT NULL,
    [Titulo]            NVARCHAR (30)  NULL,
    [FechaContratacion] DATETIME       NULL,
    [Ciudad]            NVARCHAR (15)  NULL,
    [Pais]              NVARCHAR (15)  NULL,
    [NombreSupervisor]  NVARCHAR (40)  NULL,
    CONSTRAINT [PK_Dim_Empleado] PRIMARY KEY CLUSTERED ([SK_Empleado] ASC),
    CONSTRAINT [UQ_Dim_Empleado_NatKey] UNIQUE NONCLUSTERED ([EmployeeID] ASC)
);
