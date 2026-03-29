/*
    31_sps_ai_log_etl_english.sql
    -----------------------------------------------
    Turkish -> English table/column rename migration
    for ai.*, log.*, etl.* stored procedures.

    Rules:
      - Table & column names -> English
      - SP names -> English
      - SP parameter names -> STAY TURKISH (project convention)
      - src.* views -> STAY TURKISH, use aliasing in SP body
      - ref.* tables -> STAY TURKISH (not in rename scope)

    Generated: 2026-03-29
*/

-- =============================================
-- 1) ai.sp_SemanticVector_SourceList
--    (was: ai.sp_Ai_GecmisVektor_KaynakListe)
-- =============================================
IF OBJECT_ID('ai.sp_SemanticVector_SourceList', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_SemanticVector_SourceList;
GO

CREATE PROCEDURE ai.sp_SemanticVector_SourceList
    @Top int = 200
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        d.DofId,
        d.DofImza,
        d.Baslik,
        d.Aciklama,
        d.KaynakAnahtar,
        d.RiskSeviyesi,
        d.Durum
    FROM dof.DofKayit d
    LEFT JOIN ai.SemanticVectors v ON v.SourceId = d.DofId
    WHERE d.Durum = 'KAPANDI'
      AND v.SourceId IS NULL
    ORDER BY d.DofId DESC;
END
GO


-- =============================================
-- 2) ai.sp_SemanticVector_List
--    (was: ai.sp_Ai_GecmisVektor_Liste)
-- =============================================
IF OBJECT_ID('ai.sp_SemanticVector_List', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_SemanticVector_List;
GO

CREATE PROCEDURE ai.sp_SemanticVector_List
    @Top int = 500,
    @KritikMi bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        VectorId,
        SourceId,
        DofId,
        Title,
        SummaryText,
        IsCritical,
        VectorJson
    FROM ai.SemanticVectors
    WHERE (@KritikMi IS NULL OR IsCritical = @KritikMi)
    ORDER BY CreatedAt DESC;
END
GO


-- =============================================
-- 3) ai.sp_SemanticVector_Upsert
--    (was: ai.sp_Ai_GecmisVektor_Upsert)
-- =============================================
IF OBJECT_ID('ai.sp_SemanticVector_Upsert', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_SemanticVector_Upsert;
GO

CREATE PROCEDURE ai.sp_SemanticVector_Upsert
    @RiskId bigint,
    @DofId bigint = NULL,
    @Baslik nvarchar(200) = NULL,
    @OzetMetin nvarchar(500) = NULL,
    @KritikMi bit = 0,
    @VektorJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE ai.SemanticVectors AS t
    USING (SELECT @RiskId AS SourceId) AS s
    ON t.SourceId = s.SourceId
    WHEN MATCHED THEN
        UPDATE SET
            t.DofId = @DofId,
            t.Title = @Baslik,
            t.SummaryText = @OzetMetin,
            t.IsCritical = @KritikMi,
            t.VectorJson = @VektorJson,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (SourceId, DofId, Title, SummaryText, IsCritical, VectorJson, CreatedAt)
        VALUES (@RiskId, @DofId, @Baslik, @OzetMetin, @KritikMi, @VektorJson, SYSDATETIME());
END
GO


-- =============================================
-- 4) ai.sp_AnalysisQueue_Get
--    (was: ai.sp_Ai_Istek_Getir)
-- =============================================
IF OBJECT_ID('ai.sp_AnalysisQueue_Get', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_AnalysisQueue_Get;
GO

CREATE PROCEDURE ai.sp_AnalysisQueue_Get
    @IstekId bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        i.RequestId,
        i.SnapshotDate,
        i.PeriodCode,
        i.LocationId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', i.LocationId)),
        i.ProductId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', i.ProductId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', i.ProductId)),
        RiskScore = r.RiskScore,
        i.Priority,
        i.Status,
        i.EvidencePlan,
        i.EvidenceJson,
        i.RuleNote,
        i.ErrorMessage,
        i.RetryCount,
        i.SonDenemeTarihi,
        i.CreatedAt,
        i.UpdatedAt
    FROM ai.AnalysisQueue i
    LEFT JOIN src.vw_Mekan m ON m.MekanId = i.LocationId
    LEFT JOIN src.vw_Urun u ON u.StokId = i.ProductId
    LEFT JOIN rpt.DailyProductRisk r
        ON r.SnapshotDate = i.SnapshotDate
       AND r.PeriodCode = i.PeriodCode
       AND r.LocationId = i.LocationId
       AND r.ProductId = i.ProductId
    WHERE i.RequestId = @IstekId;
END
GO


-- =============================================
-- 5) ai.sp_AnalysisQueue_List
--    (was: ai.sp_Ai_Istek_Liste)
-- =============================================
IF OBJECT_ID('ai.sp_AnalysisQueue_List', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_AnalysisQueue_List;
GO

CREATE PROCEDURE ai.sp_AnalysisQueue_List
    @Top int = 200,
    @Durum varchar(20) = NULL,
    @Search nvarchar(80) = NULL,
    @KesimBas date = NULL,
    @KesimBit date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SearchTerm nvarchar(80) = NULLIF(LTRIM(RTRIM(@Search)), '');
    DECLARE @Bas date = COALESCE(@KesimBas, '19000101');
    DECLARE @Bit date = COALESCE(@KesimBit, '99991231');

    SELECT TOP (@Top)
        i.RequestId,
        i.SnapshotDate,
        i.PeriodCode,
        i.LocationId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', i.LocationId)),
        i.ProductId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', i.ProductId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', i.ProductId)),
        RiskScore = r.RiskScore,
        i.Priority,
        i.Status,
        i.EvidencePlan,
        i.RuleNote,
        i.ErrorMessage,
        i.RetryCount,
        i.SonDenemeTarihi,
        i.CreatedAt,
        i.UpdatedAt
    FROM ai.AnalysisQueue i
    LEFT JOIN src.vw_Mekan m ON m.MekanId = i.LocationId
    LEFT JOIN src.vw_Urun u ON u.StokId = i.ProductId
    LEFT JOIN rpt.DailyProductRisk r
        ON r.SnapshotDate = i.SnapshotDate
       AND r.PeriodCode = i.PeriodCode
       AND r.LocationId = i.LocationId
       AND r.ProductId = i.ProductId
    WHERE CONVERT(date, i.SnapshotDate) BETWEEN @Bas AND @Bit
      AND (@Durum IS NULL OR i.Status = @Durum)
      AND (
            @SearchTerm IS NULL
            OR CAST(i.LocationId AS varchar(20)) = @SearchTerm
            OR CAST(i.ProductId AS varchar(20)) = @SearchTerm
            OR COALESCE(m.MekanAd, CONCAT('Mekan-', i.LocationId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunAd, CONCAT('Urun-', i.ProductId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunKod, CONCAT('BK-', i.ProductId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(i.SourceKey, '') LIKE '%' + @SearchTerm + '%'
      )
    ORDER BY i.CreatedAt DESC;
END
GO


-- =============================================
-- 6) ai.sp_LlmResults_List
--    (was: ai.sp_Ai_LlmSonuc_Liste)
-- =============================================
IF OBJECT_ID('ai.sp_LlmResults_List', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_LlmResults_List;
GO

CREATE PROCEDURE ai.sp_LlmResults_List
    @Top int = 50,
    @Search nvarchar(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SearchTerm nvarchar(80) = NULLIF(LTRIM(RTRIM(@Search)), '');

    SELECT TOP (@Top)
        l.RequestId,
        l.ModelName,
        l.PromptVersiyon,
        l.YoneticiOzeti,
        l.ConfidenceScore,
        l.CreatedAt,
        i.PeriodCode,
        i.LocationId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', i.LocationId)),
        i.ProductId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', i.ProductId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', i.ProductId)),
        i.Status
    FROM ai.LlmResults l
    INNER JOIN ai.AnalysisQueue i ON i.RequestId = l.RequestId
    LEFT JOIN src.vw_Mekan m ON m.MekanId = i.LocationId
    LEFT JOIN src.vw_Urun u ON u.StokId = i.ProductId
    WHERE (
            @SearchTerm IS NULL
            OR CAST(i.LocationId AS varchar(20)) = @SearchTerm
            OR CAST(i.ProductId AS varchar(20)) = @SearchTerm
            OR COALESCE(m.MekanAd, CONCAT('Mekan-', i.LocationId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunAd, CONCAT('Urun-', i.ProductId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunKod, CONCAT('BK-', i.ProductId)) LIKE '%' + @SearchTerm + '%'
      )
    ORDER BY l.CreatedAt DESC;
END
GO


-- =============================================
-- 7) ai.sp_AnalysisQueue_ResetAndTrigger
--    (was: ai.sp_Ai_Reset_ve_Tetikle)
-- =============================================
IF OBJECT_ID('ai.sp_AnalysisQueue_ResetAndTrigger', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_AnalysisQueue_ResetAndTrigger;
GO

CREATE PROCEDURE ai.sp_AnalysisQueue_ResetAndTrigger
    @Top int = 200,
    @MinSkor int = 80,
    @SilVektor bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM ai.LlmResults;
        DELETE FROM ai.AiLmSonuc;
        DELETE FROM ai.AnalysisQueue;
        IF @SilVektor = 1
            DELETE FROM ai.SemanticVectors;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH

    EXEC ai.sp_AnalysisQueue_Create @Top = @Top, @MinSkor = @MinSkor;
END
GO


-- =============================================
-- 8) ai.sp_RiskSummary_Get
--    (was: ai.sp_Ai_RiskOzet_Getir)
-- =============================================
IF OBJECT_ID('ai.sp_RiskSummary_Get', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_RiskSummary_Get;
GO

CREATE PROCEDURE ai.sp_RiskSummary_Get
    @KesimTarihi datetime2(0),
    @DonemKodu varchar(10),
    @MekanId int,
    @StokId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        r.SnapshotDate,
        r.PeriodCode,
        r.LocationId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', r.LocationId)),
        r.ProductId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', r.ProductId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', r.ProductId)),
        r.RiskScore,
        r.RiskComment,
        r.FlagDataQuality,
        r.FlagSalesWithoutEntry,
        r.FlagDeadStock,
        r.FlagNetAccumulation,
        r.FlagHighReturn,
        r.FlagHighDamagedReturn,
        r.FlagHighCountAdjustment,
        r.FlagHighInternalUse,
        r.FlagFastTurnover,
        r.FlagSalesAging
    FROM rpt.DailyProductRisk r
    LEFT JOIN src.vw_Mekan m ON m.MekanId = r.LocationId
    LEFT JOIN src.vw_Urun u ON u.StokId = r.ProductId
    WHERE r.SnapshotDate = @KesimTarihi
      AND r.PeriodCode = @DonemKodu
      AND r.LocationId = @MekanId
      AND r.ProductId = @StokId;
END
GO


-- =============================================
-- 9) ai.sp_RiskPrediction_Run
--    (was: ai.sp_AiRisk_Predict)
-- =============================================
IF OBJECT_ID('ai.sp_RiskPrediction_Run', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_RiskPrediction_Run;
GO

CREATE PROCEDURE ai.sp_RiskPrediction_Run
    @ModelId int,
    @MekanId int,
    @StokId int = NULL,
    @PredictionHorizon int = 7
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PredictionDate date = CAST(SYSDATETIME() AS date);
    DECLARE @TargetDate date = DATEADD(day, @PredictionHorizon, @PredictionDate);

    -- Simple moving average prediction (placeholder for more sophisticated models)
    WITH HistoricalData AS (
        SELECT
            LocationId, ProductId, SnapshotDay, RiskScore,
            AVG(CAST(RiskScore AS decimal(10,2))) OVER (
                PARTITION BY LocationId, ProductId
                ORDER BY SnapshotDay
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ) as MovingAvg7,
            ROW_NUMBER() OVER (PARTITION BY LocationId, ProductId ORDER BY SnapshotDay DESC) as rn
        FROM rpt.DailyProductRisk
        WHERE LocationId = @MekanId
          AND (@StokId IS NULL OR ProductId = @StokId)
          AND SnapshotDay >= DATEADD(day, -30, @PredictionDate)
    ),
    LatestData AS (
        SELECT LocationId, ProductId, MovingAvg7, RiskScore
        FROM HistoricalData
        WHERE rn = 1
    )
    INSERT INTO ai.RiskPredictions (
        ModelId, MekanId, StokId, RiskType, PredictionDate, TargetDate,
        PredictedValue, ConfidenceScore, PredictionMetadata
    )
    SELECT
        @ModelId, LocationId, ProductId, 'OVERALL_RISK', @PredictionDate, @TargetDate,
        MovingAvg7 as PredictedValue,
        CASE
            WHEN ABS(RiskScore - MovingAvg7) < 5 THEN 0.9
            WHEN ABS(RiskScore - MovingAvg7) < 10 THEN 0.7
            ELSE 0.5
        END as ConfidenceScore,
        '{"method":"moving_average","window":7,"last_actual":' + CAST(RiskScore AS NVARCHAR(50)) + '}' as PredictionMetadata
    FROM LatestData;

    SELECT @@ROWCOUNT as PredictionsCreated;
END
GO


-- =============================================
-- 10) log.sp_DailyProductRisk_Run
--     (was: log.sp_RiskUrunOzet_Calistir)
--     THIS IS THE BIGGEST SP (~16KB)
-- =============================================
IF OBJECT_ID('log.sp_DailyProductRisk_Run', 'P') IS NOT NULL
    DROP PROCEDURE log.sp_DailyProductRisk_Run;
GO

CREATE PROCEDURE log.sp_DailyProductRisk_Run
    @MekanCSV varchar(max) = NULL,
    @ToplamYaz bit = 0  -- MekanId=0 yok; toplam rapor view ile. Bu parametre compatibility icin var.
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @t0 datetime2(0)=SYSDATETIME();
    DECLARE @t1 datetime2(0);
    DECLARE @err nvarchar(4000);
    DECLARE @logId bigint;

    INSERT INTO log.RiskEtlRuns (BaslamaZamani, Durum) VALUES (@t0, 'RUNNING');
    SET @logId = SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @KesimTarihi datetime2(0)=SYSDATETIME();
        DECLARE @KesimGunu date = CONVERT(date, @KesimTarihi);
        DECLARE @Bitis datetime2(0)=DATEADD(day,1,@KesimGunu);

        DECLARE @Son30_Bas date = DATEADD(day,-30,@KesimGunu);
        DECLARE @AyBasi_Bas date = DATEFROMPARTS(YEAR(@KesimGunu), MONTH(@KesimGunu), 1);

        -- parametreler
        DECLARE @IadeOranEsik decimal(9,2) = COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='IadeOranEsik'), 20);
        DECLARE @NetBirikimAdetEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='NetBirikimAdetEsik'), 10);
        DECLARE @IcKullanimTutarEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='IcKullanimTutarEsik'), 1000);
        DECLARE @BozukAdetEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='BozukAdetEsik'), 5);
        DECLARE @SayimDuzeltmeAdetEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='SayimDuzeltmeAdetEsik'), 10);
        DECLARE @HizliDevirOranEsik decimal(9,4)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='HizliDevirOranEsik'), 0.80);
        DECLARE @SatisYaslanmaGunEsik int = COALESCE((SELECT DegerInt FROM ref.RiskParam WHERE ParamKodu='SatisYaslanmaGunEsik'), 90);

        -- Ayni gun ayni donem ayni mekani sil (gunde tek snapshot)
        DELETE r
        FROM rpt.DailyProductRisk r
        JOIN log.tvf_MekanListesi(@MekanCSV) mk ON mk.MekanId=r.LocationId
        WHERE r.SnapshotDay=@KesimGunu;

        -- Insert
        ;WITH Mekan AS (
            SELECT MekanId FROM log.tvf_MekanListesi(@MekanCSV)
        ),
        Kaynak AS (
            SELECT
                h.MekanId, h.StokId, h.HareketTarihi, h.Adet, h.Tutar, h.TipId
            FROM src.vw_StokHareket h
            JOIN Mekan mk ON mk.MekanId=h.MekanId
            WHERE h.AltDepoId=0
              AND h.HareketTarihi < @Bitis
              AND h.HareketTarihi >= @Son30_Bas
        ),
        Mapli AS (
            SELECT
                k.*,
                COALESCE(g.GrupKodu,'DIGER') AS GrupKodu
            FROM Kaynak k
            LEFT JOIN ref.IrsTipGrupMap g ON g.TipId = k.TipId AND g.AktifMi=1
        ),
        Donem AS (
            SELECT DonemKodu='Son30Gun', Baslangic=@Son30_Bas
            UNION ALL
            SELECT 'AyBasi', @AyBasi_Bas
        ),
        Keys AS (
            SELECT d.DonemKodu, d.Baslangic, k.MekanId, k.StokId
            FROM (SELECT DISTINCT MekanId, StokId FROM Mapli) k
            CROSS JOIN Donem d
        ),
        Opening AS (
            SELECT
                k.DonemKodu,
                k.MekanId,
                k.StokId,
                OpeningStok = o.StockQty
            FROM Keys k
            OUTER APPLY (
                SELECT TOP (1) b.StockQty
                FROM rpt.DailyStockBalance b
                WHERE b.LocationId = k.MekanId
                  AND b.ProductId = k.StokId
                  AND b.[Date] < k.Baslangic
                ORDER BY b.[Date] DESC
            ) o
        ),
        Aggr AS (
            SELECT
                KesimTarihi=@KesimTarihi,
                d.DonemKodu,
                m.MekanId,
                m.StokId,

                NetAdet = CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN m.Adet ELSE 0 END) AS decimal(18,3)),
                BrutAdet= CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                NetTutar= CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN m.Tutar ELSE 0 END) AS decimal(18,3)),
                BrutTutar=CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),

                GirisBrutAdet = CAST(SUM(CASE
                    WHEN m.HareketTarihi >= d.Baslangic
                     AND m.Adet > 0
                     AND m.GrupKodu IN ('ALIS','TRANSFER','SAYIM','DUZELTME')
                    THEN m.Adet ELSE 0 END) AS decimal(18,3)),

                AlisBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ALIS' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                SatisBrutAdet= CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SATIS' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                IadeBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='IADE' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                TransferBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                TransferNetAdet  = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN m.Adet ELSE 0 END) AS decimal(18,3)),
                SayimBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SAYIM' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                DuzeltmeBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='DUZELTME' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                IcKullanimBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ICKULLANIM' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                BozukBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='BOZUK' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),

                AlisBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ALIS' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                SatisBrutTutar= CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SATIS' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                IadeBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='IADE' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                TransferBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                TransferNetTutar  = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN m.Tutar ELSE 0 END) AS decimal(18,3)),
                SayimBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SAYIM' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                DuzeltmeBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='DUZELTME' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                IcKullanimBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ICKULLANIM' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                BozukBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='BOZUK' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),

                SonSatisTarihi = MAX(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SATIS' AND m.Adet<0 THEN m.HareketTarihi END),
                AdetSifirTutarVarSatir = SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.Adet=0 AND m.Tutar<>0 THEN 1 ELSE 0 END)
            FROM Mapli m
            CROSS JOIN Donem d
            GROUP BY d.DonemKodu, m.MekanId, m.StokId
        ),
        Hesap AS (
            SELECT
                a.*,
                OpeningStok = COALESCE(o.OpeningStok, 0),
                SatisYasiGun = CASE WHEN a.SonSatisTarihi IS NULL THEN NULL ELSE DATEDIFF(day, CONVERT(date,a.SonSatisTarihi), @KesimGunu) END,
                IadeOraniYuzde = CASE WHEN a.SatisBrutTutar=0 THEN NULL ELSE CAST(a.IadeBrutTutar / NULLIF(a.SatisBrutTutar,0) * 100 AS decimal(9,2)) END,

                FlagVeriKalite       = CONVERT(bit, CASE WHEN a.AdetSifirTutarVarSatir>0 THEN 1 ELSE 0 END),
                FlagGirissizSatis    = CONVERT(bit, CASE
                    WHEN a.SatisBrutAdet>0
                     AND a.GirisBrutAdet=0
                     AND COALESCE(o.OpeningStok, 0) <= 0
                    THEN 1 ELSE 0 END),
                FlagOluStok          = CONVERT(bit, CASE WHEN a.AlisBrutAdet>0 AND a.SatisBrutAdet=0 THEN 1 ELSE 0 END),
                FlagNetBirikim       = CONVERT(bit, CASE WHEN a.NetAdet >= @NetBirikimAdetEsik THEN 1 ELSE 0 END),
                FlagIadeYuksek       = CONVERT(bit, CASE WHEN a.SatisBrutTutar>0 AND (a.IadeBrutTutar / NULLIF(a.SatisBrutTutar,0) * 100) >= @IadeOranEsik THEN 1 ELSE 0 END),
                FlagBozukIadeYuksek  = CONVERT(bit, CASE WHEN a.BozukBrutAdet >= @BozukAdetEsik THEN 1 ELSE 0 END),
                FlagSayimDuzeltmeYuk = CONVERT(bit, CASE WHEN (a.SayimBrutAdet + a.DuzeltmeBrutAdet) >= @SayimDuzeltmeAdetEsik THEN 1 ELSE 0 END),
                FlagSirketIciYuksek  = CONVERT(bit, CASE WHEN a.IcKullanimBrutTutar >= @IcKullanimTutarEsik THEN 1 ELSE 0 END),
                FlagHizliDevir       = CONVERT(bit, CASE WHEN a.AlisBrutAdet>0 AND (a.SatisBrutAdet / NULLIF(a.AlisBrutAdet,0)) >= @HizliDevirOranEsik THEN 1 ELSE 0 END),
                FlagSatisYaslanma    = CONVERT(bit, CASE WHEN a.SonSatisTarihi IS NOT NULL AND DATEDIFF(day, CONVERT(date,a.SonSatisTarihi), @KesimGunu) >= @SatisYaslanmaGunEsik AND a.NetAdet>0 THEN 1 ELSE 0 END)
            FROM Aggr a
            LEFT JOIN Opening o ON o.DonemKodu = a.DonemKodu AND o.MekanId = a.MekanId AND o.StokId = a.StokId
        ),
        Skor AS (
            SELECT
                h.*,
                RiskSkor = (
                    SELECT SUM(w.Puan)
                    FROM ref.RiskSkorAgirlik w
                    WHERE w.AktifMi=1 AND (
                        (w.FlagKodu='FlagVeriKalite'       AND h.FlagVeriKalite=1) OR
                        (w.FlagKodu='FlagGirissizSatis'    AND h.FlagGirissizSatis=1) OR
                        (w.FlagKodu='FlagOluStok'          AND h.FlagOluStok=1) OR
                        (w.FlagKodu='FlagNetBirikim'       AND h.FlagNetBirikim=1) OR
                        (w.FlagKodu='FlagIadeYuksek'       AND h.FlagIadeYuksek=1) OR
                        (w.FlagKodu='FlagBozukIadeYuksek'  AND h.FlagBozukIadeYuksek=1) OR
                        (w.FlagKodu='FlagSayimDuzeltmeYuk' AND h.FlagSayimDuzeltmeYuk=1) OR
                        (w.FlagKodu='FlagSirketIciYuksek'  AND h.FlagSirketIciYuksek=1) OR
                        (w.FlagKodu='FlagHizliDevir'       AND h.FlagHizliDevir=1) OR
                        (w.FlagKodu='FlagSatisYaslanma'    AND h.FlagSatisYaslanma=1)
                    )
                )
            FROM Hesap h
        )
        INSERT INTO rpt.DailyProductRisk
        (
            SnapshotDate, PeriodCode, LocationId, ProductId,
            NetQty, GrossQty, NetAmount, GrossAmount,
            PurchaseGrossQty, SalesGrossQty, ReturnGrossQty, TransferGrossQty, TransferNetQty,
            CountGrossQty, AdjustmentGrossQty, InternalUseGrossQty, DamagedGrossQty,
            PurchaseGrossAmount, SalesGrossAmount, ReturnGrossAmount, TransferGrossAmount, TransferNetAmount,
            CountGrossAmount, AdjustmentGrossAmount, InternalUseGrossAmount, DamagedGrossAmount,
            LastSaleDate, SaleAgeDays, ZeroQtyWithAmountRows, ReturnRatePct,
            FlagDataQuality, FlagSalesWithoutEntry, FlagDeadStock, FlagNetAccumulation, FlagHighReturn,
            FlagHighDamagedReturn, FlagHighCountAdjustment, FlagHighInternalUse, FlagFastTurnover, FlagSalesAging,
            RiskScore, RiskComment
        )
        SELECT
            s.KesimTarihi, s.DonemKodu, s.MekanId, s.StokId,
            s.NetAdet, s.BrutAdet, s.NetTutar, s.BrutTutar,
            s.AlisBrutAdet, s.SatisBrutAdet, s.IadeBrutAdet, s.TransferBrutAdet, s.TransferNetAdet,
            s.SayimBrutAdet, s.DuzeltmeBrutAdet, s.IcKullanimBrutAdet, s.BozukBrutAdet,
            s.AlisBrutTutar, s.SatisBrutTutar, s.IadeBrutTutar, s.TransferBrutTutar, s.TransferNetTutar,
            s.SayimBrutTutar, s.DuzeltmeBrutTutar, s.IcKullanimBrutTutar, s.BozukBrutTutar,
            s.SonSatisTarihi, s.SatisYasiGun, s.AdetSifirTutarVarSatir, s.IadeOraniYuzde,
            s.FlagVeriKalite, s.FlagGirissizSatis, s.FlagOluStok, s.FlagNetBirikim, s.FlagIadeYuksek,
            s.FlagBozukIadeYuksek, s.FlagSayimDuzeltmeYuk, s.FlagSirketIciYuksek, s.FlagHizliDevir, s.FlagSatisYaslanma,
            RiskScore = CASE WHEN s.RiskSkor IS NULL THEN 0 ELSE IIF(s.RiskSkor>100,100,s.RiskSkor) END,
            RiskComment = y.RiskYorum
        FROM Skor s
        OUTER APPLY (
            SELECT RiskYorum = NULLIF(STUFF((
                SELECT TOP (5)
                    ' | ' + t.Metin
                FROM (
                    SELECT w.Oncelik,
                           Metin = CASE w.FlagKodu
                                WHEN 'FlagVeriKalite'       THEN CONCAT(N'VeriKalite: satir=', s.AdetSifirTutarVarSatir)
                                WHEN 'FlagGirissizSatis'    THEN CONCAT(N'GirissizSatis: satis=', s.SatisBrutAdet)
                                WHEN 'FlagOluStok'          THEN CONCAT(N'OluStok: alis=', s.AlisBrutAdet)
                                WHEN 'FlagNetBirikim'       THEN CONCAT(N'NetBirikim: net=', s.NetAdet)
                                WHEN 'FlagIadeYuksek'       THEN CONCAT(N'IadeYuksek: %', COALESCE(CONVERT(varchar(20),s.IadeOraniYuzde),'?'))
                                WHEN 'FlagBozukIadeYuksek'  THEN CONCAT(N'Bozuk: adet=', s.BozukBrutAdet)
                                WHEN 'FlagSayimDuzeltmeYuk' THEN CONCAT(N'Sayim+Duzeltme: adet=', s.SayimBrutAdet + s.DuzeltmeBrutAdet)
                                WHEN 'FlagSirketIciYuksek'  THEN CONCAT(N'IcKullanim: tutar=', s.IcKullanimBrutTutar)
                                WHEN 'FlagHizliDevir'       THEN CONCAT(N'HizliDevir: satis/alis=', CAST(s.SatisBrutAdet/NULLIF(s.AlisBrutAdet,0) AS decimal(9,2)))
                                WHEN 'FlagSatisYaslanma'    THEN CONCAT(N'SatisYaslanma: gun=', COALESCE(CONVERT(varchar(20),s.SatisYasiGun),'?'))
                           END
                    FROM ref.RiskSkorAgirlik w
                    WHERE w.AktifMi=1 AND (
                        (w.FlagKodu='FlagVeriKalite'       AND s.FlagVeriKalite=1) OR
                        (w.FlagKodu='FlagGirissizSatis'    AND s.FlagGirissizSatis=1) OR
                        (w.FlagKodu='FlagOluStok'          AND s.FlagOluStok=1) OR
                        (w.FlagKodu='FlagNetBirikim'       AND s.FlagNetBirikim=1) OR
                        (w.FlagKodu='FlagIadeYuksek'       AND s.FlagIadeYuksek=1) OR
                        (w.FlagKodu='FlagBozukIadeYuksek'  AND s.FlagBozukIadeYuksek=1) OR
                        (w.FlagKodu='FlagSayimDuzeltmeYuk' AND s.FlagSayimDuzeltmeYuk=1) OR
                        (w.FlagKodu='FlagSirketIciYuksek'  AND s.FlagSirketIciYuksek=1) OR
                        (w.FlagKodu='FlagHizliDevir'       AND s.FlagHizliDevir=1) OR
                        (w.FlagKodu='FlagSatisYaslanma'    AND s.FlagSatisYaslanma=1)
                    )
                ) t
                ORDER BY t.Oncelik
                FOR XML PATH(''), TYPE).value('.','nvarchar(max)'), 1, 3, ''), '')
        ) y
        OPTION (RECOMPILE);

        SET @t1 = SYSDATETIME();
        UPDATE log.RiskEtlRuns
        SET BitisZamani=@t1,
            Durum='SUCCESS',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            Hata=NULL
        WHERE LogId=@logId;

    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        SET @t1 = SYSDATETIME();
        UPDATE log.RiskEtlRuns
        SET BitisZamani=@t1,
            Durum='FAIL',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            Hata=@err
        WHERE LogId=@logId;
        THROW;
    END CATCH
END
GO


-- =============================================
-- 11) log.sp_DailyStockBalance_Run
--     (was: log.sp_StokBakiyeGunluk_Calistir)
-- =============================================
IF OBJECT_ID('log.sp_DailyStockBalance_Run', 'P') IS NOT NULL
    DROP PROCEDURE log.sp_DailyStockBalance_Run;
GO

CREATE PROCEDURE log.sp_DailyStockBalance_Run
    @GeriyeDonukGun int = 120,
    @MekanCSV varchar(max) = NULL,
    @BitisTarihi date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @t0 datetime2(0)=SYSDATETIME();
    DECLARE @t1 datetime2(0);
    DECLARE @err nvarchar(4000);
    DECLARE @logId bigint;

    INSERT INTO log.StockEtlRuns (BaslamaZamani, Durum) VALUES (@t0, 'RUNNING');
    SET @logId = SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @Bugun date = CONVERT(date, SYSDATETIME());
        DECLARE @Bitis date = COALESCE(@BitisTarihi, DATEADD(day,-1,@Bugun));
        DECLARE @Baslangic date = DATEADD(day, -ABS(@GeriyeDonukGun), @Bitis);

        ;WITH Mekan AS (SELECT MekanId FROM log.tvf_MekanListesi(@MekanCSV))
        SELECT DISTINCT
            h.MekanId, h.StokId
        INTO #Aktif
        FROM src.vw_StokHareket h
        JOIN Mekan mk ON mk.MekanId=h.MekanId
        WHERE h.AltDepoId=0
          AND h.HareketTarihi >= @Baslangic
          AND h.HareketTarihi <  DATEADD(day,1,@Bitis);

        CREATE UNIQUE CLUSTERED INDEX IX_#Aktif ON #Aktif(MekanId, StokId);

        -- Opening balance (all movements before @Baslangic)
        SELECT
            a.MekanId, a.StokId,
            Opening = CAST(SUM(h.Adet) AS decimal(18,3))
        INTO #Opening
        FROM #Aktif a
        JOIN src.vw_StokHareket h ON h.MekanId=a.MekanId AND h.StokId=a.StokId
        WHERE h.AltDepoId=0
          AND h.HareketTarihi < @Baslangic
        GROUP BY a.MekanId, a.StokId;

        CREATE UNIQUE CLUSTERED INDEX IX_#Opening ON #Opening(MekanId, StokId);

        -- Daily net movement
        SELECT
            h.MekanId, h.StokId,
            Tarih = CONVERT(date, h.HareketTarihi),
            NetHareket = CAST(SUM(h.Adet) AS decimal(18,3))
        INTO #GunlukNet
        FROM src.vw_StokHareket h
        JOIN #Aktif a ON a.MekanId=h.MekanId AND a.StokId=h.StokId
        WHERE h.AltDepoId=0
          AND h.HareketTarihi >= @Baslangic
          AND h.HareketTarihi <  DATEADD(day,1,@Bitis)
        GROUP BY h.MekanId, h.StokId, CONVERT(date, h.HareketTarihi);

        CREATE CLUSTERED INDEX IX_#GunlukNet ON #GunlukNet(MekanId, StokId, Tarih);

        -- Delete-rewrite (window)
        DELETE s
        FROM rpt.DailyStockBalance s
        JOIN log.tvf_MekanListesi(@MekanCSV) mk ON mk.MekanId=s.LocationId
        WHERE s.[Date] BETWEEN @Baslangic AND @Bitis;

        -- Balance = Opening + running sum
        INSERT INTO rpt.DailyStockBalance ([Date], LocationId, ProductId, StockQty)
        SELECT
            g.Tarih,
            g.MekanId,
            g.StokId,
            StockQty = CAST(COALESCE(o.Opening,0)
                           + SUM(g.NetHareket) OVER (PARTITION BY g.MekanId, g.StokId ORDER BY g.Tarih ROWS UNBOUNDED PRECEDING)
                           AS decimal(18,3))
        FROM #GunlukNet g
        LEFT JOIN #Opening o ON o.MekanId=g.MekanId AND o.StokId=g.StokId
        OPTION (RECOMPILE);

        SET @t1 = SYSDATETIME();
        UPDATE log.StockEtlRuns
        SET BitisZamani=@t1,
            Durum='SUCCESS',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            HedefBaslangic=@Baslangic,
            HedefBitis=@Bitis
        WHERE LogId=@logId;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        SET @t1 = SYSDATETIME();
        UPDATE log.StockEtlRuns
        SET BitisZamani=@t1,
            Durum='FAIL',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            Hata=@err
        WHERE LogId=@logId;
        THROW;
    END CATCH
END
GO


-- =============================================
-- 12) log.sp_MonthlyClose_Run
--     (was: log.sp_AylikKapanis_Calistir)
-- =============================================
IF OBJECT_ID('log.sp_MonthlyClose_Run', 'P') IS NOT NULL
    DROP PROCEDURE log.sp_MonthlyClose_Run;
GO

CREATE PROCEDURE log.sp_MonthlyClose_Run
    @DonemAy int = NULL -- YYYYMM. NULL ise gecen ay.
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @KesimTarihi datetime2(0)=SYSDATETIME();
    DECLARE @Bugun date=CONVERT(date,@KesimTarihi);

    IF @DonemAy IS NULL
    BEGIN
        DECLARE @onceki date=DATEADD(month,-1,DATEFROMPARTS(YEAR(@Bugun),MONTH(@Bugun),1));
        SET @DonemAy = YEAR(@onceki)*100 + MONTH(@onceki);
    END

    -- ilgili ayin son snapshot gunu (DailyProductRisk icinden)
    ;WITH r AS (
        SELECT *
        FROM rpt.DailyProductRisk
        WHERE YEAR(SnapshotDay)*100 + MONTH(SnapshotDay) = @DonemAy
    ),
    son AS (
        SELECT MAX(SnapshotDay) AS SonGun FROM r
    )
    INSERT INTO rpt.RiskUrunOzet_Aylik
    (
        DonemAy, DonemKodu, MekanId, StokId, KesimTarihi,
        NetAdet, BrutAdet, NetTutar, BrutTutar, RiskSkor,
        FlagVeriKalite, FlagGirissizSatis, FlagOluStok, FlagNetBirikim, FlagIadeYuksek,
        FlagBozukIadeYuksek, FlagSayimDuzeltmeYuk, FlagSirketIciYuksek, FlagHizliDevir, FlagSatisYaslanma,
        RiskYorum
    )
    SELECT
        DonemAy=@DonemAy,
        r.PeriodCode, r.LocationId, r.ProductId, KesimTarihi=@KesimTarihi,
        r.NetQty, r.GrossQty, r.NetAmount, r.GrossAmount, r.RiskScore,
        r.FlagDataQuality, r.FlagSalesWithoutEntry, r.FlagDeadStock, r.FlagNetAccumulation, r.FlagHighReturn,
        r.FlagHighDamagedReturn, r.FlagHighCountAdjustment, r.FlagHighInternalUse, r.FlagFastTurnover, r.FlagSalesAging,
        r.RiskComment
    FROM r
    CROSS JOIN son
    WHERE r.SnapshotDay = son.SonGun
    AND NOT EXISTS (
        SELECT 1 FROM rpt.RiskUrunOzet_Aylik a
        WHERE a.DonemAy=@DonemAy AND a.DonemKodu=r.PeriodCode AND a.MekanId=r.LocationId AND a.StokId=r.ProductId
    );
END
GO


-- =============================================
-- 13) log.sp_HealthCheck_Run
--     (was: log.sp_SaglikKontrol_Calistir)
-- =============================================
IF OBJECT_ID('log.sp_HealthCheck_Run', 'P') IS NOT NULL
    DROP PROCEDURE log.sp_HealthCheck_Run;
GO

CREATE PROCEDURE log.sp_HealthCheck_Run
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Bugun date = CONVERT(date,SYSDATETIME());
    DECLARE @Dun date = DATEADD(day,-1,@Bugun);

    DECLARE @t TABLE
    (
        KontrolKodu   varchar(60) NOT NULL,
        Seviye        tinyint NOT NULL,              -- 1=kritik,2=orta,3=bilgi
        Durum         varchar(10) NOT NULL,          -- PASS/WARN/FAIL
        Detay         nvarchar(400) NULL,
        SayisalDeger  decimal(18,3) NULL,
        TarihDeger    datetime2(0) NULL
    );

    /* 1) Risk job son durum */
    INSERT INTO @t
    SELECT
        'RISK_JOB_SON',
        1,
        Durum = CASE WHEN x.Durum='SUCCESS' AND x.BitisZamani >= DATEADD(hour,-24,SYSDATETIME()) THEN 'PASS'
                     WHEN x.Durum='SUCCESS' THEN 'WARN'
                     ELSE 'FAIL' END,
        Detay = CONCAT('Durum=',x.Durum,'; Hata=',COALESCE(x.Hata,'')),
        SayisalDeger = x.SureMs,
        TarihDeger = x.BitisZamani
    FROM (
        SELECT TOP 1 Durum, BitisZamani, SureMs, Hata
        FROM log.RiskEtlRuns
        ORDER BY LogId DESC
    ) x;

    /* 2) Stok job son durum */
    INSERT INTO @t
    SELECT
        'STOK_JOB_SON',
        1,
        Durum = CASE WHEN x.Durum='SUCCESS' AND x.BitisZamani >= DATEADD(hour,-24,SYSDATETIME()) THEN 'PASS'
                     WHEN x.Durum='SUCCESS' THEN 'WARN'
                     ELSE 'FAIL' END,
        Detay = CONCAT('Durum=',x.Durum,'; Pencere=',COALESCE(CONVERT(varchar(10),x.HedefBaslangic,120),''),'..',COALESCE(CONVERT(varchar(10),x.HedefBitis,120),''),' ; Hata=',COALESCE(x.Hata,'')),
        SayisalDeger = x.SureMs,
        TarihDeger = x.BitisZamani
    FROM (
        SELECT TOP 1 Durum, BitisZamani, SureMs, HedefBaslangic, HedefBitis, Hata
        FROM log.StockEtlRuns
        ORDER BY LogId DESC
    ) x;

    /* 3) Bugun risk uretildi mi? */
    INSERT INTO @t
    SELECT
        'RISK_BUGUN_VAR_MI',
        1,
        Durum = CASE WHEN c.cnt>0 THEN 'PASS' ELSE 'FAIL' END,
        Detay = CONCAT('SnapshotDay=',CONVERT(varchar(10),@Bugun,120),' ; satir=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (SELECT cnt=COUNT(*) FROM rpt.DailyProductRisk WHERE SnapshotDay=@Bugun AND PeriodCode='Son30Gun') c;

    /* 4) Dun stok bakiyesi var mi? */
    INSERT INTO @t
    SELECT
        'STOK_DUN_VAR_MI',
        1,
        Durum = CASE WHEN mx.MaxTarih>=@Dun THEN 'PASS' ELSE 'WARN' END,
        Detay = CONCAT('MaxDate=',COALESCE(CONVERT(varchar(10),mx.MaxTarih,120),'NULL')),
        SayisalDeger = NULL,
        TarihDeger = CAST(mx.MaxTarih AS datetime2(0))
    FROM (SELECT MaxTarih=MAX([Date]) FROM rpt.DailyStockBalance) mx;

    /* 5) Kaynakta AltDepo!=0 var mi? (son 7 gun) */
    INSERT INTO @t
    SELECT
        'ALTDEPO_SAPMA_7GUN',
        2,
        Durum = CASE WHEN c.cnt=0 THEN 'PASS' ELSE 'WARN' END,
        Detay = CONCAT('AltDepo!=0 satir=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (
        SELECT cnt=COUNT(*)
        FROM src.vw_StokHareket
        WHERE HareketTarihi >= DATEADD(day,-7,CONVERT(date,SYSDATETIME()))
          AND AltDepoId<>0
    ) c;

    /* 6) Tip mapping eksik mi? (son 30 gun) */
    INSERT INTO @t
    SELECT
        'TIP_MAP_EKSIK_30GUN',
        2,
        Durum = CASE WHEN c.cnt=0 THEN 'PASS' ELSE 'WARN' END,
        Detay = CONCAT('Map yok tip adedi=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (
        SELECT cnt=COUNT(DISTINCT h.TipId)
        FROM src.vw_StokHareket h
        LEFT JOIN ref.IrsTipGrupMap m ON m.TipId=h.TipId AND m.AktifMi=1
        WHERE h.HareketTarihi >= DATEADD(day,-30,CONVERT(date,SYSDATETIME()))
          AND m.TipId IS NULL
    ) c;

    /* 7) Unique index ihlali var mi? */
    INSERT INTO @t
    SELECT
        'RISK_DUP_KESIM',
        1,
        Durum = CASE WHEN c.cnt=0 THEN 'PASS' ELSE 'FAIL' END,
        Detay = CONCAT('dup satir=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (
        SELECT cnt=COUNT(*)
        FROM (
            SELECT SnapshotDay, PeriodCode, LocationId, ProductId, n=COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE SnapshotDay=@Bugun
            GROUP BY SnapshotDay, PeriodCode, LocationId, ProductId
            HAVING COUNT(*)>1
        ) d
    ) c;

    SELECT * FROM @t ORDER BY Seviye, CASE Durum WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END, KontrolKodu;
END
GO


-- =============================================
-- 14) etl.sp_StockMovement_Extract
--     (was: etl.sp_ErpStokHareket_Extract)
-- =============================================
IF OBJECT_ID('etl.sp_StockMovement_Extract', 'P') IS NOT NULL
    DROP PROCEDURE etl.sp_StockMovement_Extract;
GO

CREATE PROCEDURE etl.sp_StockMovement_Extract
    @BatchSize int = 10000,
    @LastSyncDate datetime2(0) = NULL,
    @TargetDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @BatchId uniqueidentifier = NEWID();
    DECLARE @ProcessedRecords int = 0;

    BEGIN TRY
        -- Hedef tarih belirleme (varsayilan dun)
        IF @TargetDate IS NULL
            SET @TargetDate = CAST(DATEADD(day, -1, SYSDATETIME()) AS date);

        -- Son senkronizasyon tarihini al
        IF @LastSyncDate IS NULL
        BEGIN
            SELECT @LastSyncDate = ISNULL(LastSyncDate, CAST(DATEADD(day, -7, SYSDATETIME()) AS datetime2(0)))
            FROM etl.SyncStatus
            WHERE TableName = 'src.StokHareket';
        END

        -- Log kaydini baslat
        INSERT INTO etl.EtlRuns (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('StockMovement_Extract', 'EXTRACT', 'CALISIYOR', @StartTime, 'ERP_SYSTEM', 'STAGING',
                CONCAT('Stok hareket verisi cekme baslatildi. Hedef tarih: ', @TargetDate));

        -- ERP'den stok hareket verilerini cek
        INSERT INTO etl.StockMovementStaging (
            ErpHareketNo, ErpStokKodu, MekanKodu, HareketTarihi, HareketTipi,
            GirisMiktar, CikisMiktar, BirimMaliyet, ToplamMaliyet, EtlBatchId, EtlTarihi
        )
        SELECT TOP (@BatchSize)
            CONCAT('ERP-H-', sh.HareketId) as ErpHareketNo,
            s.StokKodu as ErpStokKodu,
            m.MekanKodu,
            CAST(sh.HareketTarihi AS date) as HareketTarihi,
            CASE
                WHEN sh.Adet > 0 THEN 'GIRIS'
                WHEN sh.Adet < 0 THEN 'CIKIS'
                ELSE 'TRANSFER'
            END as HareketTipi,
            CASE WHEN sh.Adet > 0 THEN sh.Adet ELSE NULL END as GirisMiktar,
            CASE WHEN sh.Adet < 0 THEN ABS(sh.Adet) ELSE NULL END as CikisMiktar,
            CASE WHEN sh.Tutar <> 0 AND sh.Adet <> 0 THEN ABS(sh.Tutar / sh.Adet) ELSE 0 END as BirimMaliyet,
            ABS(sh.Tutar) as ToplamMaliyet,
            @BatchId,
            SYSDATETIME()
        FROM src.StokHareket sh
        INNER JOIN ref.Stok s ON s.StokId = sh.StokId
        INNER JOIN ref.Mekan m ON m.MekanId = sh.MekanId
        WHERE CAST(sh.HareketTarihi AS date) = @TargetDate
          AND NOT EXISTS (
              SELECT 1 FROM etl.StockMovementStaging es
              WHERE es.ErpHareketNo = CONCAT('ERP-H-', sh.HareketId)
                AND es.ProcessedFlag = 0
          )
        ORDER BY sh.HareketTarihi, sh.HareketId;

        SET @ProcessedRecords = @@ROWCOUNT;

        -- Senkronizasyon durumunu guncelle
        MERGE etl.SyncStatus AS target
        USING (SELECT 'src.StokHareket' as TableName) AS source
        ON target.TableName = source.TableName
        WHEN MATCHED THEN
            UPDATE SET
                LastSyncDate = SYSDATETIME(),
                LastUpdateDate = @TargetDate,
                RecordsProcessed = @ProcessedRecords,
                Status = 'TAMAMLANDI',
                UpdatedDate = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (TableName, LastSyncDate, LastUpdateDate, RecordsProcessed, Status)
            VALUES (source.TableName, SYSDATETIME(), @TargetDate, @ProcessedRecords, 'TAMAMLANDI');

        -- Log kaydini tamamla
        UPDATE etl.EtlRuns
        SET Status = 'TAMAMLANDI',
            EndTime = SYSDATETIME(),
            RecordsProcessed = @ProcessedRecords,
            Message = CONCAT('Stok hareket verisi cekme tamamlandi. Islenen kayit: ', @ProcessedRecords)
        WHERE JobName = 'StockMovement_Extract'
          AND StartTime = @StartTime;

        SELECT @ProcessedRecords as ProcessedRecords, 'Basarili' as Status;

    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlRuns (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('StockMovement_Extract', 'EXTRACT', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());

        THROW;
    END CATCH
END
GO
