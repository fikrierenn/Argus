-- ============================================================================
-- 56 — ERP → AI hatti onarimi (plan: 02, Faz 1)
--
-- Hat dort bagimsiz noktadan kirikti ve hic uctan uca calismamisti:
--   1. ai.RuleResults tablosu hic yaratilmamis — AiWorkerService MERGE atiyor,
--      SqlException firlatiyor, catch yakaliyor, kayit ERROR'a dusuyor.
--   2. ai.AnalysisQueue.RuleNote kolonu yok — bir sonraki UPDATE de patlardi.
--   3. ai.sp_Trigger_PostRiskEtl, PeriodCode yazmiyor; kolon NOT NULL ve
--      varsayilani yok -> "Cannot insert NULL" ile patlardi.
--   4. Ayni SP mukerrer kontrolune PeriodCode'u katmiyor. rpt.DailyProductRisk
--      PK'sinda PeriodCode var; ayni mekan+urun+gun icin birden cok periyot
--      satiri mevcut. SELECT DISTINCT bunlari cokertiyor, hangi periyodun risk
--      skorunun kuyruga girdigi rastgele oluyordu.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

-- ─────────────────────────────────────────────────────
-- 1. ai.RuleResults — LM Rules (deterministik katman) ciktisi
--    Kademeli maliyet modelinin ilk basamagi burada kayit altina alinir:
--    hangi kural neden LLM gerektirdi, hangi kanit plani secildi.
--    ai.AnalysisQueue ile 1:1; istek silinirse birlikte silinir.
-- ─────────────────────────────────────────────────────
IF OBJECT_ID('ai.RuleResults', 'U') IS NULL
BEGIN
    CREATE TABLE ai.RuleResults
    (
        RequestId       bigint        NOT NULL CONSTRAINT PK_RuleResults PRIMARY KEY,
        RootCauseClass  varchar(30)   NOT NULL CONSTRAINT DF_RuleResults_RootCauseClass DEFAULT('DIGER'),
        EvidencePlan    varchar(50)   NOT NULL CONSTRAINT DF_RuleResults_EvidencePlan   DEFAULT('BASIC'),
        LlmRequired     bit           NOT NULL CONSTRAINT DF_RuleResults_LlmRequired    DEFAULT(0),
        PriorityScore   int           NOT NULL CONSTRAINT DF_RuleResults_PriorityScore  DEFAULT(0),
        BriefSummary    nvarchar(500) NULL,
        FeatureJson     nvarchar(max) NULL,
        RuleSetVersion  varchar(20)   NOT NULL CONSTRAINT DF_RuleResults_RuleSetVersion DEFAULT('v1'),
        CreatedAt       datetime2(0)  NOT NULL CONSTRAINT DF_RuleResults_CreatedAt      DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)  NOT NULL CONSTRAINT DF_RuleResults_UpdatedAt      DEFAULT(SYSDATETIME()),
        CONSTRAINT FK_RuleResults_AnalysisQueue FOREIGN KEY (RequestId)
            REFERENCES ai.AnalysisQueue (RequestId) ON DELETE CASCADE
    );
END
GO

-- LLM gerektiren istekleri oncelige gore taramak icin
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RuleResults_LlmRequired' AND object_id = OBJECT_ID('ai.RuleResults'))
    CREATE INDEX IX_RuleResults_LlmRequired ON ai.RuleResults (LlmRequired, PriorityScore DESC);
GO

-- ─────────────────────────────────────────────────────
-- 2. ai.AnalysisQueue.RuleNote — semantik hafiza notu
--    LmRules kararini semantik eslesme degistirdiyse gerekcesi buraya yazilir
--    ("Bu risk, gecmisteki ID:42 nolu olaya %91 benziyor").
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ai.AnalysisQueue', 'RuleNote') IS NULL
    ALTER TABLE ai.AnalysisQueue ADD RuleNote nvarchar(1000) NULL;
GO

-- ─────────────────────────────────────────────────────
-- 3. ai.sp_RuleResult_Upsert — LM ciktisini yazar
--    Inline MERGE'un yerini alir (SP-first; architecture.md §2).
--    UPDATE dalinda CreatedAt korunur, yalniz UpdatedAt tazelenir — eski
--    inline MERGE CreatedAt'i her seferinde eziyordu, ilk uretim zamani kayipti.
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_RuleResult_Upsert
    @IstekId          bigint,
    @KokNedenSinifi   varchar(30),
    @KanitPlani       varchar(50),
    @LlmGerekli       bit,
    @OncelikSkoru     int,
    @KisaOzet         nvarchar(500)  = NULL,
    @OzellikJson      nvarchar(max)  = NULL,
    @KuralSetiSurumu  varchar(20)    = 'v1'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: istek yoksa kural sonucu yazilamaz (yetim kayit engeli)
        IF NOT EXISTS (SELECT 1 FROM ai.AnalysisQueue WHERE RequestId = @IstekId)
            THROW 50101, N'Analiz istegi bulunamadi.', 1;

        MERGE ai.RuleResults AS t
        USING (SELECT @IstekId AS RequestId) AS s
           ON t.RequestId = s.RequestId
        WHEN MATCHED THEN
            UPDATE SET
                RootCauseClass = @KokNedenSinifi,
                EvidencePlan   = @KanitPlani,
                LlmRequired    = @LlmGerekli,
                PriorityScore  = @OncelikSkoru,
                BriefSummary   = @KisaOzet,
                FeatureJson    = @OzellikJson,
                RuleSetVersion = @KuralSetiSurumu,
                UpdatedAt      = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (RequestId, RootCauseClass, EvidencePlan, LlmRequired,
                    PriorityScore, BriefSummary, FeatureJson, RuleSetVersion)
            VALUES (@IstekId, @KokNedenSinifi, @KanitPlani, @LlmGerekli,
                    @OncelikSkoru, @KisaOzet, @OzellikJson, @KuralSetiSurumu);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- 4. ai.sp_AnalysisQueue_SetRuleOutcome — LM sonrasi kuyruk durumunu tasir
--    Inline UPDATE'in yerini alir (SP-first).
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_AnalysisQueue_SetRuleOutcome
    @IstekId     bigint,
    @Durum       varchar(20),
    @KanitPlani  nvarchar(1000) = NULL,
    @KuralNotu   nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        UPDATE ai.AnalysisQueue
           SET Status       = @Durum,
               EvidencePlan = @KanitPlani,
               RuleNote     = @KuralNotu,
               UpdatedAt    = SYSDATETIME()
         WHERE RequestId = @IstekId;

        -- Is kurali: eslesme yoksa sessiz gecme — cagiran yanlis id gondermistir
        IF @@ROWCOUNT = 0
            THROW 50102, N'Analiz istegi bulunamadi, durum guncellenemedi.', 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- 5. ai.sp_Trigger_PostRiskEtl — PeriodCode onarimi
--    Onceki surum PeriodCode yazmiyordu (NOT NULL, varsayilani yok -> patlardi)
--    ve mukerrer kontrolune de katmiyordu. Artik periyot bazinda kuyruklanir.
--    Yorumlar Turkce'ye cevrildi (coding-discipline.md).
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_Trigger_PostRiskEtl
    @RiskEsik        int          = 85,
    @PeriyotKodu     varchar(20)  = NULL,  -- NULL = tum periyotlar
    @SnapshotTarih   date         = NULL   -- NULL = bugun; geriye donuk kuyruklama ve test icin
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @Bugun date = ISNULL(@SnapshotTarih, CAST(SYSDATETIME() AS date));

        -- Gunluk risk ETL'i sonrasi, esigi asan urunleri AI analizine kuyrukla.
        -- Mukerrer kontrolu PeriodCode dahil yapilir: ayni mekan+urun+gun icin
        -- her periyot AYRI bir analiz istegidir (rpt.DailyProductRisk PK'si de boyle).
        INSERT INTO ai.AnalysisQueue
            (SnapshotDate, PeriodCode, LocationId, ProductId, SourceType, SourceKey, Priority, Status)
        SELECT
            r.SnapshotDate,
            r.PeriodCode,
            r.LocationId,
            r.ProductId,
            'ETL_TRIGGER',
            CONCAT(r.LocationId, '_', r.ProductId, '_', r.PeriodCode),
            CASE WHEN r.RiskScore >= 90 THEN 90 ELSE 70 END,
            'NEW'
        FROM rpt.DailyProductRisk r
        WHERE r.SnapshotDate = @Bugun
          AND r.RiskScore   >= @RiskEsik
          AND (@PeriyotKodu IS NULL OR r.PeriodCode = @PeriyotKodu)
          AND NOT EXISTS (
                  SELECT 1
                  FROM   ai.AnalysisQueue aq
                  WHERE  aq.SnapshotDate = r.SnapshotDate
                    AND  aq.PeriodCode   = r.PeriodCode
                    AND  aq.LocationId   = r.LocationId
                    AND  aq.ProductId    = r.ProductId
              );

        SELECT @@ROWCOUNT AS QueuedCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '56_ai_pipeline_repair uygulandi.';
GO
