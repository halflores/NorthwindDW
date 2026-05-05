/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 04: Poblar Dimensión de Tiempo (Dim_Tiempo)
  
  Descripción : Genera registros de fecha desde 1996-01-01 hasta 1998-12-31.
                 Este rango cubre todas las fechas de órdenes de Northwind.
                 Se usa un bucle WHILE para insertar cada día.
  Motor       : SQL Server 2019+
  Esquema     : dbo
  Autor       : Estudiante — Módulo II, Tarea I
  Fecha       : 2026-05-05
==========================================================================
*/

USE NorthwindDW;
GO

SET NOCOUNT ON;
GO

-- =====================================================================
-- Limpiar datos existentes
-- =====================================================================
DELETE FROM dbo.Dim_Tiempo;
GO

-- =====================================================================
-- Generar fechas con bucle WHILE
-- =====================================================================
DECLARE @FechaInicio DATE = '1996-01-01';
DECLARE @FechaFin    DATE = '1998-12-31';
DECLARE @Fecha       DATE = @FechaInicio;

WHILE @Fecha <= @FechaFin
BEGIN
    INSERT INTO dbo.Dim_Tiempo (
        SK_Tiempo,
        Fecha,
        Anio,
        Trimestre,
        Mes,
        NombreMes,
        Dia,
        DiaSemana,
        NombreDiaSemana,
        Semana
    )
    VALUES (
        -- SK_Tiempo: formato YYYYMMDD como entero
        YEAR(@Fecha) * 10000 + MONTH(@Fecha) * 100 + DAY(@Fecha),

        -- Fecha completa
        @Fecha,

        -- Año
        YEAR(@Fecha),

        -- Trimestre (1-4)
        DATEPART(QUARTER, @Fecha),

        -- Mes (1-12)
        MONTH(@Fecha),

        -- Nombre del mes en español
        CASE MONTH(@Fecha)
            WHEN  1 THEN 'Enero'
            WHEN  2 THEN 'Febrero'
            WHEN  3 THEN 'Marzo'
            WHEN  4 THEN 'Abril'
            WHEN  5 THEN 'Mayo'
            WHEN  6 THEN 'Junio'
            WHEN  7 THEN 'Julio'
            WHEN  8 THEN 'Agosto'
            WHEN  9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre'
            WHEN 11 THEN 'Noviembre'
            WHEN 12 THEN 'Diciembre'
        END,

        -- Día del mes
        DAY(@Fecha),

        -- Día de la semana (1=Domingo, 7=Sábado en SQL Server default)
        DATEPART(WEEKDAY, @Fecha),

        -- Nombre del día en español
        CASE DATEPART(WEEKDAY, @Fecha)
            WHEN 1 THEN 'Domingo'
            WHEN 2 THEN 'Lunes'
            WHEN 3 THEN 'Martes'
            WHEN 4 THEN 'Miércoles'
            WHEN 5 THEN 'Jueves'
            WHEN 6 THEN 'Viernes'
            WHEN 7 THEN 'Sábado'
        END,

        -- Semana del año
        DATEPART(WEEK, @Fecha)
    );

    SET @Fecha = DATEADD(DAY, 1, @Fecha);
END;
GO

-- =====================================================================
-- Verificación
-- =====================================================================
DECLARE @Total INT = (SELECT COUNT(*) FROM dbo.Dim_Tiempo);
PRINT '>> Dim_Tiempo poblada con ' + CAST(@Total AS VARCHAR(10)) + ' registros.';
GO

-- Muestra de datos
SELECT TOP 5 * FROM dbo.Dim_Tiempo ORDER BY SK_Tiempo;
GO
