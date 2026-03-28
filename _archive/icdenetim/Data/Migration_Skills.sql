-- Skills Engine migration
-- Skill tanımları ve versiyon desteği ekler.
-- Uygulama başlangıcında DbMigration tarafından otomatik çalıştırılır.

-- Skills tablosu
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Skills')
CREATE TABLE Skills (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(50) NOT NULL UNIQUE,
    Name NVARCHAR(200) NOT NULL,
    Department NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- SkillVersions tablosu (versiyon desteği)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SkillVersions')
CREATE TABLE SkillVersions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    SkillId INT NOT NULL,
    VersionNo INT NOT NULL DEFAULT 1,
    EffectiveFrom DATE NOT NULL DEFAULT GETDATE(),
    EffectiveTo DATE NULL,
    RiskRules NVARCHAR(MAX) NULL,
    AiPromptContext NVARCHAR(MAX) NULL,
    CreatedBy INT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_SkillVersions_Skill FOREIGN KEY (SkillId) REFERENCES Skills(Id),
    CONSTRAINT UQ_SkillVersions UNIQUE(SkillId, VersionNo)
);
GO

-- AuditItems: SkillId ekleme (nullable - geriye uyumluluk)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('AuditItems') AND name = 'SkillId')
ALTER TABLE AuditItems ADD SkillId INT NULL;
GO

-- FK ekleme
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_AuditItems_Skill')
ALTER TABLE AuditItems ADD CONSTRAINT FK_AuditItems_Skill FOREIGN KEY (SkillId) REFERENCES Skills(Id);
GO

-- Varsayılan skill seed
IF NOT EXISTS (SELECT 1 FROM Skills WHERE Code = 'MAGAZA')
BEGIN
    INSERT INTO Skills (Code, Name, Department) VALUES ('MAGAZA', N'Mağaza Denetimi', N'Operasyon');

    DECLARE @skillId INT = SCOPE_IDENTITY();
    INSERT INTO SkillVersions (SkillId, VersionNo, EffectiveFrom) VALUES (@skillId, 1, GETDATE());

    UPDATE AuditItems SET SkillId = @skillId WHERE SkillId IS NULL;
END
