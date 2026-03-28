/* 09_sps_yonetim.sql
   Yonetim SP'leri: personel entegrasyon ozet/log ve kullanici-personel esleme
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'log.sp_PersonelEntegrasyon_Ozet', N'P') IS NOT NULL DROP PROCEDURE log.sp_PersonelEntegrasyon_Ozet;
GO
CREATE PROCEDURE log.sp_PersonelEntegrasyon_Ozet
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        KaynakSistem,
        SonCalisma = COALESCE(BitisZamani, BaslamaZamani),
        SonrakiCalisma = CASE
            WHEN COALESCE(BitisZamani, BaslamaZamani) IS NULL THEN NULL
            ELSE DATEADD(day, 1, COALESCE(BitisZamani, BaslamaZamani))
        END,
        Toplam,
        Eklenen,
        Guncellenen,
        PasifEdilen
    FROM log.PersonelEntegrasyonLog
    ORDER BY LogId DESC;
END
GO

IF OBJECT_ID(N'log.sp_PersonelEntegrasyon_Log_Liste', N'P') IS NOT NULL DROP PROCEDURE log.sp_PersonelEntegrasyon_Log_Liste;
GO
CREATE PROCEDURE log.sp_PersonelEntegrasyon_Log_Liste
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        Tarih = COALESCE(BitisZamani, BaslamaZamani),
        Durum,
        Toplam,
        NotAciklama = Hata
    FROM log.PersonelEntegrasyonLog
    ORDER BY LogId DESC;
END
GO

IF OBJECT_ID(N'ref.sp_KullaniciPersonel_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KullaniciPersonel_Liste;
GO
CREATE PROCEDURE ref.sp_KullaniciPersonel_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        kp.BaglantiId,
        k.KullaniciAdi,
        PersonelAd = CONCAT(p.Ad, ' ', p.Soyad),
        k.RolKodu,
        kp.BaslangicTarihi,
        kp.AktifMi
    FROM ref.KullaniciPersonel kp
    INNER JOIN ref.Kullanici k ON k.KullaniciId = kp.KullaniciId
    INNER JOIN ref.Personel p ON p.PersonelId = kp.PersonelId
    ORDER BY kp.AktifMi DESC, kp.BaslangicTarihi DESC;
END
GO

IF OBJECT_ID(N'ref.sp_KullaniciPersonel_Kapat', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KullaniciPersonel_Kapat;
GO
CREATE PROCEDURE ref.sp_KullaniciPersonel_Kapat
    @BaglantiId bigint,
    @KullaniciId int = NULL,
    @Aciklama nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @BaglantiId IS NULL OR @BaglantiId <= 0
        THROW 50000, 'BaglantiId zorunludur', 1;

    UPDATE ref.KullaniciPersonel
    SET
        AktifMi = 0,
        BitisTarihi = COALESCE(BitisTarihi, SYSDATETIME()),
        Aciklama = COALESCE(@Aciklama, Aciklama),
        GuncelleyenKullaniciId = @KullaniciId,
        GuncellemeTarihi = SYSDATETIME()
    WHERE BaglantiId = @BaglantiId
      AND AktifMi = 1;
END
GO

IF OBJECT_ID(N'ref.sp_KullaniciPersonel_GunSonuKapat', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KullaniciPersonel_GunSonuKapat;
GO
CREATE PROCEDURE ref.sp_KullaniciPersonel_GunSonuKapat
    @KullaniciId int = NULL,
    @Aciklama nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ref.KullaniciPersonel
    SET
        AktifMi = 0,
        BitisTarihi = COALESCE(BitisTarihi, SYSDATETIME()),
        Aciklama = COALESCE(@Aciklama, Aciklama),
        GuncelleyenKullaniciId = @KullaniciId,
        GuncellemeTarihi = SYSDATETIME()
    WHERE AktifMi = 1;
END
GO
