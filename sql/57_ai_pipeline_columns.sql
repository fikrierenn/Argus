-- ============================================================================
-- 57 — AiWorker ↔ canli sema kolon uzlastirmasi (plan: 02, Faz 1)
--
-- AiWorkerService, hicbir zaman var olmamis bir semaya gore yazilmis. Kodun
-- okudugu/yazdigi 9 kolon canli veritabaninda yok; her biri calisma aninda
-- "Gecersiz sutun adi" ile patliyor ve istek ERROR'a dusuyor.
--
-- ai.AnalysisQueue eksikleri:
--   LastRetryAt   — ProcessQueueAsync kuyruk alma UPDATE'i yaziyor
--   ErrorMessage  — MarkErrorAsync yaziyor
--   EvidenceJson  — ProcessLlmQueueAsync okuyor
--
-- ai.LlmResults eksikleri (LLM dali tamamen yazilamaz durumda):
--   PromptVersion, RootCauseHypotheses, VerificationSteps,
--   RecommendedActions, DofDraftJson, ExecutiveSummary
--
-- Ayrica: kod ai.LlmResults'a RequestId uzerinden MERGE atiyor ama RequestId
-- essiz degil (PK = ResultId). Essizlik kisiti olmadan MERGE birden cok satirla
-- eslesip hata verebilir; benzersiz index ekleniyor.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

-- ─────────────────────────────────────────────────────
-- 1. ai.AnalysisQueue eksik kolonlari
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ai.AnalysisQueue', 'LastRetryAt') IS NULL
    ALTER TABLE ai.AnalysisQueue ADD LastRetryAt datetime2(0) NULL;
GO

IF COL_LENGTH('ai.AnalysisQueue', 'ErrorMessage') IS NULL
    ALTER TABLE ai.AnalysisQueue ADD ErrorMessage nvarchar(2000) NULL;
GO

IF COL_LENGTH('ai.AnalysisQueue', 'EvidenceJson') IS NULL
    ALTER TABLE ai.AnalysisQueue ADD EvidenceJson nvarchar(max) NULL;
GO

-- ─────────────────────────────────────────────────────
-- 2. ai.LlmResults eksik kolonlari
--    Not: PromptText / ResultText / TokenCount / DurationMs zaten var ama kod
--    doldurmuyor. TokenCount + DurationMs, AI denetim izinin (TODO G1) tam da
--    istedigi alanlar — ayri adimda baglanacak.
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ai.LlmResults', 'PromptVersion') IS NULL
    ALTER TABLE ai.LlmResults ADD PromptVersion varchar(20) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'RootCauseHypotheses') IS NULL
    ALTER TABLE ai.LlmResults ADD RootCauseHypotheses nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'VerificationSteps') IS NULL
    ALTER TABLE ai.LlmResults ADD VerificationSteps nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'RecommendedActions') IS NULL
    ALTER TABLE ai.LlmResults ADD RecommendedActions nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'DofDraftJson') IS NULL
    ALTER TABLE ai.LlmResults ADD DofDraftJson nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'ExecutiveSummary') IS NULL
    ALTER TABLE ai.LlmResults ADD ExecutiveSummary nvarchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmResults', 'UpdatedAt') IS NULL
    ALTER TABLE ai.LlmResults ADD UpdatedAt datetime2(0) NULL;
GO

-- Istek basina tek LLM sonucu — MERGE'un dogru calismasi icin sart
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_LlmResults_RequestId' AND object_id = OBJECT_ID('ai.LlmResults'))
    CREATE UNIQUE INDEX UQ_LlmResults_RequestId ON ai.LlmResults (RequestId);
GO

-- ─────────────────────────────────────────────────────
-- 3. ai.sp_LlmResult_Upsert — LLM ciktisini yazar
--    Inline MERGE'un yerini alir (SP-first; architecture.md §2).
--    UPDATE dalinda CreatedAt korunur — eski inline MERGE her seferinde eziyordu.
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmResult_Upsert
    @IstekId          bigint,
    @ModelAdi         varchar(100),
    @PromptSurumu     varchar(20)    = 'v1',
    @KokNedenHipotez  nvarchar(max)  = NULL,
    @DogrulamaAdimlari nvarchar(max) = NULL,
    @OnerilenAksiyon  nvarchar(max)  = NULL,
    @DofTaslakJson    nvarchar(max)  = NULL,
    @YoneticiOzeti    nvarchar(max)  = NULL,
    @GuvenSkoru       int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: istek yoksa sonuc yazilamaz (yetim kayit engeli)
        IF NOT EXISTS (SELECT 1 FROM ai.AnalysisQueue WHERE RequestId = @IstekId)
            THROW 50103, N'Analiz istegi bulunamadi.', 1;

        MERGE ai.LlmResults AS t
        USING (SELECT @IstekId AS RequestId) AS s
           ON t.RequestId = s.RequestId
        WHEN MATCHED THEN
            UPDATE SET
                ModelName           = @ModelAdi,
                PromptVersion       = @PromptSurumu,
                RootCauseHypotheses = @KokNedenHipotez,
                VerificationSteps   = @DogrulamaAdimlari,
                RecommendedActions  = @OnerilenAksiyon,
                DofDraftJson        = @DofTaslakJson,
                ExecutiveSummary    = @YoneticiOzeti,
                ConfidenceScore     = @GuvenSkoru,
                UpdatedAt           = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (RequestId, ModelName, PromptVersion, RootCauseHypotheses,
                    VerificationSteps, RecommendedActions, DofDraftJson,
                    ExecutiveSummary, ConfidenceScore)
            VALUES (@IstekId, @ModelAdi, @PromptSurumu, @KokNedenHipotez,
                    @DogrulamaAdimlari, @OnerilenAksiyon, @DofTaslakJson,
                    @YoneticiOzeti, @GuvenSkoru);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- 4. ai.sp_AnalysisQueue_MarkError — istegi hataya dusurur
--    Inline UPDATE'in yerini alir (SP-first).
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_AnalysisQueue_MarkError
    @IstekId     bigint,
    @HataMesaji  nvarchar(2000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        UPDATE ai.AnalysisQueue
           SET Status       = 'ERROR',
               ErrorMessage = @HataMesaji,
               UpdatedAt    = SYSDATETIME()
         WHERE RequestId = @IstekId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '57_ai_pipeline_columns uygulandi.';
GO
