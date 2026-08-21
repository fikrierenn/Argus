-- ============================================================================
-- 63 — Geri getirme olcum seti (ai.RetrievalEvalSet, ai.RetrievalEvalRuns)
--
-- Neden gerekli: bu oturumda arama uzerinde dort karar verildi (agirligin
-- carpan olmasi, sablon oneki, RRF k'si, reranker) ve her birinde tahmin
-- yanildi, olcum duzeltti. Kalici bir olcum seti olmadan bir sonraki karar
-- yine tahmine dayanir.
--
-- Tasarim: ground truth KAYNAK KAYIT ID'sidir. Bir kayittan sorgu uretilir,
-- dogru cevap o kayittir. Karar deterministik — LLM yargic gerekmez, yanlilik
-- girmez. LLM yalniz sorgu METNINI uretir, dogruluk kararini vermez.
--
-- Beklenti kalibrasyonu: 30 sorgu kucuk bir settir. Bir yapilandirmanin
-- digerinden birkac puan onde cikmasi gurultu olabilir; yalnizca BUYUK farklar
-- (or. 0,767 -> 0,967) guvenle yorumlanmali. Set buyudukce ince farklar da
-- anlam kazanir. Sorgu sayisi her kosumda kaydedilir ki sonuc tek basina
-- degil, dayandigi ornek sayisiyla birlikte okunsun.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

-- ─────────────────────────────────────────────────────
-- Sorgu seti
-- ─────────────────────────────────────────────────────
IF OBJECT_ID('ai.RetrievalEvalSet', 'U') IS NULL
BEGIN
    CREATE TABLE ai.RetrievalEvalSet
    (
        EvalId        int IDENTITY(1,1) CONSTRAINT PK_RetrievalEvalSet PRIMARY KEY,
        QueryText     nvarchar(500) NOT NULL,
        -- Dogru cevap: hangi arsiv kaydi getirilmeliydi
        ExpectSource  varchar(20)   NOT NULL,
        ExpectId      bigint        NOT NULL,
        -- Sorgunun nasil uretildigi: LLM | MANUEL. Elle yazilanlar daha
        -- guvenilirdir cunku uretici modelin kendi yanliligini tasimazlar.
        Origin        varchar(20)   NOT NULL CONSTRAINT DF_EvalSet_Origin DEFAULT('LLM'),
        Notes         nvarchar(500) NULL,
        IsActive      bit           NOT NULL CONSTRAINT DF_EvalSet_IsActive DEFAULT(1),
        CreatedAt     datetime2(0)  NOT NULL CONSTRAINT DF_EvalSet_CreatedAt DEFAULT(SYSDATETIME()),
        CONSTRAINT UQ_RetrievalEvalSet_Query UNIQUE (QueryText)
    );
END
GO

-- ─────────────────────────────────────────────────────
-- Kosum sonuclari — yapilandirmalar arasi karsilastirma buradan okunur
-- ─────────────────────────────────────────────────────
IF OBJECT_ID('ai.RetrievalEvalRuns', 'U') IS NULL
BEGIN
    CREATE TABLE ai.RetrievalEvalRuns
    (
        RunId          int IDENTITY(1,1) CONSTRAINT PK_RetrievalEvalRuns PRIMARY KEY,
        -- Neyin olculdugu: "vector", "bm25", "hybrid", "hybrid+rerank-tr" ...
        Configuration  varchar(100)  NOT NULL,
        EmbeddingModel varchar(100)  NULL,
        RerankerModel  varchar(100)  NULL,
        RrfK           int           NULL,
        QueryCount     int           NOT NULL,
        HitRate1       decimal(5,4)  NOT NULL,
        HitRate3       decimal(5,4)  NOT NULL,
        HitRate5       decimal(5,4)  NOT NULL,
        Mrr10          decimal(5,4)  NOT NULL,
        Recall10       decimal(5,4)  NOT NULL,
        AvgLatencyMs   int           NULL,
        Notes          nvarchar(1000) NULL,
        CreatedAt      datetime2(0)  NOT NULL CONSTRAINT DF_EvalRuns_CreatedAt DEFAULT(SYSDATETIME())
    );
END
GO

-- ─────────────────────────────────────────────────────
-- Sorgu ekleme
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_RetrievalEval_AddQuery
    @SorguMetni    nvarchar(500),
    @BeklenenTip   varchar(20),
    @BeklenenId    bigint,
    @Kaynak        varchar(20)   = 'LLM',
    @Not           nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: beklenen kayit gercekten arsivde olmali, yoksa sorgu
        -- hicbir zaman gecemez ve olcumu sessizce asagi ceker
        IF NOT EXISTS (SELECT 1 FROM ai.SemanticVectors
                       WHERE Source = @BeklenenTip AND SourceId = @BeklenenId)
            THROW 50120, N'Beklenen kayit semantik arsivde bulunamadi.', 1;

        IF EXISTS (SELECT 1 FROM ai.RetrievalEvalSet WHERE QueryText = @SorguMetni)
        BEGIN
            SELECT EvalId FROM ai.RetrievalEvalSet WHERE QueryText = @SorguMetni;
            RETURN;
        END

        INSERT INTO ai.RetrievalEvalSet (QueryText, ExpectSource, ExpectId, Origin, Notes)
        VALUES (@SorguMetni, @BeklenenTip, @BeklenenId, @Kaynak, @Not);

        SELECT CAST(SCOPE_IDENTITY() AS int) AS EvalId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE ai.sp_RetrievalEval_List
    @SadeceAktif bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT EvalId, QueryText, ExpectSource, ExpectId, Origin, Notes
    FROM   ai.RetrievalEvalSet
    WHERE  (@SadeceAktif = 0 OR IsActive = 1)
    ORDER BY EvalId;
END
GO

-- ─────────────────────────────────────────────────────
-- Kosum sonucu kaydi
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_RetrievalEval_SaveRun
    @Yapilandirma  varchar(100),
    @GommeModeli   varchar(100)   = NULL,
    @RerankModeli  varchar(100)   = NULL,
    @RrfK          int            = NULL,
    @SorguSayisi   int,
    @Isabet1       decimal(5,4),
    @Isabet3       decimal(5,4),
    @Isabet5       decimal(5,4),
    @Mrr10         decimal(5,4),
    @Recall10      decimal(5,4),
    @OrtGecikmeMs  int            = NULL,
    @Not           nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO ai.RetrievalEvalRuns
        (Configuration, EmbeddingModel, RerankerModel, RrfK, QueryCount,
         HitRate1, HitRate3, HitRate5, Mrr10, Recall10, AvgLatencyMs, Notes)
    VALUES
        (@Yapilandirma, @GommeModeli, @RerankModeli, @RrfK, @SorguSayisi,
         @Isabet1, @Isabet3, @Isabet5, @Mrr10, @Recall10, @OrtGecikmeMs, @Not);

    SELECT CAST(SCOPE_IDENTITY() AS int) AS RunId;
END
GO

-- ─────────────────────────────────────────────────────
-- Karsilastirma gorunumu — hangi yapilandirma daha iyi
-- ─────────────────────────────────────────────────────
CREATE OR ALTER VIEW ai.vw_RetrievalEvalCompare
AS
SELECT TOP 100 PERCENT
    Configuration, QueryCount, HitRate1, HitRate3, Mrr10, Recall10,
    AvgLatencyMs, RerankerModel, RrfK, CreatedAt
FROM ai.RetrievalEvalRuns
ORDER BY HitRate1 DESC, Mrr10 DESC;
GO

PRINT '63_retrieval_eval uygulandi.';
GO
