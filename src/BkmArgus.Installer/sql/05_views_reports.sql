/* 05_views_reports.sql */
USE BKMDenetim;
GO

IF OBJECT_ID(N'rpt.vw_RiskUrunOzet_Stok', N'V') IS NOT NULL DROP VIEW rpt.vw_RiskUrunOzet_Stok;
GO
CREATE VIEW rpt.vw_RiskUrunOzet_Stok
AS
SELECT
    r.*,
    StokBakiyeTarihi = s.Tarih,
    StokMiktar       = s.StokMiktar,
    FlagStokKaydiYok = CONVERT(bit, CASE WHEN s.Tarih IS NULL THEN 1 ELSE 0 END),
    FlagStokSifir    = CONVERT(bit, CASE WHEN s.Tarih IS NOT NULL AND s.StokMiktar=0 THEN 1 ELSE 0 END)
FROM rpt.RiskUrunOzet_Gunluk r
OUTER APPLY (
    SELECT TOP (1) b.Tarih, b.StokMiktar
    FROM rpt.StokBakiyeGunluk b
    WHERE b.MekanId=r.MekanId
      AND b.StokId=r.StokId
      AND b.Tarih <= DATEADD(day,-1,r.KesimGunu)
    ORDER BY b.Tarih DESC
) s;
GO

/* “Toplam” raporu: DB’de MekanId=0 yok; bu view toplamı hesaplar.
   Transfer double olmaması için sadece pozitif transfer net bacağı sayılır.
*/
IF OBJECT_ID(N'rpt.vw_RiskUrunOzet_Toplam', N'V') IS NOT NULL DROP VIEW rpt.vw_RiskUrunOzet_Toplam;
GO
CREATE VIEW rpt.vw_RiskUrunOzet_Toplam
AS
SELECT
    KesimGunu,
    KesimTarihi = MAX(KesimTarihi),
    DonemKodu,
    MekanId = 0,
    StokId,

    NetAdet  = SUM(NetAdet),
    BrutAdet = SUM(BrutAdet),
    NetTutar = SUM(NetTutar),
    BrutTutar= SUM(BrutTutar),

    -- transfer teki:
    TransferTekAdet  = SUM(CASE WHEN TransferNetAdet>0 THEN TransferNetAdet ELSE 0 END),
    TransferTekTutar = SUM(CASE WHEN TransferNetTutar>0 THEN TransferNetTutar ELSE 0 END),

    RiskSkor = MAX(RiskSkor),

    FlagVeriKalite       = MAX(CONVERT(int,FlagVeriKalite)),
    FlagGirissizSatis    = MAX(CONVERT(int,FlagGirissizSatis)),
    FlagOluStok          = MAX(CONVERT(int,FlagOluStok)),
    FlagNetBirikim       = MAX(CONVERT(int,FlagNetBirikim)),
    FlagIadeYuksek       = MAX(CONVERT(int,FlagIadeYuksek)),
    FlagBozukIadeYuksek  = MAX(CONVERT(int,FlagBozukIadeYuksek)),
    FlagSayimDuzeltmeYuk = MAX(CONVERT(int,FlagSayimDuzeltmeYuk)),
    FlagSirketIciYuksek  = MAX(CONVERT(int,FlagSirketIciYuksek)),
    FlagHizliDevir       = MAX(CONVERT(int,FlagHizliDevir)),
    FlagSatisYaslanma    = MAX(CONVERT(int,FlagSatisYaslanma))
FROM rpt.RiskUrunOzet_Gunluk r
JOIN src.vw_Mekan m ON m.MekanId=r.MekanId
GROUP BY KesimGunu, DonemKodu, StokId;
GO

IF OBJECT_ID(N'rpt.vw_RiskUrunOzet_Son', N'V') IS NOT NULL DROP VIEW rpt.vw_RiskUrunOzet_Son;
GO
CREATE VIEW rpt.vw_RiskUrunOzet_Son
AS
WITH x AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY KesimGunu, DonemKodu, MekanId, StokId ORDER BY KesimTarihi DESC)
    FROM rpt.RiskUrunOzet_Gunluk
)
SELECT * FROM x WHERE rn=1;
GO
