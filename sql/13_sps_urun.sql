/* 13_sps_urun.sql
   Urun detay ve hareket listesi
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'rpt.sp_UrunDetay_Getir', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_UrunDetay_Getir;
GO
CREATE PROCEDURE rpt.sp_UrunDetay_Getir
    @StokId int,
    @MekanId int = NULL,
    @DonemKodu varchar(10) = 'Son30Gun',
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StokId IS NULL OR @StokId <= 0
        THROW 50000, 'StokId zorunludur', 1;

    DECLARE @Kesim date = COALESCE(@KesimGunu, (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk));
    IF @Kesim IS NULL
        RETURN;

    DECLARE @IadeOranEsik decimal(9,2) =
        COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='IadeOranEsik'), 0);

    ;WITH Secilen AS (
        SELECT TOP 1 r.*
        FROM rpt.vw_RiskUrunOzet_Stok r
        WHERE r.KesimGunu = @Kesim
          AND r.DonemKodu = @DonemKodu
          AND r.StokId = @StokId
          AND (@MekanId IS NULL OR r.MekanId = @MekanId)
        ORDER BY CASE WHEN r.MekanId=@MekanId THEN 0 ELSE 1 END,
                 r.RiskSkor DESC,
                 r.MekanId
    )
    SELECT
        StokId = s.StokId,
        MekanId = s.MekanId,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', s.MekanId)),
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', s.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', s.StokId)),
        Kategori3 = u.Kategori3,
        DonemKodu = s.DonemKodu,
        RiskSkor = s.RiskSkor,
        RiskYorum = s.RiskYorum,
        IadeOranEsik = @IadeOranEsik,
        IadeOraniYuzde = s.IadeOraniYuzde,
        StokMiktar = COALESCE(s.StokMiktar, 0),
        StokBakiyeTarihi = s.StokBakiyeTarihi,
        SonSatisTarihi = s.SonSatisTarihi,
        FlagStokYok = CONVERT(bit, CASE WHEN s.FlagStokKaydiYok=1 OR s.FlagStokSifir=1 THEN 1 ELSE 0 END)
    FROM Secilen s
    LEFT JOIN src.vw_Mekan m ON m.MekanId = s.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = s.StokId;
END
GO

IF OBJECT_ID(N'rpt.sp_UrunRiskFlag_Liste', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_UrunRiskFlag_Liste;
GO
CREATE PROCEDURE rpt.sp_UrunRiskFlag_Liste
    @StokId int,
    @MekanId int = NULL,
    @DonemKodu varchar(10) = 'Son30Gun',
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StokId IS NULL OR @StokId <= 0
        THROW 50000, 'StokId zorunludur', 1;

    DECLARE @Kesim date = COALESCE(@KesimGunu, (SELECT MAX(KesimGunu) FROM rpt.RiskUrunOzet_Gunluk));
    IF @Kesim IS NULL
        RETURN;

    ;WITH Secilen AS (
        SELECT TOP 1 r.*
        FROM rpt.vw_RiskUrunOzet_Stok r
        WHERE r.KesimGunu = @Kesim
          AND r.DonemKodu = @DonemKodu
          AND r.StokId = @StokId
          AND (@MekanId IS NULL OR r.MekanId = @MekanId)
        ORDER BY CASE WHEN r.MekanId=@MekanId THEN 0 ELSE 1 END,
                 r.RiskSkor DESC,
                 r.MekanId
    ),
    Flags AS (
        SELECT * FROM (
            SELECT 'FlagVeriKalite' AS FlagKodu, FlagVal = s.FlagVeriKalite, DefaultAciklama = 'Veri kalitesi sorunu', DefaultEtki = 0 FROM Secilen s
            UNION ALL SELECT 'FlagGirissizSatis', s.FlagGirissizSatis, 'Satis var ama alis yok', 0 FROM Secilen s
            UNION ALL SELECT 'FlagOluStok', s.FlagOluStok, 'Alis var ama satis yok', 0 FROM Secilen s
            UNION ALL SELECT 'FlagNetBirikim', s.FlagNetBirikim, 'Net birikim yuksek', 0 FROM Secilen s
            UNION ALL SELECT 'FlagIadeYuksek', s.FlagIadeYuksek, 'Iade orani yuksek', 0 FROM Secilen s
            UNION ALL SELECT 'FlagBozukIadeYuksek', s.FlagBozukIadeYuksek, 'Bozuk/Imha yuksek', 0 FROM Secilen s
            UNION ALL SELECT 'FlagSayimDuzeltmeYuk', s.FlagSayimDuzeltmeYuk, 'Sayim+Duzeltme yuksek', 0 FROM Secilen s
            UNION ALL SELECT 'FlagSirketIciYuksek', s.FlagSirketIciYuksek, 'Ic kullanim yuksek', 0 FROM Secilen s
            UNION ALL SELECT 'FlagHizliDevir', s.FlagHizliDevir, 'Hizli devir', 0 FROM Secilen s
            UNION ALL SELECT 'FlagSatisYaslanma', s.FlagSatisYaslanma, 'Satis yaslanma', 0 FROM Secilen s
            UNION ALL SELECT 'FlagStokYok',
                CONVERT(bit, CASE WHEN s.FlagStokKaydiYok=1 OR s.FlagStokSifir=1 THEN 1 ELSE 0 END),
                'Stok kaydi yok veya sifir', 0 FROM Secilen s
        ) f
    )
    SELECT
        Flag = f.FlagKodu,
        Aciklama = COALESCE(w.Aciklama, f.DefaultAciklama),
        Etki = COALESCE(w.Puan, f.DefaultEtki)
    FROM Flags f
    LEFT JOIN ref.RiskSkorAgirlik w ON w.FlagKodu = f.FlagKodu AND w.AktifMi=1
    WHERE f.FlagVal = 1
    ORDER BY COALESCE(w.Oncelik, 999), f.FlagKodu;
END
GO

IF OBJECT_ID(N'rpt.sp_UrunHareket_Liste', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_UrunHareket_Liste;
GO
CREATE PROCEDURE rpt.sp_UrunHareket_Liste
    @StokId int,
    @MekanId int = NULL,
    @Top int = 30
AS
BEGIN
    SET NOCOUNT ON;

    IF @StokId IS NULL OR @StokId <= 0
        THROW 50000, 'StokId zorunludur', 1;

    SELECT TOP (@Top)
        Tarih = h.HareketTarihi,
        MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', h.MekanId)),
        HareketTipi = COALESCE(g.GrupAdi, g.GrupKodu, 'Diger'),
        Tip = COALESCE(t.TipAdi, CONCAT('Tip-', h.TipId)),
        Islem = COALESCE(g.IslemAdi, g.GrupAdi, g.GrupKodu),
        EvrakNo = COALESCE(CONVERT(varchar(40), e.EvrakNo), CONCAT('E-', h.EvrakId)),
        BirimFiyat = CAST(ABS(h.Tutar) / NULLIF(ABS(h.Adet), 0) AS decimal(18,2)),
        Giris = CASE WHEN h.Adet > 0 THEN h.Adet END,
        Cikis = CASE WHEN h.Adet < 0 THEN ABS(h.Adet) END,
        Kalan = CAST(SUM(h.Adet) OVER (
            PARTITION BY h.MekanId
            ORDER BY h.HareketTarihi, h.HrkId
            ROWS UNBOUNDED PRECEDING
        ) AS decimal(18,3)),
        Tutar = h.Tutar,
        Maliyet = h.Maliyet,
        [Not] = CONCAT('Evrak ', h.EvrakId)
    FROM src.vw_StokHareket h
    LEFT JOIN src.vw_Mekan m ON m.MekanId = h.MekanId
    LEFT JOIN src.vw_EvrakBaslik e ON e.EvrakId = h.EvrakId
    LEFT JOIN ref.IrsTipGrupMap g ON g.TipId = h.TipId AND g.AktifMi=1
    LEFT JOIN src.vw_IrsTip t ON t.TipId = h.TipId
    WHERE h.StokId = @StokId
      AND (@MekanId IS NULL OR h.MekanId = @MekanId)
      AND h.AltDepoId = 0
    ORDER BY h.HareketTarihi DESC, h.HrkId DESC;
END
GO
