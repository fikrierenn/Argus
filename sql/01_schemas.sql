/* 01_schemas.sql */
USE BKMDenetim;
GO

DECLARE @schemas TABLE (SchemaName sysname);
INSERT INTO @schemas VALUES
(N'src'),(N'ref'),(N'rpt'),(N'dof'),(N'ai'),(N'log'),(N'etl');

DECLARE @s sysname, @sql nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT SchemaName FROM @schemas;
OPEN c;
FETCH NEXT FROM c INTO @s;
WHILE @@FETCH_STATUS=0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=@s)
    BEGIN
        SET @sql = N'CREATE SCHEMA ' + QUOTENAME(@s) + N';';
        EXEC sp_executesql @sql;
    END
    FETCH NEXT FROM c INTO @s;
END
CLOSE c; DEALLOCATE c;
GO
