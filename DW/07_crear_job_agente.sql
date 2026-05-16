/*
==========================================================================
  NORTHWIND DATA WAREHOUSE
  Script 07: SQL Server Agent Job — Job_ETL_NorthwindDW
  
  Descripción : Crea un Job en SQL Server Agent que ejecuta el SP 
                 sp_ETL_CargaIncremental cada 1 minuto de forma automática.
  
  NOTA: Requiere permisos de sysadmin o SQLAgentOperatorRole.
        SQL Server Express NO soporta Agent.
==========================================================================
*/

USE msdb;
GO

-- -----------------------------------------------------------------
-- Eliminar Job si ya existe (para re-ejecución idempotente)
-- -----------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Job_ETL_NorthwindDW')
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = N'Job_ETL_NorthwindDW',
        @delete_unused_schedule = 1;
END
GO

-- -----------------------------------------------------------------
-- Crear el Job
-- -----------------------------------------------------------------
DECLARE @jobId BINARY(16);

EXEC msdb.dbo.sp_add_job
    @job_name           = N'Job_ETL_NorthwindDW',
    @enabled            = 1,
    @description        = N'Carga ETL automática del Data Warehouse NorthwindDW. Patrón PULL Incremental: extrae datos del OLTP Northwind cada 1 minuto.',
    @category_name      = N'[Uncategorized (Local)]',
    @owner_login_name   = N'sa',
    @job_id             = @jobId OUTPUT;

PRINT '>> Job creado: Job_ETL_NorthwindDW';

-- -----------------------------------------------------------------
-- Agregar Step 1: Ejecutar el SP de carga
-- -----------------------------------------------------------------
EXEC msdb.dbo.sp_add_jobstep
    @job_id             = @jobId,
    @step_name          = N'Ejecutar_sp_ETL_CargaIncremental',
    @step_id            = 1,
    @subsystem          = N'TSQL',
    @command            = N'EXEC dbo.sp_ETL_CargaIncremental;',
    @database_name      = N'NorthwindDW',
    @on_success_action  = 1,   -- Quit with success
    @on_fail_action     = 2,   -- Quit with failure
    @retry_attempts     = 0,
    @retry_interval     = 0;

PRINT '>> Step agregado: Ejecutar_sp_ETL_CargaIncremental';

-- -----------------------------------------------------------------
-- Agregar Schedule: Cada 1 minuto, 24/7
-- -----------------------------------------------------------------
EXEC msdb.dbo.sp_add_jobschedule
    @job_id                 = @jobId,
    @name                   = N'Schedule_Cada_1_Minuto',
    @enabled                = 1,
    @freq_type              = 4,        -- Diario
    @freq_interval          = 1,        -- Cada 1 día
    @freq_subday_type       = 4,        -- En minutos
    @freq_subday_interval   = 1,        -- Cada 1 minuto
    @active_start_date      = 20260101,
    @active_end_date        = 99991231,
    @active_start_time      = 0,
    @active_end_time        = 235959;

PRINT '>> Schedule agregado: Cada 1 minuto';

-- -----------------------------------------------------------------
-- Asignar el Job al servidor local
-- -----------------------------------------------------------------
EXEC msdb.dbo.sp_add_jobserver
    @job_id         = @jobId,
    @server_name    = N'(LOCAL)';

PRINT '>> Job asignado al servidor local.';
GO
