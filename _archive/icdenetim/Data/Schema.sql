-- IcDenetim veritabanı şeması (tüm kolonlar İngilizce)
-- Çalıştırma: sqlcmd -S . -d master -i Schema.sql
-- veya SSMS üzerinden master'a bağlanıp çalıştır

USE master;
GO
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'BKMDenetim')
    CREATE DATABASE BKMDenetim;
GO
USE BKMDenetim;
GO

-- Users
IF OBJECT_ID('dbo.Users','U') IS NULL
CREATE TABLE Users (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Email NVARCHAR(256) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(256) NOT NULL,
    FullName NVARCHAR(200) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_Email' AND object_id = OBJECT_ID('dbo.Users'))
CREATE UNIQUE INDEX IX_Users_Email ON Users(Email);
GO

-- AuditItems (master madde listesi)
IF OBJECT_ID('dbo.AuditItems','U') IS NULL
CREATE TABLE AuditItems (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AuditGroup NVARCHAR(50) NOT NULL,
    Area NVARCHAR(100) NOT NULL,
    RiskType NVARCHAR(100) NOT NULL,
    ItemText NVARCHAR(MAX) NOT NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    FindingType NVARCHAR(10) NULL,
    Probability INT NOT NULL DEFAULT 1,
    Impact INT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditItems_AuditGroup' AND object_id = OBJECT_ID('dbo.AuditItems'))
CREATE INDEX IX_AuditItems_AuditGroup ON AuditItems(AuditGroup);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditItems_Area' AND object_id = OBJECT_ID('dbo.AuditItems'))
CREATE INDEX IX_AuditItems_Area ON AuditItems(Area);
GO

-- Audits
IF OBJECT_ID('dbo.Audits','U') IS NULL
CREATE TABLE Audits (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    LocationName NVARCHAR(200) NOT NULL,
    LocationType NVARCHAR(100) NOT NULL,
    AuditDate DATETIME2 NOT NULL,
    ReportDate DATETIME2 NOT NULL,
    ReportNo NVARCHAR(100) NOT NULL,
    AuditorId INT NOT NULL,
    Manager NVARCHAR(200) NULL,
    Directorate NVARCHAR(200) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Audits_Auditor FOREIGN KEY (AuditorId) REFERENCES Users(Id)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Audits_AuditDate' AND object_id = OBJECT_ID('dbo.Audits'))
CREATE INDEX IX_Audits_AuditDate ON Audits(AuditDate);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Audits_LocationName' AND object_id = OBJECT_ID('dbo.Audits'))
CREATE INDEX IX_Audits_LocationName ON Audits(LocationName);
GO

-- AuditResults (madde snapshot - eski denetimler değişmez)
IF OBJECT_ID('dbo.AuditResults','U') IS NULL
CREATE TABLE AuditResults (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AuditId INT NOT NULL,
    AuditItemId INT NOT NULL,
    AuditGroup NVARCHAR(50) NOT NULL,
    Area NVARCHAR(100) NOT NULL,
    RiskType NVARCHAR(100) NOT NULL,
    ItemText NVARCHAR(MAX) NOT NULL,
    SortOrder INT NOT NULL,
    IsPassed BIT NOT NULL,
    FindingType NVARCHAR(10) NULL,
    Probability INT NOT NULL,
    Impact INT NOT NULL,
    RiskScore INT NOT NULL,
    RiskLevel NVARCHAR(50) NULL,
    Remark NVARCHAR(MAX) NULL,
    CONSTRAINT FK_AuditResults_Audit FOREIGN KEY (AuditId) REFERENCES Audits(Id) ON DELETE CASCADE
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditResults_AuditId' AND object_id = OBJECT_ID('dbo.AuditResults'))
CREATE INDEX IX_AuditResults_AuditId ON AuditResults(AuditId);
GO

-- AuditResultPhotos
IF OBJECT_ID('dbo.AuditResultPhotos','U') IS NULL
CREATE TABLE AuditResultPhotos (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AuditResultId INT NOT NULL,
    FilePath NVARCHAR(500) NOT NULL,
    Remark NVARCHAR(500) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_AuditResultPhotos_Result FOREIGN KEY (AuditResultId) REFERENCES AuditResults(Id) ON DELETE CASCADE
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditResultPhotos_AuditResultId' AND object_id = OBJECT_ID('dbo.AuditResultPhotos'))
CREATE INDEX IX_AuditResultPhotos_AuditResultId ON AuditResultPhotos(AuditResultId);
GO

-- AuditItems: Mağaza/Kafe ayrımı - her madde hangi lokasyon tipine ait
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.AuditItems') AND name = 'LocationType')
ALTER TABLE AuditItems ADD LocationType NVARCHAR(20) NOT NULL DEFAULT N'Mağaza';
GO

-- Kesinleştirme alanları: Denetim kesinleştiğinde raporlar otomatik oluşur
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Audits') AND name = 'IsFinalized')
ALTER TABLE Audits ADD IsFinalized BIT NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Audits') AND name = 'FinalizedAt')
ALTER TABLE Audits ADD FinalizedAt DATETIME2 NULL;
GO
