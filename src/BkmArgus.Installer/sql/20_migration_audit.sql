/* 20_migration_audit.sql
   Field Audit (Saha Denetim) schema and tables
   Tables: audit.Skills, audit.SkillVersions,
           audit.AuditItems, audit.Audits,
           audit.AuditResults, audit.AuditResultPhotos
   Seed: ref.KaynakSistem, ref.KaynakNesne, default skill
   Compat: dof.DofKayit effectiveness fields

   Convention: English table/column names + RiskAnaliz patterns
   (datetime2(0), SYSDATETIME(), audit columns, IF OBJECT_ID)
*/
USE BKMDenetim;
GO

/* ===== 1. audit schema ===== */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='audit')
    EXEC('CREATE SCHEMA audit');
GO

/* ===== 2. audit.Skills ===== */

IF OBJECT_ID(N'audit.Skills', N'U') IS NULL
BEGIN
    CREATE TABLE audit.Skills
    (
        Id                      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        Code                    varchar(30)   NOT NULL,
        Name                    nvarchar(100) NOT NULL,
        Department              nvarchar(100) NULL,
        Description             nvarchar(500) NULL,
        IsActive                bit           NOT NULL CONSTRAINT DF_Skills_IsActive DEFAULT(1),
        CreatedByUserId         int           NULL,
        UpdatedByUserId         int           NULL,
        CreatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_Skills_CreatedAt DEFAULT(SYSDATETIME()),
        UpdatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_Skills_UpdatedAt DEFAULT(SYSDATETIME()),

        CONSTRAINT UQ_Skills_Code UNIQUE (Code)
    );
END
GO

/* ===== 3. audit.SkillVersions ===== */

IF OBJECT_ID(N'audit.SkillVersions', N'U') IS NULL
BEGIN
    CREATE TABLE audit.SkillVersions
    (
        Id                      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SkillId                 int           NOT NULL,
        VersionNo               int           NOT NULL,
        IsActive                bit           NOT NULL CONSTRAINT DF_SkillVersions_IsActive DEFAULT(1),
        EffectiveFrom           datetime2(0)  NOT NULL CONSTRAINT DF_SkillVersions_EffFrom DEFAULT(SYSDATETIME()),
        EffectiveTo             datetime2(0)  NULL,
        RiskRules               nvarchar(max) NULL,
        AiPromptContext         nvarchar(max) NULL,
        CreatedByUserId         int           NULL,
        UpdatedByUserId         int           NULL,
        CreatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_SkillVersions_CreatedAt DEFAULT(SYSDATETIME()),
        UpdatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_SkillVersions_UpdatedAt DEFAULT(SYSDATETIME()),

        CONSTRAINT FK_SkillVersions_Skills FOREIGN KEY (SkillId) REFERENCES audit.Skills(Id),
        CONSTRAINT UQ_SkillVersions_SkillVersion UNIQUE (SkillId, VersionNo)
    );
END
GO

/* ===== 4. audit.AuditItems (master checklist) ===== */

IF OBJECT_ID(N'audit.AuditItems', N'U') IS NULL
BEGIN
    CREATE TABLE audit.AuditItems
    (
        Id                      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LocationType            varchar(20)   NOT NULL CONSTRAINT DF_AuditItems_LocType DEFAULT('Both'),
        AuditGroup              nvarchar(100) NOT NULL,
        Area                    nvarchar(100) NOT NULL,
        RiskType                nvarchar(100) NOT NULL,
        ItemText                nvarchar(500) NOT NULL,
        SortOrder               int           NOT NULL,
        FindingType             char(1)       NULL,
        Probability             tinyint       NOT NULL CONSTRAINT DF_AuditItems_Prob DEFAULT(3),
        Impact                  tinyint       NOT NULL CONSTRAINT DF_AuditItems_Impact DEFAULT(3),
        SkillId                 int           NULL,
        IsActive                bit           NOT NULL CONSTRAINT DF_AuditItems_IsActive DEFAULT(1),
        CreatedByUserId         int           NULL,
        UpdatedByUserId         int           NULL,
        CreatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_AuditItems_CreatedAt DEFAULT(SYSDATETIME()),
        UpdatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_AuditItems_UpdatedAt DEFAULT(SYSDATETIME()),

        CONSTRAINT FK_AuditItems_Skills FOREIGN KEY (SkillId) REFERENCES audit.Skills(Id)
    );

    CREATE INDEX IX_AuditItems_Group ON audit.AuditItems (AuditGroup, SortOrder);
END
GO

/* ===== 5. audit.Audits ===== */

IF OBJECT_ID(N'audit.Audits', N'U') IS NULL
BEGIN
    CREATE TABLE audit.Audits
    (
        Id                      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LocationName            nvarchar(100) NOT NULL,
        LocationType            varchar(20)   NOT NULL CONSTRAINT DF_Audits_LocType DEFAULT('Store'),
        LocationId              int           NULL,
        AuditDate               datetime2(0)  NOT NULL,
        ReportDate              datetime2(0)  NOT NULL,
        ReportNo                varchar(30)   NOT NULL,
        AuditorUserId           int           NULL,
        Manager                 nvarchar(100) NULL,
        Directorate             nvarchar(100) NULL,
        IsFinalized             bit           NOT NULL CONSTRAINT DF_Audits_IsFinalized DEFAULT(0),
        FinalizedAt             datetime2(0)  NULL,
        CreatedByUserId         int           NULL,
        UpdatedByUserId         int           NULL,
        CreatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_Audits_CreatedAt DEFAULT(SYSDATETIME()),
        UpdatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_Audits_UpdatedAt DEFAULT(SYSDATETIME())
    );

    CREATE INDEX IX_Audits_LocationDate ON audit.Audits (LocationName, AuditDate);
    CREATE INDEX IX_Audits_FinalizedDate ON audit.Audits (IsFinalized, AuditDate);
END
GO

/* ===== 6. audit.AuditResults (snapshot) ===== */

IF OBJECT_ID(N'audit.AuditResults', N'U') IS NULL
BEGIN
    CREATE TABLE audit.AuditResults
    (
        Id                      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AuditId                 int           NOT NULL,
        AuditItemId             int           NOT NULL,
        AuditGroup              nvarchar(100) NOT NULL,
        Area                    nvarchar(100) NOT NULL,
        RiskType                nvarchar(100) NOT NULL,
        ItemText                nvarchar(500) NOT NULL,
        SortOrder               int           NOT NULL,
        FindingType             char(1)       NULL,
        Probability             tinyint       NOT NULL,
        Impact                  tinyint       NOT NULL,
        RiskScore               AS (CAST(Probability AS int) * CAST(Impact AS int)) PERSISTED,
        RiskLevel               AS (CASE
                                    WHEN CAST(Probability AS int) * CAST(Impact AS int) <= 8 THEN 'Low'
                                    WHEN CAST(Probability AS int) * CAST(Impact AS int) <= 15 THEN 'Medium'
                                    ELSE 'High'
                                    END) PERSISTED,
        IsPassed                bit           NOT NULL CONSTRAINT DF_AuditResults_IsPassed DEFAULT(1),
        Remark                  nvarchar(500) NULL,
        FirstSeenAt             datetime2(0)  NULL,
        LastSeenAt              datetime2(0)  NULL,
        RepeatCount             int           NOT NULL CONSTRAINT DF_AuditResults_RepeatCount DEFAULT(0),
        IsSystemic              bit           NOT NULL CONSTRAINT DF_AuditResults_IsSystemic DEFAULT(0),

        CONSTRAINT FK_AuditResults_Audits FOREIGN KEY (AuditId) REFERENCES audit.Audits(Id) ON DELETE CASCADE,
        CONSTRAINT FK_AuditResults_AuditItems FOREIGN KEY (AuditItemId) REFERENCES audit.AuditItems(Id)
    );

    CREATE INDEX IX_AuditResults_AuditPassed ON audit.AuditResults (AuditId, IsPassed);
    CREATE INDEX IX_AuditResults_ItemPassed ON audit.AuditResults (AuditItemId, IsPassed);
END
GO

/* ===== 7. audit.AuditResultPhotos ===== */

IF OBJECT_ID(N'audit.AuditResultPhotos', N'U') IS NULL
BEGIN
    CREATE TABLE audit.AuditResultPhotos
    (
        Id                      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AuditResultId           int           NOT NULL,
        FilePath                nvarchar(400) NOT NULL,
        Remark                  nvarchar(200) NULL,
        CreatedAt               datetime2(0)  NOT NULL CONSTRAINT DF_AuditResultPhotos_CreatedAt DEFAULT(SYSDATETIME()),

        CONSTRAINT FK_AuditResultPhotos_Results FOREIGN KEY (AuditResultId) REFERENCES audit.AuditResults(Id) ON DELETE CASCADE
    );
END
GO

/* ===== 8. Seed data ===== */

-- ref.KaynakSistem: SAHA_DENETIM
IF OBJECT_ID(N'ref.KaynakSistem', N'U') IS NOT NULL
BEGIN
    MERGE ref.KaynakSistem AS t
    USING (SELECT 'SAHA_DENETIM' AS SistemKodu, N'Saha Denetim Sistemi' AS SistemAdi) AS s
    ON t.SistemKodu = s.SistemKodu
    WHEN NOT MATCHED THEN
        INSERT (SistemKodu, SistemAdi, AktifMi, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (s.SistemKodu, s.SistemAdi, 1, SYSDATETIME(), SYSDATETIME());
END
GO

-- ref.KaynakNesne: DENETIM_BULGU, DENETIM_MADDE
IF OBJECT_ID(N'ref.KaynakNesne', N'U') IS NOT NULL
BEGIN
    MERGE ref.KaynakNesne AS t
    USING (
        SELECT 'DENETIM_BULGU' AS NesneKodu, N'Denetim Bulgusu' AS NesneAdi
        UNION ALL
        SELECT 'DENETIM_MADDE', N'Denetim Maddesi'
    ) AS s ON t.NesneKodu = s.NesneKodu
    WHEN NOT MATCHED THEN
        INSERT (NesneKodu, NesneAdi, AktifMi, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (s.NesneKodu, s.NesneAdi, 1, SYSDATETIME(), SYSDATETIME());
END
GO

-- Default STORE skill
IF NOT EXISTS (SELECT 1 FROM audit.Skills WHERE Code='STORE')
BEGIN
    INSERT INTO audit.Skills (Code, Name, Department, Description, CreatedAt, UpdatedAt)
    VALUES ('STORE', N'Store Audit', N'Operations', N'Standard store audit checklist', SYSDATETIME(), SYSDATETIME());

    DECLARE @skillId int = SCOPE_IDENTITY();

    INSERT INTO audit.SkillVersions (SkillId, VersionNo, EffectiveFrom, RiskRules, AiPromptContext, CreatedAt, UpdatedAt)
    VALUES (@skillId, 1, SYSDATETIME(),
        N'{
  "riskMultipliers": {
    "Cleaning": 1.0,
    "Safety": 1.5,
    "CustomerExperience": 1.2,
    "Inventory": 1.1,
    "Staff": 1.0,
    "VisualStandards": 0.9
  },
  "systemicThreshold": 3,
  "repeatEscalationRate": 0.15,
  "criticalAreas": ["Safety", "OccupationalHealth"]
}',
        N'You are BKMKitap store audit AI assistant.
Your role: Analyze audit findings, detect repeating issues, perform root cause analysis.
Audit areas: Cleaning, Safety, Customer Experience, Inventory, Staff, Visual Standards.
Rules:
- Safety and OHS findings always have priority.
- Perform root cause analysis for repeating issues.
- Suggest structural solutions for systemic issues (3+ locations).
- Provide specific, measurable, time-bound action items for DOFs.
- Respond in Turkish.',
        SYSDATETIME(), SYSDATETIME());

    UPDATE audit.AuditItems SET SkillId = @skillId WHERE SkillId IS NULL;
END
GO

/* ===== 9. dof.DofKayit compatibility ===== */

IF OBJECT_ID(N'dof.DofKayit', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dof.DofKayit') AND name='IsEffective')
        ALTER TABLE dof.DofKayit ADD IsEffective bit NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dof.DofKayit') AND name='EffectivenessScore')
        ALTER TABLE dof.DofKayit ADD EffectivenessScore decimal(5,2) NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dof.DofKayit') AND name='EffectivenessNote')
        ALTER TABLE dof.DofKayit ADD EffectivenessNote nvarchar(500) NULL;
END
GO

PRINT '20_migration_audit.sql completed successfully.';
GO
