-- Data Intelligence: Tekrar/sistemik tespit alanları ve indeksler
-- AuditResults tablosuna zeka alanları eklenir.

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('AuditResults') AND name = 'FirstSeenAt')
ALTER TABLE AuditResults ADD FirstSeenAt DATETIME2 NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('AuditResults') AND name = 'LastSeenAt')
ALTER TABLE AuditResults ADD LastSeenAt DATETIME2 NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('AuditResults') AND name = 'RepeatCount')
ALTER TABLE AuditResults ADD RepeatCount INT NOT NULL DEFAULT 0;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('AuditResults') AND name = 'IsSystemic')
ALTER TABLE AuditResults ADD IsSystemic BIT NOT NULL DEFAULT 0;

-- Composite index for repeat detection queries
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_AuditResults_ItemLocation')
CREATE INDEX IX_AuditResults_ItemLocation ON AuditResults(AuditItemId, IsPassed);
