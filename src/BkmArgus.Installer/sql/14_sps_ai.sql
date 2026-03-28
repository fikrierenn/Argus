/* 14_sps_ai.sql
   AI istek, risk ozet ve semantik hafiza SP'leri
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'ai.sp_Ai_Istek_Al', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Al;
GO
IF OBJECT_ID(N'ai.sp_Ai_Istek_Olustur', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Olustur;
GO
CREATE PROCEDURE ai.sp_Ai_Istek_Olustur
    @Top int = 200,
    @KesimGunu date = NULL,
    @MinSkor int = 80
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kesim date = COALESCE(@KesimGunu, (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk));
    IF @Kesim IS NULL
        RETURN;

    INSERT INTO ai.AiAnalizIstegi
        (KesimTarihi, DonemKodu, MekanId, StokId, KaynakTip, KaynakAnahtar, Oncelik, Durum)
    SELECT TOP (@Top)
        r.KesimTarihi,
        r.DonemKodu,
        r.MekanId,
        r.StokId,
        'RISK',
        CONCAT('Kesim=', CONVERT(varchar(10), r.KesimGunu, 120),
               '|Donem=', r.DonemKodu,
               '|Mekan=', r.MekanId,
               '|Stok=', r.StokId),
        Oncelik = CASE WHEN r.RiskSkor >= 90 THEN 1 WHEN r.RiskSkor >= 75 THEN 2 ELSE 3 END,
        Durum = 'NEW'
    FROM rpt.RiskUrunOzet_Gunluk r
    WHERE r.KesimGunu = @Kesim
      AND r.RiskSkor >= @MinSkor
      AND NOT EXISTS (
          SELECT 1
          FROM ai.AiAnalizIstegi a
          WHERE a.KesimTarihi = r.KesimTarihi
            AND a.DonemKodu = r.DonemKodu
            AND a.MekanId = r.MekanId
            AND a.StokId = r.StokId
      )
    ORDER BY r.RiskSkor DESC;
END
GO

CREATE PROCEDURE ai.sp_Ai_Istek_Al
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte AS (
        SELECT TOP (@Top) *
        FROM ai.AiAnalizIstegi WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE Durum IN ('NEW', 'BEKLEMEDE')
        ORDER BY Oncelik DESC, OlusturmaTarihi
    )
    UPDATE cte
    SET Durum = 'LM_RUNNING',
        DenemeSayisi = DenemeSayisi + 1,
        SonDenemeTarihi = SYSDATETIME(),
        GuncellemeTarihi = SYSDATETIME()
    OUTPUT
        inserted.IstekId,
        inserted.KesimTarihi,
        inserted.DonemKodu,
        inserted.MekanId,
        inserted.StokId,
        inserted.KaynakTip,
        inserted.KaynakAnahtar,
        inserted.Oncelik,
        inserted.Durum,
        inserted.OlusturmaTarihi;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_Istek_Retry', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Retry;
GO
CREATE PROCEDURE ai.sp_Ai_Istek_Retry
    @Top int = 200,
    @MaxDeneme int = 3,
    @BeklemeDakika int = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte AS (
        SELECT TOP (@Top) *
        FROM ai.AiAnalizIstegi WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE Durum = 'ERROR'
          AND DenemeSayisi < @MaxDeneme
          AND DATEADD(minute, @BeklemeDakika, COALESCE(SonDenemeTarihi, GuncellemeTarihi, OlusturmaTarihi)) <= SYSDATETIME()
        ORDER BY COALESCE(SonDenemeTarihi, GuncellemeTarihi, OlusturmaTarihi)
    )
    UPDATE cte
    SET Durum = 'BEKLEMEDE',
        HataMesaji = NULL,
        GuncellemeTarihi = SYSDATETIME()
    OUTPUT inserted.IstekId;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_Istek_Guncelle', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Guncelle;
GO
CREATE PROCEDURE ai.sp_Ai_Istek_Guncelle
    @IstekId bigint,
    @Durum varchar(20),
    @EvidencePlan varchar(20) = NULL,
    @LmNot nvarchar(500) = NULL,
    @EvidenceJson nvarchar(max) = NULL,
    @HataMesaji nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ai.AiAnalizIstegi
    SET Durum = @Durum,
        EvidencePlan = COALESCE(@EvidencePlan, EvidencePlan),
        LmNot = COALESCE(@LmNot, LmNot),
        EvidenceJson = COALESCE(@EvidenceJson, EvidenceJson),
        HataMesaji = @HataMesaji,
        GuncellemeTarihi = SYSDATETIME()
    WHERE IstekId = @IstekId;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_RiskOzet_Getir', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_RiskOzet_Getir;
GO
CREATE PROCEDURE ai.sp_Ai_RiskOzet_Getir
    @KesimTarihi datetime2(0),
    @DonemKodu varchar(10),
    @MekanId int,
    @StokId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        r.KesimTarihi,
        r.DonemKodu,
        r.MekanId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', r.MekanId)),
        r.StokId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', r.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)),
        r.RiskSkor,
        r.RiskYorum,
        r.FlagVeriKalite,
        r.FlagGirissizSatis,
        r.FlagOluStok,
        r.FlagNetBirikim,
        r.FlagIadeYuksek,
        r.FlagBozukIadeYuksek,
        r.FlagSayimDuzeltmeYuk,
        r.FlagSirketIciYuksek,
        r.FlagHizliDevir,
        r.FlagSatisYaslanma
    FROM rpt.RiskUrunOzet_Gunluk r
    LEFT JOIN src.vw_Mekan m ON m.MekanId = r.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = r.StokId
    WHERE r.KesimTarihi = @KesimTarihi
      AND r.DonemKodu = @DonemKodu
      AND r.MekanId = @MekanId
      AND r.StokId = @StokId;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_GecmisVektor_KaynakListe', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_GecmisVektor_KaynakListe;
GO
CREATE PROCEDURE ai.sp_Ai_GecmisVektor_KaynakListe
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
    LEFT JOIN ai.AiGecmisVektorler v ON v.DofId = d.DofId
    WHERE d.Durum = 'KAPANDI'
      AND v.DofId IS NULL
    ORDER BY d.DofId DESC;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_GecmisVektor_Upsert', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_GecmisVektor_Upsert;
GO
CREATE PROCEDURE ai.sp_Ai_GecmisVektor_Upsert
    @RiskId bigint,
    @DofId bigint = NULL,
    @Baslik nvarchar(200) = NULL,
    @OzetMetin nvarchar(500) = NULL,
    @KritikMi bit = 0,
    @VektorJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE ai.AiGecmisVektorler AS t
    USING (SELECT @RiskId AS RiskId) AS s
    ON t.RiskId = s.RiskId
    WHEN MATCHED THEN
        UPDATE SET
            t.DofId = @DofId,
            t.Baslik = @Baslik,
            t.OzetMetin = @OzetMetin,
            t.KritikMi = @KritikMi,
            t.VektorJson = @VektorJson,
            t.OlusturmaTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (RiskId, DofId, Baslik, OzetMetin, KritikMi, VektorJson, OlusturmaTarihi)
        VALUES (@RiskId, @DofId, @Baslik, @OzetMetin, @KritikMi, @VektorJson, SYSDATETIME());
END
GO

IF OBJECT_ID(N'ai.sp_Ai_GecmisVektor_Liste', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_GecmisVektor_Liste;
GO
CREATE PROCEDURE ai.sp_Ai_GecmisVektor_Liste
    @Top int = 500,
    @KritikMi bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        VektorId,
        RiskId,
        DofId,
        Baslik,
        OzetMetin,
        KritikMi,
        VektorJson
    FROM ai.AiGecmisVektorler
    WHERE (@KritikMi IS NULL OR KritikMi = @KritikMi)
    ORDER BY OlusturmaTarihi DESC;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_Istek_Liste', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Liste;
GO
CREATE PROCEDURE ai.sp_Ai_Istek_Liste
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
        i.IstekId,
        i.KesimTarihi,
        i.DonemKodu,
        i.MekanId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', i.MekanId)),
        i.StokId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', i.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', i.StokId)),
        RiskSkor = r.RiskSkor,
        i.Oncelik,
        i.Durum,
        i.EvidencePlan,
        i.LmNot,
        i.HataMesaji,
        i.DenemeSayisi,
        i.SonDenemeTarihi,
        i.OlusturmaTarihi,
        i.GuncellemeTarihi
    FROM ai.AiAnalizIstegi i
    LEFT JOIN src.vw_Mekan m ON m.MekanId = i.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = i.StokId
    LEFT JOIN rpt.RiskUrunOzet_Gunluk r
        ON r.KesimTarihi = i.KesimTarihi
       AND r.DonemKodu = i.DonemKodu
       AND r.MekanId = i.MekanId
       AND r.StokId = i.StokId
    WHERE CONVERT(date, i.KesimTarihi) BETWEEN @Bas AND @Bit
      AND (@Durum IS NULL OR i.Durum = @Durum)
      AND (
            @SearchTerm IS NULL
            OR CAST(i.MekanId AS varchar(20)) = @SearchTerm
            OR CAST(i.StokId AS varchar(20)) = @SearchTerm
            OR COALESCE(m.MekanAd, CONCAT('Mekan-', i.MekanId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunAd, CONCAT('Urun-', i.StokId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunKod, CONCAT('BK-', i.StokId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(i.KaynakAnahtar, '') LIKE '%' + @SearchTerm + '%'
      )
    ORDER BY i.OlusturmaTarihi DESC;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_Istek_Getir', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Getir;
GO
CREATE PROCEDURE ai.sp_Ai_Istek_Getir
    @IstekId bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        i.IstekId,
        i.KesimTarihi,
        i.DonemKodu,
        i.MekanId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', i.MekanId)),
        i.StokId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', i.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', i.StokId)),
        RiskSkor = r.RiskSkor,
        i.Oncelik,
        i.Durum,
        i.EvidencePlan,
        i.EvidenceJson,
        i.LmNot,
        i.HataMesaji,
        i.DenemeSayisi,
        i.SonDenemeTarihi,
        i.OlusturmaTarihi,
        i.GuncellemeTarihi
    FROM ai.AiAnalizIstegi i
    LEFT JOIN src.vw_Mekan m ON m.MekanId = i.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = i.StokId
    LEFT JOIN rpt.RiskUrunOzet_Gunluk r
        ON r.KesimTarihi = i.KesimTarihi
       AND r.DonemKodu = i.DonemKodu
       AND r.MekanId = i.MekanId
       AND r.StokId = i.StokId
    WHERE i.IstekId = @IstekId;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_LlmSonuc_Liste', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Liste;
GO
CREATE PROCEDURE ai.sp_Ai_LlmSonuc_Liste
    @Top int = 50,
    @Search nvarchar(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SearchTerm nvarchar(80) = NULLIF(LTRIM(RTRIM(@Search)), '');

    SELECT TOP (@Top)
        l.IstekId,
        l.Model,
        l.PromptVersiyon,
        l.YoneticiOzeti,
        l.GuvenSkoru,
        l.OlusturmaTarihi,
        i.DonemKodu,
        i.MekanId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', i.MekanId)),
        i.StokId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', i.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', i.StokId)),
        i.Durum
    FROM ai.AiLlmSonuc l
    INNER JOIN ai.AiAnalizIstegi i ON i.IstekId = l.IstekId
    LEFT JOIN src.vw_Mekan m ON m.MekanId = i.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = i.StokId
    WHERE (
            @SearchTerm IS NULL
            OR CAST(i.MekanId AS varchar(20)) = @SearchTerm
            OR CAST(i.StokId AS varchar(20)) = @SearchTerm
            OR COALESCE(m.MekanAd, CONCAT('Mekan-', i.MekanId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunAd, CONCAT('Urun-', i.StokId)) LIKE '%' + @SearchTerm + '%'
            OR COALESCE(u.UrunKod, CONCAT('BK-', i.StokId)) LIKE '%' + @SearchTerm + '%'
      )
    ORDER BY l.OlusturmaTarihi DESC;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_LlmSonuc_Getir', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Getir;
GO
CREATE PROCEDURE ai.sp_Ai_LlmSonuc_Getir
    @IstekId bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        l.IstekId,
        l.Model,
        l.PromptVersiyon,
        l.KokNedenHipotezleri,
        l.DogrulamaAdimlari,
        l.OnerilenAksiyonlar,
        l.DofTaslakJson,
        l.YoneticiOzeti,
        l.GuvenSkoru,
        l.OlusturmaTarihi
    FROM ai.AiLlmSonuc l
    WHERE l.IstekId = @IstekId;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_LlmSonuc_Son', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Son;
GO
CREATE PROCEDURE ai.sp_Ai_LlmSonuc_Son
    @StokId int,
    @MekanId int = NULL,
    @DonemKodu varchar(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        l.IstekId,
        l.Model,
        l.PromptVersiyon,
        l.KokNedenHipotezleri,
        l.DogrulamaAdimlari,
        l.OnerilenAksiyonlar,
        l.DofTaslakJson,
        l.YoneticiOzeti,
        l.GuvenSkoru,
        l.OlusturmaTarihi,
        i.DonemKodu,
        i.MekanId,
        i.StokId,
        i.EvidencePlan
    FROM ai.AiLlmSonuc l
    INNER JOIN ai.AiAnalizIstegi i ON i.IstekId = l.IstekId
    WHERE i.StokId = @StokId
      AND (@MekanId IS NULL OR i.MekanId = @MekanId)
      AND (@DonemKodu IS NULL OR i.DonemKodu = @DonemKodu)
    ORDER BY l.OlusturmaTarihi DESC;
END
GO

IF OBJECT_ID(N'ai.sp_Ai_Reset_ve_Tetikle', N'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Reset_ve_Tetikle;
GO
CREATE PROCEDURE ai.sp_Ai_Reset_ve_Tetikle
    @Top int = 200,
    @MinSkor int = 80,
    @SilVektor bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM ai.AiLlmSonuc;
        DELETE FROM ai.AiLmSonuc;
        DELETE FROM ai.AiAnalizIstegi;
        IF @SilVektor = 1
            DELETE FROM ai.AiGecmisVektorler;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH

    EXEC ai.sp_Ai_Istek_Olustur @Top = @Top, @MinSkor = @MinSkor;
END
GO
IF OBJECT_ID(N'ai.sp_AiEmbedding_Maintenance', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiEmbedding_Maintenance;
GO
CREATE PROCEDURE ai.sp_AiEmbedding_Maintenance
    @BatchSize int = 500
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProcessedCount int = 0;
    DECLARE @ArchivedCount int = 0;
    
    BEGIN TRY
        -- Hafiza katmani bakimi - eski embedding'leri arsivle
        UPDATE ai.AiMultiModalEmbedding 
        SET MemoryLayer = 'SOGUK',
            UpdatedDate = SYSDATETIME()
        WHERE MemoryLayer = 'ILIK'
          AND LastAccessTime < DATEADD(day, -90, SYSDATETIME())
          AND IsActive = 1;
        
        SET @ArchivedCount = @@ROWCOUNT;
        
        -- Kalite skorlarini guncelle
        UPDATE ai.AiMultiModalEmbedding 
        SET QualityScore = CASE 
                WHEN AccessCount > 10 THEN 0.95
                WHEN AccessCount > 5 THEN 0.85
                WHEN AccessCount > 1 THEN 0.75
                ELSE 0.65
            END,
            UpdatedDate = SYSDATETIME()
        WHERE QualityScore IS NULL 
           OR UpdatedDate < DATEADD(day, -7, SYSDATETIME());
        
        SET @ProcessedCount = @@ROWCOUNT;
        
        SELECT 
            @ProcessedCount as UpdatedEmbeddings,
            @ArchivedCount as ArchivedEmbeddings,
            'Embedding bakimi tamamlandi' as Message;
            
    END TRY
    BEGIN CATCH
        SELECT 
            ERROR_MESSAGE() as ErrorMessage,
            'Embedding bakim hatasi' as Status;
    END CATCH
END
GO

IF OBJECT_ID(N'ai.sp_AiModel_PerformanceUpdate', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiModel_PerformanceUpdate;
GO
CREATE PROCEDURE ai.sp_AiModel_PerformanceUpdate
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today date = CAST(SYSDATETIME() AS date);
    DECLARE @ProcessedCount int = 0;
    
    BEGIN TRY
        -- Gunluk model performans metriklerini guncelle
        MERGE ai.AiModelPerformance AS target
        USING (
            SELECT 
                'DefaultModel' as ModelName,
                'V2.0' as ModelVersion,
                'RISK_ANALISTI' as AgentType,
                @Today as MeasurementDate,
                COUNT(*) as TotalRequests,
                SUM(CASE WHEN Durum = 'COMPLETED' THEN 1 ELSE 0 END) as SuccessfulRequests,
                SUM(CASE WHEN Durum = 'FAILED' OR Durum = 'ERROR' THEN 1 ELSE 0 END) as FailedRequests,
                CASE 
                    WHEN COUNT(*) > 0 THEN 
                        CAST(SUM(CASE WHEN Durum = 'COMPLETED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS decimal(5,2))
                    ELSE 75.0 
                END as AverageAccuracy,
                CASE 
                    WHEN COUNT(*) > 0 THEN 
                        CAST((100.0 - AVG(CAST(DenemeSayisi AS float)) * 10) AS decimal(5,2))
                    ELSE 75.0 
                END as AverageConfidence,
                5000 as AverageResponseTime
            FROM ai.AiAnalizIstegi
            WHERE CAST(OlusturmaTarihi AS date) = @Today
        ) AS source
        ON target.ModelName = source.ModelName 
           AND target.ModelVersion = source.ModelVersion
           AND target.MeasurementDate = source.MeasurementDate
        WHEN MATCHED THEN
            UPDATE SET 
                TotalRequests = source.TotalRequests,
                SuccessfulRequests = source.SuccessfulRequests,
                FailedRequests = source.FailedRequests,
                AverageAccuracy = source.AverageAccuracy,
                AverageConfidence = source.AverageConfidence,
                AverageResponseTime = source.AverageResponseTime
        WHEN NOT MATCHED AND source.TotalRequests > 0 THEN
            INSERT (ModelName, ModelVersion, AgentType, MeasurementDate,
                   TotalRequests, SuccessfulRequests, FailedRequests,
                   AverageAccuracy, AverageConfidence, AverageResponseTime)
            VALUES (source.ModelName, source.ModelVersion, source.AgentType, source.MeasurementDate,
                   source.TotalRequests, source.SuccessfulRequests, source.FailedRequests,
                   source.AverageAccuracy, source.AverageConfidence, source.AverageResponseTime);
        
        SET @ProcessedCount = @@ROWCOUNT;
        
        SELECT 
            @ProcessedCount as UpdatedRecords,
            'Model performans guncellendi' as Message,
            @Today as Date;
            
    END TRY
    BEGIN CATCH
        SELECT 
            ERROR_MESSAGE() as ErrorMessage,
            'Model performans guncelleme hatasi' as Status;
    END CATCH
END
GO\r\n