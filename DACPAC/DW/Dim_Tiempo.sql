CREATE TABLE [dbo].[Dim_Tiempo] (
    [SK_Tiempo]       INT            NOT NULL,
    [Fecha]           DATE           NOT NULL,
    [Anio]            INT            NOT NULL,
    [Trimestre]       INT            NOT NULL,
    [Mes]             INT            NOT NULL,
    [NombreMes]       NVARCHAR (20)  NOT NULL,
    [Dia]             INT            NOT NULL,
    [DiaSemana]       INT            NOT NULL,
    [NombreDiaSemana] NVARCHAR (20)  NOT NULL,
    [Semana]          INT            NOT NULL,
    CONSTRAINT [PK_Dim_Tiempo] PRIMARY KEY CLUSTERED ([SK_Tiempo] ASC)
);
