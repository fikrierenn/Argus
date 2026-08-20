-- ============================================================================
-- 58 — LLM saglayici kayit defteri (ai.LlmProviders)
--
-- Saglayici zinciri koda gomuluydu: yeni bir AI eklemek LlmService icinde
-- if/else dali, AiWorkerOptions'ta alan ve Program.cs'te named client
-- gerektiriyordu. Prompt'lar zaten ai.Skills'te versiyonlu tutuluyor;
-- saglayicilar da ayni yere tasiniyor. Yeni AI eklemek artik bir satir kayit.
--
-- GUVENLIK: API anahtari BURADA TUTULMAZ. Tablo yalniz anahtarin ADINI tasir
-- (ApiKeyRef, or. 'GLM_API_KEY'); deger ortam degiskeninden veya
-- appsettings.Local.json'dan cozulur. Boylece anahtar ne kaynak kontrolune
-- ne veritabani yedegine ne de yonetim ekranina duser
-- (security-principles.md §5).
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID('ai.LlmProviders', 'U') IS NULL
BEGIN
    CREATE TABLE ai.LlmProviders
    (
        ProviderId      int IDENTITY(1,1) CONSTRAINT PK_LlmProviders PRIMARY KEY,
        Name            varchar(50)   NOT NULL,   -- zincirde/logda gorunen ad
        Kind            varchar(20)   NOT NULL,   -- openai | gemini | claude | ollama
        DisplayName     nvarchar(100) NOT NULL,
        BaseUrl         varchar(300)  NOT NULL,
        RequestPath     varchar(200)  NOT NULL CONSTRAINT DF_LlmProviders_RequestPath  DEFAULT('/v1/chat/completions'),
        ApiKeyRef       varchar(100)  NULL,       -- ANAHTAR ADI; deger asla burada degil
        RequiresApiKey  bit           NOT NULL CONSTRAINT DF_LlmProviders_RequiresKey  DEFAULT(1),
        Model           varchar(100)  NOT NULL,
        FallbackModel   varchar(100)  NULL,
        Priority        int           NOT NULL CONSTRAINT DF_LlmProviders_Priority     DEFAULT(100),
        IsActive        bit           NOT NULL CONSTRAINT DF_LlmProviders_IsActive     DEFAULT(0),
        Notes           nvarchar(500) NULL,
        CreatedAt       datetime2(0)  NOT NULL CONSTRAINT DF_LlmProviders_CreatedAt    DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)  NOT NULL CONSTRAINT DF_LlmProviders_UpdatedAt    DEFAULT(SYSDATETIME()),
        CreatedByUserId int           NULL,
        UpdatedByUserId int           NULL,
        CONSTRAINT UQ_LlmProviders_Name UNIQUE (Name),
        CONSTRAINT CK_LlmProviders_Kind CHECK (Kind IN ('openai','gemini','claude','ollama'))
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LlmProviders_Active' AND object_id = OBJECT_ID('ai.LlmProviders'))
    CREATE INDEX IX_LlmProviders_Active ON ai.LlmProviders (IsActive, Priority);
GO

-- ─────────────────────────────────────────────────────
-- SP: liste (yonetim ekrani ve worker ortak kullanir)
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_List
    @SadeceAktif bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProviderId, Name, Kind, DisplayName, BaseUrl, RequestPath,
           ApiKeyRef, RequiresApiKey, Model, FallbackModel,
           Priority, IsActive, Notes, CreatedAt, UpdatedAt
    FROM   ai.LlmProviders
    WHERE  (@SadeceAktif = 0 OR IsActive = 1)
    ORDER BY IsActive DESC, Priority, Name;
END
GO

CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_Get
    @SaglayiciId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProviderId, Name, Kind, DisplayName, BaseUrl, RequestPath,
           ApiKeyRef, RequiresApiKey, Model, FallbackModel,
           Priority, IsActive, Notes, CreatedAt, UpdatedAt
    FROM   ai.LlmProviders
    WHERE  ProviderId = @SaglayiciId;
END
GO

-- ─────────────────────────────────────────────────────
-- SP: ekle/guncelle
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_Upsert
    @SaglayiciId     int            = NULL,
    @Ad              varchar(50),
    @Tur             varchar(20),
    @GorunenAd       nvarchar(100),
    @TemelAdres      varchar(300),
    @IstekYolu       varchar(200)   = '/v1/chat/completions',
    @AnahtarAdi      varchar(100)   = NULL,
    @AnahtarGerekli  bit            = 1,
    @Model           varchar(100),
    @YedekModel      varchar(100)   = NULL,
    @Oncelik         int            = 100,
    @Aktif           bit            = 0,
    @Not             nvarchar(500)  = NULL,
    @KullaniciId     int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: anahtar gerektiren saglayici anahtar adi olmadan aktif edilemez
        IF @Aktif = 1 AND @AnahtarGerekli = 1 AND NULLIF(LTRIM(RTRIM(@AnahtarAdi)), '') IS NULL
            THROW 50110, N'Anahtar gerektiren saglayici, anahtar adi bos birakilarak aktif edilemez.', 1;

        -- Is kurali: ad benzersiz olmali (zincirde ad ile eslesir)
        IF EXISTS (SELECT 1 FROM ai.LlmProviders
                   WHERE Name = @Ad AND (@SaglayiciId IS NULL OR ProviderId <> @SaglayiciId))
            THROW 50111, N'Bu saglayici adi zaten kullaniliyor.', 1;

        IF @SaglayiciId IS NULL
        BEGIN
            INSERT INTO ai.LlmProviders
                (Name, Kind, DisplayName, BaseUrl, RequestPath, ApiKeyRef, RequiresApiKey,
                 Model, FallbackModel, Priority, IsActive, Notes, CreatedByUserId, UpdatedByUserId)
            VALUES
                (@Ad, @Tur, @GorunenAd, @TemelAdres, @IstekYolu, @AnahtarAdi, @AnahtarGerekli,
                 @Model, @YedekModel, @Oncelik, @Aktif, @Not, @KullaniciId, @KullaniciId);

            SELECT CAST(SCOPE_IDENTITY() AS int) AS ProviderId;
        END
        ELSE
        BEGIN
            UPDATE ai.LlmProviders
               SET Name            = @Ad,
                   Kind            = @Tur,
                   DisplayName     = @GorunenAd,
                   BaseUrl         = @TemelAdres,
                   RequestPath     = @IstekYolu,
                   ApiKeyRef       = @AnahtarAdi,
                   RequiresApiKey  = @AnahtarGerekli,
                   Model           = @Model,
                   FallbackModel   = @YedekModel,
                   Priority        = @Oncelik,
                   IsActive        = @Aktif,
                   Notes           = @Not,
                   UpdatedAt       = SYSDATETIME(),
                   UpdatedByUserId = @KullaniciId
             WHERE ProviderId = @SaglayiciId;

            IF @@ROWCOUNT = 0
                THROW 50112, N'Saglayici bulunamadi.', 1;

            SELECT @SaglayiciId AS ProviderId;
        END
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- SP: aktif/pasif
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_SetActive
    @SaglayiciId int,
    @Aktif       bit,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: anahtar adi tanimsiz saglayici aktif edilemez
        IF @Aktif = 1 AND EXISTS (
                SELECT 1 FROM ai.LlmProviders
                WHERE ProviderId = @SaglayiciId
                  AND RequiresApiKey = 1
                  AND NULLIF(LTRIM(RTRIM(ApiKeyRef)), '') IS NULL)
            THROW 50113, N'Anahtar adi tanimlanmadan saglayici aktif edilemez.', 1;

        UPDATE ai.LlmProviders
           SET IsActive        = @Aktif,
               UpdatedAt       = SYSDATETIME(),
               UpdatedByUserId = @KullaniciId
         WHERE ProviderId = @SaglayiciId;

        IF @@ROWCOUNT = 0
            THROW 50112, N'Saglayici bulunamadi.', 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- Seed — mevcut dort saglayici. Hepsi PASIF baslar; anahtari tanimlanan
-- yonetim ekranindan acilir. Boylece migration tek basina maliyet uretmez.
-- ─────────────────────────────────────────────────────
MERGE ai.LlmProviders AS t
USING (VALUES
    ('gemini',   'gemini', N'Google Gemini',  'https://generativelanguage.googleapis.com', '',                             'GEMINI_API_KEY', 1, 'gemini-2.5-flash',  'gemini-2.5-flash', 10, N'Google AI Studio anahtari.'),
    ('claude',   'claude', N'Anthropic Claude','https://api.anthropic.com',                '/v1/messages',                  'CLAUDE_API_KEY', 1, 'claude-sonnet-4-6', NULL,               20, N'Anthropic Console anahtari.'),
    ('glm',      'openai', N'GLM (Z.AI)',     'https://api.z.ai',                          '/api/paas/v4/chat/completions','GLM_API_KEY',    1, 'glm-4.6',           NULL,               30, N'OpenAI uyumlu uc.'),
    ('ollama',   'ollama', N'Ollama (yerel)', 'http://localhost:11434',                    '/api/generate',                 NULL,             0, 'qwen2.5:7b',        NULL,               90, N'Yerel model, anahtar gerektirmez.')
) AS s (Name, Kind, DisplayName, BaseUrl, RequestPath, ApiKeyRef, RequiresApiKey, Model, FallbackModel, Priority, Notes)
   ON t.Name = s.Name
WHEN NOT MATCHED THEN
    INSERT (Name, Kind, DisplayName, BaseUrl, RequestPath, ApiKeyRef, RequiresApiKey,
            Model, FallbackModel, Priority, IsActive, Notes)
    VALUES (s.Name, s.Kind, s.DisplayName, s.BaseUrl, s.RequestPath, s.ApiKeyRef, s.RequiresApiKey,
            s.Model, s.FallbackModel, s.Priority, 0, s.Notes);
GO

PRINT '58_llm_provider_registry uygulandi.';
GO
