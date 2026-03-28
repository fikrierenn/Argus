-- AuditLog tablosu - tüm veri değişikliklerinin izlenmesi
-- DbMigration tarafından otomatik çalıştırılır.

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLog')
CREATE TABLE AuditLog (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NULL,
    Operation NVARCHAR(50) NOT NULL,
    TableName NVARCHAR(100) NOT NULL,
    RecordId INT NOT NULL,
    OldValues NVARCHAR(MAX) NULL,
    NewValues NVARCHAR(MAX) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_AuditLog_Table')
CREATE INDEX IX_AuditLog_Table ON AuditLog(TableName, RecordId);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_AuditLog_Date')
CREATE INDEX IX_AuditLog_Date ON AuditLog(CreatedAt);
