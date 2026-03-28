/* 07_seed.sql
   Başlangıç parametreleri / ağırlıklar / örnek mapping
*/
USE BKMDenetim;
GO

/* Mekan kapsam: örnek (kendi mekânlarını yaz) */
IF NOT EXISTS (SELECT 1 FROM ref.AyarMekanKapsam)
BEGIN
    -- TODO: gerçek mekânları buraya gir
    INSERT INTO ref.AyarMekanKapsam (MekanId, AktifMi, Aciklama)
    VALUES (1,1,N'Örnek'),(2,1,N'Örnek');
END
GO

/* Risk parametreleri */
MERGE ref.RiskParam AS t
USING (VALUES
    ('IadeOranEsik',         NULL, CAST(20.0 AS decimal(18,6)), NULL, N'İade oranı % eşiği'),
    ('NetBirikimAdetEsik',   NULL, CAST(10.0 AS decimal(18,6)), NULL, N'Net birikim adet eşiği'),
    ('IcKullanimTutarEsik',  NULL, CAST(1000.0 AS decimal(18,6)), NULL, N'İç kullanım tutar eşiği'),
    ('BozukAdetEsik',        NULL, CAST(5.0 AS decimal(18,6)), NULL, N'Bozuk/İmha adet eşiği'),
    ('SayimDuzeltmeAdetEsik',NULL, CAST(10.0 AS decimal(18,6)), NULL, N'Sayım+düzeltme adet eşiği'),
    ('HizliDevirOranEsik',   NULL, CAST(0.80 AS decimal(18,6)), NULL, N'Hızlı devir oran eşiği'),
    ('SatisYaslanmaGunEsik', 90,   NULL, NULL, N'Satış yaşlanma gün eşiği')
) AS s(ParamKodu, DegerInt, DegerDec, DegerStr, Aciklama)
ON t.ParamKodu=s.ParamKodu
WHEN MATCHED THEN
    UPDATE SET t.DegerInt=s.DegerInt, t.DegerDec=s.DegerDec, t.DegerStr=s.DegerStr, t.Aciklama=s.Aciklama, t.GuncellemeTarihi=SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (ParamKodu, DegerInt, DegerDec, DegerStr, Aciklama) VALUES (s.ParamKodu, s.DegerInt, s.DegerDec, s.DegerStr, s.Aciklama);
GO

/* Skor ağırlıkları */
MERGE ref.RiskSkorAgirlik AS t
USING (VALUES
    ('FlagVeriKalite',        25,  1, 1, N'Adet=0 ama tutar var / tutarsız satır'),
    ('FlagGirissizSatis',     20,  2, 1, N'Alış yok ama satış var'),
    ('FlagOluStok',           15,  3, 1, N'Alış var ama satış yok'),
    ('FlagNetBirikim',        10,  4, 1, N'Net birikim yüksek'),
    ('FlagIadeYuksek',        10,  5, 1, N'İade oranı yüksek'),
    ('FlagBozukIadeYuksek',   10,  6, 1, N'Bozuk/İmha yüksek'),
    ('FlagSayimDuzeltmeYuk',   8,  7, 1, N'Sayım+düzeltme yoğun'),
    ('FlagSirketIciYuksek',    8,  8, 1, N'İç kullanım yoğun'),
    ('FlagHizliDevir',         5,  9, 1, N'Hızlı devir'),
    ('FlagSatisYaslanma',      5, 10, 1, N'Satış yaşlanma')
) AS s(FlagKodu, Puan, Oncelik, AktifMi, Aciklama)
ON t.FlagKodu=s.FlagKodu
WHEN MATCHED THEN UPDATE SET t.Puan=s.Puan, t.Oncelik=s.Oncelik, t.AktifMi=s.AktifMi, t.Aciklama=s.Aciklama, t.GuncellemeTarihi=SYSDATETIME()
WHEN NOT MATCHED THEN INSERT (FlagKodu,Puan,Oncelik,AktifMi,Aciklama) VALUES (s.FlagKodu,s.Puan,s.Oncelik,s.AktifMi,s.Aciklama);
GO

/* Tip→Grup mapping (bildiklerimiz)
   Not: Eksik tipler sağlık kontrolünde WARN verir; tamamlayınca düzelt.
*/
MERGE ref.IrsTipGrupMap AS t
USING (VALUES
    (1,  'SATIS', N'Satış', NULL, 1),
    (4,  'SATIS', N'Satış', NULL, 1),
    (100,'SATIS', N'Satış', NULL, 1),

    (3,  'IADE',  N'Müşteri İade', NULL, 1),
    (5,  'IADE',  N'Müşteri İade', NULL, 1),
    (101,'IADE',  N'Müşteri İade', NULL, 1),

    (93, 'BOZUK', N'Bozuk/İmha', NULL, 1)

    -- TODO: ALIS / TRANSFER / SAYIM / DUZELTME / ICKULLANIM tiplerini ekle
) AS s(TipId,GrupKodu,GrupAdi,IslemAdi,AktifMi)
ON t.TipId=s.TipId
WHEN MATCHED THEN UPDATE SET t.GrupKodu=s.GrupKodu, t.GrupAdi=s.GrupAdi, t.IslemAdi=s.IslemAdi, t.AktifMi=s.AktifMi, t.GuncellemeTarihi=SYSDATETIME()
WHEN NOT MATCHED THEN INSERT (TipId,GrupKodu,GrupAdi,IslemAdi,AktifMi) VALUES (s.TipId,s.GrupKodu,s.GrupAdi,s.IslemAdi,s.AktifMi);
GO

/* Kaynak sistem / nesne (Dof icin secilebilir) */
MERGE ref.KaynakSistem AS t
USING (VALUES
    ('DERINSIS', N'DerinSIS', 1, N'ERP kaynak'),
    ('MANUEL',  N'Manuel', 1, N'Elle giris'),
    ('IMPORT',  N'Import', 1, N'Harici yukleme')
) AS s(SistemKodu, SistemAdi, AktifMi, Aciklama)
ON t.SistemKodu=s.SistemKodu
WHEN MATCHED THEN UPDATE SET t.SistemAdi=s.SistemAdi, t.AktifMi=s.AktifMi, t.Aciklama=s.Aciklama, t.GuncellemeTarihi=SYSDATETIME()
WHEN NOT MATCHED THEN INSERT (SistemKodu,SistemAdi,AktifMi,Aciklama) VALUES (s.SistemKodu,s.SistemAdi,s.AktifMi,s.Aciklama);
GO

MERGE ref.KaynakNesne AS t
USING (VALUES
    ('RISK_URUN_OZET', N'RiskUrunOzet', 1, N'Risk ozet kaydi'),
    ('STOK_HAREKET',   N'StokHareket', 1, N'Hareket kaydi'),
    ('KASA',           N'Kasa', 1, N'Kasa hareketi'),
    ('MUHASEBE',       N'Muhasebe', 1, N'Muhasebe fisleri')
) AS s(NesneKodu, NesneAdi, AktifMi, Aciklama)
ON t.NesneKodu=s.NesneKodu
WHEN MATCHED THEN UPDATE SET t.NesneAdi=s.NesneAdi, t.AktifMi=s.AktifMi, t.Aciklama=s.Aciklama, t.GuncellemeTarihi=SYSDATETIME()
WHEN NOT MATCHED THEN INSERT (NesneKodu,NesneAdi,AktifMi,Aciklama) VALUES (s.NesneKodu,s.NesneAdi,s.AktifMi,s.Aciklama);
GO

/* Personel ve kullanici ornekleri */
IF NOT EXISTS (SELECT 1 FROM ref.Personel)
BEGIN
    INSERT INTO ref.Personel (PersonelKodu, Ad, Soyad, Unvan, Birim, UstPersonelId, Eposta, Telefon, AktifMi)
    VALUES
        ('P001', N'Mert', N'Aydin', N'Genel Mudur', N'Operasyon', NULL, N'mert.aydin@bkmkitap.com', NULL, 1),
        ('P010', N'Ayse', N'Kaya', N'Denetci', N'Icerik Denetim', NULL, N'ayse.kaya@bkmkitap.com', NULL, 1),
        ('P011', N'Furkan', N'Yilmaz', N'Denetci', N'Icerik Denetim', NULL, N'furkan.yilmaz@bkmkitap.com', NULL, 1);

    UPDATE p
    SET UstPersonelId = u.PersonelId
    FROM ref.Personel p
    JOIN ref.Personel u ON u.PersonelKodu = 'P001'
    WHERE p.PersonelKodu IN ('P010','P011');
END
GO

IF NOT EXISTS (SELECT 1 FROM ref.Kullanici)
BEGIN
    INSERT INTO ref.Kullanici (KullaniciAdi, PersonelId, RolKodu, AktifMi)
    SELECT 'maydin', p.PersonelId, 'YONETICI', 1 FROM ref.Personel p WHERE p.PersonelKodu = 'P001';

    INSERT INTO ref.Kullanici (KullaniciAdi, PersonelId, RolKodu, AktifMi)
    SELECT 'akaya', p.PersonelId, 'DENETCI', 1 FROM ref.Personel p WHERE p.PersonelKodu = 'P010';

    INSERT INTO ref.Kullanici (KullaniciAdi, PersonelId, RolKodu, AktifMi)
    SELECT 'fyilmaz', p.PersonelId, 'DENETCI', 1 FROM ref.Personel p WHERE p.PersonelKodu = 'P011';
END
GO

IF NOT EXISTS (SELECT 1 FROM ref.KullaniciPersonel)
BEGIN
    INSERT INTO ref.KullaniciPersonel (KullaniciId, PersonelId, BaslangicTarihi, BitisTarihi, AktifMi, Aciklama)
    SELECT k.KullaniciId, p.PersonelId, DATEADD(hour, -2, SYSDATETIME()), NULL, 1, N'Guncel esleme'
    FROM ref.Kullanici k
    JOIN ref.Personel p ON p.PersonelId = k.PersonelId
    WHERE k.AktifMi = 1 AND p.AktifMi = 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM log.PersonelEntegrasyonLog)
BEGIN
    INSERT INTO log.PersonelEntegrasyonLog (KaynakSistem, BaslamaZamani, BitisZamani, Durum, Toplam, Eklenen, Guncellenen, PasifEdilen, Hata)
    VALUES ('DERINSIS', DATEADD(minute, -30, SYSDATETIME()), SYSDATETIME(), 'SUCCESS', 120, 3, 115, 2, NULL);
END
GO
