-- ============================================================================
-- 61 — Semantik hafizanin onarimi ve genisletilmesi
--
-- ai.SemanticVectors bugune kadar TEK SATIR uretmedi. Uc ayri sebep vardi:
--
--   1. ai.sp_SemanticVector_SourceList, dof.DofKayit tablosunu sorguluyordu.
--      O tablo Turkce->Ingilizce gecisinde dof.Findings olarak yeniden
--      adlandirilmis ama SP guncellenmemis; her cagride "gecersiz nesne adi"
--      ile patliyordu. Rename'in sql/ zincirine hic girmemis olmasinin bir
--      kalintisi daha.
--
--   2. Kaynak yalniz KAPANMIS DOF'lardi. 84 bulgunun 2'si kapali. Iki ornekten
--      ogrenen bir hafiza, hafiza degildir.
--
--   3. Embedding servisi (Ollama) ayakta degildi.
--
-- Bu betik 1 ve 2'yi cozer; 3 icin embedding yerel ONNX'e tasindi.
--
-- Kaynak genisletiliyor: kapanmis DOF hala EN DEGERLI sinyal (sonucu bilinen
-- vaka) ama tek kaynak olamaz. Acik bulgular, denetim sonuclari ve gecmis AI
-- analizleri de hafizaya girer — her biri kendi agirligiyla, boylece "cozulmus
-- vaka" ile "hentai acik bulgu" esit muamele gormez.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

-- ─────────────────────────────────────────────────────
-- 1. Vektorun hangi modelle uretildigi kayda gecer
--    Model degisince eski vektorler yenileriyle KIYASLANAMAZ (farkli boyut,
--    farkli uzay). Bu kolon olmadan karisik vektorler sessizce sacma benzerlik
--    uretir — olcemeyecegimiz bir bozulma.
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ai.SemanticVectors', 'EmbeddingModel') IS NULL
    ALTER TABLE ai.SemanticVectors ADD EmbeddingModel varchar(100) NULL;
GO

IF COL_LENGTH('ai.SemanticVectors', 'Dimensions') IS NULL
    ALTER TABLE ai.SemanticVectors ADD Dimensions int NULL;
GO

IF COL_LENGTH('ai.SemanticVectors', 'UpdatedAt') IS NULL
    ALTER TABLE ai.SemanticVectors ADD UpdatedAt datetime2(0) NULL;
GO

-- Ayni kaynak iki kez vektorlenmesin
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_SemanticVectors_Source' AND object_id = OBJECT_ID('ai.SemanticVectors'))
    CREATE UNIQUE INDEX UQ_SemanticVectors_Source ON ai.SemanticVectors (Source, SourceId);
GO

-- ─────────────────────────────────────────────────────
-- 2. Kaynak listesi — dogru tablolar, genis kapsam
--
-- Agirlik mantigi (Weight): benzerlik skoru bu katsayiyla carpilir.
--   1.00  kapanmis + etkili DOF  — sonucu dogrulanmis vaka, en guvenilir
--   0.85  kapanmis DOF           — sonuclanmis ama etkinligi olculmemis
--   0.60  acik/devam eden DOF    — henuz dogrulanmamis, yine de sinyal
--   0.70  denetim bulgusu        — sahadan gelen gozlem
--   0.50  gecmis AI analizi      — makine urunu, insan onayindan gecmemis
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_SemanticVector_SourceList
    @Top          int         = 200,
    @KaynakTipi   varchar(20) = NULL,   -- NULL = hepsi
    @ModelAdi     varchar(100) = NULL   -- verilirse bu modelle uretilmemisler de listelenir
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH kaynaklar AS
    (
        -- DOF bulgulari
        SELECT
            'DOF'                       AS Source,
            d.DofId                     AS SourceId,
            d.DofId                     AS DofId,
            LEFT(d.Title, 500)          AS Title,
            CONCAT(
                d.Title, N'. ',
                ISNULL(d.Description, N''),
                CASE WHEN d.EffectivenessNote IS NOT NULL
                     THEN N' Etkinlik degerlendirmesi: ' + d.EffectivenessNote ELSE N'' END
            )                           AS SummaryText,
            CAST(CASE WHEN d.RiskLevel >= 4 THEN 1 ELSE 0 END AS bit) AS IsCritical,
            CASE
                WHEN d.Status IN ('CLOSED','KAPANDI') AND d.IsEffective = 1 THEN 1.00
                WHEN d.Status IN ('CLOSED','KAPANDI')                       THEN 0.85
                ELSE 0.60
            END                         AS Weight
        FROM dof.Findings d
        WHERE NULLIF(LTRIM(RTRIM(d.Title)), '') IS NOT NULL

        UNION ALL

        -- Saha denetim sonuclari — denetcinin gozlemi.
        -- ItemText zaten denormalize tutuluyor, AuditItems'a join gerekmiyor.
        SELECT
            'AUDIT',
            r.Id,
            NULL,
            LEFT(ISNULL(NULLIF(r.ItemText, N''), CONCAT(N'Denetim bulgusu #', r.Id)), 500),
            CONCAT(
                ISNULL(r.Area, N''), N' / ', ISNULL(r.RiskType, N''), N'. ',
                ISNULL(r.ItemText, N''), N' ',
                ISNULL(r.Remark, N''),
                CASE WHEN r.RepeatCount > 1
                     THEN CONCAT(N' (bu bulgu ', r.RepeatCount, N' kez tekrarlandi)') ELSE N'' END
            ),
            CAST(CASE WHEN r.RiskLevel IN ('YUKSEK','KRITIK') OR r.IsSystemic = 1 THEN 1 ELSE 0 END AS bit),
            -- Sistemik ve tekrarlayan bulgu daha degerli: bir kereye mahsus
            -- gozlemden cok, surekli bir kontrol zafiyetine isaret ediyor
            CASE WHEN r.IsSystemic = 1 THEN 0.90
                 WHEN r.RepeatCount > 1 THEN 0.80
                 ELSE 0.70 END
        FROM audit.AuditResults r
        WHERE NULLIF(LTRIM(RTRIM(r.Remark)), '') IS NOT NULL
           OR NULLIF(LTRIM(RTRIM(r.ItemText)), '') IS NOT NULL

        UNION ALL

        -- Gecmis AI analizleri — makine urunu, dusuk agirlik
        SELECT
            'AI',
            a.Id,
            NULL,
            LEFT(CONCAT(a.AnalysisType, N' analizi #', a.Id), 500),
            ISNULL(a.Summary, N''),
            CAST(CASE WHEN a.Severity IN ('HIGH','CRITICAL') THEN 1 ELSE 0 END AS bit),
            0.50
        FROM audit.AiAnalyses a
        WHERE NULLIF(LTRIM(RTRIM(a.Summary)), '') IS NOT NULL
    )
    SELECT TOP (@Top)
        k.Source, k.SourceId, k.DofId, k.Title, k.SummaryText, k.IsCritical, k.Weight
    FROM   kaynaklar k
    LEFT JOIN ai.SemanticVectors v
           ON v.Source = k.Source
          AND v.SourceId = k.SourceId
          AND (@ModelAdi IS NULL OR v.EmbeddingModel = @ModelAdi)
    WHERE  v.VectorId IS NULL
      AND  (@KaynakTipi IS NULL OR k.Source = @KaynakTipi)
    ORDER BY k.Weight DESC, k.SourceId DESC;
END
GO

-- ─────────────────────────────────────────────────────
-- 3. Vektor yazimi — model kimligiyle birlikte
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_SemanticVector_Upsert
    @KaynakTipi   varchar(20),
    @KaynakId     bigint,
    @DofId        bigint         = NULL,
    @Baslik       nvarchar(500),
    @OzetMetin    nvarchar(max)  = NULL,
    @Kritik       bit            = 0,
    @VektorJson   nvarchar(max),
    @Agirlik      float          = 1.0,
    @ModelAdi     varchar(100),
    @Boyut        int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        MERGE ai.SemanticVectors AS t
        USING (SELECT @KaynakTipi AS Source, @KaynakId AS SourceId) AS s
           ON t.Source = s.Source AND t.SourceId = s.SourceId
        WHEN MATCHED THEN
            UPDATE SET
                DofId          = @DofId,
                Title          = @Baslik,
                SummaryText    = @OzetMetin,
                IsCritical     = @Kritik,
                VectorJson     = @VektorJson,
                Weight         = @Agirlik,
                EmbeddingModel = @ModelAdi,
                Dimensions     = @Boyut,
                UpdatedAt      = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (Source, SourceId, DofId, Title, SummaryText, IsCritical,
                    VectorJson, Weight, EmbeddingModel, Dimensions, UpdatedAt)
            VALUES (@KaynakTipi, @KaynakId, @DofId, @Baslik, @OzetMetin, @Kritik,
                    @VektorJson, @Agirlik, @ModelAdi, @Boyut, SYSDATETIME());
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ─────────────────────────────────────────────────────
-- 4. Arama listesi — yalniz AYNI modelle uretilmis vektorler
--    Farkli modellerin vektorleri ayni uzayda degildir; karistirmak
--    anlamsiz benzerlik uretir.
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_SemanticVector_ListWeighted
    @ModelAdi varchar(100),
    @Top      int = 500
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        VectorId, Source, SourceId, DofId, Title, SummaryText,
        IsCritical, VectorJson, Weight, Dimensions
    FROM   ai.SemanticVectors
    WHERE  EmbeddingModel = @ModelAdi
      AND  VectorJson IS NOT NULL
    ORDER BY Weight DESC, VectorId DESC;
END
GO

-- ─────────────────────────────────────────────────────
-- 5. Model degisirse eski vektorleri temizleme yardimcisi
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_SemanticVector_PurgeModel
    @ModelAdi varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM ai.SemanticVectors WHERE EmbeddingModel = @ModelAdi;
    SELECT @@ROWCOUNT AS SilinenSatir;
END
GO

PRINT '61_semantic_memory_rebuild uygulandi.';
GO

-- ─────────────────────────────────────────────────────
-- 6. Title genisletmesi
--    Kolon nvarchar(200) idi (sys.columns 400 BAYT gosterir — karakter degil).
--    Denetim madde metinleri bunu asiyor ve kayit "string veya binary data
--    truncated" ile patliyordu. Baslik olarak 500 karakter yeterli.
-- ─────────────────────────────────────────────────────
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('ai.SemanticVectors') AND name = 'Title' AND max_length < 1000)
    ALTER TABLE ai.SemanticVectors ALTER COLUMN Title nvarchar(500) NOT NULL;
GO
