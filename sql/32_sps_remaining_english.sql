/*
 * 32_sps_remaining_english.sql
 * ---------------------------------------------------------------------------
 * English versions of all remaining Turkish stored procedures.
 *
 * Rules:
 *   - SP names:     schema.sp_Entity_Action (English)
 *   - Parameters:   STAY TURKISH with @ prefix
 *   - Table/column: English names
 *   - src.* views:  NEVER changed, use aliases
 *   - SET NOCOUNT ON first line
 *   - TRY-CATCH where applicable
 *   - datetime2(0), SYSDATETIME()
 *   - Idempotent: IF OBJECT_ID DROP + CREATE
 *
 * Generated: 2026-03-30
 * ---------------------------------------------------------------------------
 */


-- ===========================================================================
-- DROP OLD TURKISH SPs
-- ===========================================================================
IF OBJECT_ID('rpt.sp_GenelBakis_Kpi', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_GenelBakis_Kpi;
IF OBJECT_ID('rpt.sp_GenelBakis_Not', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_GenelBakis_Not;
IF OBJECT_ID('rpt.sp_Dashboard_Kpi', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_Kpi;
IF OBJECT_ID('rpt.sp_Dashboard_RiskTrend', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_RiskTrend;
IF OBJECT_ID('rpt.sp_Dashboard_TopRisk', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_TopRisk;
IF OBJECT_ID('dof.sp_Dashboard_Dof_Liste', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Dashboard_Dof_Liste;
IF OBJECT_ID('ref.sp_Dashboard_Ref_Ozet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Dashboard_Ref_Ozet;
IF OBJECT_ID('rpt.sp_UrunDetay_Getir', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_UrunDetay_Getir;
IF OBJECT_ID('rpt.sp_UrunRiskFlag_Liste', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_UrunRiskFlag_Liste;
IF OBJECT_ID('rpt.sp_UrunHareket_Liste', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_UrunHareket_Liste;
IF OBJECT_ID('ai.sp_Ai_LlmSonuc_Son', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Son;
IF OBJECT_ID('ai.sp_Ai_LlmSonuc_Getir', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Getir;
IF OBJECT_ID('log.sp_PersonelEntegrasyon_Ozet', 'P') IS NOT NULL DROP PROCEDURE log.sp_PersonelEntegrasyon_Ozet;
IF OBJECT_ID('log.sp_PersonelEntegrasyon_Log_Liste', 'P') IS NOT NULL DROP PROCEDURE log.sp_PersonelEntegrasyon_Log_Liste;
IF OBJECT_ID('ref.sp_KullaniciPersonel_Kapat', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KullaniciPersonel_Kapat;
IF OBJECT_ID('ref.sp_KullaniciPersonel_GunSonuKapat', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KullaniciPersonel_GunSonuKapat;
IF OBJECT_ID('ref.sp_KullaniciPersonel_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KullaniciPersonel_Liste;
GO

-- ===========================================================================
-- DROP NEW ENGLISH SPs IF THEY ALREADY EXIST (idempotent)
-- ===========================================================================
IF OBJECT_ID('rpt.sp_DashboardOverview_Kpi', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_DashboardOverview_Kpi;
IF OBJECT_ID('rpt.sp_DashboardOverview_Notes', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_DashboardOverview_Notes;
IF OBJECT_ID('rpt.sp_Dashboard_Kpi', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_Kpi;
IF OBJECT_ID('rpt.sp_Dashboard_RiskTrend', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_RiskTrend;
IF OBJECT_ID('rpt.sp_Dashboard_TopRisk', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_TopRisk;
IF OBJECT_ID('dof.sp_Dashboard_Dof_List', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Dashboard_Dof_List;
IF OBJECT_ID('ref.sp_Dashboard_Ref_Summary', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Dashboard_Ref_Summary;
IF OBJECT_ID('rpt.sp_ProductDetail_Get', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_ProductDetail_Get;
IF OBJECT_ID('rpt.sp_ProductRiskFlag_List', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_ProductRiskFlag_List;
IF OBJECT_ID('rpt.sp_ProductMovement_List', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_ProductMovement_List;
IF OBJECT_ID('ai.sp_LlmResults_Latest', 'P') IS NOT NULL DROP PROCEDURE ai.sp_LlmResults_Latest;
IF OBJECT_ID('ai.sp_LlmResults_Get', 'P') IS NOT NULL DROP PROCEDURE ai.sp_LlmResults_Get;
IF OBJECT_ID('log.sp_PersonnelSync_Summary', 'P') IS NOT NULL DROP PROCEDURE log.sp_PersonnelSync_Summary;
IF OBJECT_ID('log.sp_PersonnelSync_Log_List', 'P') IS NOT NULL DROP PROCEDURE log.sp_PersonnelSync_Log_List;
IF OBJECT_ID('ref.sp_UserPersonnelLink_Close', 'P') IS NOT NULL DROP PROCEDURE ref.sp_UserPersonnelLink_Close;
IF OBJECT_ID('ref.sp_UserPersonnelLink_CloseAll', 'P') IS NOT NULL DROP PROCEDURE ref.sp_UserPersonnelLink_CloseAll;
IF OBJECT_ID('ref.sp_UserPersonnelLink_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_UserPersonnelLink_List;
GO


-- ===========================================================================
-- 1) rpt.sp_DashboardOverview_Kpi  (was: rpt.sp_GenelBakis_Kpi)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
--    View:  rpt.vw_RiskUrunOzet_Stok stays as-is
-- ===========================================================================
CREATE PROCEDURE rpt.sp_DashboardOverview_Kpi
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            SET @Kesim = CONVERT(date, SYSDATETIME());

        DECLARE @KritikSkorEsik int = COALESCE(
            (SELECT IntValue FROM ref.RiskParameters WHERE ParamCode = 'KritikSkorEsik'), 80);

        DECLARE @RiskSatir int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
        );

        DECLARE @KritikSkor int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
              AND RiskScore >= @KritikSkorEsik
        );

        DECLARE @DofAcik int = (
            SELECT COUNT(*) FROM dof.Findings
            WHERE Status <> 'KAPANDI'
        );

        DECLARE @StokSapma int = (
            SELECT COUNT(*) FROM rpt.vw_RiskUrunOzet_Stok
            WHERE KesimGunu = @Kesim AND DonemKodu = 'Son30Gun'
              AND (FlagStokKaydiYok = 1 OR FlagStokSifir = 1)
        );

        SELECT Sira, Kodu, Baslik, Deger, NotAciklama, Tone
        FROM (
            SELECT
                Sira = 1,
                Kodu = 'RiskSatir',
                Baslik = 'Risk Satir',
                Deger = @RiskSatir,
                NotAciklama = 'Son 24 saat',
                Tone = CASE WHEN @RiskSatir > 0 THEN 'tone-good' ELSE 'tone-warn' END
            UNION ALL
            SELECT 2, 'KritikSkor', 'Kritik Skor', @KritikSkor,
                CONCAT('Esik ', @KritikSkorEsik, '+'),
                CASE WHEN @KritikSkor > 0 THEN 'tone-warn' ELSE 'tone-good' END
            UNION ALL
            SELECT 3, 'DofAcik', 'Dof Acik', @DofAcik,
                'SLA takibi',
                CASE WHEN @DofAcik > 0 THEN 'tone-alert' ELSE 'tone-good' END
            UNION ALL
            SELECT 4, 'StokSapma', 'Stok Sapma', @StokSapma,
                'Dun yakalanan',
                CASE WHEN @StokSapma > 0 THEN 'tone-warn' ELSE 'tone-good' END
        ) x
        ORDER BY x.Sira;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 2) rpt.sp_DashboardOverview_Notes  (was: rpt.sp_GenelBakis_Not)
--    Tables: log.RiskEtlRuns (was: log.RiskCalismaLog)
--            log.StockEtlRuns (was: log.StokCalismaLog)
--            ref.TransactionTypeMap (was: ref.IrsTipGrupMap)
--    View:   src.vw_StokHareket stays as-is
-- ===========================================================================
CREATE PROCEDURE rpt.sp_DashboardOverview_Notes
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @RiskDurum varchar(10) = NULL;
        DECLARE @RiskZaman datetime2(0) = NULL;
        SELECT TOP 1
            @RiskDurum = CASE
                WHEN Status = 'SUCCESS' AND EndTime >= DATEADD(hour, -24, SYSDATETIME()) THEN 'PASS'
                WHEN Status = 'SUCCESS' THEN 'WARN'
                ELSE 'FAIL'
            END,
            @RiskZaman = EndTime
        FROM log.RiskEtlRuns
        ORDER BY LogId DESC;

        DECLARE @StokDurum varchar(10) = NULL;
        DECLARE @StokZaman datetime2(0) = NULL;
        SELECT TOP 1
            @StokDurum = CASE
                WHEN Status = 'SUCCESS' AND EndTime >= DATEADD(hour, -24, SYSDATETIME()) THEN 'PASS'
                WHEN Status = 'SUCCESS' THEN 'WARN'
                ELSE 'FAIL'
            END,
            @StokZaman = EndTime
        FROM log.StockEtlRuns
        ORDER BY LogId DESC;

        DECLARE @TipMapEksik int = (
            SELECT COUNT(DISTINCT h.TipId)
            FROM src.vw_StokHareket h
            LEFT JOIN ref.TransactionTypeMap m ON m.TypeId = h.TipId AND m.IsActive = 1
            WHERE h.HareketTarihi >= DATEADD(day, -30, CONVERT(date, SYSDATETIME()))
              AND m.TypeId IS NULL
        );

        SELECT Metin = CONCAT('Risk job durumu: ', COALESCE(@RiskDurum, '-'),
                              ' (', COALESCE(CONVERT(varchar(16), @RiskZaman, 120), '-'), ')')
        UNION ALL
        SELECT CONCAT('Stok job durumu: ', COALESCE(@StokDurum, '-'),
                      ' (', COALESCE(CONVERT(varchar(16), @StokZaman, 120), '-'), ')')
        UNION ALL
        SELECT CASE
            WHEN @TipMapEksik = 0 THEN 'Tip map eksigi yok.'
            ELSE CONCAT('Tip map eksik: ', @TipMapEksik)
        END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 3) rpt.sp_Dashboard_Kpi  (was: rpt.sp_Dashboard_Kpi from 11_sps_dashboard)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
-- ===========================================================================
CREATE PROCEDURE rpt.sp_Dashboard_Kpi
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            SET @Kesim = CONVERT(date, SYSDATETIME());

        DECLARE @KritikSkorEsik int = COALESCE(
            (SELECT IntValue FROM ref.RiskParameters WHERE ParamCode = 'KritikSkorEsik'), 80);

        DECLARE @KritikRisk int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
              AND RiskScore >= @KritikSkorEsik
        );

        DECLARE @BekleyenDof int = (
            SELECT COUNT(*) FROM dof.Findings
            WHERE Status <> 'KAPANDI'
        );

        DECLARE @TarananStok int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
        );

        SELECT Sira, Kodu, Deger, NotAciklama
        FROM (
            SELECT
                Sira = 1,
                Kodu = 'KRITIK_RISK',
                Deger = @KritikRisk,
                NotAciklama = CONCAT('Esik ', @KritikSkorEsik, '+')
            UNION ALL
            SELECT 2, 'BEKLEYEN_DOF', @BekleyenDof, 'SLA takibi'
            UNION ALL
            SELECT 3, 'TARANAN_STOK', @TarananStok, 'Son gece'
        ) x
        ORDER BY x.Sira;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 4) rpt.sp_Dashboard_RiskTrend  (was: rpt.sp_Dashboard_RiskTrend from 11)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
-- ===========================================================================
CREATE PROCEDURE rpt.sp_Dashboard_RiskTrend
    @Gun int = 30
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Kesim date = (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk);
        IF @Kesim IS NULL
            RETURN;

        DECLARE @Baslangic date = DATEADD(day, -ABS(@Gun) + 1, @Kesim);

        SELECT
            Tarih        = CONVERT(date, r.SnapshotDate),
            OrtalamaSkor = CAST(AVG(CAST(r.RiskScore AS decimal(9,2))) AS decimal(9,2))
        FROM rpt.DailyProductRisk r
        WHERE CONVERT(date, r.SnapshotDate) BETWEEN @Baslangic AND @Kesim
          AND r.PeriodCode = 'Son30Gun'
        GROUP BY CONVERT(date, r.SnapshotDate)
        ORDER BY CONVERT(date, r.SnapshotDate);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 5) rpt.sp_Dashboard_TopRisk  (was: rpt.sp_Dashboard_TopRisk from 11)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
--    Views: src.vw_Mekan, src.vw_Urun stay as-is
-- ===========================================================================
CREATE PROCEDURE rpt.sp_Dashboard_TopRisk
    @Top int = 10,
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            RETURN;

        SELECT TOP (@Top)
            MekanId  = r.LocationId,
            MekanAd  = COALESCE(m.MekanAd, CONCAT('Mekan-', r.LocationId)),
            StokId   = r.ProductId,
            UrunKod  = COALESCE(u.UrunKod, CONCAT('BK-', r.ProductId)),
            UrunAd   = COALESCE(u.UrunAd, CONCAT('Urun-', r.ProductId)),
            DonemKodu = r.PeriodCode,
            RiskSkor = r.RiskScore,
            Flag = COALESCE(
                NULLIF(LTRIM(RTRIM(LEFT(r.RiskComment, CHARINDEX('|', r.RiskComment + '|') - 1))), ''),
                'YOK'
            )
        FROM rpt.DailyProductRisk r
        LEFT JOIN src.vw_Mekan m ON m.MekanId = r.LocationId
        LEFT JOIN src.vw_Urun u ON u.StokId = r.ProductId
        WHERE CONVERT(date, r.SnapshotDate) = @Kesim
          AND r.PeriodCode = 'Son30Gun'
        ORDER BY r.RiskScore DESC, r.LocationId, r.ProductId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 6) dof.sp_Dashboard_Dof_List  (was: dof.sp_Dashboard_Dof_Liste)
--    Table: dof.Findings stays as-is (not yet renamed)
-- ===========================================================================
CREATE PROCEDURE dof.sp_Dashboard_Dof_List
    @Top int = 5
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Top)
            Title,
            Sorumlu = COALESCE(NULLIF(LTRIM(RTRIM(AssignedTo)), ''), 'Atanmadi'),
            SLA = CASE
                WHEN SlaDueDate IS NULL THEN 'Suresiz'
                ELSE CONCAT(DATEDIFF(day, CONVERT(date, SYSDATETIME()), SlaDueDate), ' gun')
            END,
            Status
        FROM dof.Findings
        WHERE Status <> 'KAPANDI'
        ORDER BY RiskLevel DESC, SlaDueDate;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 7) ref.sp_Dashboard_Ref_Summary  (was: ref.sp_Dashboard_Ref_Ozet)
--    Tables: ref.TransactionTypeMap (was: ref.IrsTipGrupMap)
--            ref.RiskParameters (was: ref.RiskParam)
--    Views:  src.vw_Mekan, src.vw_IrsTip stay as-is
-- ===========================================================================
CREATE PROCEDURE ref.sp_Dashboard_Ref_Summary
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @AktifMekan int = (SELECT COUNT(*) FROM src.vw_Mekan);
        DECLARE @ToplamTip  int = (SELECT COUNT(*) FROM src.vw_IrsTip);
        DECLARE @MapliTip   int = (SELECT COUNT(*) FROM ref.TransactionTypeMap WHERE IsActive = 1);
        DECLARE @RiskParam  int = (SELECT COUNT(*) FROM ref.RiskParameters WHERE IsActive = 1);

        SELECT Sira, Baslik, Deger, NotAciklama
        FROM (
            SELECT
                Sira = 1,
                Baslik = 'Mekan',
                Deger = CONCAT(@AktifMekan, ' mekan'),
                NotAciklama = 'Toplam mekan sayisi'
            UNION ALL
            SELECT 2, 'Tip map',
                CONCAT(@MapliTip, ' / ', @ToplamTip),
                'Mapli tip sayisi'
            UNION ALL
            SELECT 3, 'Risk param',
                CONCAT(@RiskParam, ' param'),
                'Esikler aktif'
        ) x
        ORDER BY x.Sira;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 8) rpt.sp_ProductDetail_Get  (was: rpt.sp_UrunDetay_Getir)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
--    View:  rpt.vw_RiskUrunOzet_Stok stays as-is
--    Views: src.vw_Mekan, src.vw_Urun stay as-is
-- ===========================================================================
CREATE PROCEDURE rpt.sp_ProductDetail_Get
    @StokId int,
    @MekanId int = NULL,
    @DonemKodu varchar(10) = 'Son30Gun',
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @StokId IS NULL OR @StokId <= 0
            THROW 50000, 'StokId zorunludur', 1;

        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            RETURN;

        DECLARE @IadeOranEsik decimal(9,2) = COALESCE(
            (SELECT DecValue FROM ref.RiskParameters WHERE ParamCode = 'IadeOranEsik'), 0);

        ;WITH Secilen AS (
            SELECT TOP 1 r.*
            FROM rpt.vw_RiskUrunOzet_Stok r
            WHERE r.KesimGunu = @Kesim
              AND r.DonemKodu = @DonemKodu
              AND r.StokId = @StokId
              AND (@MekanId IS NULL OR r.MekanId = @MekanId)
            ORDER BY CASE WHEN r.MekanId = @MekanId THEN 0 ELSE 1 END,
                     r.RiskSkor DESC,
                     r.MekanId
        )
        SELECT
            StokId           = s.StokId,
            MekanId          = s.MekanId,
            MekanAd          = COALESCE(m.MekanAd, CONCAT('Mekan-', s.MekanId)),
            UrunKod          = COALESCE(u.UrunKod, CONCAT('BK-', s.StokId)),
            UrunAd           = COALESCE(u.UrunAd, CONCAT('Urun-', s.StokId)),
            Kategori3        = u.Kategori3,
            DonemKodu        = s.DonemKodu,
            RiskSkor         = s.RiskSkor,
            RiskYorum        = s.RiskYorum,
            IadeOranEsik     = @IadeOranEsik,
            IadeOraniYuzde   = s.IadeOraniYuzde,
            StokMiktar       = COALESCE(s.StokMiktar, 0),
            StokBakiyeTarihi = s.StokBakiyeTarihi,
            SonSatisTarihi   = s.SonSatisTarihi,
            FlagStokYok      = CONVERT(bit, CASE WHEN s.FlagStokKaydiYok = 1 OR s.FlagStokSifir = 1 THEN 1 ELSE 0 END)
        FROM Secilen s
        LEFT JOIN src.vw_Mekan m ON m.MekanId = s.MekanId
        LEFT JOIN src.vw_Urun u ON u.StokId = s.StokId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 9) rpt.sp_ProductRiskFlag_List  (was: rpt.sp_UrunRiskFlag_Liste)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
--    View:  rpt.vw_RiskUrunOzet_Stok stays as-is
--    Table: ref.RiskScoreWeights (was: ref.RiskSkorAgirlik)
-- ===========================================================================
CREATE PROCEDURE rpt.sp_ProductRiskFlag_List
    @StokId int,
    @MekanId int = NULL,
    @DonemKodu varchar(10) = 'Son30Gun',
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @StokId IS NULL OR @StokId <= 0
            THROW 50000, 'StokId zorunludur', 1;

        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            RETURN;

        ;WITH Secilen AS (
            SELECT TOP 1 r.*
            FROM rpt.vw_RiskUrunOzet_Stok r
            WHERE r.KesimGunu = @Kesim
              AND r.DonemKodu = @DonemKodu
              AND r.StokId = @StokId
              AND (@MekanId IS NULL OR r.MekanId = @MekanId)
            ORDER BY CASE WHEN r.MekanId = @MekanId THEN 0 ELSE 1 END,
                     r.RiskSkor DESC,
                     r.MekanId
        ),
        Flags AS (
            SELECT * FROM (
                SELECT 'FlagVeriKalite'       AS FlagKodu, FlagVal = s.FlagVeriKalite,       DefaultAciklama = 'Veri kalitesi sorunu',    DefaultEtki = 0 FROM Secilen s
                UNION ALL SELECT 'FlagGirissizSatis',    s.FlagGirissizSatis,    'Satis var ama alis yok',     0 FROM Secilen s
                UNION ALL SELECT 'FlagOluStok',          s.FlagOluStok,          'Alis var ama satis yok',     0 FROM Secilen s
                UNION ALL SELECT 'FlagNetBirikim',       s.FlagNetBirikim,       'Net birikim yuksek',         0 FROM Secilen s
                UNION ALL SELECT 'FlagIadeYuksek',       s.FlagIadeYuksek,       'Iade orani yuksek',          0 FROM Secilen s
                UNION ALL SELECT 'FlagBozukIadeYuksek',  s.FlagBozukIadeYuksek,  'Bozuk/Imha yuksek',          0 FROM Secilen s
                UNION ALL SELECT 'FlagSayimDuzeltmeYuk', s.FlagSayimDuzeltmeYuk, 'Sayim+Duzeltme yuksek',      0 FROM Secilen s
                UNION ALL SELECT 'FlagSirketIciYuksek',  s.FlagSirketIciYuksek,  'Ic kullanim yuksek',         0 FROM Secilen s
                UNION ALL SELECT 'FlagHizliDevir',       s.FlagHizliDevir,       'Hizli devir',                0 FROM Secilen s
                UNION ALL SELECT 'FlagSatisYaslanma',    s.FlagSatisYaslanma,    'Satis yaslanma',             0 FROM Secilen s
                UNION ALL SELECT 'FlagStokYok',
                    CONVERT(bit, CASE WHEN s.FlagStokKaydiYok = 1 OR s.FlagStokSifir = 1 THEN 1 ELSE 0 END),
                    'Stok kaydi yok veya sifir', 0 FROM Secilen s
            ) f
        )
        SELECT
            Flag     = f.FlagKodu,
            Aciklama = COALESCE(w.Description, f.DefaultAciklama),
            Etki     = COALESCE(w.Points, f.DefaultEtki)
        FROM Flags f
        LEFT JOIN ref.RiskScoreWeights w ON w.FlagCode = f.FlagKodu AND w.IsActive = 1
        WHERE f.FlagVal = 1
        ORDER BY COALESCE(w.Priority, 999), f.FlagKodu;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 10) rpt.sp_ProductMovement_List  (was: rpt.sp_UrunHareket_Liste)
--     Table: ref.TransactionTypeMap (was: ref.IrsTipGrupMap)
--     Views: src.vw_StokHareket, src.vw_Mekan, src.vw_EvrakBaslik,
--            src.vw_IrsTip stay as-is
-- ===========================================================================
CREATE PROCEDURE rpt.sp_ProductMovement_List
    @StokId int,
    @MekanId int = NULL,
    @Top int = 30
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @StokId IS NULL OR @StokId <= 0
            THROW 50000, 'StokId zorunludur', 1;

        SELECT TOP (@Top)
            Tarih       = h.HareketTarihi,
            MekanAd     = COALESCE(m.MekanAd, CONCAT('Mekan-', h.MekanId)),
            HareketTipi = COALESCE(g.GroupName, g.GroupCode, 'Diger'),
            Tip         = COALESCE(t.TipAdi, CONCAT('Tip-', h.TipId)),
            Islem       = COALESCE(g.OperationName, g.GroupName, g.GroupCode),
            EvrakNo     = COALESCE(CONVERT(varchar(40), e.EvrakNo), CONCAT('E-', h.EvrakId)),
            BirimFiyat  = CAST(ABS(h.Tutar) / NULLIF(ABS(h.Adet), 0) AS decimal(18,2)),
            Giris       = CASE WHEN h.Adet > 0 THEN h.Adet END,
            Cikis       = CASE WHEN h.Adet < 0 THEN ABS(h.Adet) END,
            Kalan       = CAST(SUM(h.Adet) OVER (
                PARTITION BY h.MekanId
                ORDER BY h.HareketTarihi, h.HrkId
                ROWS UNBOUNDED PRECEDING
            ) AS decimal(18,3)),
            Tutar       = h.Tutar,
            Maliyet     = h.Maliyet,
            [Not]       = CONCAT('Evrak ', h.EvrakId)
        FROM src.vw_StokHareket h
        LEFT JOIN src.vw_Mekan m ON m.MekanId = h.MekanId
        LEFT JOIN src.vw_EvrakBaslik e ON e.EvrakId = h.EvrakId
        LEFT JOIN ref.TransactionTypeMap g ON g.TypeId = h.TipId AND g.IsActive = 1
        LEFT JOIN src.vw_IrsTip t ON t.TipId = h.TipId
        WHERE h.StokId = @StokId
          AND (@MekanId IS NULL OR h.MekanId = @MekanId)
          AND h.AltDepoId = 0
        ORDER BY h.HareketTarihi DESC, h.HrkId DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 11) ai.sp_LlmResults_Latest  (was: ai.sp_Ai_LlmSonuc_Son)
--     Table: ai.LlmResults (was: ai.AiLlmSonuc)
--            ai.AnalysisQueue (was: ai.AiAnalizIstegi)
-- ===========================================================================
CREATE PROCEDURE ai.sp_LlmResults_Latest
    @StokId int,
    @MekanId int = NULL,
    @DonemKodu varchar(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP 1
            l.RequestId,
            l.ModelName,
            l.PromptText,
            l.ResultText,
            l.TokenCount,
            l.DurationMs,
            l.ConfidenceScore,
            l.CreatedAt,
            i.PeriodCode,
            i.LocationId,
            i.ProductId,
            i.EvidencePlan
        FROM ai.LlmResults l
        INNER JOIN ai.AnalysisQueue i ON i.RequestId = l.RequestId
        WHERE i.ProductId = @StokId
          AND (@MekanId IS NULL OR i.LocationId = @MekanId)
          AND (@DonemKodu IS NULL OR i.PeriodCode = @DonemKodu)
        ORDER BY l.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 12) ai.sp_LlmResults_Get  (was: ai.sp_Ai_LlmSonuc_Getir)
--     Table: ai.LlmResults (was: ai.AiLlmSonuc)
-- ===========================================================================
CREATE PROCEDURE ai.sp_LlmResults_Get
    @IstekId bigint
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP 1
            l.RequestId,
            l.ModelName,
            l.PromptText,
            l.ResultText,
            l.TokenCount,
            l.DurationMs,
            l.ConfidenceScore,
            l.CreatedAt
        FROM ai.LlmResults l
        WHERE l.RequestId = @IstekId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 13) log.sp_PersonnelSync_Summary  (was: log.sp_PersonelEntegrasyon_Ozet)
--     Table: log.PersonelEntegrasyonLog stays as-is (not yet renamed)
-- ===========================================================================
CREATE PROCEDURE log.sp_PersonnelSync_Summary
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP 1
            KaynakSistem   = SourceSystem,
            SonCalisma     = COALESCE(EndTime, StartTime),
            SonrakiCalisma = CASE
                WHEN COALESCE(EndTime, StartTime) IS NULL THEN NULL
                ELSE DATEADD(day, 1, COALESCE(EndTime, StartTime))
            END,
            Toplam         = TotalRecords,
            Eklenen        = InsertedCount,
            Guncellenen    = UpdatedCount,
            PasifEdilen    = DeactivatedCount
        FROM log.PersonnelIntegrationLog
        ORDER BY LogId DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 14) log.sp_PersonnelSync_Log_List  (was: log.sp_PersonelEntegrasyon_Log_Liste)
--     Table: log.PersonelEntegrasyonLog stays as-is (not yet renamed)
-- ===========================================================================
CREATE PROCEDURE log.sp_PersonnelSync_Log_List
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Top)
            Tarih        = COALESCE(EndTime, StartTime),
            Durum        = Status,
            Toplam       = TotalRecords,
            NotAciklama  = ErrorMessage
        FROM log.PersonnelIntegrationLog
        ORDER BY LogId DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 15) ref.sp_UserPersonnelLink_List  (was: ref.sp_KullaniciPersonel_Liste)
--     Tables: ref.KullaniciPersonel, ref.Kullanici, ref.Personel
--             (these stay as-is until table rename migration)
-- ===========================================================================
CREATE PROCEDURE ref.sp_UserPersonnelLink_List
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            BaglantiId       = kp.LinkId,
            KullaniciAdi     = k.Username,
            PersonelAd       = CONCAT(p.FirstName, ' ', p.LastName),
            RolKodu          = k.RoleCode,
            BaslangicTarihi  = kp.StartDate,
            AktifMi          = kp.IsActive
        FROM ref.UserPersonnelMap kp
        INNER JOIN ref.Users k ON k.UserId = kp.UserId
        INNER JOIN ref.Personnel p ON p.PersonnelId = kp.PersonnelId
        ORDER BY kp.IsActive DESC, kp.StartDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 16) ref.sp_UserPersonnelLink_Close  (was: ref.sp_KullaniciPersonel_Kapat)
--     Table: ref.KullaniciPersonel stays as-is (not yet renamed)
-- ===========================================================================
CREATE PROCEDURE ref.sp_UserPersonnelLink_Close
    @BaglantiId bigint,
    @KullaniciId int = NULL,
    @Aciklama nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @BaglantiId IS NULL OR @BaglantiId <= 0
            THROW 50000, 'BaglantiId zorunludur', 1;

        UPDATE ref.UserPersonnelMap
        SET
            IsActive = 0,
            EndDate = COALESCE(EndDate, SYSDATETIME()),
            Description = COALESCE(@Aciklama, Description),
            UpdatedByUserId = @KullaniciId,
            UpdatedAt = SYSDATETIME()
        WHERE LinkId = @BaglantiId
          AND IsActive = 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 17) ref.sp_UserPersonnelLink_CloseAll  (was: ref.sp_KullaniciPersonel_GunSonuKapat)
--     Table: ref.KullaniciPersonel stays as-is (not yet renamed)
-- ===========================================================================
CREATE PROCEDURE ref.sp_UserPersonnelLink_CloseAll
    @KullaniciId int = NULL,
    @Aciklama nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE ref.UserPersonnelMap
        SET
            IsActive = 0,
            EndDate = COALESCE(EndDate, SYSDATETIME()),
            Description = COALESCE(@Aciklama, Description),
            UpdatedByUserId = @KullaniciId,
            UpdatedAt = SYSDATETIME()
        WHERE IsActive = 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- END OF FILE
-- ===========================================================================
PRINT '32_sps_remaining_english.sql completed successfully.';
GO
