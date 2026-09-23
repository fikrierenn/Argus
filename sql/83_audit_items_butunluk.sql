/* =====================================================================
   83_audit_items_butunluk.sql — Master denetim maddesi katalogu:
       risk olcegi siniri, degisiklik izi, pasife alma yolu.

   Tarih   : 2026-09-23
   Plan    : plans/08-audit-items-solum.md (Faz 2)
   Bagimli : 20_migration_audit.sql (tablo), 21_sps_audit.sql (SP tanimlari)

   NASIL KOSULUR — ONEMLI:
       sqlcli script sql/83_audit_items_butunluk.sql       <-- DOGRU
       sqlcli migrate                                       <-- BU BETIK ICIN YANLIS
   `migrate` kipi toleransli kosar: bir batch patlasa da sonrakiler kosar.
   Asagidaki 1. adimdaki VERI KAPISI tam olarak "patla ve DUR" mantigina
   dayaniyor; toleransli kipte kapi gecilir, CHECK constraint kurulmaz ama
   SP'ler kurulur ve is "tamam:N hata:2" ile biter — yani yarim uygulanmis
   bir sonuc SESSIZCE kabul edilmis olur.
   (sql-sp-reviewer bulgusu, 2026-09-23. Betigin kendisi calistirma kipini
   zorlayamaz; bu not o yuzden burada.)

   Geri al : Ayri bir geri-alma betigi yazilir ve YALNIZ su bes SP'nin
             21_sps_audit.sql'deki tanimini geri koyar:
               sp_Item_List · sp_Item_Insert · sp_Item_Update ·
               sp_Result_StartAudit · (sp_Item_SetActive DROP edilir)
             + ALTER TABLE audit.AuditItems DROP CONSTRAINT CK_AuditItems_Probability;
             + ALTER TABLE audit.AuditItems DROP CONSTRAINT CK_AuditItems_Impact;

             "sql/21_sps_audit.sql'i yeniden kos" DEMEYIN: o dosya 18 SP
             tanimlar ve DORDU sonradan duzeltilmistir —
             sp_Audit_Delete (sql/79, sql/82) · sp_Audit_List (sql/79, sql/81) ·
             sp_Analysis_DofEffectiveness (sql/77) ·
             sp_Analysis_FullPipeline (sql/43).
             Dosyayi yeniden kosmak silme kapsami ve durum sozlugu
             duzeltmelerini de SESSIZCE geri alir.
             (sql-sp-reviewer bulgusu, 2026-09-23.)

             Veri DEGISMEZ: kolon eklenmiyor, silinmiyor, satir guncellenmiyor.

   NEDEN (olculdu 2026-09-23):
     1) Probability / Impact HICBIR katmanda 1-5'e sinirlanmiyordu. HTML'de
        min/max vardi (bir kolayliktir, kapi degildir), C#'ta hicbir sey,
        SP parametresi tinyint (0-255). RiskScore = Probability x Impact ve
        rozet esikleri 15/9, yani olcek 5x5 = 25 varsayiliyor. 100 x 100
        gonderen bir istek 10000 skorlu madde yaratir ve HER esigi ezer;
        audit.AuditResults.RiskLevel persisted kolonu onu "High" der ve
        rapor sessizce bozulur.
     2) CreatedByUserId / UpdatedByUserId kolonlari TABLODA VAR ama
        sp_Item_Insert / sp_Item_Update bunlari HIC yazmiyordu. "Bu maddenin
        etkisini kim 5'ten 1'e dusurdu" sorusunun cevabi yoktu.
        security-principles.md "Referans tanim degisikligi" zaten zorunlu
        audit listesinde. UpdatedAt de hic yazilmiyordu: her madde sonsuza
        kadar "olusturuldugu gun guncellenmis" gorunuyordu.
     3) sp_Item_List @IsActive parametresini ALIYOR ama WHERE'de
        KULLANMIYORDU. Soft delete tasarlanmis, baglanmamis — sozlesmenin
        bir ucu yazilmis, karsi ucu yok.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1. VERI KAPISI — sinir disi kayit varsa DUR.

   CHECK constraint'i WITH NOCHECK ile eklemek mevcut bozuk satiri
   gecerli sayar ve kusuru gizler. Onun yerine migration BURADA durur;
   veri once duzeltilir, sonra betik tekrar kosulur.
   --------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1 FROM audit.AuditItems
    WHERE Probability NOT BETWEEN 1 AND 5
       OR Impact      NOT BETWEEN 1 AND 5
)
    THROW 50830, N'audit.AuditItems icinde 1-5 disinda Probability/Impact tasiyan kayit var. Once veriyi duzeltin, sonra bu betigi tekrar calistirin.', 1;
GO

/* ---------------------------------------------------------------------
   2. CHECK constraint — TEK GERCEK KAPI.

   SP disi her yol (elle UPDATE, ileride yazilacak ikinci SP, veri
   aktarimi) buradan gecer. C# [Range] ve SP THROW bunun USTUNE gelen
   kullanici dostu katmanlardir, yerine gecmez.

   0 BILEREK YASAK: carpimsal modelde 0 diger boyutu yok eder —
   Impact=5 (felaket) + Probability=0 -> skor 0 -> yesil rozet.
   "Bu madde artik gecerli degil" demenin yolu skoru 0 yapmak degil,
   IsActive = 0'dir (asagida baglaniyor).
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_AuditItems_Probability')
    ALTER TABLE audit.AuditItems
        ADD CONSTRAINT CK_AuditItems_Probability CHECK (Probability BETWEEN 1 AND 5);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_AuditItems_Impact')
    ALTER TABLE audit.AuditItems
        ADD CONSTRAINT CK_AuditItems_Impact CHECK (Impact BETWEEN 1 AND 5);
GO

/* ---------------------------------------------------------------------
   3. sp_Item_List — @IsActive nihayet WHERE'de.

   Varsayilan NULL = "hepsi" davranisi KORUNUR; mevcut cagri yerleri
   degismeden calisir. IsActive ve UpdatedAt kolonlari da SELECT'e
   eklendi — ekran pasif maddeyi aktiften ayirt edebilsin.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Item_List
    @LocationType   varchar(20)   = NULL,
    @AuditGroup     nvarchar(100) = NULL,
    @IsActive       bit           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            i.Id,
            i.LocationType,
            i.AuditGroup,
            i.Area,
            i.RiskType,
            i.ItemText,
            i.SortOrder,
            i.FindingType,
            i.Probability,
            i.Impact,
            RiskScore = CAST(i.Probability AS int) * CAST(i.Impact AS int),
            i.SkillId,
            i.IsActive,
            i.CreatedAt,
            i.UpdatedAt
        FROM audit.AuditItems i
        WHERE (@LocationType IS NULL OR i.LocationType = @LocationType OR i.LocationType = 'Both')
          AND (@AuditGroup   IS NULL OR i.AuditGroup = @AuditGroup)
          AND (@IsActive     IS NULL OR i.IsActive   = @IsActive)
        ORDER BY i.AuditGroup, i.SortOrder, i.Id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   4. sp_Item_Insert — degisiklik izi + transaction + THROW.

   PARAMETRE ADLARI INGILIZCE KALDI. sql-conventions.md Turkce parametre
   istiyor ama bu SP'ler Ingilizce adla yayimlanmis ve C# cagri yerleri
   onlara bagli; adlari degistirmek KIRICI bir degisikliktir ve bu planin
   kapsami degildir. YENI eklenen parametre kurala uyuyor: @KullaniciId.
   Karisiklik bilincli ve kayitli bir borctur.

   RAISERROR -> THROW: sql-conventions.md §4. Gerekce ilk yazilista YANLIS
   ifade edilmisti ("numara kayboluyordu"); sql-sp-reviewer duzeltti ve
   dogrusu DAHA CIDDI:

     Mesaj metinli RAISERROR(@Msg, 16, 1) hata numarasi olarak 50000
     uretir — yani 50000-59999 araliginin ICINDE. CATCH blogu
     ERROR_MESSAGE()'i yakalayip RAISERROR ile yeniden firlattigi icin
     FK ihlali (547), aritmetik tasma, deadlock gibi SISTEM hatalari da
     50000'e donusuyordu. C# koprusu (Items.cshtml.cs) bu araligi "is
     kurali, kullaniciya gosterilebilir" sayar — yani ham SQL hata metni
     dogrudan kullaniciya gidiyordu. Kalip fail-closed degil FAIL-OPEN'di.

   Ciplak THROW; ozgun numarayi korur: 547 artik 547 kalir ve generic
   mesajla karsilanir (error-handling.md).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Item_Insert
    @LocationType       varchar(20)   = 'Both',
    @AuditGroup         nvarchar(100),
    @Area               nvarchar(100),
    @RiskType           nvarchar(100),
    @ItemText           nvarchar(500),
    @SortOrder          int,
    @FindingType        char(1)       = NULL,
    @Probability        tinyint       = 3,
    @Impact             tinyint       = 3,
    @SkillId            int           = NULL,
    @KullaniciId        int           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: olcek 5x5. CHECK zaten reddeder ama ham constraint
        -- hatasi kullaniciya anlamsiz gorunur; mesaj Turkce ve 5xxxx.
        IF @Probability NOT BETWEEN 1 AND 5
            THROW 50831, N'Olasilik 1-5 araliginda olmali.', 1;

        IF @Impact NOT BETWEEN 1 AND 5
            THROW 50832, N'Etki 1-5 araliginda olmali.', 1;

        INSERT INTO audit.AuditItems
        (
            LocationType, AuditGroup, Area, RiskType, ItemText,
            SortOrder, FindingType, Probability, Impact,
            SkillId,
            CreatedByUserId, UpdatedByUserId,
            CreatedAt, UpdatedAt
        )
        VALUES
        (
            @LocationType, @AuditGroup, @Area, @RiskType, @ItemText,
            @SortOrder, @FindingType, @Probability, @Impact,
            @SkillId,
            @KullaniciId, @KullaniciId,
            SYSDATETIME(), SYSDATETIME()
        );

        DECLARE @YeniId int = CAST(SCOPE_IDENTITY() AS int);

        COMMIT TRANSACTION;

        SELECT @YeniId AS Id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   5. sp_Item_Update — UpdatedByUserId + UpdatedAt + sinir guard'i.

   COALESCE ANLAMI KORUNUYOR: NULL = "bu alani degistirme". C# tarafi
   Probability/Impact'i non-nullable int gonderdigi icin bos birakilan
   alan 0 gelebiliyordu; artik [Range(1,5)], asagidaki guard ve CHECK
   ucu birden reddediyor.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Item_Update
    @ItemId             int,
    @LocationType       varchar(20)   = NULL,
    @AuditGroup         nvarchar(100) = NULL,
    @Area               nvarchar(100) = NULL,
    @RiskType           nvarchar(100) = NULL,
    @ItemText           nvarchar(500) = NULL,
    @SortOrder          int           = NULL,
    @FindingType        char(1)       = NULL,
    @Probability        tinyint       = NULL,
    @Impact             tinyint       = NULL,
    @SkillId            int           = NULL,
    @KullaniciId        int           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM audit.AuditItems WHERE Id = @ItemId)
            THROW 50833, N'Denetim maddesi bulunamadi.', 1;

        IF @Probability IS NOT NULL AND @Probability NOT BETWEEN 1 AND 5
            THROW 50831, N'Olasilik 1-5 araliginda olmali.', 1;

        IF @Impact IS NOT NULL AND @Impact NOT BETWEEN 1 AND 5
            THROW 50832, N'Etki 1-5 araliginda olmali.', 1;

        UPDATE audit.AuditItems
        SET LocationType    = COALESCE(@LocationType,    LocationType),
            AuditGroup      = COALESCE(@AuditGroup,      AuditGroup),
            Area            = COALESCE(@Area,            Area),
            RiskType        = COALESCE(@RiskType,        RiskType),
            ItemText        = COALESCE(@ItemText,        ItemText),
            SortOrder       = COALESCE(@SortOrder,       SortOrder),
            FindingType     = COALESCE(@FindingType,     FindingType),
            Probability     = COALESCE(@Probability,     Probability),
            Impact          = COALESCE(@Impact,          Impact),
            SkillId         = COALESCE(@SkillId,         SkillId),
            UpdatedByUserId = COALESCE(@KullaniciId,     UpdatedByUserId),
            UpdatedAt       = SYSDATETIME()
        WHERE Id = @ItemId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   6. sp_Item_SetActive — pasife alma / geri acma.

   NEDEN SERT SILME DEGIL: bir madde silinirse ona bagli gecmis
   audit.AuditResults satirlarinin AuditItemId'si sahipsiz kalir ve
   "bu sonuc hangi maddeydi" sorusu cevapsizlasir. Katalog bir REFERANS
   kumesi; referanslar emekliye ayrilir, yok edilmez
   (sql-conventions.md §7 "soft delete tercih").

   Bu SP, 3. adimda WHERE'e baglanan @IsActive'in KARSI UCUDUR: parametre
   artik hem suzulebilir hem degistirilebilir. Yalniz birini yapmak,
   kapatmaya calistigimiz "sozlesmenin tek ucu yazilmis" hatasinin
   aynisi olurdu. Ucuncu uc 7. adimda: TUKETIM.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Item_SetActive
    @ItemId         int,
    @Aktif          bit,
    @KullaniciId    int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM audit.AuditItems WHERE Id = @ItemId)
            THROW 50833, N'Denetim maddesi bulunamadi.', 1;

        UPDATE audit.AuditItems
        SET IsActive        = @Aktif,
            UpdatedByUserId = COALESCE(@KullaniciId, UpdatedByUserId),
            UpdatedAt       = SYSDATETIME()
        WHERE Id = @ItemId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   7. sp_Result_StartAudit — PASIF MADDE ARTIK YENI DENETIME DUSMEZ.

   🔴 BU BOLUM BIR DENETCI BULGUSUDUR (sql-sp-reviewer, 2026-09-23,
   confidence 97) ve migration'in ilk halinde YOKTU.

   Yukaridaki 3. ve 6. adimlar IsActive'i suzulebilir ve degistirilebilir
   yapti. Ama audit.AuditResults'a YAZAN tek yer olan bu SP IsActive'i
   HIC sormuyordu: pasife alinan madde her yeni denetime kopyalanmaya
   devam ederdi. Bu arada ekran (Features/Audit/Items.cshtml) kullaniciya
   birebir soyle diyor:

       "...maddesi pasife alinacak. Yeni acilan denetimlere artik
        eklenmeyecek; gecmis denetim sonuclari oldugu gibi kalacak."

   Yani arayuz tutulmayan bir SOZ veriyordu. Kapatmaya calistigimiz
   hatanin (sozlesmenin bir ucu yazilmis, karsi ucu yok) tam olarak
   kendisi, bir katman otede.

   GECMIS ETKILENMEZ: audit.AuditResults bir snapshot'tir, bu degisiklik
   yalniz BUNDAN SONRA acilacak denetimlerin madde kumesini etkiler.

   Geri kalan govde sql/21_sps_audit.sql:507-560'tan AYNEN korundu;
   tek fark WHERE'e eklenen IsActive kosulu ve CATCH'in THROW'a donmesi.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Result_StartAudit
    @AuditId        int,
    @LocationType   varchar(20) = 'Store'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
            THROW 50834, N'Denetim bulunamadi.', 1;

        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
            THROW 50835, N'Kesinlestirilmis denetime madde eklenemez.', 1;

        -- Is kurali: ayni denetim icin sonuclar bir kez uretilir.
        IF EXISTS (SELECT 1 FROM audit.AuditResults WHERE AuditId = @AuditId)
            THROW 50836, N'Bu denetim icin sonuclar zaten olusturulmus.', 1;

        INSERT INTO audit.AuditResults
        (
            AuditId, AuditItemId,
            AuditGroup, Area, RiskType, ItemText,
            SortOrder, FindingType, Probability, Impact,
            IsPassed, RepeatCount, IsSystemic
        )
        SELECT
            @AuditId, i.Id,
            i.AuditGroup, i.Area, i.RiskType, i.ItemText,
            i.SortOrder, i.FindingType, i.Probability, i.Impact,
            1,  -- IsPassed = 1 (varsayilan gecti)
            0,  -- RepeatCount
            0   -- IsSystemic
        FROM audit.AuditItems i
        WHERE (i.LocationType = @LocationType OR i.LocationType = 'Both')
          AND i.IsActive = 1          -- <<< DENETCI BULGUSU: eksik olan kosul
        ORDER BY i.AuditGroup, i.SortOrder;

        DECLARE @EklenenSayi int = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT @EklenenSayi AS InsertedCount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
