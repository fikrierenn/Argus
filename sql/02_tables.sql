/* 02_tables.sql
   Tablolar: ref + rpt + dof + ai + log
*/
USE BKMDenetim;
GO

/* ===== ref ===== */

IF OBJECT_ID(N'ref.AyarMekanKapsam', N'U') IS NULL
BEGIN
    CREATE TABLE ref.AyarMekanKapsam
    (
        MekanId      int         NOT NULL PRIMARY KEY,
        AktifMi      bit         NOT NULL CONSTRAINT DF_AyarMekanKapsam_AktifMi DEFAULT(1),
        Aciklama     nvarchar(100) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_AyarMekanKapsam_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_AyarMekanKapsam_Guncelleme DEFAULT (SYSDATETIME())
    );
END
GO

IF OBJECT_ID(N'ref.IrsTipGrupMap', N'U') IS NULL
BEGIN
    CREATE TABLE ref.IrsTipGrupMap
    (
        TipId        tinyint      NOT NULL PRIMARY KEY,
        GrupKodu     varchar(30)  NOT NULL,
        GrupAdi      nvarchar(60) NOT NULL,
        IslemAdi     nvarchar(60) NULL,
        AktifMi      bit          NOT NULL CONSTRAINT DF_IrsTipGrupMap_AktifMi DEFAULT(1),
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_IrsTipGrupMap_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_IrsTipGrupMap_Guncelleme DEFAULT (SYSDATETIME())
    );

    CREATE INDEX IX_IrsTipGrupMap_GrupKodu ON ref.IrsTipGrupMap (GrupKodu);
END
GO

IF OBJECT_ID(N'ref.RiskParam', N'U') IS NULL
BEGIN
    CREATE TABLE ref.RiskParam
    (
        ParamKodu    varchar(50)  NOT NULL PRIMARY KEY,
        DegerInt     int          NULL,
        DegerDec     decimal(18,6) NULL,
        DegerStr     nvarchar(200) NULL,
        AktifMi      bit          NOT NULL CONSTRAINT DF_RiskParam_AktifMi DEFAULT(1),
        Aciklama     nvarchar(200) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_RiskParam_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_RiskParam_Guncelleme DEFAULT (SYSDATETIME())
    );
END
GO

IF COL_LENGTH('ref.RiskParam', 'AktifMi') IS NULL
BEGIN
    ALTER TABLE ref.RiskParam ADD AktifMi bit NOT NULL CONSTRAINT DF_RiskParam_AktifMi DEFAULT(1);
END
GO

IF OBJECT_ID(N'ref.RiskSkorAgirlik', N'U') IS NULL
BEGIN
    CREATE TABLE ref.RiskSkorAgirlik
    (
        FlagKodu     varchar(50) NOT NULL PRIMARY KEY,
        Puan         int         NOT NULL,
        Oncelik      int         NOT NULL,
        AktifMi      bit         NOT NULL CONSTRAINT DF_RiskSkorAgirlik_AktifMi DEFAULT(1),
        Aciklama     nvarchar(200) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_RiskSkorAgirlik_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_RiskSkorAgirlik_Guncelleme DEFAULT (SYSDATETIME())
    );
END
GO

IF OBJECT_ID(N'ref.KaynakSistem', N'U') IS NULL
BEGIN
    CREATE TABLE ref.KaynakSistem
    (
        SistemKodu   varchar(30)  NOT NULL PRIMARY KEY,
        SistemAdi    nvarchar(80) NOT NULL,
        AktifMi      bit          NOT NULL CONSTRAINT DF_KaynakSistem_AktifMi DEFAULT(1),
        Aciklama     nvarchar(200) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_KaynakSistem_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_KaynakSistem_Guncelleme DEFAULT (SYSDATETIME())
    );
END
GO

IF OBJECT_ID(N'ref.KaynakNesne', N'U') IS NULL
BEGIN
    CREATE TABLE ref.KaynakNesne
    (
        NesneKodu    varchar(50)  NOT NULL PRIMARY KEY,
        NesneAdi     nvarchar(80) NOT NULL,
        AktifMi      bit          NOT NULL CONSTRAINT DF_KaynakNesne_AktifMi DEFAULT(1),
        Aciklama     nvarchar(200) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_KaynakNesne_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_KaynakNesne_Guncelleme DEFAULT (SYSDATETIME())
    );
END
GO

IF OBJECT_ID(N'ref.Personel', N'U') IS NULL
BEGIN
    CREATE TABLE ref.Personel
    (
        PersonelId    int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PersonelKodu  varchar(30) NULL,
        Ad            nvarchar(60) NOT NULL,
        Soyad         nvarchar(60) NOT NULL,
        Unvan         nvarchar(80) NULL,
        Birim         nvarchar(80) NULL,
        UstPersonelId int NULL,
        Eposta        nvarchar(120) NULL,
        Telefon       nvarchar(30) NULL,
        AktifMi       bit NOT NULL CONSTRAINT DF_Personel_AktifMi DEFAULT(1),
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_Personel_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_Personel_Guncelleme DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_Personel_UstPersonel FOREIGN KEY (UstPersonelId) REFERENCES ref.Personel(PersonelId)
    );

    CREATE UNIQUE INDEX UX_Personel_PersonelKodu ON ref.Personel (PersonelKodu) WHERE PersonelKodu IS NOT NULL;
    CREATE INDEX IX_Personel_UstPersonelId ON ref.Personel (UstPersonelId);
END
GO

IF OBJECT_ID(N'ref.Kullanici', N'U') IS NULL
BEGIN
    CREATE TABLE ref.Kullanici
    (
        KullaniciId     int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        KullaniciAdi    varchar(60) NOT NULL UNIQUE,
        PersonelId      int NULL,
        RolKodu         varchar(30) NULL,
        AktifMi         bit NOT NULL CONSTRAINT DF_Kullanici_AktifMi DEFAULT(1),
        SonGirisTarihi  datetime2(0) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_Kullanici_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_Kullanici_Guncelleme DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_Kullanici_Personel FOREIGN KEY (PersonelId) REFERENCES ref.Personel(PersonelId)
    );
END
GO

IF OBJECT_ID(N'ref.KullaniciPersonel', N'U') IS NULL
BEGIN
    CREATE TABLE ref.KullaniciPersonel
    (
        BaglantiId      bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        KullaniciId     int NOT NULL,
        PersonelId      int NOT NULL,
        BaslangicTarihi datetime2(0) NOT NULL CONSTRAINT DF_KullaniciPersonel_Baslangic DEFAULT (SYSDATETIME()),
        BitisTarihi     datetime2(0) NULL,
        AktifMi         bit NOT NULL CONSTRAINT DF_KullaniciPersonel_AktifMi DEFAULT(1),
        Aciklama        nvarchar(200) NULL,
        OlusturanKullaniciId int NULL,
        GuncelleyenKullaniciId int NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_KullaniciPersonel_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_KullaniciPersonel_Guncelleme DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_KullaniciPersonel_Kullanici FOREIGN KEY (KullaniciId) REFERENCES ref.Kullanici(KullaniciId),
        CONSTRAINT FK_KullaniciPersonel_Personel FOREIGN KEY (PersonelId) REFERENCES ref.Personel(PersonelId)
    );

    CREATE UNIQUE INDEX UX_KullaniciPersonel_Aktif ON ref.KullaniciPersonel (KullaniciId) WHERE AktifMi = 1;
    CREATE INDEX IX_KullaniciPersonel_PersonelId ON ref.KullaniciPersonel (PersonelId);
END
GO

/* ===== rpt ===== */

IF OBJECT_ID(N'rpt.RiskUrunOzet_Gunluk', N'U') IS NULL
BEGIN
    CREATE TABLE rpt.RiskUrunOzet_Gunluk
    (
        KesimTarihi      datetime2(0) NOT NULL,
        KesimGunu        AS (CONVERT(date, KesimTarihi)) PERSISTED,
        DonemKodu        varchar(10)  NOT NULL,  -- Son30Gun / AyBasi
        MekanId          int          NOT NULL,
        StokId           int          NOT NULL,

        -- toplam net/brüt
        NetAdet          decimal(18,3) NOT NULL,
        BrutAdet         decimal(18,3) NOT NULL,
        NetTutar         decimal(18,3) NOT NULL,
        BrutTutar        decimal(18,3) NOT NULL,

        -- grup bazlı (örnek set)
        AlisBrutAdet     decimal(18,3) NOT NULL,
        SatisBrutAdet    decimal(18,3) NOT NULL,
        IadeBrutAdet     decimal(18,3) NOT NULL,
        TransferBrutAdet decimal(18,3) NOT NULL,
        TransferNetAdet  decimal(18,3) NOT NULL,
        SayimBrutAdet    decimal(18,3) NOT NULL,
        DuzeltmeBrutAdet decimal(18,3) NOT NULL,
        IcKullanimBrutAdet decimal(18,3) NOT NULL,
        BozukBrutAdet    decimal(18,3) NOT NULL,

        AlisBrutTutar     decimal(18,3) NOT NULL,
        SatisBrutTutar    decimal(18,3) NOT NULL,
        IadeBrutTutar     decimal(18,3) NOT NULL,
        TransferBrutTutar decimal(18,3) NOT NULL,
        TransferNetTutar  decimal(18,3) NOT NULL,
        SayimBrutTutar    decimal(18,3) NOT NULL,
        DuzeltmeBrutTutar decimal(18,3) NOT NULL,
        IcKullanimBrutTutar decimal(18,3) NOT NULL,
        BozukBrutTutar    decimal(18,3) NOT NULL,

        -- yardımcı metrikler
        SonSatisTarihi   datetime2(0) NULL,
        SatisYasiGun     int          NULL,
        AdetSifirTutarVarSatir int    NOT NULL,

        IadeOraniYuzde   decimal(9,2) NULL,

        -- flagler
        FlagVeriKalite       bit NOT NULL,
        FlagGirissizSatis    bit NOT NULL,
        FlagOluStok          bit NOT NULL,
        FlagNetBirikim       bit NOT NULL,
        FlagIadeYuksek       bit NOT NULL,
        FlagBozukIadeYuksek  bit NOT NULL,
        FlagSayimDuzeltmeYuk bit NOT NULL,
        FlagSirketIciYuksek  bit NOT NULL,
        FlagHizliDevir       bit NOT NULL,
        FlagSatisYaslanma    bit NOT NULL,

        RiskSkor         int NOT NULL,
        RiskYorum        nvarchar(500) NULL,

        CONSTRAINT PK_RiskUrunOzet_Gunluk PRIMARY KEY CLUSTERED (KesimTarihi, DonemKodu, MekanId, StokId)
    );

    -- günde tek snapshot: (KesimGunu, DonemKodu, MekanId, StokId) unique
    CREATE UNIQUE INDEX UX_RiskUrunOzet_KesimGunu
    ON rpt.RiskUrunOzet_Gunluk (KesimGunu, DonemKodu, MekanId, StokId)
    WITH (IGNORE_DUP_KEY = OFF);

    CREATE INDEX IX_RiskUrunOzet_Rapor
    ON rpt.RiskUrunOzet_Gunluk (KesimGunu, DonemKodu, MekanId)
    INCLUDE (RiskSkor, BrutTutar, FlagNetBirikim, FlagSatisYaslanma, FlagVeriKalite);
END
GO

IF OBJECT_ID(N'rpt.StokBakiyeGunluk', N'U') IS NULL
BEGIN
    CREATE TABLE rpt.StokBakiyeGunluk
    (
        Tarih        date         NOT NULL,
        MekanId      int          NOT NULL,
        StokId       int          NOT NULL,
        StokMiktar   decimal(18,3) NOT NULL,
        CONSTRAINT PK_StokBakiyeGunluk PRIMARY KEY CLUSTERED (Tarih, MekanId, StokId)
    );

    CREATE INDEX IX_StokBakiyeGunluk_MekanStok
    ON rpt.StokBakiyeGunluk (MekanId, StokId, Tarih) INCLUDE (StokMiktar);
END
GO

IF OBJECT_ID(N'rpt.RiskUrunOzet_Aylik', N'U') IS NULL
BEGIN
    CREATE TABLE rpt.RiskUrunOzet_Aylik
    (
        DonemAy       int          NOT NULL,  -- YYYYMM
        DonemKodu     varchar(10)  NOT NULL,
        MekanId       int          NOT NULL,
        StokId        int          NOT NULL,
        KesimTarihi   datetime2(0) NOT NULL,

        NetAdet       decimal(18,3) NOT NULL,
        BrutAdet      decimal(18,3) NOT NULL,
        NetTutar      decimal(18,3) NOT NULL,
        BrutTutar     decimal(18,3) NOT NULL,
        RiskSkor      int NOT NULL,

        FlagVeriKalite       bit NOT NULL,
        FlagGirissizSatis    bit NOT NULL,
        FlagOluStok          bit NOT NULL,
        FlagNetBirikim       bit NOT NULL,
        FlagIadeYuksek       bit NOT NULL,
        FlagBozukIadeYuksek  bit NOT NULL,
        FlagSayimDuzeltmeYuk bit NOT NULL,
        FlagSirketIciYuksek  bit NOT NULL,
        FlagHizliDevir       bit NOT NULL,
        FlagSatisYaslanma    bit NOT NULL,

        RiskYorum     nvarchar(500) NULL,

        CONSTRAINT PK_RiskUrunOzet_Aylik PRIMARY KEY CLUSTERED (DonemAy, DonemKodu, MekanId, StokId)
    );
END
GO

/* ===== dof ===== */

IF OBJECT_ID(N'dof.DofKayit', N'U') IS NULL
BEGIN
    CREATE TABLE dof.DofKayit
    (
        DofId           bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DofImza         varchar(120) NOT NULL UNIQUE,

        KaynakSistemKodu varchar(30)  NOT NULL, -- ref.KaynakSistem
        KaynakNesneKodu  varchar(50)  NOT NULL, -- ref.KaynakNesne
        KaynakAnahtar    varchar(120) NULL,     -- serbest format

        Baslik          nvarchar(200) NOT NULL,
        Aciklama        nvarchar(max)  NULL,

        RiskSeviyesi    tinyint NOT NULL CONSTRAINT DF_DofKayit_RiskSeviyesi DEFAULT(1),
        SLA_HedefTarih  date NULL,

        Durum           varchar(20) NOT NULL CONSTRAINT DF_DofKayit_Durum DEFAULT('ACIK'),
        Olusturan       nvarchar(80) NOT NULL,
        Sorumlu         nvarchar(80) NULL,
        Onayci          nvarchar(80) NULL,
        OlusturanKullaniciId int NULL,
        SorumluPersonelId int NULL,
        OnayciPersonelId int NULL,

        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_DofKayit_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_DofKayit_Guncelleme DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_DofKayit_KaynakSistem FOREIGN KEY (KaynakSistemKodu) REFERENCES ref.KaynakSistem(SistemKodu),
        CONSTRAINT FK_DofKayit_KaynakNesne FOREIGN KEY (KaynakNesneKodu) REFERENCES ref.KaynakNesne(NesneKodu),
        CONSTRAINT FK_DofKayit_OlusturanKullanici FOREIGN KEY (OlusturanKullaniciId) REFERENCES ref.Kullanici(KullaniciId),
        CONSTRAINT FK_DofKayit_SorumluPersonel FOREIGN KEY (SorumluPersonelId) REFERENCES ref.Personel(PersonelId),
        CONSTRAINT FK_DofKayit_OnayciPersonel FOREIGN KEY (OnayciPersonelId) REFERENCES ref.Personel(PersonelId)
    );
END
GO

IF OBJECT_ID(N'dof.DofBulgu', N'U') IS NULL
BEGIN
    CREATE TABLE dof.DofBulgu
    (
        BulguId         bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DofId           bigint NOT NULL,
        BulguMetni      nvarchar(max) NOT NULL,
        KökNedenMetni   nvarchar(max) NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_DofBulgu_Olusturma DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_DofBulgu_DofKayit FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );
END
GO

IF OBJECT_ID(N'dof.DofAksiyon', N'U') IS NULL
BEGIN
    CREATE TABLE dof.DofAksiyon
    (
        AksiyonId       bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DofId           bigint NOT NULL,
        AksiyonMetni    nvarchar(max) NOT NULL,
        Sorumlu         nvarchar(80) NULL,
        HedefTarih      date NULL,
        TamamlandiMi    bit NOT NULL CONSTRAINT DF_DofAksiyon_Tamamlandi DEFAULT(0),
        TamamlanmaTarihi date NULL,
        CONSTRAINT FK_DofAksiyon_DofKayit FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );
END
GO

IF OBJECT_ID(N'dof.DofKanit', N'U') IS NULL
BEGIN
    CREATE TABLE dof.DofKanit
    (
        KanitId         bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DofId           bigint NOT NULL,
        KanitTuru       varchar(30) NOT NULL, -- SQL/PNG/PDF/CSV/NOT
        KanitYolu       nvarchar(400) NULL,   -- dosya yolu
        KanitMetni      nvarchar(max) NULL,   -- küçük kanıtlar
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_DofKanit_Olusturma DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_DofKanit_DofKayit FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );
END
GO

IF OBJECT_ID(N'dof.DofDurumGecmis', N'U') IS NULL
BEGIN
    CREATE TABLE dof.DofDurumGecmis
    (
        Id              bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DofId           bigint NOT NULL,
        EskiDurum       varchar(20) NOT NULL,
        YeniDurum       varchar(20) NOT NULL,
        Degistiren      nvarchar(80) NOT NULL,
        DegisimTarihi   datetime2(0) NOT NULL CONSTRAINT DF_DofDurumGecmis_Tarih DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_DofDurumGecmis_DofKayit FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );
END
GO

/* ===== ai ===== */

-- Orijinal AI Tabloları (V1 - Geriye Uyumluluk İçin)
IF OBJECT_ID(N'ai.AiAnalizIstegi', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAnalizIstegi
    (
        IstekId         bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        KesimTarihi     datetime2(0) NOT NULL,
        DonemKodu       varchar(10) NOT NULL,
        MekanId         int NOT NULL,
        StokId          int NOT NULL,
        KaynakTip       varchar(30) NOT NULL, -- RISK_OZET, DOF_KAYIT
        KaynakAnahtar   varchar(120) NULL,
        Oncelik         tinyint NOT NULL CONSTRAINT DF_AiAnalizIstegi_Oncelik DEFAULT(5),
        Durum           varchar(20) NOT NULL CONSTRAINT DF_AiAnalizIstegi_Durum DEFAULT('NEW'),
        DenemeSayisi    int NOT NULL CONSTRAINT DF_AiAnalizIstegi_DenemeSayisi DEFAULT(0),
        
        -- AI Analiz Sonuçları
        Baslik          nvarchar(200) NULL,
        OzetMetin       nvarchar(max) NULL,
        KokNedenAnalizi nvarchar(max) NULL,
        OnerilerJson    nvarchar(max) NULL,
        GuvenilirlikSkoru decimal(5,2) NULL,
        
        -- İş Akışı
        EvidencePlan    nvarchar(max) NULL,
        
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_AiAnalizIstegi_Olusturma DEFAULT (SYSDATETIME()),
        GuncellemeTarihi datetime2(0) NOT NULL CONSTRAINT DF_AiAnalizIstegi_Guncelleme DEFAULT (SYSDATETIME())
    );

    CREATE INDEX IX_AiAnalizIstegi_Durum ON ai.AiAnalizIstegi (Durum, Oncelik, OlusturmaTarihi);
    CREATE INDEX IX_AiAnalizIstegi_KesimTarihi ON ai.AiAnalizIstegi (KesimTarihi, DonemKodu, MekanId, StokId);
END
GO

IF OBJECT_ID(N'ai.AiGecmisVektorler', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiGecmisVektorler
    (
        VektorId        bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RiskId          bigint NOT NULL,
        DofId           bigint NULL,
        Baslik          nvarchar(200) NOT NULL,
        OzetMetin       nvarchar(max) NULL,
        KritikMi        bit NOT NULL CONSTRAINT DF_AiGecmisVektorler_KritikMi DEFAULT(0),
        VektorJson      nvarchar(max) NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_AiGecmisVektorler_Olusturma DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_AiGecmisVektorler_Dof FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );

    CREATE INDEX IX_AiGecmisVektorler_RiskId ON ai.AiGecmisVektorler (RiskId);
    CREATE INDEX IX_AiGecmisVektorler_DofId ON ai.AiGecmisVektorler (DofId);
    CREATE INDEX IX_AiGecmisVektorler_KritikMi ON ai.AiGecmisVektorler (KritikMi, OlusturmaTarihi);
END
GO

IF OBJECT_ID(N'ai.AiLlmSonuc', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiLlmSonuc
    (
        SonucId         bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IstekId         bigint NOT NULL,
        ModelAdi        varchar(100) NOT NULL,
        PromptMetni     nvarchar(max) NOT NULL,
        SonucMetni      nvarchar(max) NOT NULL,
        TokenSayisi     int NULL,
        SureMs          int NULL,
        GuvenSkoru      decimal(5,2) NULL,
        OlusturmaTarihi datetime2(0) NOT NULL CONSTRAINT DF_AiLlmSonuc_Olusturma DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_AiLlmSonuc_Istek FOREIGN KEY (IstekId) REFERENCES ai.AiAnalizIstegi(IstekId)
    );

    CREATE INDEX IX_AiLlmSonuc_IstekId ON ai.AiLlmSonuc (IstekId);
    CREATE INDEX IX_AiLlmSonuc_ModelAdi ON ai.AiLlmSonuc (ModelAdi, OlusturmaTarihi);
END
GO

-- AI V2 Geliştirme Tabloları (15_ai_enhancement_v2_tr.sql'den konsolide edildi)
-- Bu tablolar V1 tablolarıyla birlikte çalışacak şekilde tasarlandı

-- Migrasyon Takip Tablosu
IF OBJECT_ID(N'ai.AiMigrationStatus', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiMigrationStatus (
        MigrationId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ComponentName varchar(100) NOT NULL,
        OldVersion varchar(20) NOT NULL,
        NewVersion varchar(20) NOT NULL,
        MigrationDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        Status varchar(20) NOT NULL DEFAULT 'BEKLEMEDE', -- BEKLEMEDE, DEVAM_EDIYOR, TAMAMLANDI, BASARISIZ
        RecordsProcessed int DEFAULT 0,
        TotalRecords int DEFAULT 0,
        ErrorMessage nvarchar(max) NULL,
        StartTime datetime2(0) NULL,
        EndTime datetime2(0) NULL
    );
END
GO

-- Çok Boyutlu Embedding Sistemi
IF OBJECT_ID(N'ai.AiMultiModalEmbedding', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiMultiModalEmbedding (
        EmbeddingId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RiskId bigint NOT NULL,
        DofId bigint NULL,
        
        -- Çok boyutlu embedding türleri
        RiskPatternEmbedding nvarchar(max) NULL,    -- Risk desen vektörleri
        MetricEmbedding nvarchar(max) NULL,         -- Sayısal metrik vektörleri  
        TemporalEmbedding nvarchar(max) NULL,       -- Zaman bazlı desen vektörleri
        ContextEmbedding nvarchar(max) NULL,        -- Bağlamsal bilgi vektörleri
        
        -- Embedding meta verileri
        EmbeddingModel varchar(100) NOT NULL,
        EmbeddingVersion varchar(20) NOT NULL,
        VectorDimension int NOT NULL,
        
        -- Hafıza katmanı sınıflandırması
        MemoryLayer varchar(10) NOT NULL DEFAULT 'SICAK', -- SICAK, ILIK, SOGUK
        AccessCount int NOT NULL DEFAULT 0,
        LastAccessTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        -- Kalite metrikleri
        QualityScore decimal(5,2) NULL,
        ConfidenceScore decimal(5,2) NULL,
        
        -- Meta veriler
        SourceMetadata nvarchar(max) NULL,
        Tags nvarchar(500) NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT FK_AiMultiModalEmbedding_Dof FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );
    
    CREATE INDEX IX_AiMultiModalEmbedding_RiskId ON ai.AiMultiModalEmbedding (RiskId);
    CREATE INDEX IX_AiMultiModalEmbedding_MemoryLayer ON ai.AiMultiModalEmbedding (MemoryLayer, LastAccessTime);
    CREATE INDEX IX_AiMultiModalEmbedding_Model ON ai.AiMultiModalEmbedding (EmbeddingModel, EmbeddingVersion);
END
GO

-- Hafıza Katmanı Konfigürasyonu
IF OBJECT_ID(N'ai.AiMemoryLayerConfig', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiMemoryLayerConfig (
        LayerId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LayerName varchar(10) NOT NULL UNIQUE, -- SICAK, ILIK, SOGUK
        RetentionDays int NOT NULL,
        MaxCapacity int NOT NULL,
        AccessThreshold int NOT NULL,
        CompressionEnabled bit NOT NULL DEFAULT 0,
        AutoArchiveEnabled bit NOT NULL DEFAULT 1,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

-- Adaptif Benzerlik Eşikleri
IF OBJECT_ID(N'ai.AiSimilarityThreshold', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiSimilarityThreshold (
        ThresholdId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RiskType varchar(50) NOT NULL,
        EmbeddingType varchar(50) NOT NULL, -- RISK_DESENI, METRIK, ZAMANSAL, BAGLAMSAL
        BaseThreshold decimal(5,4) NOT NULL,
        AdaptiveThreshold decimal(5,4) NOT NULL,
        ConfidenceLevel decimal(5,2) NOT NULL,
        LastUpdateDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdateCount int NOT NULL DEFAULT 0,
        PerformanceScore decimal(5,2) NULL,
        IsActive bit NOT NULL DEFAULT 1
    );
    
    CREATE UNIQUE INDEX UX_AiSimilarityThreshold ON ai.AiSimilarityThreshold (RiskType, EmbeddingType);
END
GO

-- Çok Ajanlı LLM Sistemi
IF OBJECT_ID(N'ai.AiAgentConfig', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAgentConfig (
        AgentId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AgentName varchar(100) NOT NULL UNIQUE,
        AgentType varchar(50) NOT NULL, -- RISK_ANALISTI, KOK_NEDEN_UZMANI, EYLEM_PLANLAYICI, KALITE_GUVENLIK
        ModelName varchar(100) NOT NULL,
        Temperature decimal(3,2) NOT NULL,
        MaxTokens int NOT NULL,
        ExecutionOrder int NOT NULL,
        IsActive bit NOT NULL DEFAULT 1,
        
        -- Ajana özel parametreler
        SpecialtyArea varchar(100) NULL,
        PromptTemplate nvarchar(max) NULL,
        SystemPrompt nvarchar(max) NULL,
        
        -- Performans ayarları
        TimeoutSeconds int NOT NULL DEFAULT 300,
        RetryCount int NOT NULL DEFAULT 3,
        
        -- Meta veriler
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

-- Ajan Çalıştırma Sonuçları
IF OBJECT_ID(N'ai.AiAgentExecution', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAgentExecution (
        ExecutionId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RequestId bigint NOT NULL,
        AgentId int NOT NULL,
        
        -- Çalıştırma detayları
        StartTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        EndTime datetime2(0) NULL,
        Status varchar(20) NOT NULL DEFAULT 'CALISIYOR', -- CALISIYOR, TAMAMLANDI, BASARISIZ, ZAMAN_ASIMI
        
        -- Girdi/Çıktı
        InputData nvarchar(max) NULL,
        OutputData nvarchar(max) NULL,
        ErrorMessage nvarchar(max) NULL,
        
        -- Performans metrikleri
        ExecutionTimeMs int NULL,
        TokensUsed int NULL,
        ConfidenceScore decimal(5,2) NULL,
        QualityScore decimal(5,2) NULL,
        
        -- Ajanlar arası iletişim
        PreviousAgentOutput nvarchar(max) NULL,
        NextAgentInput nvarchar(max) NULL,
        
        CONSTRAINT FK_AiAgentExecution_Request FOREIGN KEY (RequestId) REFERENCES ai.AiAnalizIstegi(IstekId),
        CONSTRAINT FK_AiAgentExecution_Agent FOREIGN KEY (AgentId) REFERENCES ai.AiAgentConfig(AgentId)
    );
    
    CREATE INDEX IX_AiAgentExecution_Request ON ai.AiAgentExecution (RequestId, AgentId);
    CREATE INDEX IX_AiAgentExecution_Status ON ai.AiAgentExecution (Status, StartTime);
END
GO

-- Ajan Pipeline Orkestrasyon
IF OBJECT_ID(N'ai.AiAgentPipeline', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAgentPipeline (
        PipelineId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RequestId bigint NOT NULL,
        
        -- Pipeline durumu
        Status varchar(20) NOT NULL DEFAULT 'BEKLEMEDE', -- BEKLEMEDE, CALISIYOR, TAMAMLANDI, BASARISIZ
        StartTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        EndTime datetime2(0) NULL,
        
        -- Pipeline konfigürasyonu
        PipelineConfig nvarchar(max) NULL,
        AgentSequence varchar(500) NULL, -- Virgülle ayrılmış ajan ID'leri
        
        -- Sonuç toplama
        FinalOutput nvarchar(max) NULL,
        QualityAssessment nvarchar(max) NULL,
        OverallConfidence decimal(5,2) NULL,
        
        -- Performans metrikleri
        TotalExecutionTimeMs int NULL,
        TotalTokensUsed int NULL,
        
        CONSTRAINT FK_AiAgentPipeline_Request FOREIGN KEY (RequestId) REFERENCES ai.AiAnalizIstegi(IstekId)
    );
    
    CREATE INDEX IX_AiAgentPipeline_Request ON ai.AiAgentPipeline (RequestId);
    CREATE INDEX IX_AiAgentPipeline_Status ON ai.AiAgentPipeline (Status, StartTime);
END
GO

-- Gelişmiş Geri Bildirim Sistemi
IF OBJECT_ID(N'ai.AiEnhancedFeedback', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiEnhancedFeedback (
        FeedbackId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RequestId bigint NOT NULL,
        ExecutionId bigint NULL,
        
        -- Çok boyutlu geri bildirim
        AccuracyScore decimal(5,2) NOT NULL,        -- Doğruluk skoru
        RelevanceScore decimal(5,2) NOT NULL,       -- İlgililik skoru
        CompletenessScore decimal(5,2) NOT NULL,    -- Tamlık skoru
        ActionabilityScore decimal(5,2) NOT NULL,   -- Eyleme dönüştürülebilirlik skoru
        ExplanationQualityScore decimal(5,2) NOT NULL, -- Açıklama kalitesi skoru
        
        -- Genel değerlendirme
        OverallScore decimal(5,2) NOT NULL,
        WeightedScore decimal(5,2) NOT NULL,
        
        -- Detaylı geri bildirim
        CorrectRootCause varchar(100) NULL,
        MissedFactors nvarchar(max) NULL,
        ImprovementSuggestions nvarchar(max) NULL,
        
        -- Geri bildirim meta verileri
        FeedbackProvider varchar(100) NOT NULL,
        FeedbackDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        FeedbackType varchar(50) NOT NULL, -- MANUEL, OTOMATIK, SONUC_BAZLI
        
        -- Öğrenme entegrasyonu
        IntegratedIntoModel bit NOT NULL DEFAULT 0,
        IntegrationDate datetime2(0) NULL,
        
        CONSTRAINT FK_AiEnhancedFeedback_Request FOREIGN KEY (RequestId) REFERENCES ai.AiAnalizIstegi(IstekId),
        CONSTRAINT FK_AiEnhancedFeedback_Execution FOREIGN KEY (ExecutionId) REFERENCES ai.AiAgentExecution(ExecutionId)
    );
    
    CREATE INDEX IX_AiEnhancedFeedback_Request ON ai.AiEnhancedFeedback (RequestId);
    CREATE INDEX IX_AiEnhancedFeedback_Integration ON ai.AiEnhancedFeedback (IntegratedIntoModel, IntegrationDate);
END
GO

-- Model Performans Takibi
IF OBJECT_ID(N'ai.AiModelPerformance', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiModelPerformance (
        PerformanceId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModelName varchar(100) NOT NULL,
        ModelVersion varchar(50) NOT NULL,
        AgentType varchar(50) NULL,
        
        -- Performans metrikleri
        MeasurementDate date NOT NULL,
        TotalRequests int NOT NULL,
        SuccessfulRequests int NOT NULL,
        FailedRequests int NOT NULL,
        
        -- Kalite metrikleri
        AverageAccuracy decimal(5,2) NULL,
        AverageConfidence decimal(5,2) NULL,
        AverageResponseTime int NULL, -- milisaniye
        
        -- Öğrenme metrikleri
        FeedbackCount int NOT NULL DEFAULT 0,
        PositiveFeedbackCount int NOT NULL DEFAULT 0,
        ImprovementRate decimal(5,2) NULL,
        
        -- Kaynak kullanımı
        TotalTokensUsed bigint NULL,
        AverageTokensPerRequest int NULL,
        
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    CREATE UNIQUE INDEX UX_AiModelPerformance ON ai.AiModelPerformance (ModelName, ModelVersion, MeasurementDate, AgentType);
END
GO

-- Adaptif Öğrenme Konfigürasyonu
IF OBJECT_ID(N'ai.AiLearningConfig', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiLearningConfig (
        ConfigId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ConfigName varchar(100) NOT NULL UNIQUE,
        
        -- Öğrenme parametreleri
        LearningRate decimal(6,4) NOT NULL DEFAULT 0.01,
        MinAccuracyThreshold decimal(5,2) NOT NULL DEFAULT 0.75,
        UpdateFrequency varchar(20) NOT NULL DEFAULT 'GUNLUK', -- GERCEK_ZAMANLI, SAATLIK, GUNLUK, HAFTALIK
        
        -- Geri bildirim ağırlıkları
        AccuracyWeight decimal(3,2) NOT NULL DEFAULT 0.30,
        RelevanceWeight decimal(3,2) NOT NULL DEFAULT 0.25,
        CompletenessWeight decimal(3,2) NOT NULL DEFAULT 0.20,
        ActionabilityWeight decimal(3,2) NOT NULL DEFAULT 0.15,
        ExplanationWeight decimal(3,2) NOT NULL DEFAULT 0.10,
        
        -- Adaptasyon ayarları
        AdaptationEnabled bit NOT NULL DEFAULT 1,
        AutoRetrainingEnabled bit NOT NULL DEFAULT 0,
        
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

-- Zaman Serisi Tahmin Modelleri
IF OBJECT_ID(N'ai.AiPredictionModel', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiPredictionModel (
        ModelId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModelName varchar(100) NOT NULL,
        ModelType varchar(50) NOT NULL, -- ARIMA, LSTM, PROPHET, ENSEMBLE
        
        -- Model konfigürasyonu
        ModelParameters nvarchar(max) NULL, -- JSON konfigürasyon
        TrainingDataPeriod int NOT NULL, -- gün
        PredictionHorizon int NOT NULL, -- gün
        
        -- Performans metrikleri
        Accuracy decimal(5,2) NULL,
        MAE decimal(10,4) NULL, -- Ortalama Mutlak Hata
        RMSE decimal(10,4) NULL, -- Kök Ortalama Kare Hatası
        
        -- Model durumu
        Status varchar(20) NOT NULL DEFAULT 'EGITILIYOR', -- EGITILIYOR, AKTIF, KULLANIM_DISI
        LastTrainingDate datetime2(0) NULL,
        NextRetrainingDate datetime2(0) NULL,
        
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

-- Risk Tahminleri
IF OBJECT_ID(N'ai.AiRiskPrediction', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiRiskPrediction (
        PredictionId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModelId int NOT NULL,
        
        -- Tahmin hedefi
        MekanId int NOT NULL,
        StokId int NULL, -- Mekan seviyesi tahminler için NULL
        RiskType varchar(50) NOT NULL,
        
        -- Tahmin detayları
        PredictionDate date NOT NULL,
        TargetDate date NOT NULL,
        PredictedValue decimal(10,4) NOT NULL,
        ConfidenceInterval_Lower decimal(10,4) NULL,
        ConfidenceInterval_Upper decimal(10,4) NULL,
        ConfidenceScore decimal(5,2) NOT NULL,
        
        -- Gerçek sonuç (doğrulama için)
        ActualValue decimal(10,4) NULL,
        ActualDate date NULL,
        PredictionError decimal(10,4) NULL,
        
        -- Meta veriler
        PredictionMetadata nvarchar(max) NULL,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT FK_AiRiskPrediction_Model FOREIGN KEY (ModelId) REFERENCES ai.AiPredictionModel(ModelId)
    );
    
    CREATE INDEX IX_AiRiskPrediction_Target ON ai.AiRiskPrediction (MekanId, StokId, TargetDate);
    CREATE INDEX IX_AiRiskPrediction_Model ON ai.AiRiskPrediction (ModelId, PredictionDate);
END
GO

-- Anomali Tespiti
IF OBJECT_ID(N'ai.AiAnomalyDetection', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAnomalyDetection (
        AnomalyId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        
        -- Tespit hedefi
        MekanId int NOT NULL,
        StokId int NULL,
        DetectionDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        -- Anomali detayları
        AnomalyType varchar(50) NOT NULL, -- ISTATISTIKSEL, ML_BAZLI, DESEN_BAZLI
        AnomalyScore decimal(5,2) NOT NULL,
        Severity varchar(20) NOT NULL, -- DUSUK, ORTA, YUKSEK, KRITIK
        
        -- Tespit yöntemi
        DetectionMethod varchar(50) NOT NULL, -- Z_SKORU, IQR, ISOLATION_FOREST, AUTOENCODER
        DetectionParameters nvarchar(max) NULL,
        
        -- Anomali açıklaması
        AnomalyDescription nvarchar(max) NULL,
        AffectedMetrics nvarchar(500) NULL,
        
        -- Araştırma durumu
        Status varchar(20) NOT NULL DEFAULT 'YENI', -- YENI, ARASTIRILIYOR, COZULDU, YANLIS_POZITIF
        InvestigatedBy varchar(100) NULL,
        InvestigationNotes nvarchar(max) NULL,
        ResolutionDate datetime2(0) NULL,
        
        -- İlgili varlıklar
        RelatedDofId bigint NULL,
        RelatedRequestId bigint NULL,
        
        CONSTRAINT FK_AiAnomalyDetection_Dof FOREIGN KEY (RelatedDofId) REFERENCES dof.DofKayit(DofId),
        CONSTRAINT FK_AiAnomalyDetection_Request FOREIGN KEY (RelatedRequestId) REFERENCES ai.AiAnalizIstegi(IstekId)
    );
    
    CREATE INDEX IX_AiAnomalyDetection_Target ON ai.AiAnomalyDetection (MekanId, StokId, DetectionDate);
    CREATE INDEX IX_AiAnomalyDetection_Status ON ai.AiAnomalyDetection (Status, Severity);
END
GO

/* ===== log ===== */

IF OBJECT_ID(N'log.RiskCalismaLog', N'U') IS NULL
BEGIN
    CREATE TABLE log.RiskCalismaLog
    (
        LogId           bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        BaslamaZamani   datetime2(0) NOT NULL,
        BitisZamani     datetime2(0) NULL,
        Durum           varchar(20) NOT NULL, -- SUCCESS/FAIL
        SureMs          int NULL,
        Hata            nvarchar(4000) NULL
    );
END
GO

IF OBJECT_ID(N'log.StokCalismaLog', N'U') IS NULL
BEGIN
    CREATE TABLE log.StokCalismaLog
    (
        LogId           bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        BaslamaZamani   datetime2(0) NOT NULL,
        BitisZamani     datetime2(0) NULL,
        Durum           varchar(20) NOT NULL,
        SureMs          int NULL,
        HedefBaslangic  date NULL,
        HedefBitis      date NULL,
        Hata            nvarchar(4000) NULL
    );
END
GO

IF OBJECT_ID(N'log.PersonelEntegrasyonLog', N'U') IS NULL
BEGIN
    CREATE TABLE log.PersonelEntegrasyonLog
    (
        LogId           bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        KaynakSistem    varchar(30) NOT NULL,
        BaslamaZamani   datetime2(0) NOT NULL CONSTRAINT DF_PersonelEntegrasyon_Baslangic DEFAULT (SYSDATETIME()),
        BitisZamani     datetime2(0) NULL,
        Durum           varchar(20) NOT NULL CONSTRAINT DF_PersonelEntegrasyon_Durum DEFAULT('BASLADI'),
        Toplam          int NULL,
        Eklenen         int NULL,
        Guncellenen     int NULL,
        PasifEdilen     int NULL,
        Hata            nvarchar(4000) NULL
    );
END
GO
/* ===== etl ===== */

-- ETL Log tablosu
IF OBJECT_ID(N'etl.EtlLog', N'U') IS NULL
BEGIN
    CREATE TABLE etl.EtlLog (
        LogId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        JobName varchar(100) NOT NULL,
        JobType varchar(50) NOT NULL, -- EXTRACT, TRANSFORM, LOAD, QUALITY_CHECK
        Status varchar(20) NOT NULL, -- CALISIYOR, TAMAMLANDI, BASARISIZ
        StartTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        EndTime datetime2(0) NULL,
        RecordsProcessed int DEFAULT 0,
        RecordsFailed int DEFAULT 0,
        SourceSystem varchar(100) NULL,
        TargetSystem varchar(100) NULL,
        ErrorMessage nvarchar(max) NULL,
        Message nvarchar(max) NULL,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    CREATE INDEX IX_EtlLog_JobName ON etl.EtlLog (JobName, StartTime);
    CREATE INDEX IX_EtlLog_Status ON etl.EtlLog (Status, StartTime);
END;

-- ETL Senkronizasyon durumu
IF OBJECT_ID(N'etl.EtlSyncStatus', N'U') IS NULL
BEGIN
    CREATE TABLE etl.EtlSyncStatus (
        SyncId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TableName varchar(100) NOT NULL UNIQUE,
        LastSyncDate datetime2(0) NOT NULL,
        LastUpdateDate datetime2(0) NOT NULL,
        RecordsProcessed int DEFAULT 0,
        Status varchar(20) NOT NULL DEFAULT 'BEKLEMEDE',
        ErrorMessage nvarchar(max) NULL,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
END;

-- Stok Staging Tablosu
IF OBJECT_ID(N'etl.StokStaging', N'U') IS NULL
BEGIN
    CREATE TABLE etl.StokStaging (
        StagingId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ErpStokKodu varchar(50) NOT NULL,
        StokAdi nvarchar(200) NOT NULL,
        Kategori nvarchar(100) NULL,
        Birim nvarchar(20) NULL,
        AktifMi bit NOT NULL DEFAULT 1,
        SonGuncelleme datetime2(0) NULL,
        EtlBatchId uniqueidentifier NOT NULL,
        EtlTarihi datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        ProcessedFlag bit NOT NULL DEFAULT 0,
        ProcessedDate datetime2(0) NULL
    );
    
    CREATE INDEX IX_StokStaging_ErpKod ON etl.StokStaging (ErpStokKodu);
    CREATE INDEX IX_StokStaging_Batch ON etl.StokStaging (EtlBatchId, ProcessedFlag);
END;

-- Satış Staging Tablosu
IF OBJECT_ID(N'etl.SatisStaging', N'U') IS NULL
BEGIN
    CREATE TABLE etl.SatisStaging (
        StagingId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ErpSatisNo varchar(50) NOT NULL,
        ErpStokKodu varchar(50) NOT NULL,
        MekanKodu varchar(20) NOT NULL,
        SatisTarihi date NOT NULL,
        Miktar decimal(18,4) NOT NULL,
        BirimFiyat decimal(18,4) NOT NULL,
        ToplamTutar decimal(18,4) NOT NULL,
        KdvTutari decimal(18,4) NULL,
        NetTutar decimal(18,4) NOT NULL,
        EtlBatchId uniqueidentifier NOT NULL,
        EtlTarihi datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        ProcessedFlag bit NOT NULL DEFAULT 0,
        ProcessedDate datetime2(0) NULL
    );
    
    CREATE INDEX IX_SatisStaging_ErpKod ON etl.SatisStaging (ErpStokKodu, SatisTarihi);
    CREATE INDEX IX_SatisStaging_Batch ON etl.SatisStaging (EtlBatchId, ProcessedFlag);
END;

-- Stok Hareket Staging Tablosu
IF OBJECT_ID(N'etl.StokHareketStaging', N'U') IS NULL
BEGIN
    CREATE TABLE etl.StokHareketStaging (
        StagingId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ErpHareketNo varchar(50) NOT NULL,
        ErpStokKodu varchar(50) NOT NULL,
        MekanKodu varchar(20) NOT NULL,
        HareketTarihi date NOT NULL,
        HareketTipi varchar(20) NOT NULL, -- GIRIS, CIKIS, TRANSFER, SAYIM
        GirisMiktar decimal(18,4) NULL,
        CikisMiktar decimal(18,4) NULL,
        BirimMaliyet decimal(18,4) NULL,
        ToplamMaliyet decimal(18,4) NULL,
        EtlBatchId uniqueidentifier NOT NULL,
        EtlTarihi datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        ProcessedFlag bit NOT NULL DEFAULT 0,
        ProcessedDate datetime2(0) NULL
    );
    
    CREATE INDEX IX_StokHareketStaging_ErpKod ON etl.StokHareketStaging (ErpStokKodu, HareketTarihi);
    CREATE INDEX IX_StokHareketStaging_Batch ON etl.StokHareketStaging (EtlBatchId, ProcessedFlag);
END;

-- ETL Veri Kalitesi Sorunları
IF OBJECT_ID(N'etl.EtlDataQualityIssue', N'U') IS NULL
BEGIN
    CREATE TABLE etl.EtlDataQualityIssue (
        IssueId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TableName varchar(100) NOT NULL,
        IssueType varchar(50) NOT NULL, -- EKSIK_VERI, ANORMAL_DEGER, DUPLICATE_KEY, FOREIGN_KEY_ERROR
        IssueDescription nvarchar(500) NOT NULL,
        RecordCount int NOT NULL,
        Severity varchar(20) NOT NULL, -- KRITIK, YUKSEK, ORTA, DUSUK
        Status varchar(20) NOT NULL DEFAULT 'ACIK', -- ACIK, COZULDU, GOZARDI_EDILDI
        DetectedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        ResolvedDate datetime2(0) NULL,
        ResolvedBy varchar(100) NULL,
        ResolutionNotes nvarchar(max) NULL,
        SampleData nvarchar(max) NULL -- Örnek problemli veri
    );
    
    CREATE INDEX IX_EtlDataQualityIssue_Table ON etl.EtlDataQualityIssue (TableName, DetectedDate);
    CREATE INDEX IX_EtlDataQualityIssue_Status ON etl.EtlDataQualityIssue (Status, Severity);
END;
GO