/* =====================================================================
   78_audit_trail.sql — Denetim izi yazan TEK yol
   Plan    : 06 (Denetci Bulgulari: Sunucu Kapilari), Faz 1
   Tarih   : 2026-08-26
   Bagimli : 20_migration_audit.sql (audit.AuditLog tablosu),
             74_learning_loop_hardening.sql (mevcut satir-ici yazma deseni)
   Geri al : sp_AuditLog_Write / sp_AuditLog_List DROP edilebilir (veri kaybi
             yok). IX_AuditLog_Operation DROP edilebilir. CreatedAt
             varsayilanini geri almak icin DF_AuditLog_CreatedAt dusurulup
             varsayilan olarak GETDATE yazilir — ama GETDATE kural ihlali oldugu
             icin geri alinmasi ONERILMEZ.

   NEDEN
   -----
   `security-principles.md §Audit Log Kapsami` on bir eylemin loglanmasini
   ZORUNLU kiliyor. Olculdu (2026-08-26, canli DB):

       audit.AuditLog          -> 3 satir
       hepsi Operation = 'OGRENME_CEVAP', 2026-08-21, UserId 1
       kaynak: sql/74 ve sql/76 icindeki satir-ici INSERT'ler
       grep -rn "AuditLog" src/ --include=*.cs -> yazan 0 yer

   Yani denetim yazilimi KENDI eylemlerini kaydetmiyor: denetim silme,
   kesinlestirme, DOF durum gecisi, Excel disa aktarim, AI skill calistirma
   izsiz. Guvenlik denetimi (2026-08-26) bunu IMP-3 ve bilgi maddesi olarak
   ayri ayri raporladi.

   CANLI SEMA (olculdu, varsayilmadi — before-major-change.md §5)
   -------------------------------------------------------------
       Id        int IDENTITY PK
       UserId    int          NULL
       Operation nvarchar(100) NOT NULL
       TableName nvarchar(200) NOT NULL
       RecordId  int           NOT NULL      <- NULL KABUL ETMIYOR
       OldValues nvarchar(MAX) NULL
       NewValues nvarchar(MAX) NULL
       CreatedAt datetime2(7)  NOT NULL DEFAULT (getdate())
       IX_AuditLog_Date (CreatedAt) · IX_AuditLog_Table (TableName, RecordId)
       audit.Users.FullName mevcut (List SP'sindeki JOIN icin dogrulandi)

   BILINCLI YAPILMAYANLAR (borc olarak kayit)
   ------------------------------------------
   * `CreatedAt` tipi `datetime2(7)`; kural `datetime2(0)` istiyor. Kolon
     `IX_AuditLog_Date` index'ine dahil oldugu icin hassasiyet ALTER'i index
     bagimliligina takilabilir. Tek kazanci saniye kesrini atmak; RISKE
     DEGMEZ. Yeni tablolarda kural aynen gecerli.
   * PK adi otomatik (`PK__AuditLog__3214EC07AD5C3B20`), kural `PK_AuditLog`.
     Yeniden adlandirma veri/erisim degistirmez; ayri temizlik isi.
   * `IpAddress` / `UserAgent` kolonu YOK. Eklemek KVKK karari gerektirir
     (kisisel veri, saklama suresi) — bu fazin kapsami disi.

   TRANSACTION KARARI
   ------------------
   Iki yol birlikte kullanilir, farkli sebeplerle:
   * SP ICINDEN satir-ici INSERT (mevcut desen, sql/74): cagiran SP'nin
     transaction'ina girer. Is geri alinirsa iz de gider — DOGRU davranis,
     cunku olmayan bir eylemin izi YANLIS kayittir.
   * `sp_AuditLog_Write` (bu dosya): KENDI transaction'ini KURMAZ. C#'tan
     cagrilir (Excel disa aktarim, AI skill, basarili silme sonrasi); ambient
     transaction varsa ona katilir, yoksa tek INSERT zaten atomiktir.

   HATA DISIPLINI
   --------------
   SP hatayi YUTMAZ (`error-handling.md`: sessiz catch yasak) — `THROW` ile
   yukari verir. Ana islemi dusurmemek CAGIRANIN karari: `AuditTrail` servisi
   try/catch + LogError ile sarar; iz yazilamadigi UYGULAMA LOGUNDA gorunur,
   kullanicinin isi patlamaz. Ne sessizlik, ne kirilma.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) CreatedAt varsayilani: GETDATE yerine SYSDATETIME(), kisit ADLANDIRILIR.
   Idempotent: mevcut kisit adi otomatik uretildigi icin dinamik bulunup
   dusurulur. Zaten dogru adli ve dogru tanimli ise HIC dokunulmaz, yani
   ikinci kosuda tek ALTER bile calismaz.
--------------------------------------------------------------------- */
IF OBJECT_ID('audit.AuditLog', 'U') IS NOT NULL
BEGIN
    DECLARE @kisit sysname, @sql nvarchar(400);

    SELECT @kisit = dc.name
      FROM sys.default_constraints dc
      JOIN sys.columns c
        ON c.object_id = dc.parent_object_id
       AND c.column_id = dc.parent_column_id
     WHERE dc.parent_object_id = OBJECT_ID('audit.AuditLog')
       AND c.name = 'CreatedAt'
       AND (dc.name <> 'DF_AuditLog_CreatedAt' OR dc.definition <> '(sysdatetime())');

    IF @kisit IS NOT NULL
    BEGIN
        SET @sql = N'ALTER TABLE audit.AuditLog DROP CONSTRAINT ' + QUOTENAME(@kisit) + N';';
        EXEC sys.sp_executesql @sql;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
                    WHERE parent_object_id = OBJECT_ID('audit.AuditLog')
                      AND name = 'DF_AuditLog_CreatedAt')
        ALTER TABLE audit.AuditLog
            ADD CONSTRAINT DF_AuditLog_CreatedAt DEFAULT (SYSDATETIME()) FOR CreatedAt;
END
GO

/* ---------------------------------------------------------------------
   2) Eylem koduna gore filtreleme index'i.
   Neden: izin ilk iki kullanimi "kim neyi sildi" ve "bu ay kac Excel cikti";
   ikisi de Operation + CreatedAt uzerinden gidiyor. Mevcut iki index
   (CreatedAt tek basina, TableName+RecordId) bu erisimi karsilamiyor.
--------------------------------------------------------------------- */
IF OBJECT_ID('audit.AuditLog', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                    WHERE object_id = OBJECT_ID('audit.AuditLog')
                      AND name = 'IX_AuditLog_Operation')
    CREATE NONCLUSTERED INDEX IX_AuditLog_Operation
        ON audit.AuditLog (Operation, CreatedAt DESC)
        INCLUDE (UserId, TableName, RecordId);
GO

/* ---------------------------------------------------------------------
   3) audit.sp_AuditLog_Write — denetim izi yazan TEK yol.

   Parametreler TURKCE, kolonlar Ingilizce (`sql-conventions.md §1`).

   @KayitId: `RecordId` NOT NULL (olculdu). Tek bir kayda bagli OLMAYAN
   eylemler (Excel disa aktarim, toplu tarama) icin mevcut desen 0 kullaniyor
   (sql/76: `OGRENME_TARAMA ... 0`); ayni sozlesme surduruluyor. 0 = "tek
   kayda bagli degil". NULL secilmedi cunku sema kabul etmiyor ve semayi
   genisletmek bu fazin kapsami disi.
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_AuditLog_Write
    @Eylem       nvarchar(100),         -- SILME, KESINLESTIRME, DOF_GECIS, DISA_AKTARIM, AI_SKILL...
    @TabloAdi    nvarchar(200),         -- 'audit.Audits', 'dof.Findings', 'rpt.DailyProductRisk'
    @KullaniciId int           = NULL,  -- NULL: sistem/otomatik eylem
    @KayitId     int           = 0,     -- 0: tek kayda bagli degil
    @EskiDeger   nvarchar(MAX) = NULL,
    @YeniDeger   nvarchar(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: eylem kodu ve tablo adi zorunlu. Bos gecmek programlama
        -- hatasidir ve SESSIZ kalmamali: "bir sey oldu" diyen iz, hic
        -- olmayan izden daha kotudur (izlenemez kayit).
        IF @Eylem IS NULL OR LTRIM(RTRIM(@Eylem)) = N''
            THROW 55001, N'Denetim izi yazilamadi: eylem kodu bos.', 1;

        IF @TabloAdi IS NULL OR LTRIM(RTRIM(@TabloAdi)) = N''
            THROW 55002, N'Denetim izi yazilamadi: tablo adi bos.', 1;

        -- Not: acik BEGIN TRANSACTION YOK. Tek INSERT zaten atomik; cagiran
        -- bir transaction icindeyse ona katilir (ustteki TRANSACTION KARARI).
        INSERT INTO audit.AuditLog (UserId, Operation, TableName, RecordId,
                                    OldValues, NewValues, CreatedAt)
        VALUES (@KullaniciId,
                LEFT(@Eylem, 100),
                LEFT(@TabloAdi, 200),
                ISNULL(@KayitId, 0),
                @EskiDeger,
                @YeniDeger,
                SYSDATETIME());

        SELECT CAST(SCOPE_IDENTITY() AS int) AS LogId;
    END TRY
    BEGIN CATCH
        -- Yutma YOK. Cagiran (AuditTrail servisi) yakalar, uygulama loguna
        -- yazar ve kullanicinin islemini dusurmez.
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   4) audit.sp_AuditLog_List — izi okuma.
   Ekran henuz yok; bu SP plan 06 "done criteria"nin kanit sorgusu ve
   ileride Yonetim ekranina baglanacak. Sayfalama SP icinde (C# tarafinda
   Skip/Take yasak — tum satir cekilir).
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_AuditLog_List
    @KullaniciId    int           = NULL,
    @Eylem          nvarchar(100) = NULL,
    @TabloAdi       nvarchar(200) = NULL,
    @BaslangicTarih datetime2(0)  = NULL,
    @BitisTarih     datetime2(0)  = NULL,
    @Sayfa          int           = 1,
    @SayfaBoyutu    int           = 50
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @Sayfa IS NULL OR @Sayfa < 1 SET @Sayfa = 1;
        IF @SayfaBoyutu IS NULL OR @SayfaBoyutu < 1 SET @SayfaBoyutu = 50;
        IF @SayfaBoyutu > 200 SET @SayfaBoyutu = 200;

        -- Bitis tarihi GUN SONUNA cekilir: `<= @BitisTarih` gece yarisi
        -- karsilastirmasi ayni gunun kayitlarini dusuruyor. Ayni tuzak
        -- denetim listesinde de vardi (plan 06 I10) — tekrarlanmiyor.
        DECLARE @bitis datetime2(0) = CASE
            WHEN @BitisTarih IS NULL THEN NULL
            ELSE DATEADD(second, -1, DATEADD(day, 1, CAST(@BitisTarih AS date)))
        END;

        -- Gercek toplam AYNI TARAMADA doner; ekranin "N kayit"i gercek
        -- toplam olsun (plan 06 I6 ile ayni ders: sayfa sayisini toplam
        -- gibi gostermek sessiz kirpma uretiyor).
        SELECT l.Id,
               l.UserId,
               u.FullName        AS UserName,
               l.Operation,
               l.TableName,
               l.RecordId,
               l.OldValues,
               l.NewValues,
               l.CreatedAt,
               COUNT(*) OVER()   AS TotalCount
          FROM audit.AuditLog l
          LEFT JOIN audit.Users u ON u.Id = l.UserId
         WHERE (@KullaniciId    IS NULL OR l.UserId    = @KullaniciId)
           AND (@Eylem          IS NULL OR l.Operation = @Eylem)
           AND (@TabloAdi       IS NULL OR l.TableName = @TabloAdi)
           AND (@BaslangicTarih IS NULL OR l.CreatedAt >= @BaslangicTarih)
           AND (@bitis          IS NULL OR l.CreatedAt <= @bitis)
         ORDER BY l.Id DESC
         OFFSET (@Sayfa - 1) * @SayfaBoyutu ROWS
         FETCH NEXT @SayfaBoyutu ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
