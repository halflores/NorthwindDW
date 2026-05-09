/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 02b: Tabla de Control para Carga Incremental
  
  Descripción : Crea la tabla que guarda el último ROWVERSION procesado
                para cada tabla de origen del OLTP.
==========================================================================
*/

USE NorthwindDW;
GO

IF OBJECT_ID('dbo.Carga_Control', 'U') IS NOT NULL
    DROP TABLE dbo.Carga_Control;
GO

CREATE TABLE dbo.Carga_Control (
    TablaOrigen         NVARCHAR(50)  NOT NULL,
    UltimoRowVersion    BINARY(8)     NOT NULL DEFAULT (0x0000000000000000),
    FechaActualizacion  DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_Carga_Control PRIMARY KEY CLUSTERED (TablaOrigen)
);
GO

-- Inicializamos las tablas con el valor binario cero (para que la 1ra carga traiga todo)
INSERT INTO dbo.Carga_Control (TablaOrigen, UltimoRowVersion)
VALUES 
    ('Products', 0x0000000000000000),
    ('Customers', 0x0000000000000000),
    ('Employees', 0x0000000000000000),
    ('Shippers', 0x0000000000000000),
    ('Orders', 0x0000000000000000);
GO

PRINT '>> Tabla Carga_Control creada e inicializada.';
GO
