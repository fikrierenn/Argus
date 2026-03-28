-- Eksik sütunları ekleyen migration script
-- Uygulama başlangıcında otomatik çalışır; manuel çalıştırmak için:
-- sqlcmd -S . -d IcDenetim -i Data\Migration.sql

USE BKMDenetim;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Audits') AND name = 'IsFinalized')
ALTER TABLE Audits ADD IsFinalized BIT NOT NULL DEFAULT 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Audits') AND name = 'FinalizedAt')
ALTER TABLE Audits ADD FinalizedAt DATETIME2 NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.AuditItems') AND name = 'LocationType')
ALTER TABLE AuditItems ADD LocationType NVARCHAR(20) NOT NULL DEFAULT N'Mağaza';
GO

-- Tüm maddeleri Mağaza yap (Kafe kaldırıldı)
UPDATE AuditItems SET LocationType = N'Mağaza' WHERE LocationType IN (N'Kafe', N'Herİkisi');
GO
