/* 11_sps_dashboard.sql
   Dashboard canli veriler
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'rpt.sp_Dashboard_Kpi', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_Kpi;
GO
CREATE PROCEDURE rpt.sp_Dashboard_Kpi
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kesim date = COALESCE(@KesimGunu, (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk));
    IF @Kesim IS NULL
        SET @Kesim = CONVERT(date, SYSDATETIME());

    DECLARE @KritikSkorEsik int = COALESCE((SELECT DegerInt FROM ref.RiskParam WHERE ParamKodu='KritikSkorEsik'), 80);

    DECLARE @KritikRisk int = (
        SELECT COUNT(*) FROM rpt.RiskUrunOzet_Gunluk
        WHERE KesimGunu=@Kesim AND DonemKodu='Son30Gun' AND RiskSkor >= @KritikSkorEsik
    );

    DECLARE @BekleyenDof int = (
        SELECT COUNT(*) FROM dof.DofKayit
        WHERE Durum <> 'KAPANDI'
    );

    DECLARE @TarananStok int = (
        SELECT COUNT(*) FROM rpt.RiskUrunOzet_Gunluk
        WHERE KesimGunu=@Kesim AND DonemKodu='Son30Gun'
    );

    SELECT Sira, Kodu, Deger, NotAciklama
    FROM (
        SELECT
            Sira = 1,
            Kodu = 'KRITIK_RISK',
            Deger = @KritikRisk,
            NotAciklama = CONCAT('Esik ', @KritikSkorEsik, '+')
        UNION ALL
        SELECT
            2,
            'BEKLEYEN_DOF',
            @BekleyenDof,
            'SLA takibi'
        UNION ALL
        SELECT
            3,
            'TARANAN_STOK',
            @TarananStok,
            'Son gece'
    ) x
    ORDER BY x.Sira;
END
GO

IF OBJECT_ID(N'rpt.sp_Dashboard_RiskTrend', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_RiskTrend;
GO
CREATE PROCEDURE rpt.sp_Dashboard_RiskTrend
    @Gun int = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kesim date = (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk);
    IF @Kesim IS NULL
        RETURN;

    DECLARE @Baslangic date = DATEADD(day, -ABS(@Gun) + 1, @Kesim);

    SELECT
        Tarih = r.KesimGunu,
        OrtalamaSkor = CAST(AVG(CAST(r.RiskSkor AS decimal(9,2))) AS decimal(9,2))
    FROM rpt.RiskUrunOzet_Gunluk r
    WHERE r.KesimGunu BETWEEN @Baslangic AND @Kesim
      AND r.DonemKodu = 'Son30Gun'
    GROUP BY r.KesimGunu
    ORDER BY r.KesimGunu;
END
GO

IF OBJECT_ID(N'rpt.sp_Dashboard_TopRisk', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_Dashboard_TopRisk;
GO
CREATE PROCEDURE rpt.sp_Dashboard_TopRisk
    @Top int = 10,
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kesim date = COALESCE(@KesimGunu, (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk));
    IF @Kesim IS NULL
        RETURN;

    SELECT TOP (@Top)
        MekanId = r.MekanId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', r.MekanId)),
        StokId = r.StokId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', r.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)),
        DonemKodu = r.DonemKodu,
        RiskSkor = r.RiskSkor,
        Flag = COALESCE(
            NULLIF(LTRIM(RTRIM(LEFT(r.RiskYorum, CHARINDEX('|', r.RiskYorum + '|') - 1))), ''),
            'YOK'
        )
    FROM rpt.RiskUrunOzet_Gunluk r
    LEFT JOIN src.vw_Mekan m ON m.MekanId = r.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = r.StokId
    WHERE r.KesimGunu = @Kesim
      AND r.DonemKodu = 'Son30Gun'
    ORDER BY r.RiskSkor DESC, r.MekanId, r.StokId;
END
GO

IF OBJECT_ID(N'dof.sp_Dashboard_Dof_Liste', N'P') IS NOT NULL DROP PROCEDURE dof.sp_Dashboard_Dof_Liste;
GO
CREATE PROCEDURE dof.sp_Dashboard_Dof_Liste
    @Top int = 5
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        Baslik,
        Sorumlu = COALESCE(NULLIF(LTRIM(RTRIM(Sorumlu)), ''), 'Atanmadi'),
        SLA = CASE
            WHEN SLA_HedefTarih IS NULL THEN 'Suresiz'
            ELSE CONCAT(DATEDIFF(day, CONVERT(date, SYSDATETIME()), SLA_HedefTarih), ' gun')
        END,
        Durum
    FROM dof.DofKayit
    WHERE Durum <> 'KAPANDI'
    ORDER BY RiskSeviyesi DESC, SLA_HedefTarih;
END
GO

IF OBJECT_ID(N'ref.sp_Dashboard_Ref_Ozet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_Dashboard_Ref_Ozet;
GO
CREATE PROCEDURE ref.sp_Dashboard_Ref_Ozet
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AktifMekan int = (SELECT COUNT(*) FROM src.vw_Mekan);
    DECLARE @ToplamTip int = (SELECT COUNT(*) FROM src.vw_IrsTip);
    DECLARE @MapliTip int = (SELECT COUNT(*) FROM ref.IrsTipGrupMap WHERE AktifMi=1);
    DECLARE @RiskParam int;
    IF COL_LENGTH('ref.RiskParam', 'AktifMi') IS NULL
        SET @RiskParam = (SELECT COUNT(*) FROM ref.RiskParam);
    ELSE
        SET @RiskParam = (SELECT COUNT(*) FROM ref.RiskParam WHERE AktifMi=1);

    SELECT Sira, Baslik, Deger, NotAciklama
    FROM (
        SELECT
            Sira = 1,
            Baslik = 'Mekan',
            Deger = CONCAT(@AktifMekan, ' mekan'),
            NotAciklama = 'Toplam mekan sayisi'
        UNION ALL
        SELECT
            2,
            'Tip map',
            CONCAT(@MapliTip, ' / ', @ToplamTip),
            'Mapli tip sayisi'
        UNION ALL
        SELECT
            3,
            'Risk param',
            CONCAT(@RiskParam, ' param'),
            'Esikler aktif'
    ) x
    ORDER BY x.Sira;
END
GO
