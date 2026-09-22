/* =====================================================================
   82_zincir_onarimi_ve_kapsam.sql
   Plan    : 06 (Denetci Bulgulari) — denetci bulgulari uzerine duzeltmeler
   Tarih   : 2026-08-27
   Bagimli : 20_migration_audit.sql · 78_audit_trail.sql · 79_audit_delete_scope.sql
   Geri al : Tablo olusturma bloklari yalniz EKSIKSE calisir; var olan tabloya
             dokunmaz. SP'ler `CREATE OR ALTER` (onceki tanimlar 79/80'de).
             AuditorUserId -> AuditorId yeniden adlandirma geri alinmak
             istenirse ters yonde `sp_rename` gerekir.

   ====================================================================
   BULGU 1 (sql-sp-reviewer, HIGH): sql/ zinciri TEMIZ BIR DB'DE
   `audit.AuditLog` ve `audit.Users` tablolarini URETMIYOR.
   ====================================================================
   Olculdu (2026-08-27):
     - `grep -rn "CREATE TABLE audit.AuditLog" sql/`  -> 0 sonuc
     - `grep -rn "CREATE TABLE audit.Users" sql/`     -> 0 sonuc
     - `sql/20_migration_audit.sql` ALTI tablo yaratiyor: Skills, SkillVersions,
       AuditItems, Audits, AuditResults, AuditResultPhotos
     - Canli DB'de ON tane audit tablosu var; dosyalarda olmayan DORT tane:
       AuditLog, Users, AiAnalyses, CorrectiveActions
     - `sql/78`'in "Bagimli: 20_migration_audit.sql (audit.AuditLog tablosu)"
       satiri YANLIS: sql/20 icinde AuditLog gecmiyor.

   Yani bu tablolar canliya ELLE eklenmis. Temiz kurulumda:
     * 78'in default/index bloklari `IF OBJECT_ID(...) IS NOT NULL` ile
       korumali oldugu icin SESSIZCE atlanir,
     * `sp_Audit_Delete` icindeki `EXEC sp_AuditLog_Write` calisma aninda
       208 (nesne yok) verir ve `XACT_ABORT ON` yuzunden HICBIR DENETIM
       SILINEMEZ hale gelir.

   Bu dosya plan 06'nin DAYANDIGI iki tabloyu onariyor. `AiAnalyses` ve
   `CorrectiveActions` plan 06 SP'lerinin dokunmadigi tablolar; onlar ayri
   zincir-onarim isi olarak TODO'ya yazildi (bu dosyada UYDURULMADI).

   ====================================================================
   BULGU 2 (sql-sp-reviewer, HIGH): kolon adi ayrismasi
   ====================================================================
   `sql/20_migration_audit.sql:111` -> `AuditorUserId int NULL`
   canli + `sql/21` + `sql/79` + `sql/81`  -> `AuditorId`
   Temiz kurulumda 79/81'in SP'leri 207 (gecersiz kolon adi) ile OLUSMAZ.

   ====================================================================
   BULGU 3 (kendi olcumum, 2026-08-27): KOLON GENISLIGINI YANLIS BELGELEDIM
   ====================================================================
   `sql/78` basliginda "Operation nvarchar(100) / TableName nvarchar(200)"
   yaziyor. INFORMATION_SCHEMA ile kesin olcum:
       Operation  nvarchar(50)
       TableName  nvarchar(100)
   `sp_AuditLog_Write` parametreleri (100)/(200) tanimli ve `LEFT(@Eylem,100)`
   yapiyor — yani 50 karakteri gecen bir eylem kodu kolona SIGMAZ ve
   8152 (string truncation) verir. Bugunku kodlarin en uzunu
   'DENETIM_KESINLESTIRME' (21 karakter) oldugu icin hic tetiklenmedi.
   Ilk aracin ciktisina guvenip capraz kontrol etmemistim — `before-major-change.md
   §5`'in tam tersi yonde ayni tuzak.

   ====================================================================
   BULGU 4 (sql-sp-reviewer MEDIUM + kendi olcumum): SILME KAPI SIRASI
   ====================================================================
   79'daki sira: [var mi] -> [kesinlestirilmis mi] -> [kimlik] -> [kapsam]
   Sonuc: kapsam disi bir kullanici POST ile id tarayarak UC durumu ayirt
   ediyor — "bulunamadi" / "kesinlestirilmis" / "sana ait degil". Yani
   baskasinin denetiminin VARLIGI, DURUMU ve SAHIPLIGI sizdiriliyor
   (`security-principles.md §13`). Kendi olcumum: audit 9 icin kapsam-disi
   kullaniciya 50213 degil 50211 dondu — durum, yetkiden once ifsa ediliyor.
   Yeni sira: [kimlik] -> [var mi + kapsam AYNI mesajla] -> [kesinlestirilmis].

   ====================================================================
   BULGU 5 (sql-sp-reviewer MEDIUM): varlik NULL kolondan cikarilıyor
   ====================================================================
   `IF @denetciId IS NULL THROW 50210` — "satir yok" ile "satir var ama
   AuditorId NULL" ayni sayiliyor. `sql/20:111` kolonu NULL kabul ediyor ve
   `sql/21:116` `@AuditorId int = NULL` varsayilaniyla boyle satir uretilebilir.
   Boyle bir denetim SILINEMEZ hale gelir ve ekran "yok" der. `NOT EXISTS` ile
   ayristirildi.

   ====================================================================
   BULGU 6 (security-reviewer IMP-3): rol talebi 7 GUNLUK FOTOGRAF
   ====================================================================
   `Program.cs:30-31` `ExpireTimeSpan = 7 gun` + `SlidingExpiration`, ve
   `OnValidatePrincipal` kancasi YOK. ADMIN'den DENETCI'ye dusurulen ya da
   `IsLocked = 1` yapilan kullanici, cerezi ADMIN dedigi surece baskasinin
   denetimini silmeye devam eder. Rol artik SP ICINDE `audit.Users`'tan
   COZULUYOR: dusurme/kilitleme aninda etkili olur, iz metnindeki rol
   kendi kendine tutarli olur ve kilitli/pasif kullanici reddedilir.
   @RolKodu parametresi GERIYE UYUM icin duruyor ama YETKI KARARINDA
   KULLANILMIYOR (yalnizca cagiranin ne gonderdigini ize yazmak icin).
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) audit.AuditLog — temiz kurulumda yoksa olusturulur.
   Tipler CANLI SEMADAN olculdu (INFORMATION_SCHEMA).
   Not: CreatedAt canlida datetime2(7); kural datetime2(0) istiyor ama
   canliyla ayrismamak icin (7) korunuyor — borc sql/78 basliginda kayitli.
--------------------------------------------------------------------- */
IF OBJECT_ID('audit.AuditLog', 'U') IS NULL
BEGIN
    CREATE TABLE audit.AuditLog
    (
        Id         int            IDENTITY(1,1) NOT NULL,
        UserId     int            NULL,
        Operation  nvarchar(50)   NOT NULL,
        TableName  nvarchar(100)  NOT NULL,
        RecordId   int            NOT NULL,
        OldValues  nvarchar(max)  NULL,
        NewValues  nvarchar(max)  NULL,
        CreatedAt  datetime2(7)   NOT NULL CONSTRAINT DF_AuditLog_CreatedAt DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (Id)
    );
END
GO

IF OBJECT_ID('audit.AuditLog', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('audit.AuditLog') AND name = 'IX_AuditLog_Table')
    CREATE NONCLUSTERED INDEX IX_AuditLog_Table ON audit.AuditLog (TableName, RecordId);
GO

IF OBJECT_ID('audit.AuditLog', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('audit.AuditLog') AND name = 'IX_AuditLog_Date')
    CREATE NONCLUSTERED INDEX IX_AuditLog_Date ON audit.AuditLog (CreatedAt);
GO

/* ---------------------------------------------------------------------
   2) audit.Users — temiz kurulumda yoksa olusturulur (16 kolon, canliyla bire bir).
   `ref.Users` ve `audit.Users` AYRI tablolardir (CLAUDE.md): ref = ERP
   kullanicilari, audit = giris yapan uygulama kullanicilari.
--------------------------------------------------------------------- */
IF OBJECT_ID('audit.Users', 'U') IS NULL
BEGIN
    CREATE TABLE audit.Users
    (
        Id                    int            IDENTITY(1,1) NOT NULL,
        Email                 nvarchar(256)  NOT NULL,
        PasswordHash          nvarchar(256)  NOT NULL,
        FullName              nvarchar(200)  NOT NULL,
        CreatedAt             datetime2(7)   NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSDATETIME()),
        Username              nvarchar(50)   NULL,
        RoleCode              varchar(20)    NOT NULL CONSTRAINT DF_Users_RoleCode DEFAULT ('DENETCI'),
        FailedLoginCount      int            NOT NULL CONSTRAINT DF_Users_FailedLoginCount DEFAULT (0),
        IsLocked              bit            NOT NULL CONSTRAINT DF_Users_IsLocked DEFAULT (0),
        LastLoginAt           datetime2(0)   NULL,
        LastPasswordChangeAt  datetime2(0)   NULL,
        IsActive              bit            NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
        UpdatedAt             datetime2(0)   NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT (SYSDATETIME()),
        CreatedByUserId       int            NULL,
        UpdatedByUserId       int            NULL,
        MustChangePassword    bit            NOT NULL CONSTRAINT DF_Users_MustChangePassword DEFAULT (1),
        CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Users_Email UNIQUE (Email)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UQ_Users_Username ON audit.Users (Username)
        WHERE Username IS NOT NULL;
END
GO

/* ---------------------------------------------------------------------
   3) audit.Audits kolon adi uzlastirma: AuditorUserId -> AuditorId.
   Canlida AuditorId var; temiz kurulumda sql/20 AuditorUserId uretiyor.
   Idempotent: yalniz eski ad VAR ve yeni ad YOKSA yeniden adlandirir.
--------------------------------------------------------------------- */
IF OBJECT_ID('audit.Audits', 'U') IS NOT NULL
   AND COL_LENGTH('audit.Audits', 'AuditorUserId') IS NOT NULL
   AND COL_LENGTH('audit.Audits', 'AuditorId') IS NULL
BEGIN
    EXEC sys.sp_rename N'audit.Audits.AuditorUserId', N'AuditorId', N'COLUMN';
END
GO

/* ---------------------------------------------------------------------
   4) audit.sp_AuditLog_Write — kolon genisligi DUZELTILDI.
   Parametreler ve LEFT() siniri gercek kolon genisligine cekildi
   (Operation 50, TableName 100). Onceki hal 50'lik kolona 100 karakter
   sokmaya calisabiliyordu -> 8152.
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_AuditLog_Write
    @Eylem       nvarchar(50),          -- kolon genisligi 50 (olculdu)
    @TabloAdi    nvarchar(100),         -- kolon genisligi 100 (olculdu)
    @KullaniciId int           = NULL,
    @KayitId     int           = 0,
    @EskiDeger   nvarchar(MAX) = NULL,
    @YeniDeger   nvarchar(MAX) = NULL,
    @LogId       int           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: eylem kodu ve tablo adi zorunlu. "Bir sey oldu" diyen iz,
        -- hic olmayan izden daha kotudur (izlenemez kayit).
        --
        -- NOT: 55001/55002 kullaniciya gosterilebilir bantta (50000-59999) ama
        -- bunlar PROGRAMLAMA hatasi. Bugun iki cagri yeri de sabit metin
        -- gectigi icin ulasilamaz; mesajlar kullaniciyi suclamayan bicimde
        -- yazildi (sql-sp-reviewer LOW).
        IF @Eylem IS NULL OR LTRIM(RTRIM(@Eylem)) = N''
            THROW 55001, N'Denetim izi yazilamadi: eylem kodu bos (sistem hatasi).', 1;

        IF @TabloAdi IS NULL OR LTRIM(RTRIM(@TabloAdi)) = N''
            THROW 55002, N'Denetim izi yazilamadi: tablo adi bos (sistem hatasi).', 1;

        -- Acik BEGIN TRANSACTION YOK: tek INSERT atomik; cagiran bir
        -- transaction icindeyse ONA KATILIR. sp_Audit_Delete bu davranisa
        -- dayaniyor (iz ile silme ayni transaction'da).
        INSERT INTO audit.AuditLog (UserId, Operation, TableName, RecordId,
                                    OldValues, NewValues, CreatedAt)
        VALUES (@KullaniciId,
                LEFT(@Eylem, 50),
                LEFT(@TabloAdi, 100),
                ISNULL(@KayitId, 0),
                @EskiDeger,
                @YeniDeger,
                SYSDATETIME());

        SET @LogId = CAST(SCOPE_IDENTITY() AS int);   -- sonuc kumesi YOK
    END TRY
    BEGIN CATCH
        THROW;   -- yutma yok; cagiran (AuditTrail) loglar, isi dusurmez
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   5) audit.sp_Audit_Delete — kapi sirasi, varlik testi ve ROL KAYNAGI
      duzeltildi.

   Degisenler:
     a) Sira: kimlik -> (varlik + kapsam AYNI mesaj) -> kesinlestirilmis.
        Kapsam disi kullanici artik "var mi / kesinlesmis mi / kimin"
        ayrimini OGRENEMIYOR.
     b) Varlik `NOT EXISTS` ile test ediliyor; AuditorId NULL olan satir
        artik "yok" sayilmiyor.
     c) Rol `audit.Users`'tan COZULUYOR (cerezdeki 7 gunluk fotograf degil).
        Kilitli veya pasif kullanici reddediliyor.
     d) @RolKodu yalnizca IZE yaziliyor; yetki kararinda kullanilmiyor.
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Audit_Delete
    @AuditId     int,
    @KullaniciId int          = NULL,   -- NULL: kimlik bilinmiyor -> reddedilir
    @RolKodu     varchar(20)  = NULL    -- YALNIZ iz icin; yetkide kullanilmaz
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- (1) KIMLIK. Fail-closed: "bilinmiyorsa izin ver" en pahali varsayim.
        IF @KullaniciId IS NULL
            THROW 50212, N'Denetim silinemedi: kullanici kimligi gelmedi.', 1;

        -- (2) ROL, DB'DEN. Cerezdeki rol 7 gun bayat kalabiliyor; dusurme ya da
        -- kilitleme aninda etkili olsun (security-reviewer IMP-3).
        DECLARE @gercekRol varchar(20), @kilitli bit, @aktif bit;

        SELECT @gercekRol = u.RoleCode,
               @kilitli   = u.IsLocked,
               @aktif     = u.IsActive
          FROM audit.Users u
         WHERE u.Id = @KullaniciId;

        IF @gercekRol IS NULL
            THROW 50214, N'Denetim silinemedi: kullanici bulunamadi.', 1;

        IF @kilitli = 1 OR @aktif = 0
            THROW 50215, N'Denetim silinemedi: hesabiniz kilitli ya da pasif.', 1;

        -- (3) VARLIK + KAPSAM, AYNI MESAJ. Ikisini ayirmak kapsam disi
        -- kullaniciya baskasinin denetiminin varligini sizdirirdi
        -- (`security-principles.md §13`: yetkisizde "yok" gibi davran).
        DECLARE @denetciId int;

        SELECT @denetciId = a.AuditorId
          FROM audit.Audits a
         WHERE a.Id = @AuditId;

        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
           OR NOT (@gercekRol IN ('ADMIN', 'YONETICI') OR @denetciId = @KullaniciId)
            THROW 50213, N'Denetim bulunamadi ya da silme yetkiniz yok.', 1;

        -- (4) IS KURALI: kesinlestirilmis denetim silinemez (evrak butunlugu).
        -- Artik YETKIDEN SONRA: bu bilgi yalniz yetkili kullaniciya veriliyor.
        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
            THROW 50211, N'Kesinlestirilmis denetim silinemez.', 1;

        -- CASCADE kapsami ize SAYILARLA yaziliyor: silindikten sonra kac
        -- madde/fotograf gittigini okuyacak yer kalmiyor.
        DECLARE @mekan nvarchar(200), @tarih datetime2(0), @raporNo nvarchar(100);
        DECLARE @madde int, @foto int;

        SELECT @mekan = a.LocationName, @tarih = a.AuditDate, @raporNo = a.ReportNo
          FROM audit.Audits a WHERE a.Id = @AuditId;

        SELECT @madde = COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId;

        SELECT @foto = COUNT(*)
          FROM audit.AuditResultPhotos p
          JOIN audit.AuditResults r ON r.Id = p.AuditResultId
         WHERE r.AuditId = @AuditId;

        -- EXEC argumani IFADE olamaz; metin once degiskene kurulur.
        DECLARE @izMetni nvarchar(1000) =
              N'Mekan: ' + ISNULL(@mekan, N'-')
            + N' | Tarih: ' + CONVERT(varchar(10), @tarih, 23)
            + N' | Rapor no: ' + ISNULL(@raporNo, N'-')
            + N' | Denetci (AuditorId): ' + ISNULL(CAST(@denetciId AS varchar(12)), N'-')
            + N' | Silinen madde: ' + CAST(@madde AS varchar(12))
            + N' | Silinen fotograf: ' + CAST(@foto AS varchar(12))
            + N' | Silen rol (DB): ' + @gercekRol
            + N' | Cagiranin bildirdigi rol: ' + ISNULL(@RolKodu, N'-');

        -- Iz SILMEDEN ONCE ve AYNI transaction icinde: silme geri alinirsa
        -- iz de geri alinir.
        EXEC audit.sp_AuditLog_Write
             @Eylem       = N'DENETIM_SILME',
             @TabloAdi    = N'audit.Audits',
             @KullaniciId = @KullaniciId,
             @KayitId     = @AuditId,
             @EskiDeger   = @izMetni;

        DELETE FROM audit.Audits WHERE Id = @AuditId;   -- CASCADE sonuc+fotograf

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;   -- mesaj EZILMEZ
    END CATCH
END
GO
