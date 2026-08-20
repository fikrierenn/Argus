-- ============================================================================
-- 60 — Saglayiciya ozel istek parametreleri + LLM sonuc denetim izi
--
-- (A) ExtraBodyJson
-- Her saglayicinin kendine ozel govde parametreleri var:
--   glm-4.7  -> {"thinking":{"type":"disabled"}}      (muhakeme kapatilabilir)
--   glm-5.3  -> {"reasoning_effort":"low"}            (muhakeme kapatilamaz, seviye ayarlanir)
--   diger    -> top_p, presence_penalty, response_format...
-- Bunlari koda gomersek "yeni AI eklemek kod degil veri" ilkesi bozulur.
-- Serbest JSON olarak saklanir ve istek govdesine birlestirilir.
--
-- Gercek olay: glm-4.6, 2048 token'lik butcenin tamamini reasoning_content'e
-- harcayip content'i bos dondurdu. Cozum ya butceyi buyutmek ya muhakemeyi
-- kismak — ikisi de artik saglayici bazinda ayarlanabilir.
--
-- (B) MaxOutputTokens
-- Tek global MaxTokens yetmiyor: muhakeme modeli 16K isterken kucuk bir model
-- 2K ile yetinir. Bos birakilirsa global ayar kullanilir.
--
-- (C) ai.LlmResults denetim izi
-- PromptText NOT NULL'di ve yeni upsert onu doldurmuyordu -> her yazma
-- patliyordu. Ayni sirada TODO G1'in istedigi alanlar da baglaniyor:
-- hangi saglayici, kac token, kac milisaniye.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

-- ─────────────────────────────────────────────────────
-- A + B: saglayici kolonlari
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ai.LlmProviders', 'ExtraBodyJson') IS NULL
    ALTER TABLE ai.LlmProviders ADD ExtraBodyJson nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmProviders', 'MaxOutputTokens') IS NULL
    ALTER TABLE ai.LlmProviders ADD MaxOutputTokens int NULL;
GO

-- Gecersiz JSON zincire girmesin — cagri aninda patlamaktansa kayitta engelle
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_LlmProviders_ExtraBodyJson')
    ALTER TABLE ai.LlmProviders ADD CONSTRAINT CK_LlmProviders_ExtraBodyJson
        CHECK (ExtraBodyJson IS NULL OR ISJSON(ExtraBodyJson) = 1);
GO

-- ─────────────────────────────────────────────────────
-- C: ai.LlmResults — PromptText artik zorunlu degil, denetim izi tamamlanir
-- ─────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('ai.LlmResults') AND name = 'PromptText' AND is_nullable = 0)
    ALTER TABLE ai.LlmResults ALTER COLUMN PromptText nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'ProviderName') IS NULL
    ALTER TABLE ai.LlmResults ADD ProviderName varchar(50) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'FinishReason') IS NULL
    ALTER TABLE ai.LlmResults ADD FinishReason varchar(30) NULL;
GO

-- ─────────────────────────────────────────────────────
-- Liste SP'si yeni kolonlari da dondurur
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_List
    @SadeceAktif bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProviderId, Name, Kind, DisplayName, BaseUrl, RequestPath,
           ApiKeyRef, RequiresApiKey, ApiKeyEncrypted,
           CAST(CASE WHEN NULLIF(ApiKeyEncrypted, '') IS NULL THEN 0 ELSE 1 END AS bit) AS HasStoredKey,
           ApiKeySetAt,
           Model, FallbackModel, MaxOutputTokens, ExtraBodyJson,
           Priority, IsActive, Notes, CreatedAt, UpdatedAt
    FROM   ai.LlmProviders
    WHERE  (@SadeceAktif = 0 OR IsActive = 1)
    ORDER BY IsActive DESC, Priority, Name;
END
GO

-- ─────────────────────────────────────────────────────
-- Upsert: iki yeni alan
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
    @MaksCiktiToken  int            = NULL,
    @EkGovdeJson     nvarchar(max)  = NULL,
    @Oncelik         int            = 100,
    @Aktif           bit            = 0,
    @Not             nvarchar(500)  = NULL,
    @KullaniciId     int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @Aktif = 1 AND @AnahtarGerekli = 1 AND NULLIF(LTRIM(RTRIM(@AnahtarAdi)), '') IS NULL
            THROW 50110, N'Anahtar gerektiren saglayici, anahtar adi bos birakilarak aktif edilemez.', 1;

        IF EXISTS (SELECT 1 FROM ai.LlmProviders
                   WHERE Name = @Ad AND (@SaglayiciId IS NULL OR ProviderId <> @SaglayiciId))
            THROW 50111, N'Bu saglayici adi zaten kullaniliyor.', 1;

        -- Is kurali: bozuk JSON kaydedilmez — cagri aninda degil burada yakalanir
        IF NULLIF(@EkGovdeJson, '') IS NOT NULL AND ISJSON(@EkGovdeJson) = 0
            THROW 50114, N'Ek govde parametreleri gecerli bir JSON degil.', 1;

        IF @SaglayiciId IS NULL
        BEGIN
            INSERT INTO ai.LlmProviders
                (Name, Kind, DisplayName, BaseUrl, RequestPath, ApiKeyRef, RequiresApiKey,
                 Model, FallbackModel, MaxOutputTokens, ExtraBodyJson,
                 Priority, IsActive, Notes, CreatedByUserId, UpdatedByUserId)
            VALUES
                (@Ad, @Tur, @GorunenAd, @TemelAdres, @IstekYolu, @AnahtarAdi, @AnahtarGerekli,
                 @Model, @YedekModel, @MaksCiktiToken, NULLIF(@EkGovdeJson, ''),
                 @Oncelik, @Aktif, @Not, @KullaniciId, @KullaniciId);

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
                   MaxOutputTokens = @MaksCiktiToken,
                   ExtraBodyJson   = NULLIF(@EkGovdeJson, ''),
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
-- LLM sonuc yazimi — denetim izi alanlariyla birlikte
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmResult_Upsert
    @IstekId           bigint,
    @ModelAdi          varchar(100),
    @SaglayiciAdi      varchar(50)    = NULL,
    @PromptSurumu      varchar(20)    = 'v1',
    @PromptMetni       nvarchar(max)  = NULL,
    @SonucMetni        nvarchar(max)  = NULL,
    @KokNedenHipotez   nvarchar(max)  = NULL,
    @DogrulamaAdimlari nvarchar(max)  = NULL,
    @OnerilenAksiyon   nvarchar(max)  = NULL,
    @DofTaslakJson     nvarchar(max)  = NULL,
    @YoneticiOzeti     nvarchar(max)  = NULL,
    @GuvenSkoru        int            = NULL,
    @TokenSayisi       int            = NULL,
    @SureMs            int            = NULL,
    @BitisSebebi       varchar(30)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM ai.AnalysisQueue WHERE RequestId = @IstekId)
            THROW 50103, N'Analiz istegi bulunamadi.', 1;

        MERGE ai.LlmResults AS t
        USING (SELECT @IstekId AS RequestId) AS s
           ON t.RequestId = s.RequestId
        WHEN MATCHED THEN
            UPDATE SET
                ModelName           = @ModelAdi,
                ProviderName        = @SaglayiciAdi,
                PromptVersion       = @PromptSurumu,
                PromptText          = @PromptMetni,
                ResultText          = @SonucMetni,
                RootCauseHypotheses = @KokNedenHipotez,
                VerificationSteps   = @DogrulamaAdimlari,
                RecommendedActions  = @OnerilenAksiyon,
                DofDraftJson        = @DofTaslakJson,
                ExecutiveSummary    = @YoneticiOzeti,
                ConfidenceScore     = @GuvenSkoru,
                TokenCount          = @TokenSayisi,
                DurationMs          = @SureMs,
                FinishReason        = @BitisSebebi,
                UpdatedAt           = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (RequestId, ModelName, ProviderName, PromptVersion, PromptText, ResultText,
                    RootCauseHypotheses, VerificationSteps, RecommendedActions, DofDraftJson,
                    ExecutiveSummary, ConfidenceScore, TokenCount, DurationMs, FinishReason)
            VALUES (@IstekId, @ModelAdi, @SaglayiciAdi, @PromptSurumu, @PromptMetni, @SonucMetni,
                    @KokNedenHipotez, @DogrulamaAdimlari, @OnerilenAksiyon, @DofTaslakJson,
                    @YoneticiOzeti, @GuvenSkoru, @TokenSayisi, @SureMs, @BitisSebebi);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- Seed guncellemesi: glm-4.6 -> glm-4.7, muhakeme kapali
-- glm-4.6 muhakemeye tum token butcesini harciyordu. 4.7'de thinking
-- kapatilabiliyor; yapilandirilmis JSON ciktisi icin dogru secim bu.
-- ─────────────────────────────────────────────────────
UPDATE ai.LlmProviders
   SET Model           = 'glm-4.7',
       FallbackModel   = 'glm-4.6',
       MaxOutputTokens = 8192,
       ExtraBodyJson   = N'{"thinking":{"type":"disabled"}}',
       Notes           = N'OpenAI uyumlu uc. 200K baglam / 128K cikti. Muhakeme kapali — yapilandirilmis JSON icin.',
       UpdatedAt       = SYSDATETIME()
 WHERE Name = 'glm' AND Model = 'glm-4.6';
GO

PRINT '60_llm_provider_extra_body uygulandi.';
GO
