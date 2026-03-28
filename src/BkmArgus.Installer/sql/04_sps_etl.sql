/* 04_sps_etl.sql
   - log.sp_RiskUrunOzet_Calistir
   - log.sp_StokBakiyeGunluk_Calistir
   - rpt.sp_StokBakiyeTarihGetir (ad-hoc)
   - log.sp_AylikKapanis_Calistir
*/
USE BKMDenetim;
GO

-- ETL şemasını oluştur (eğer yoksa)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
BEGIN
    EXEC('CREATE SCHEMA etl');
    PRINT 'ETL şeması oluşturuldu.';
END
ELSE
BEGIN
    PRINT 'ETL şeması zaten mevcut.';
END
GO

-- =============================================================================
-- ETL TABLOLARI
-- =============================================================================

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
    PRINT 'ETL Log tablosu oluşturuldu.';
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
    PRINT 'ETL Sync Status tablosu oluşturuldu.';
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
    PRINT 'Stok Staging tablosu oluşturuldu.';
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
    PRINT 'Satış Staging tablosu oluşturuldu.';
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
    PRINT 'Stok Hareket Staging tablosu oluşturuldu.';
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
    PRINT 'ETL Data Quality Issue tablosu oluşturuldu.';
END;
GO

PRINT 'ETL tabloları kontrol edildi ve gerekli olanlar oluşturuldu.';
GO

-- =============================================================================
-- ETL STORED PROCEDURE'LARI
-- =============================================================================

/* ========== Yardımcı: mekan listesi çıkar ========== */
IF OBJECT_ID(N'log.tvf_MekanListesi', N'IF') IS NOT NULL DROP FUNCTION log.tvf_MekanListesi;
GO
CREATE FUNCTION log.tvf_MekanListesi(@MekanCSV varchar(max))
RETURNS TABLE
AS
RETURN
(
    SELECT MekanId
    FROM (
        SELECT TRY_CAST(value AS int) AS MekanId
        FROM STRING_SPLIT(COALESCE(@MekanCSV,''), ',')
        WHERE LTRIM(RTRIM(COALESCE(value,''))) <> ''
    ) x
    WHERE x.MekanId IS NOT NULL

    UNION

    SELECT MekanId
    FROM src.vw_Mekan
    WHERE (COALESCE(@MekanCSV,'') = '')
);
GO

/* ========== Ad-hoc: istenen tarihte stok bakiyesi ========== */
IF OBJECT_ID(N'rpt.sp_StokBakiyeTarihGetir', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_StokBakiyeTarihGetir;
GO
CREATE PROCEDURE rpt.sp_StokBakiyeTarihGetir
    @Tarih date,
    @MekanCSV varchar(max) = NULL,
    @StokId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Tarih IS NULL
        THROW 50000, 'Tarih zorunludur', 1;

    ;WITH Mekan AS (
        SELECT MekanId FROM log.tvf_MekanListesi(@MekanCSV)
    ),
    Hedef AS (
        SELECT DISTINCT s.MekanId, s.StokId
        FROM rpt.StokBakiyeGunluk s
        JOIN Mekan m ON m.MekanId = s.MekanId
        WHERE (@StokId IS NULL OR s.StokId = @StokId)
    )
    SELECT
        h.MekanId,
        h.StokId,
        BakiyeninTarihi = x.Tarih,
        StokMiktar      = x.StokMiktar
    FROM Hedef h
    OUTER APPLY (
        SELECT TOP (1) s.Tarih, s.StokMiktar
        FROM rpt.StokBakiyeGunluk s
        WHERE s.MekanId=h.MekanId AND s.StokId=h.StokId AND s.Tarih <= @Tarih
        ORDER BY s.Tarih DESC
    ) x
    ORDER BY h.MekanId, h.StokId;
END
GO

/* ========== Stok bakiye ETL (120 gün pencere) ========== */
IF OBJECT_ID(N'log.sp_StokBakiyeGunluk_Calistir', N'P') IS NOT NULL DROP PROCEDURE log.sp_StokBakiyeGunluk_Calistir;
GO
CREATE PROCEDURE log.sp_StokBakiyeGunluk_Calistir
    @GeriyeDonukGun int = 120,
    @MekanCSV varchar(max) = NULL,
    @BitisTarihi date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @t0 datetime2(0)=SYSDATETIME();
    DECLARE @t1 datetime2(0);
    DECLARE @err nvarchar(4000);
    DECLARE @logId bigint;

    INSERT INTO log.StokCalismaLog (BaslamaZamani, Durum) VALUES (@t0, 'RUNNING');
    SET @logId = SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @Bugun date = CONVERT(date, SYSDATETIME());
        DECLARE @Bitis date = COALESCE(@BitisTarihi, DATEADD(day,-1,@Bugun));  -- dün
        DECLARE @Baslangic date = DATEADD(day, -ABS(@GeriyeDonukGun), @Bitis);

        ;WITH Mekan AS (SELECT MekanId FROM log.tvf_MekanListesi(@MekanCSV))
        SELECT DISTINCT
            h.MekanId, h.StokId
        INTO #Aktif
        FROM src.vw_StokHareket h
        JOIN Mekan m ON m.MekanId=h.MekanId
        WHERE h.AltDepoId=0
          AND h.HareketTarihi >= @Baslangic
          AND h.HareketTarihi <  DATEADD(day,1,@Bitis);

        CREATE UNIQUE CLUSTERED INDEX IX_#Aktif ON #Aktif(MekanId, StokId);

        -- Opening bakiye (Baslangic-1 dahil önceki tüm hareketler)
        SELECT
            a.MekanId, a.StokId,
            Opening = CAST(SUM(h.Adet) AS decimal(18,3))
        INTO #Opening
        FROM #Aktif a
        JOIN src.vw_StokHareket h ON h.MekanId=a.MekanId AND h.StokId=a.StokId
        WHERE h.AltDepoId=0
          AND h.HareketTarihi < @Baslangic
        GROUP BY a.MekanId, a.StokId;

        CREATE UNIQUE CLUSTERED INDEX IX_#Opening ON #Opening(MekanId, StokId);

        -- Günlük net hareket
        SELECT
            h.MekanId, h.StokId,
            Tarih = CONVERT(date, h.HareketTarihi),
            NetHareket = CAST(SUM(h.Adet) AS decimal(18,3))
        INTO #GunlukNet
        FROM src.vw_StokHareket h
        JOIN #Aktif a ON a.MekanId=h.MekanId AND a.StokId=h.StokId
        WHERE h.AltDepoId=0
          AND h.HareketTarihi >= @Baslangic
          AND h.HareketTarihi <  DATEADD(day,1,@Bitis)
        GROUP BY h.MekanId, h.StokId, CONVERT(date, h.HareketTarihi);

        CREATE CLUSTERED INDEX IX_#GunlukNet ON #GunlukNet(MekanId, StokId, Tarih);

        -- Sil-yaz (pencere)
        DELETE s
        FROM rpt.StokBakiyeGunluk s
        JOIN log.tvf_MekanListesi(@MekanCSV) m ON m.MekanId=s.MekanId
        WHERE s.Tarih BETWEEN @Baslangic AND @Bitis;

        -- Bakiye = Opening + running sum
        INSERT INTO rpt.StokBakiyeGunluk (Tarih, MekanId, StokId, StokMiktar)
        SELECT
            g.Tarih,
            g.MekanId,
            g.StokId,
            StokMiktar = CAST(COALESCE(o.Opening,0) 
                           + SUM(g.NetHareket) OVER (PARTITION BY g.MekanId, g.StokId ORDER BY g.Tarih ROWS UNBOUNDED PRECEDING)
                           AS decimal(18,3))
        FROM #GunlukNet g
        LEFT JOIN #Opening o ON o.MekanId=g.MekanId AND o.StokId=g.StokId
        OPTION (RECOMPILE);

        SET @t1 = SYSDATETIME();
        UPDATE log.StokCalismaLog
        SET BitisZamani=@t1,
            Durum='SUCCESS',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            HedefBaslangic=@Baslangic,
            HedefBitis=@Bitis
        WHERE LogId=@logId;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        SET @t1 = SYSDATETIME();
        UPDATE log.StokCalismaLog
        SET BitisZamani=@t1,
            Durum='FAIL',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            Hata=@err
        WHERE LogId=@logId;
        THROW;
    END CATCH
END
GO

/* ========== Risk ETL ========== */
IF OBJECT_ID(N'log.sp_RiskUrunOzet_Calistir', N'P') IS NOT NULL DROP PROCEDURE log.sp_RiskUrunOzet_Calistir;
GO
CREATE PROCEDURE log.sp_RiskUrunOzet_Calistir
    @MekanCSV varchar(max) = NULL,
    @ToplamYaz bit = 0  -- MekanId=0 yok; toplam rapor view ile. Bu parametre compatibility için var.
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @t0 datetime2(0)=SYSDATETIME();
    DECLARE @t1 datetime2(0);
    DECLARE @err nvarchar(4000);
    DECLARE @logId bigint;

    INSERT INTO log.RiskCalismaLog (BaslamaZamani, Durum) VALUES (@t0, 'RUNNING');
    SET @logId = SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @KesimTarihi datetime2(0)=SYSDATETIME();
        DECLARE @KesimGunu date = CONVERT(date, @KesimTarihi);
        DECLARE @Bitis datetime2(0)=DATEADD(day,1,@KesimGunu);

        DECLARE @Son30_Bas date = DATEADD(day,-30,@KesimGunu);
        DECLARE @AyBasi_Bas date = DATEFROMPARTS(YEAR(@KesimGunu), MONTH(@KesimGunu), 1);

        -- parametreler
        DECLARE @IadeOranEsik decimal(9,2) = COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='IadeOranEsik'), 20);
        DECLARE @NetBirikimAdetEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='NetBirikimAdetEsik'), 10);
        DECLARE @IcKullanimTutarEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='IcKullanimTutarEsik'), 1000);
        DECLARE @BozukAdetEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='BozukAdetEsik'), 5);
        DECLARE @SayimDuzeltmeAdetEsik decimal(18,3)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='SayimDuzeltmeAdetEsik'), 10);
        DECLARE @HizliDevirOranEsik decimal(9,4)= COALESCE((SELECT DegerDec FROM ref.RiskParam WHERE ParamKodu='HizliDevirOranEsik'), 0.80);
        DECLARE @SatisYaslanmaGunEsik int = COALESCE((SELECT DegerInt FROM ref.RiskParam WHERE ParamKodu='SatisYaslanmaGunEsik'), 90);

        -- Önce aynı gün aynı dönem aynı mekânı sil (günde tek snapshot)
        DELETE r
        FROM rpt.RiskUrunOzet_Gunluk r
        JOIN log.tvf_MekanListesi(@MekanCSV) m ON m.MekanId=r.MekanId
        WHERE r.KesimGunu=@KesimGunu;

        -- Insert
        ;WITH Mekan AS (
            SELECT MekanId FROM log.tvf_MekanListesi(@MekanCSV)
        ),
        Kaynak AS (
            SELECT
                h.MekanId, h.StokId, h.HareketTarihi, h.Adet, h.Tutar, h.TipId
            FROM src.vw_StokHareket h
            JOIN Mekan m ON m.MekanId=h.MekanId
            WHERE h.AltDepoId=0
              AND h.HareketTarihi < @Bitis
              AND h.HareketTarihi >= @Son30_Bas  -- Son30Gun en geniş pencere; AyBasi bunun içinde kalabilir
        ),
        Mapli AS (
            SELECT
                k.*,
                COALESCE(g.GrupKodu,'DIGER') AS GrupKodu
            FROM Kaynak k
            LEFT JOIN ref.IrsTipGrupMap g ON g.TipId = k.TipId AND g.AktifMi=1
        ),
        Donem AS (
            SELECT DonemKodu='Son30Gun', Baslangic=@Son30_Bas
            UNION ALL
            SELECT 'AyBasi', @AyBasi_Bas
        ),
        Keys AS (
            SELECT d.DonemKodu, d.Baslangic, k.MekanId, k.StokId
            FROM (SELECT DISTINCT MekanId, StokId FROM Mapli) k
            CROSS JOIN Donem d
        ),
        Opening AS (
            SELECT
                k.DonemKodu,
                k.MekanId,
                k.StokId,
                OpeningStok = o.StokMiktar
            FROM Keys k
            OUTER APPLY (
                SELECT TOP (1) b.StokMiktar
                FROM rpt.StokBakiyeGunluk b
                WHERE b.MekanId = k.MekanId
                  AND b.StokId = k.StokId
                  AND b.Tarih < k.Baslangic
                ORDER BY b.Tarih DESC
            ) o
        ),
        Aggr AS (
            SELECT
                KesimTarihi=@KesimTarihi,
                d.DonemKodu,
                m.MekanId,
                m.StokId,

                NetAdet = CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN m.Adet ELSE 0 END) AS decimal(18,3)),
                BrutAdet= CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                NetTutar= CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN m.Tutar ELSE 0 END) AS decimal(18,3)),
                BrutTutar=CAST(SUM(CASE WHEN m.HareketTarihi >= d.Baslangic THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),

                GirisBrutAdet = CAST(SUM(CASE
                    WHEN m.HareketTarihi >= d.Baslangic
                     AND m.Adet > 0
                     AND m.GrupKodu IN ('ALIS','TRANSFER','SAYIM','DUZELTME')
                    THEN m.Adet ELSE 0 END) AS decimal(18,3)),

                AlisBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ALIS' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                SatisBrutAdet= CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SATIS' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                IadeBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='IADE' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                TransferBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                TransferNetAdet  = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN m.Adet ELSE 0 END) AS decimal(18,3)),
                SayimBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SAYIM' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                DuzeltmeBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='DUZELTME' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                IcKullanimBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ICKULLANIM' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),
                BozukBrutAdet = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='BOZUK' THEN ABS(m.Adet) ELSE 0 END) AS decimal(18,3)),

                AlisBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ALIS' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                SatisBrutTutar= CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SATIS' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                IadeBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='IADE' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                TransferBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                TransferNetTutar  = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='TRANSFER' THEN m.Tutar ELSE 0 END) AS decimal(18,3)),
                SayimBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SAYIM' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                DuzeltmeBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='DUZELTME' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                IcKullanimBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='ICKULLANIM' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),
                BozukBrutTutar = CAST(SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='BOZUK' THEN ABS(m.Tutar) ELSE 0 END) AS decimal(18,3)),

                SonSatisTarihi = MAX(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.GrupKodu='SATIS' AND m.Adet<0 THEN m.HareketTarihi END),
                AdetSifirTutarVarSatir = SUM(CASE WHEN m.HareketTarihi>=d.Baslangic AND m.Adet=0 AND m.Tutar<>0 THEN 1 ELSE 0 END)
            FROM Mapli m
            CROSS JOIN Donem d
            GROUP BY d.DonemKodu, m.MekanId, m.StokId
        ),
        Hesap AS (
            SELECT
                a.*,
                OpeningStok = COALESCE(o.OpeningStok, 0),
                SatisYasiGun = CASE WHEN a.SonSatisTarihi IS NULL THEN NULL ELSE DATEDIFF(day, CONVERT(date,a.SonSatisTarihi), @KesimGunu) END,
                IadeOraniYuzde = CASE WHEN a.SatisBrutTutar=0 THEN NULL ELSE CAST(a.IadeBrutTutar / NULLIF(a.SatisBrutTutar,0) * 100 AS decimal(9,2)) END,

                FlagVeriKalite       = CONVERT(bit, CASE WHEN a.AdetSifirTutarVarSatir>0 THEN 1 ELSE 0 END),
                FlagGirissizSatis    = CONVERT(bit, CASE
                    WHEN a.SatisBrutAdet>0
                     AND a.GirisBrutAdet=0
                     AND COALESCE(o.OpeningStok, 0) <= 0
                    THEN 1 ELSE 0 END),
                FlagOluStok          = CONVERT(bit, CASE WHEN a.AlisBrutAdet>0 AND a.SatisBrutAdet=0 THEN 1 ELSE 0 END),
                FlagNetBirikim       = CONVERT(bit, CASE WHEN a.NetAdet >= @NetBirikimAdetEsik THEN 1 ELSE 0 END),
                FlagIadeYuksek       = CONVERT(bit, CASE WHEN a.SatisBrutTutar>0 AND (a.IadeBrutTutar / NULLIF(a.SatisBrutTutar,0) * 100) >= @IadeOranEsik THEN 1 ELSE 0 END),
                FlagBozukIadeYuksek  = CONVERT(bit, CASE WHEN a.BozukBrutAdet >= @BozukAdetEsik THEN 1 ELSE 0 END),
                FlagSayimDuzeltmeYuk = CONVERT(bit, CASE WHEN (a.SayimBrutAdet + a.DuzeltmeBrutAdet) >= @SayimDuzeltmeAdetEsik THEN 1 ELSE 0 END),
                FlagSirketIciYuksek  = CONVERT(bit, CASE WHEN a.IcKullanimBrutTutar >= @IcKullanimTutarEsik THEN 1 ELSE 0 END),
                FlagHizliDevir       = CONVERT(bit, CASE WHEN a.AlisBrutAdet>0 AND (a.SatisBrutAdet / NULLIF(a.AlisBrutAdet,0)) >= @HizliDevirOranEsik THEN 1 ELSE 0 END),
                FlagSatisYaslanma    = CONVERT(bit, CASE WHEN a.SonSatisTarihi IS NOT NULL AND DATEDIFF(day, CONVERT(date,a.SonSatisTarihi), @KesimGunu) >= @SatisYaslanmaGunEsik AND a.NetAdet>0 THEN 1 ELSE 0 END)
            FROM Aggr a
            LEFT JOIN Opening o ON o.DonemKodu = a.DonemKodu AND o.MekanId = a.MekanId AND o.StokId = a.StokId
        ),
        Skor AS (
            SELECT
                h.*,
                RiskSkor = (
                    SELECT SUM(w.Puan)
                    FROM ref.RiskSkorAgirlik w
                    WHERE w.AktifMi=1 AND (
                        (w.FlagKodu='FlagVeriKalite'       AND h.FlagVeriKalite=1) OR
                        (w.FlagKodu='FlagGirissizSatis'    AND h.FlagGirissizSatis=1) OR
                        (w.FlagKodu='FlagOluStok'          AND h.FlagOluStok=1) OR
                        (w.FlagKodu='FlagNetBirikim'       AND h.FlagNetBirikim=1) OR
                        (w.FlagKodu='FlagIadeYuksek'       AND h.FlagIadeYuksek=1) OR
                        (w.FlagKodu='FlagBozukIadeYuksek'  AND h.FlagBozukIadeYuksek=1) OR
                        (w.FlagKodu='FlagSayimDuzeltmeYuk' AND h.FlagSayimDuzeltmeYuk=1) OR
                        (w.FlagKodu='FlagSirketIciYuksek'  AND h.FlagSirketIciYuksek=1) OR
                        (w.FlagKodu='FlagHizliDevir'       AND h.FlagHizliDevir=1) OR
                        (w.FlagKodu='FlagSatisYaslanma'    AND h.FlagSatisYaslanma=1)
                    )
                )
            FROM Hesap h
        )
        INSERT INTO rpt.RiskUrunOzet_Gunluk
        (
            KesimTarihi, DonemKodu, MekanId, StokId,
            NetAdet, BrutAdet, NetTutar, BrutTutar,
            AlisBrutAdet, SatisBrutAdet, IadeBrutAdet, TransferBrutAdet, TransferNetAdet,
            SayimBrutAdet, DuzeltmeBrutAdet, IcKullanimBrutAdet, BozukBrutAdet,
            AlisBrutTutar, SatisBrutTutar, IadeBrutTutar, TransferBrutTutar, TransferNetTutar,
            SayimBrutTutar, DuzeltmeBrutTutar, IcKullanimBrutTutar, BozukBrutTutar,
            SonSatisTarihi, SatisYasiGun, AdetSifirTutarVarSatir, IadeOraniYuzde,
            FlagVeriKalite, FlagGirissizSatis, FlagOluStok, FlagNetBirikim, FlagIadeYuksek,
            FlagBozukIadeYuksek, FlagSayimDuzeltmeYuk, FlagSirketIciYuksek, FlagHizliDevir, FlagSatisYaslanma,
            RiskSkor, RiskYorum
        )
        SELECT
            s.KesimTarihi, s.DonemKodu, s.MekanId, s.StokId,
            s.NetAdet, s.BrutAdet, s.NetTutar, s.BrutTutar,
            s.AlisBrutAdet, s.SatisBrutAdet, s.IadeBrutAdet, s.TransferBrutAdet, s.TransferNetAdet,
            s.SayimBrutAdet, s.DuzeltmeBrutAdet, s.IcKullanimBrutAdet, s.BozukBrutAdet,
            s.AlisBrutTutar, s.SatisBrutTutar, s.IadeBrutTutar, s.TransferBrutTutar, s.TransferNetTutar,
            s.SayimBrutTutar, s.DuzeltmeBrutTutar, s.IcKullanimBrutTutar, s.BozukBrutTutar,
            s.SonSatisTarihi, s.SatisYasiGun, s.AdetSifirTutarVarSatir, s.IadeOraniYuzde,
            s.FlagVeriKalite, s.FlagGirissizSatis, s.FlagOluStok, s.FlagNetBirikim, s.FlagIadeYuksek,
            s.FlagBozukIadeYuksek, s.FlagSayimDuzeltmeYuk, s.FlagSirketIciYuksek, s.FlagHizliDevir, s.FlagSatisYaslanma,
            RiskSkor = CASE WHEN s.RiskSkor IS NULL THEN 0 ELSE IIF(s.RiskSkor>100,100,s.RiskSkor) END,
            RiskYorum = y.RiskYorum
        FROM Skor s
        OUTER APPLY (
            SELECT RiskYorum = NULLIF(STUFF((
                SELECT TOP (5)
                    ' | ' + t.Metin
                FROM (
                    SELECT w.Oncelik,
                           Metin = CASE w.FlagKodu
                                WHEN 'FlagVeriKalite'       THEN CONCAT(N'VeriKalite: satir=', s.AdetSifirTutarVarSatir)
                                WHEN 'FlagGirissizSatis'    THEN CONCAT(N'GirissizSatis: satis=', s.SatisBrutAdet)
                                WHEN 'FlagOluStok'          THEN CONCAT(N'OluStok: alis=', s.AlisBrutAdet)
                                WHEN 'FlagNetBirikim'       THEN CONCAT(N'NetBirikim: net=', s.NetAdet)
                                WHEN 'FlagIadeYuksek'       THEN CONCAT(N'IadeYuksek: %', COALESCE(CONVERT(varchar(20),s.IadeOraniYuzde),'?'))
                                WHEN 'FlagBozukIadeYuksek'  THEN CONCAT(N'Bozuk: adet=', s.BozukBrutAdet)
                                WHEN 'FlagSayimDuzeltmeYuk' THEN CONCAT(N'Sayim+Duzeltme: adet=', s.SayimBrutAdet + s.DuzeltmeBrutAdet)
                                WHEN 'FlagSirketIciYuksek'  THEN CONCAT(N'IcKullanim: tutar=', s.IcKullanimBrutTutar)
                                WHEN 'FlagHizliDevir'       THEN CONCAT(N'HizliDevir: satis/alis=', CAST(s.SatisBrutAdet/NULLIF(s.AlisBrutAdet,0) AS decimal(9,2)))
                                WHEN 'FlagSatisYaslanma'    THEN CONCAT(N'SatisYaslanma: gun=', COALESCE(CONVERT(varchar(20),s.SatisYasiGun),'?'))
                           END
                    FROM ref.RiskSkorAgirlik w
                    WHERE w.AktifMi=1 AND (
                        (w.FlagKodu='FlagVeriKalite'       AND s.FlagVeriKalite=1) OR
                        (w.FlagKodu='FlagGirissizSatis'    AND s.FlagGirissizSatis=1) OR
                        (w.FlagKodu='FlagOluStok'          AND s.FlagOluStok=1) OR
                        (w.FlagKodu='FlagNetBirikim'       AND s.FlagNetBirikim=1) OR
                        (w.FlagKodu='FlagIadeYuksek'       AND s.FlagIadeYuksek=1) OR
                        (w.FlagKodu='FlagBozukIadeYuksek'  AND s.FlagBozukIadeYuksek=1) OR
                        (w.FlagKodu='FlagSayimDuzeltmeYuk' AND s.FlagSayimDuzeltmeYuk=1) OR
                        (w.FlagKodu='FlagSirketIciYuksek'  AND s.FlagSirketIciYuksek=1) OR
                        (w.FlagKodu='FlagHizliDevir'       AND s.FlagHizliDevir=1) OR
                        (w.FlagKodu='FlagSatisYaslanma'    AND s.FlagSatisYaslanma=1)
                    )
                ) t
                ORDER BY t.Oncelik
                FOR XML PATH(''), TYPE).value('.','nvarchar(max)'), 1, 3, ''), '')
        ) y
        OPTION (RECOMPILE);

        SET @t1 = SYSDATETIME();
        UPDATE log.RiskCalismaLog
        SET BitisZamani=@t1,
            Durum='SUCCESS',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            Hata=NULL
        WHERE LogId=@logId;

    END TRY
    BEGIN CATCH
        SET @err = ERROR_MESSAGE();
        SET @t1 = SYSDATETIME();
        UPDATE log.RiskCalismaLog
        SET BitisZamani=@t1,
            Durum='FAIL',
            SureMs=DATEDIFF(millisecond,@t0,@t1),
            Hata=@err
        WHERE LogId=@logId;
        THROW;
    END CATCH
END
GO

/* ========== Aylık kapanış ========== */
IF OBJECT_ID(N'log.sp_AylikKapanis_Calistir', N'P') IS NOT NULL DROP PROCEDURE log.sp_AylikKapanis_Calistir;
GO
CREATE PROCEDURE log.sp_AylikKapanis_Calistir
    @DonemAy int = NULL -- YYYYMM. NULL ise geçen ay.
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @KesimTarihi datetime2(0)=SYSDATETIME();
    DECLARE @Bugun date=CONVERT(date,@KesimTarihi);

    IF @DonemAy IS NULL
    BEGIN
        DECLARE @onceki date=DATEADD(month,-1,DATEFROMPARTS(YEAR(@Bugun),MONTH(@Bugun),1));
        SET @DonemAy = YEAR(@onceki)*100 + MONTH(@onceki);
    END

    -- ilgili ayın son snapshot günü (RiskUrunOzet_Gunluk içinden)
    ;WITH r AS (
        SELECT *
        FROM rpt.RiskUrunOzet_Gunluk
        WHERE YEAR(KesimGunu)*100 + MONTH(KesimGunu) = @DonemAy
    ),
    son AS (
        SELECT MAX(KesimGunu) AS SonGun FROM r
    )
    INSERT INTO rpt.RiskUrunOzet_Aylik
    (
        DonemAy, DonemKodu, MekanId, StokId, KesimTarihi,
        NetAdet, BrutAdet, NetTutar, BrutTutar, RiskSkor,
        FlagVeriKalite, FlagGirissizSatis, FlagOluStok, FlagNetBirikim, FlagIadeYuksek,
        FlagBozukIadeYuksek, FlagSayimDuzeltmeYuk, FlagSirketIciYuksek, FlagHizliDevir, FlagSatisYaslanma,
        RiskYorum
    )
    SELECT
        DonemAy=@DonemAy,
        r.DonemKodu, r.MekanId, r.StokId, KesimTarihi=@KesimTarihi,
        r.NetAdet, r.BrutAdet, r.NetTutar, r.BrutTutar, r.RiskSkor,
        r.FlagVeriKalite, r.FlagGirissizSatis, r.FlagOluStok, r.FlagNetBirikim, r.FlagIadeYuksek,
        r.FlagBozukIadeYuksek, r.FlagSayimDuzeltmeYuk, r.FlagSirketIciYuksek, r.FlagHizliDevir, r.FlagSatisYaslanma,
        r.RiskYorum
    FROM r
    CROSS JOIN son
    WHERE r.KesimGunu = son.SonGun
    AND NOT EXISTS (
        SELECT 1 FROM rpt.RiskUrunOzet_Aylik a
        WHERE a.DonemAy=@DonemAy AND a.DonemKodu=r.DonemKodu AND a.MekanId=r.MekanId AND a.StokId=r.StokId
    );
END
GO

-- =============================================================================
-- ERP ETL STORED PROCEDURE'LARI
-- =============================================================================

/* ERP'den Stok Verilerini Çekme */
IF OBJECT_ID(N'etl.sp_ErpStok_Extract', N'P') IS NOT NULL DROP PROCEDURE etl.sp_ErpStok_Extract;
GO
CREATE PROCEDURE etl.sp_ErpStok_Extract
    @BatchSize int = 1000,
    @LastSyncDate datetime2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @BatchId uniqueidentifier = NEWID();
    DECLARE @ProcessedRecords int = 0;
    
    BEGIN TRY
        -- Son senkronizasyon tarihini al
        IF @LastSyncDate IS NULL
        BEGIN
            SELECT @LastSyncDate = ISNULL(LastSyncDate, '1900-01-01')
            FROM etl.EtlSyncStatus 
            WHERE TableName = 'ref.Stok';
        END
        
        -- Log kaydı başlat
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('ErpStok_Extract', 'EXTRACT', 'CALISIYOR', @StartTime, 'ERP_SYSTEM', 'STAGING', 
                CONCAT('Stok verisi çekme başlatıldı. Son sync: ', @LastSyncDate));
        
        -- ERP'den stok verilerini çek (simülasyon - gerçek ERP bağlantısı gerekli)
        -- Bu kısım gerçek ERP sistemine göre özelleştirilmeli
        INSERT INTO etl.StokStaging (
            ErpStokKodu, StokAdi, Kategori, Birim, AktifMi, 
            SonGuncelleme, EtlBatchId, EtlTarihi
        )
        SELECT TOP (@BatchSize)
            s.StokKodu as ErpStokKodu,
            s.StokAdi,
            s.KategoriAdi as Kategori,
            s.BirimAdi as Birim,
            s.AktifMi,
            SYSDATETIME() as SonGuncelleme,
            @BatchId,
            SYSDATETIME()
        FROM ref.Stok s
        WHERE s.GuncellemeTarihi > @LastSyncDate
          AND NOT EXISTS (
              SELECT 1 FROM etl.StokStaging es 
              WHERE es.ErpStokKodu = s.StokKodu 
                AND es.ProcessedFlag = 0
          )
        ORDER BY s.GuncellemeTarihi;
        
        SET @ProcessedRecords = @@ROWCOUNT;
        
        -- Senkronizasyon durumunu güncelle
        MERGE etl.EtlSyncStatus AS target
        USING (SELECT 'ref.Stok' as TableName) AS source
        ON target.TableName = source.TableName
        WHEN MATCHED THEN
            UPDATE SET 
                LastSyncDate = SYSDATETIME(),
                LastUpdateDate = SYSDATETIME(),
                RecordsProcessed = @ProcessedRecords,
                Status = 'TAMAMLANDI',
                UpdatedDate = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (TableName, LastSyncDate, LastUpdateDate, RecordsProcessed, Status)
            VALUES (source.TableName, SYSDATETIME(), SYSDATETIME(), @ProcessedRecords, 'TAMAMLANDI');
        
        -- Log kaydını tamamla
        UPDATE etl.EtlLog 
        SET Status = 'TAMAMLANDI', 
            EndTime = SYSDATETIME(), 
            RecordsProcessed = @ProcessedRecords,
            Message = CONCAT('Stok verisi çekme tamamlandı. İşlenen kayıt: ', @ProcessedRecords)
        WHERE JobName = 'ErpStok_Extract' 
          AND StartTime = @StartTime;
        
        SELECT @ProcessedRecords as ProcessedRecords, 'Başarılı' as Status;
        
    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('ErpStok_Extract', 'EXTRACT', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());
        
        THROW;
    END CATCH
END
GO

/* ERP'den Satış Verilerini Çekme */
IF OBJECT_ID(N'etl.sp_ErpSatis_Extract', N'P') IS NOT NULL DROP PROCEDURE etl.sp_ErpSatis_Extract;
GO
CREATE PROCEDURE etl.sp_ErpSatis_Extract
    @BatchSize int = 5000,
    @LastSyncDate datetime2(0) = NULL,
    @TargetDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @BatchId uniqueidentifier = NEWID();
    DECLARE @ProcessedRecords int = 0;
    
    BEGIN TRY
        -- Hedef tarih belirleme (varsayılan dün)
        IF @TargetDate IS NULL
            SET @TargetDate = CAST(DATEADD(day, -1, SYSDATETIME()) AS date);
        
        -- Son senkronizasyon tarihini al
        IF @LastSyncDate IS NULL
        BEGIN
            SELECT @LastSyncDate = ISNULL(LastSyncDate, CAST(DATEADD(day, -7, SYSDATETIME()) AS datetime2(0)))
            FROM etl.EtlSyncStatus 
            WHERE TableName = 'src.SatisDetay';
        END
        
        -- Log kaydı başlat
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('ErpSatis_Extract', 'EXTRACT', 'CALISIYOR', @StartTime, 'ERP_SYSTEM', 'STAGING', 
                CONCAT('Satış verisi çekme başlatıldı. Hedef tarih: ', @TargetDate));
        
        -- ERP'den satış verilerini çek (simülasyon - gerçek ERP bağlantısı gerekli)
        INSERT INTO etl.SatisStaging (
            ErpSatisNo, ErpStokKodu, MekanKodu, SatisTarihi, Miktar, BirimFiyat,
            ToplamTutar, KdvTutari, NetTutar, EtlBatchId, EtlTarihi
        )
        SELECT TOP (@BatchSize)
            CONCAT('ERP-', sd.SatisId) as ErpSatisNo,
            s.StokKodu as ErpStokKodu,
            m.MekanKodu,
            sd.SatisTarihi,
            sd.Miktar,
            sd.BirimFiyat,
            sd.ToplamTutar,
            sd.ToplamTutar * 0.18 as KdvTutari, -- %18 KDV varsayımı
            sd.NetTutar,
            @BatchId,
            SYSDATETIME()
        FROM src.SatisDetay sd
        INNER JOIN ref.Stok s ON s.StokId = sd.StokId
        INNER JOIN ref.Mekan m ON m.MekanId = sd.MekanId
        WHERE sd.SatisTarihi = @TargetDate
          AND NOT EXISTS (
              SELECT 1 FROM etl.SatisStaging es 
              WHERE es.ErpSatisNo = CONCAT('ERP-', sd.SatisId)
                AND es.ProcessedFlag = 0
          )
        ORDER BY sd.SatisTarihi, sd.SatisId;
        
        SET @ProcessedRecords = @@ROWCOUNT;
        
        -- Senkronizasyon durumunu güncelle
        MERGE etl.EtlSyncStatus AS target
        USING (SELECT 'src.SatisDetay' as TableName) AS source
        ON target.TableName = source.TableName
        WHEN MATCHED THEN
            UPDATE SET 
                LastSyncDate = SYSDATETIME(),
                LastUpdateDate = @TargetDate,
                RecordsProcessed = @ProcessedRecords,
                Status = 'TAMAMLANDI',
                UpdatedDate = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (TableName, LastSyncDate, LastUpdateDate, RecordsProcessed, Status)
            VALUES (source.TableName, SYSDATETIME(), @TargetDate, @ProcessedRecords, 'TAMAMLANDI');
        
        -- Log kaydını tamamla
        UPDATE etl.EtlLog 
        SET Status = 'TAMAMLANDI', 
            EndTime = SYSDATETIME(), 
            RecordsProcessed = @ProcessedRecords,
            Message = CONCAT('Satış verisi çekme tamamlandı. İşlenen kayıt: ', @ProcessedRecords)
        WHERE JobName = 'ErpSatis_Extract' 
          AND StartTime = @StartTime;
        
        SELECT @ProcessedRecords as ProcessedRecords, 'Başarılı' as Status;
        
    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('ErpSatis_Extract', 'EXTRACT', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());
        
        THROW;
    END CATCH
END
GO

/* ERP'den Stok Hareketlerini Çekme */
IF OBJECT_ID(N'etl.sp_ErpStokHareket_Extract', N'P') IS NOT NULL DROP PROCEDURE etl.sp_ErpStokHareket_Extract;
GO
CREATE PROCEDURE etl.sp_ErpStokHareket_Extract
    @BatchSize int = 10000,
    @LastSyncDate datetime2(0) = NULL,
    @TargetDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @BatchId uniqueidentifier = NEWID();
    DECLARE @ProcessedRecords int = 0;
    
    BEGIN TRY
        -- Hedef tarih belirleme (varsayılan dün)
        IF @TargetDate IS NULL
            SET @TargetDate = CAST(DATEADD(day, -1, SYSDATETIME()) AS date);
        
        -- Son senkronizasyon tarihini al
        IF @LastSyncDate IS NULL
        BEGIN
            SELECT @LastSyncDate = ISNULL(LastSyncDate, CAST(DATEADD(day, -7, SYSDATETIME()) AS datetime2(0)))
            FROM etl.EtlSyncStatus 
            WHERE TableName = 'src.StokHareket';
        END
        
        -- Log kaydı başlat
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('ErpStokHareket_Extract', 'EXTRACT', 'CALISIYOR', @StartTime, 'ERP_SYSTEM', 'STAGING', 
                CONCAT('Stok hareket verisi çekme başlatıldı. Hedef tarih: ', @TargetDate));
        
        -- ERP'den stok hareket verilerini çek (simülasyon - gerçek ERP bağlantısı gerekli)
        INSERT INTO etl.StokHareketStaging (
            ErpHareketNo, ErpStokKodu, MekanKodu, HareketTarihi, HareketTipi,
            GirisMiktar, CikisMiktar, BirimMaliyet, ToplamMaliyet, EtlBatchId, EtlTarihi
        )
        SELECT TOP (@BatchSize)
            CONCAT('ERP-H-', sh.HareketId) as ErpHareketNo,
            s.StokKodu as ErpStokKodu,
            m.MekanKodu,
            CAST(sh.HareketTarihi AS date) as HareketTarihi,
            CASE 
                WHEN sh.Adet > 0 THEN 'GIRIS'
                WHEN sh.Adet < 0 THEN 'CIKIS'
                ELSE 'TRANSFER'
            END as HareketTipi,
            CASE WHEN sh.Adet > 0 THEN sh.Adet ELSE NULL END as GirisMiktar,
            CASE WHEN sh.Adet < 0 THEN ABS(sh.Adet) ELSE NULL END as CikisMiktar,
            CASE WHEN sh.Tutar <> 0 AND sh.Adet <> 0 THEN ABS(sh.Tutar / sh.Adet) ELSE 0 END as BirimMaliyet,
            ABS(sh.Tutar) as ToplamMaliyet,
            @BatchId,
            SYSDATETIME()
        FROM src.StokHareket sh
        INNER JOIN ref.Stok s ON s.StokId = sh.StokId
        INNER JOIN ref.Mekan m ON m.MekanId = sh.MekanId
        WHERE CAST(sh.HareketTarihi AS date) = @TargetDate
          AND NOT EXISTS (
              SELECT 1 FROM etl.StokHareketStaging es 
              WHERE es.ErpHareketNo = CONCAT('ERP-H-', sh.HareketId)
                AND es.ProcessedFlag = 0
          )
        ORDER BY sh.HareketTarihi, sh.HareketId;
        
        SET @ProcessedRecords = @@ROWCOUNT;
        
        -- Senkronizasyon durumunu güncelle
        MERGE etl.EtlSyncStatus AS target
        USING (SELECT 'src.StokHareket' as TableName) AS source
        ON target.TableName = source.TableName
        WHEN MATCHED THEN
            UPDATE SET 
                LastSyncDate = SYSDATETIME(),
                LastUpdateDate = @TargetDate,
                RecordsProcessed = @ProcessedRecords,
                Status = 'TAMAMLANDI',
                UpdatedDate = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (TableName, LastSyncDate, LastUpdateDate, RecordsProcessed, Status)
            VALUES (source.TableName, SYSDATETIME(), @TargetDate, @ProcessedRecords, 'TAMAMLANDI');
        
        -- Log kaydını tamamla
        UPDATE etl.EtlLog 
        SET Status = 'TAMAMLANDI', 
            EndTime = SYSDATETIME(), 
            RecordsProcessed = @ProcessedRecords,
            Message = CONCAT('Stok hareket verisi çekme tamamlandı. İşlenen kayıt: ', @ProcessedRecords)
        WHERE JobName = 'ErpStokHareket_Extract' 
          AND StartTime = @StartTime;
        
        SELECT @ProcessedRecords as ProcessedRecords, 'Başarılı' as Status;
        
    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('ErpStokHareket_Extract', 'EXTRACT', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());
        
        THROW;
    END CATCH
END
GO

/* Staging'den Ana Tablolara Veri Yükleme */
IF OBJECT_ID(N'etl.sp_StagingToMain_Load', N'P') IS NOT NULL DROP PROCEDURE etl.sp_StagingToMain_Load;
GO
CREATE PROCEDURE etl.sp_StagingToMain_Load
    @TableName varchar(100),
    @BatchSize int = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @ProcessedRecords int = 0;
    
    BEGIN TRY
        -- Log kaydı başlat
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('StagingToMain_Load', 'LOAD', 'CALISIYOR', @StartTime, 'STAGING', 'MAIN_TABLES', 
                CONCAT('Staging''den ana tablolara yükleme başlatıldı: ', @TableName));
        
        IF @TableName = 'ALL' OR @TableName = 'ref.Stok'
        BEGIN
            -- Stok verilerini yükle
            MERGE ref.Stok AS target
            USING (
                SELECT ErpStokKodu, StokAdi, Kategori, Birim, AktifMi
                FROM etl.StokStaging 
                WHERE ProcessedFlag = 0
            ) AS source
            ON target.StokKodu = source.ErpStokKodu
            WHEN MATCHED THEN
                UPDATE SET
                    StokAdi = source.StokAdi,
                    KategoriAdi = source.Kategori,
                    BirimAdi = source.Birim,
                    AktifMi = source.AktifMi,
                    GuncellemeTarihi = SYSDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (StokKodu, StokAdi, KategoriAdi, BirimAdi, AktifMi, OlusturmaTarihi, GuncellemeTarihi)
                VALUES (source.ErpStokKodu, source.StokAdi, source.Kategori, source.Birim, 
                        source.AktifMi, SYSDATETIME(), SYSDATETIME());
            
            SET @ProcessedRecords = @@ROWCOUNT;
            
            -- Staging tablosunu işaretli olarak güncelle
            UPDATE etl.StokStaging SET ProcessedFlag = 1, ProcessedDate = SYSDATETIME()
            WHERE ProcessedFlag = 0;
        END
        
        ELSE IF @TableName = 'src.SatisDetay'
        BEGIN
            -- Satış verilerini yükle
            INSERT INTO src.SatisDetay (
                SatisNo, StokId, MekanId, SatisTarihi, Miktar, BirimFiyat, 
                ToplamTutar, KdvTutari, NetTutar, OlusturmaTarihi
            )
            SELECT 
                ss.ErpSatisNo,
                s.StokId,
                m.MekanId,
                ss.SatisTarihi,
                ss.Miktar,
                ss.BirimFiyat,
                ss.ToplamTutar,
                ss.KdvTutari,
                ss.NetTutar,
                SYSDATETIME()
            FROM etl.SatisStaging ss
            INNER JOIN ref.Stok s ON s.StokKodu = ss.ErpStokKodu
            INNER JOIN ref.Mekan m ON m.MekanKodu = ss.MekanKodu
            WHERE ss.ProcessedFlag = 0;
            
            SET @ProcessedRecords = @@ROWCOUNT;
            
            -- Staging tablosunu işaretli olarak güncelle
            UPDATE etl.SatisStaging SET ProcessedFlag = 1, ProcessedDate = SYSDATETIME()
            WHERE ProcessedFlag = 0;
        END
        
        ELSE IF @TableName = 'src.StokHareket'
        BEGIN
            -- Stok hareket verilerini yükle
            INSERT INTO src.StokHareket (
                HareketNo, StokId, MekanId, HareketTarihi, HareketTipi,
                GirisMiktar, CikisMiktar, BirimMaliyet, ToplamMaliyet, OlusturmaTarihi
            )
            SELECT 
                shs.ErpHareketNo,
                s.StokId,
                m.MekanId,
                shs.HareketTarihi,
                shs.HareketTipi,
                shs.GirisMiktar,
                shs.CikisMiktar,
                shs.BirimMaliyet,
                shs.ToplamMaliyet,
                SYSDATETIME()
            FROM etl.StokHareketStaging shs
            INNER JOIN ref.Stok s ON s.StokKodu = shs.ErpStokKodu
            INNER JOIN ref.Mekan m ON m.MekanKodu = shs.MekanKodu
            WHERE shs.ProcessedFlag = 0;
            
            SET @ProcessedRecords = @@ROWCOUNT;
            
            -- Staging tablosunu işaretli olarak güncelle
            UPDATE etl.StokHareketStaging SET ProcessedFlag = 1, ProcessedDate = SYSDATETIME()
            WHERE ProcessedFlag = 0;
        END
        
        -- Log kaydı
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, EndTime, RecordsProcessed, Message)
        VALUES ('StagingToMain_Load', 'LOAD', 'TAMAMLANDI', @StartTime, SYSDATETIME(), 
                @ProcessedRecords, CONCAT(@TableName, ' tablosuna veri yüklendi'));
        
        SELECT @ProcessedRecords as ProcessedRecords, 'Başarılı' as Status;
        
    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlLog (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('StagingToMain_Load', 'LOAD', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());
        
        THROW;
    END CATCH
END
GO

PRINT 'ERP ETL stored procedure''ları başarıyla oluşturuldu!';
PRINT 'Eklenen ERP ETL bileşenleri:';
PRINT '- etl.sp_ErpStok_Extract: ERP stok verilerini çekme';
PRINT '- etl.sp_ErpSatis_Extract: ERP satış verilerini çekme';
PRINT '- etl.sp_ErpStokHareket_Extract: ERP stok hareket verilerini çekme';
PRINT '- etl.sp_StagingToMain_Load: Staging''den ana tablolara yükleme';
PRINT '- etl.EtlLog: ETL işlem takip tablosu';
PRINT '- etl.EtlSyncStatus: ETL senkronizasyon durumu';
PRINT '- etl.StokStaging: Stok staging tablosu';
PRINT '- etl.SatisStaging: Satış staging tablosu';
PRINT '- etl.StokHareketStaging: Stok hareket staging tablosu';
PRINT '- etl.EtlDataQualityIssue: ETL veri kalitesi sorun takibi';