/* 10_sps_dashboard.sql
   Dashboard/Genel Bakis KPI ve notlar
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'rpt.sp_GenelBakis_Kpi', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_GenelBakis_Kpi;
GO
CREATE PROCEDURE rpt.sp_GenelBakis_Kpi
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kesim date = COALESCE(@KesimGunu, (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk));
    IF @Kesim IS NULL
        SET @Kesim = CONVERT(date, SYSDATETIME());

    DECLARE @KritikSkorEsik int = COALESCE((SELECT DegerInt FROM ref.RiskParam WHERE ParamKodu='KritikSkorEsik'), 80);

    DECLARE @RiskSatir int = (
        SELECT COUNT(*) FROM rpt.RiskUrunOzet_Gunluk
        WHERE KesimGunu=@Kesim AND DonemKodu='Son30Gun'
    );

    DECLARE @KritikSkor int = (
        SELECT COUNT(*) FROM rpt.RiskUrunOzet_Gunluk
        WHERE KesimGunu=@Kesim AND DonemKodu='Son30Gun' AND RiskSkor >= @KritikSkorEsik
    );

    DECLARE @DofAcik int = (
        SELECT COUNT(*) FROM dof.DofKayit
        WHERE Durum <> 'KAPANDI'
    );

    DECLARE @StokSapma int = (
        SELECT COUNT(*) FROM rpt.vw_RiskUrunOzet_Stok
        WHERE KesimGunu=@Kesim AND DonemKodu='Son30Gun'
          AND (FlagStokKaydiYok=1 OR FlagStokSifir=1)
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
        SELECT
            2,
            'KritikSkor',
            'Kritik Skor',
            @KritikSkor,
            NotAciklama = CONCAT('Esik ', @KritikSkorEsik, '+'),
            Tone = CASE WHEN @KritikSkor > 0 THEN 'tone-warn' ELSE 'tone-good' END
        UNION ALL
        SELECT
            3,
            'DofAcik',
            'Dof Acik',
            @DofAcik,
            NotAciklama = 'SLA takibi',
            Tone = CASE WHEN @DofAcik > 0 THEN 'tone-alert' ELSE 'tone-good' END
        UNION ALL
        SELECT
            4,
            'StokSapma',
            'Stok Sapma',
            @StokSapma,
            NotAciklama = 'Dun yakalanan',
            Tone = CASE WHEN @StokSapma > 0 THEN 'tone-warn' ELSE 'tone-good' END
    ) x
    ORDER BY x.Sira;
END
GO

IF OBJECT_ID(N'rpt.sp_GenelBakis_Not', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_GenelBakis_Not;
GO
CREATE PROCEDURE rpt.sp_GenelBakis_Not
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RiskDurum varchar(10) = NULL;
    DECLARE @RiskZaman datetime2(0) = NULL;
    SELECT TOP 1
        @RiskDurum = CASE
            WHEN Durum='SUCCESS' AND BitisZamani >= DATEADD(hour,-24,SYSDATETIME()) THEN 'PASS'
            WHEN Durum='SUCCESS' THEN 'WARN'
            ELSE 'FAIL'
        END,
        @RiskZaman = BitisZamani
    FROM log.RiskCalismaLog
    ORDER BY LogId DESC;

    DECLARE @StokDurum varchar(10) = NULL;
    DECLARE @StokZaman datetime2(0) = NULL;
    SELECT TOP 1
        @StokDurum = CASE
            WHEN Durum='SUCCESS' AND BitisZamani >= DATEADD(hour,-24,SYSDATETIME()) THEN 'PASS'
            WHEN Durum='SUCCESS' THEN 'WARN'
            ELSE 'FAIL'
        END,
        @StokZaman = BitisZamani
    FROM log.StokCalismaLog
    ORDER BY LogId DESC;

    DECLARE @TipMapEksik int = (
        SELECT COUNT(DISTINCT h.TipId)
        FROM src.vw_StokHareket h
        LEFT JOIN ref.IrsTipGrupMap m ON m.TipId=h.TipId AND m.AktifMi=1
        WHERE h.HareketTarihi >= DATEADD(day,-30,CONVERT(date,SYSDATETIME()))
          AND m.TipId IS NULL
    );

    SELECT Metin = CONCAT('Risk job durumu: ', COALESCE(@RiskDurum,'-'),
                          ' (', COALESCE(CONVERT(varchar(16), @RiskZaman, 120), '-'), ')')
    UNION ALL
    SELECT CONCAT('Stok job durumu: ', COALESCE(@StokDurum,'-'),
                  ' (', COALESCE(CONVERT(varchar(16), @StokZaman, 120), '-'), ')')
    UNION ALL
    SELECT CASE
        WHEN @TipMapEksik = 0 THEN 'Tip map eksigi yok.'
        ELSE CONCAT('Tip map eksik: ', @TipMapEksik)
    END;
END
GO
