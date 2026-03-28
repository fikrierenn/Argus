/* 03_views_src.sql
   ERP bağımlılığını tek noktaya toplar.
   NOT: DerinSIS DB adı/şema farklıysa bu dosyayı güncelle.
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'src.vw_StokHareket', N'V') IS NOT NULL DROP VIEW src.vw_StokHareket;
GO
CREATE VIEW src.vw_StokHareket
AS
SELECT
    HrkId         = h.hrkID,
    EvrakId       = h.ehID,
    StokId        = h.ehstkID,
    MekanId       = h.ehMekan,
    AltDepoId     = h.ehAltDepo,
    EvrakTarihi   = h.ehTrhS,
    HareketTarihi = h.hrkTarih,
    TipId         = h.ehTip,
    Adet          = CAST(h.ehAdetN AS decimal(18,3)),
    Tutar         = CAST(h.ehTutarN AS decimal(18,3)),
    Maliyet       = CAST(h.ehMlyt  AS decimal(18,5)),
    TutarOzel     = CAST(h.ehTutarOzl AS decimal(18,3))
FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK);
GO

IF OBJECT_ID(N'src.vw_EvrakBaslik', N'V') IS NOT NULL DROP VIEW src.vw_EvrakBaslik;
GO
CREATE VIEW src.vw_EvrakBaslik
AS
SELECT
    EvrakId      = i.eID,
    EvrakNo      = i.eNo,
    MekanId      = i.eMekan,
    EvrakTarihiS = i.eTarihS,
    EvrakTarihi  = i.eTarih,
    GirisCikis   = i.eGC,
    TipId        = i.eTip,
    Durum        = i.eDurum,
    AltDepoId    = i.eAltDepo
FROM DerinSISBkm.dbo.irs i WITH (NOLOCK);
GO

IF OBJECT_ID(N'src.vw_EvrakDetay', N'V') IS NOT NULL DROP VIEW src.vw_EvrakDetay;
GO
CREATE VIEW src.vw_EvrakDetay
AS
SELECT
    EvrakId     = a.ehID,
    Sira        = a.ehSira,
    StokId      = a.ehStkID,
    Adet        = CAST(a.ehAdetN AS decimal(18,3)),
    Tutar       = CAST(a.ehTutar AS decimal(18,3)),
    Indirim     = CAST(a.ehIndirim AS decimal(18,3)),
    TutarKDV    = CAST(a.ehTutarKDV AS decimal(18,3)),
    KDV         = a.ehKDV,
    Maliyet     = CAST(a.ehMaliyet AS decimal(18,3))
FROM DerinSISBkm.dbo.irsAyr a WITH (NOLOCK);
GO

/* Ürün/mekan zenginleştirme view’leri opsiyoneldir.
   ERP tarafında karşılığı netleşince buraya ekle.
*/

IF OBJECT_ID(N'src.vw_IrsTip', N'V') IS NOT NULL DROP VIEW src.vw_IrsTip;
GO
CREATE VIEW src.vw_IrsTip
AS
SELECT
    TipId  = t.TipId,
    TipAdi = t.TipAd
FROM DerinSISBkm.dbo.irsTip_vw t WITH (NOLOCK);
GO

IF OBJECT_ID(N'src.vw_Mekan', N'V') IS NOT NULL DROP VIEW src.vw_Mekan;
GO
CREATE VIEW src.vw_Mekan
AS
SELECT
    MekanId = m.mekanID,
    MekanAd = m.mekanAd
FROM DerinSISBkm.dbo.Mekan_vw m WITH (NOLOCK)
WHERE m.mekantip = 2;
GO

IF OBJECT_ID(N'src.vw_Urun', N'V') IS NOT NULL DROP VIEW src.vw_Urun;
GO
CREATE VIEW src.vw_Urun
AS
SELECT
    StokId    = u.stkID,
    UrunKod   = u.stkKod,
    Barkod    = u.BarkodAna,
    UrunAd    = u.stkAd,
    UrunDurum = u.UrunDurum,
    MarkaId   = u.mrkID,
    MarkaAd   = u.mrkAd,
    ReyonId   = u.ReyonId,
    ReyonAd   = u.ReyonAd,
    Kategori3 = u.Kategori3
FROM DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK);
GO
