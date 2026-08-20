/* =====================================================================
   51_ai_skill_registry.sql — AI Skill Registry (DB tabanli, versiyonlu)
   Tarih   : 2026-08-20
   Amac    : Prompt template'leri koddan (SkillRegistry.cs) DB'ye tasir.
             Skill versiyonlanir; hangi ciktinin hangi prompt surumuyle
             uretildigi izlenebilir olur.
   Bagimli : 15_ai_enhancement_v2.sql (ai semasi)
   Geri al : DROP PROCEDURE ai.sp_Skill_*; DROP TABLE ai.SkillVersions, ai.Skills;
             (veri kaybi — once yedek al)
   Not     : audit.Skills FARKLI bir tablodur (denetim yetkinlik alanlari).
             AI skill'leri ai.Skills altinda tutulur.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------- 1. ai.Skills ---------- */
IF OBJECT_ID('ai.Skills', 'U') IS NULL
BEGIN
    CREATE TABLE ai.Skills
    (
        SkillId          varchar(60)    NOT NULL,
        Name             nvarchar(200)  NOT NULL,
        Description      nvarchar(1000) NULL,
        Category         varchar(20)    NOT NULL CONSTRAINT DF_AiSkills_Category    DEFAULT('General'),
        TriggerMode      varchar(20)    NOT NULL CONSTRAINT DF_AiSkills_Trigger     DEFAULT('Reactive'),
        OutputType       varchar(20)    NOT NULL CONSTRAINT DF_AiSkills_Output      DEFAULT('Text'),
        RequiredContext  varchar(500)   NULL,
        Temperature      decimal(3,2)   NOT NULL CONSTRAINT DF_AiSkills_Temp        DEFAULT(0.20),
        MaxTokens        int            NOT NULL CONSTRAINT DF_AiSkills_MaxTokens   DEFAULT(2048),
        CurrentVersion   int            NOT NULL CONSTRAINT DF_AiSkills_CurVer      DEFAULT(1),
        IsActive         bit            NOT NULL CONSTRAINT DF_AiSkills_IsActive    DEFAULT(1),
        CreatedAt        datetime2(0)   NOT NULL CONSTRAINT DF_AiSkills_CreatedAt   DEFAULT(SYSDATETIME()),
        UpdatedAt        datetime2(0)   NULL,
        CreatedByUserId  int            NULL,
        UpdatedByUserId  int            NULL,
        CONSTRAINT PK_AiSkills PRIMARY KEY CLUSTERED (SkillId),
        CONSTRAINT CK_AiSkills_Category   CHECK (Category    IN ('Audit','DOF','Risk','Report','General','Semantic')),
        CONSTRAINT CK_AiSkills_Trigger    CHECK (TriggerMode IN ('Reactive','Proactive','Hybrid')),
        CONSTRAINT CK_AiSkills_Output     CHECK (OutputType  IN ('Text','StructuredJson','ActionList','Suggestion'))
    );
END
GO

/* ---------- 2. ai.SkillVersions ---------- */
IF OBJECT_ID('ai.SkillVersions', 'U') IS NULL
BEGIN
    CREATE TABLE ai.SkillVersions
    (
        Id                    int            IDENTITY(1,1) NOT NULL,
        SkillId               varchar(60)    NOT NULL,
        VersionNo             int            NOT NULL,
        SystemPromptTemplate  nvarchar(max)  NOT NULL,
        UserPromptTemplate    nvarchar(max)  NOT NULL,
        ChangeNote            nvarchar(500)  NULL,
        IsActive              bit            NOT NULL CONSTRAINT DF_AiSkillVer_IsActive  DEFAULT(1),
        CreatedAt             datetime2(0)   NOT NULL CONSTRAINT DF_AiSkillVer_CreatedAt DEFAULT(SYSDATETIME()),
        UpdatedAt             datetime2(0)   NULL,
        CreatedByUserId       int            NULL,
        UpdatedByUserId       int            NULL,
        CONSTRAINT PK_AiSkillVersions PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_AiSkillVersions_Skill_Version UNIQUE (SkillId, VersionNo),
        CONSTRAINT FK_AiSkillVersions_Skills FOREIGN KEY (SkillId) REFERENCES ai.Skills(SkillId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_AiSkillVersions_SkillId' AND object_id=OBJECT_ID('ai.SkillVersions'))
    CREATE NONCLUSTERED INDEX IX_AiSkillVersions_SkillId ON ai.SkillVersions(SkillId, VersionNo DESC);
GO

/* ---------- 3. ai.SkillExecutions: hangi prompt surumu kullanildi ---------- */
IF COL_LENGTH('ai.SkillExecutions', 'SkillVersionNo') IS NULL
    ALTER TABLE ai.SkillExecutions ADD SkillVersionNo int NULL;
GO

/* =====================================================================
   SP'ler
   ===================================================================== */

CREATE OR ALTER PROCEDURE ai.sp_Skill_List
    @SadeceAktif bit = 1,
    @Kategori    varchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Aktif surumun prompt'lariyla birlikte skill listesi
        SELECT  s.SkillId, s.Name, s.Description, s.Category, s.TriggerMode, s.OutputType,
                s.RequiredContext, s.Temperature, s.MaxTokens, s.CurrentVersion, s.IsActive,
                v.SystemPromptTemplate, v.UserPromptTemplate
        FROM    ai.Skills s
        LEFT JOIN ai.SkillVersions v
               ON v.SkillId = s.SkillId AND v.VersionNo = s.CurrentVersion
        WHERE  (@SadeceAktif = 0 OR s.IsActive = 1)
          AND  (@Kategori IS NULL OR s.Category = @Kategori)
        ORDER BY s.Category, s.SkillId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ai.sp_Skill_Get
    @SkillId varchar(60)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT  s.SkillId, s.Name, s.Description, s.Category, s.TriggerMode, s.OutputType,
                s.RequiredContext, s.Temperature, s.MaxTokens, s.CurrentVersion, s.IsActive,
                v.SystemPromptTemplate, v.UserPromptTemplate
        FROM    ai.Skills s
        LEFT JOIN ai.SkillVersions v
               ON v.SkillId = s.SkillId AND v.VersionNo = s.CurrentVersion
        WHERE   s.SkillId = @SkillId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ai.sp_Skill_Upsert
    @SkillId         varchar(60),
    @Ad              nvarchar(200),
    @Aciklama        nvarchar(1000) = NULL,
    @Kategori        varchar(20)    = 'General',
    @TetikModu       varchar(20)    = 'Reactive',
    @CiktiTipi       varchar(20)    = 'Text',
    @GerekliBaglam   varchar(500)   = NULL,
    @Sicaklik        decimal(3,2)   = 0.20,
    @MaksToken       int            = 2048,
    @SistemPrompt    nvarchar(max),
    @KullaniciPrompt nvarchar(max),
    @DegisiklikNotu  nvarchar(500)  = NULL,
    @KullaniciId     int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: prompt bos olamaz
        IF LTRIM(RTRIM(ISNULL(@SistemPrompt, ''))) = '' OR LTRIM(RTRIM(ISNULL(@KullaniciPrompt, ''))) = ''
            THROW 50120, N'Sistem ve kullanici prompt sablonlari bos olamaz.', 1;

        DECLARE @YeniVersiyon int = 1;

        IF EXISTS (SELECT 1 FROM ai.Skills WHERE SkillId = @SkillId)
        BEGIN
            -- Prompt gercekten degistiyse yeni surum uret; degismediyse sadece metaveri guncelle
            DECLARE @MevcutSys nvarchar(max), @MevcutUsr nvarchar(max), @MevcutVer int;

            SELECT @MevcutVer = s.CurrentVersion FROM ai.Skills s WHERE s.SkillId = @SkillId;
            SELECT @MevcutSys = v.SystemPromptTemplate, @MevcutUsr = v.UserPromptTemplate
              FROM ai.SkillVersions v WHERE v.SkillId = @SkillId AND v.VersionNo = @MevcutVer;

            IF ISNULL(@MevcutSys, '') = @SistemPrompt AND ISNULL(@MevcutUsr, '') = @KullaniciPrompt
                SET @YeniVersiyon = @MevcutVer;
            ELSE
                SET @YeniVersiyon = @MevcutVer + 1;

            UPDATE ai.Skills
               SET Name = @Ad, Description = @Aciklama, Category = @Kategori,
                   TriggerMode = @TetikModu, OutputType = @CiktiTipi,
                   RequiredContext = @GerekliBaglam, Temperature = @Sicaklik, MaxTokens = @MaksToken,
                   CurrentVersion = @YeniVersiyon, UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE SkillId = @SkillId;
        END
        ELSE
        BEGIN
            INSERT INTO ai.Skills (SkillId, Name, Description, Category, TriggerMode, OutputType,
                                   RequiredContext, Temperature, MaxTokens, CurrentVersion, CreatedByUserId)
            VALUES (@SkillId, @Ad, @Aciklama, @Kategori, @TetikModu, @CiktiTipi,
                    @GerekliBaglam, @Sicaklik, @MaksToken, 1, @KullaniciId);
        END

        -- Surum kaydi (idempotent: ayni surum varsa uzerine yaz)
        IF EXISTS (SELECT 1 FROM ai.SkillVersions WHERE SkillId = @SkillId AND VersionNo = @YeniVersiyon)
            UPDATE ai.SkillVersions
               SET SystemPromptTemplate = @SistemPrompt, UserPromptTemplate = @KullaniciPrompt,
                   ChangeNote = @DegisiklikNotu, UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE SkillId = @SkillId AND VersionNo = @YeniVersiyon;
        ELSE
            INSERT INTO ai.SkillVersions (SkillId, VersionNo, SystemPromptTemplate, UserPromptTemplate, ChangeNote, CreatedByUserId)
            VALUES (@SkillId, @YeniVersiyon, @SistemPrompt, @KullaniciPrompt, @DegisiklikNotu, @KullaniciId);

        COMMIT TRANSACTION;

        SELECT @SkillId AS SkillId, @YeniVersiyon AS VersionNo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ai.sp_Skill_SetActive
    @SkillId     varchar(60),
    @AktifMi     bit,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM ai.Skills WHERE SkillId = @SkillId)
            THROW 50121, N'Skill bulunamadi.', 1;

        UPDATE ai.Skills
           SET IsActive = @AktifMi, UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
         WHERE SkillId = @SkillId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ai.sp_Skill_VersionList
    @SkillId varchar(60)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT v.Id, v.SkillId, v.VersionNo, v.ChangeNote, v.IsActive, v.CreatedAt, v.CreatedByUserId,
               CAST(CASE WHEN v.VersionNo = s.CurrentVersion THEN 1 ELSE 0 END AS bit) AS IsCurrent
        FROM   ai.SkillVersions v
        JOIN   ai.Skills s ON s.SkillId = v.SkillId
        WHERE  v.SkillId = @SkillId
        ORDER BY v.VersionNo DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '51_ai_skill_registry.sql tamamlandi.';
GO
