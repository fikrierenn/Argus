/* =====================================================================
   79_audit_delete_scope.sql — Denetim silmede kapsam kapisi + tarih siniri
   Plan    : 06 (Denetci Bulgulari: Sunucu Kapilari), Faz 2 + Faz 5/S7
   Tarih   : 2026-08-26
   Bagimli : 21_sps_audit.sql (sp_Audit_Delete, sp_Audit_List)
             78_audit_trail.sql (audit.sp_AuditLog_Write)
   Geri al : Iki SP de `CREATE OR ALTER` — onceki tanima donmek icin
             sql/21_sps_audit.sql'deki bloklar yeniden uygulanir. Veri kaybi
             yok; geri alinirsa YALNIZ kontrol kalkar.

   NEDEN — olculdu, varsayilmadi
   -----------------------------
   Guvenlik denetimi (2026-08-26, IMP-3, confidence 95) uc eksigi bir arada
   buldu: kapsam kontrolu yok · hata koprusu yok · denetim izi yok. C# tarafi
   (try/catch + THROW koprusu + onay metninde cascade sayilari) ayni gun
   kapandi; SP tarafi bu dosya.

   CANLI TANIM (olculdu):
       CREATE PROCEDURE audit.sp_Audit_Delete @AuditId int
       - transaction YOK, XACT_ABORT YOK
       - yalniz iki kontrol: kayit var mi, IsFinalized mi
       - KIM sildigi hicbir yere yazilmiyor
       - CASCADE ile audit.AuditResults + AuditResultPhotos gidiyor

   KAPSAM KARARI ve NEDEN BU
   -------------------------
   `audit.Audits` semasi olculdu: **LocationId YOK** (yalniz `LocationName`
   nvarchar, serbest metin). Yani mekan-bazli kapsam kurulamaz. Kayit
   sahipligini tasiyan tek kolon `AuditorId int NOT NULL`.

   `AuditorId` hangi kimlik uzayinda? Veriden ANLASILMIYOR (butun denetimlerde
   1 ve id 1 hem `audit.Users` hem `ref.Personnel` icinde var). Yazan yer
   arandi: `sql/99_smoke_tests.sql:21` `@RealUserId = SELECT TOP 1 Id FROM
   audit.Users` -> **audit.Users.Id**. Kural bu uzaya gore kuruldu.

   Kural:
     ADMIN / YONETICI  -> her denetimi silebilir (yonetimsel yetki), AMA
                          iz kaydinda rol yaziliyor
     digerleri         -> yalniz KENDI denetimini (AuditorId = @KullaniciId)

   ADMIN'e genis yetki verilmesi bilincli; DOF gecisindeki ADMIN atlamasindan
   (plan 06 S11) farki su: burada atlama YOK, kural bu — ustelik silinebilen
   tek sey kesinlestirilmemis denetim ve her silme iz birakiyor. S11'deki
   sorun, onay zincirinin sessizce atlanmasiydi.

   IZ, TRANSACTION ICINDE yaziliyor: silme geri alinirsa iz de gitmeli
   (olmayan bir eylemin izi yanlis kayittir — 78'deki karar).
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) audit.sp_Audit_Delete — kapsam + transaction + Turkce THROW + iz
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Audit_Delete
    @AuditId     int,
    @KullaniciId int          = NULL,   -- NULL: kimlik bilinmiyor -> reddedilir
    @RolKodu     varchar(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @denetciId int, @mekan nvarchar(200), @tarih datetime2(0), @raporNo nvarchar(100);

        SELECT @denetciId = a.AuditorId,
               @mekan     = a.LocationName,
               @tarih     = a.AuditDate,
               @raporNo   = a.ReportNo
          FROM audit.Audits a
         WHERE a.Id = @AuditId;

        -- Is kurali: kayit yok.
        IF @denetciId IS NULL
            THROW 50210, N'Denetim bulunamadi.', 1;

        -- Is kurali: kesinlestirilmis denetim silinemez (evrak butunlugu).
        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
            THROW 50211, N'Kesinlestirilmis denetim silinemez.', 1;

        -- Is kurali: KAPSAM. Kimlik gelmediyse reddet — "bilinmiyorsa izin ver"
        -- en pahali varsayim olurdu (fail-closed).
        IF @KullaniciId IS NULL
            THROW 50212, N'Denetim silinemedi: kullanici kimligi gelmedi.', 1;

        IF NOT (@RolKodu IN ('ADMIN', 'YONETICI') OR @denetciId = @KullaniciId)
            THROW 50213, N'Bu denetimi silme yetkiniz yok: denetim baska bir denetciye ait.', 1;

        -- CASCADE kapsami: iz kaydina SAYILARLA yaziliyor, cunku silindikten
        -- sonra kac madde/fotograf gittigini okuyacak bir yer kalmiyor.
        DECLARE @madde int, @foto int;

        SELECT @madde = COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId;

        SELECT @foto = COUNT(*)
          FROM audit.AuditResultPhotos p
          JOIN audit.AuditResults r ON r.Id = p.AuditResultId
         WHERE r.AuditId = @AuditId;

        -- Iz metni ONCE degiskene kurulur: T-SQL'de EXEC argumani IFADE
        -- OLAMAZ (yalniz sabit veya degisken). Ilk yazimda birlestirme
        -- dogrudan @EskiDeger = N'..' + N'..' seklindeydi ve "'+' yakininda
        -- sozdizimi yanlis" (102) verdi — migration UYGULANMADI, yani hata
        -- sessizce gecmedi.
        DECLARE @izMetni nvarchar(1000) =
              N'Mekan: ' + ISNULL(@mekan, N'-')
            + N' | Tarih: ' + CONVERT(varchar(10), @tarih, 23)
            + N' | Rapor no: ' + ISNULL(@raporNo, N'-')
            + N' | Denetci (AuditorId): ' + CAST(@denetciId AS varchar(12))
            + N' | Silinen madde: ' + CAST(@madde AS varchar(12))
            + N' | Silinen fotograf: ' + CAST(@foto AS varchar(12))
            + N' | Silen rol: ' + ISNULL(@RolKodu, N'-');

        -- Iz SILMEDEN ONCE yazilir: ayni transaction icinde oldugu icin
        -- silme basarisiz olursa iz de geri alinir.
        EXEC audit.sp_AuditLog_Write
             @Eylem       = N'DENETIM_SILME',
             @TabloAdi    = N'audit.Audits',
             @KullaniciId = @KullaniciId,
             @KayitId     = @AuditId,
             @EskiDeger   = @izMetni;

        -- CASCADE audit.AuditResults ve AuditResultPhotos'u da siler.
        DELETE FROM audit.Audits WHERE Id = @AuditId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;   -- mesaj EZILMEZ (eski surum RAISERROR ile yeniden sariyordu)
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   2) audit.sp_Audit_List — bitis tarihi GUN SONU + gercek toplam
   (Faz 5 / S7 + I13'un yarisini kapatir)

   Olculen kusur: `a.AuditDate <= @EndDate`. `AuditDate` datetime2(0), yani
   saat tasiyabilir; `type="date"` girdisi gece yarisini gonderir. Bugun
   09:30'da kaydedilmis denetim "bitis = bugun" suzgecinde DUSUYORDU ve
   kullanici "bugunun denetimi girilmemis" saniyordu.

   Ek: `TotalCount = COUNT(*) OVER()`. Ekran basligi "@Audits.Count kayit"
   yaziyordu ve bu, TOP (@Top) ile kirpilmis sayiydi — 140 denetimlik bir
   ceyrekte kullanici "100 kayit" gorup ceyrek raporunu 100 denetimle
   yaziyordu. Simdi gercek toplam ayni taramada donuyor.
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_Audit_List
    @LocationName   nvarchar(100) = NULL,
    @StartDate      datetime2(0)  = NULL,
    @EndDate        datetime2(0)  = NULL,
    @IsFinalized    bit           = NULL,
    @Top            int           = 50
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Bitis tarihi gun sonuna cekilir. SARGable kalir: kolona fonksiyon
        -- uygulanmiyor, sinir DEGERI hesaplaniyor.
        DECLARE @bitis datetime2(0) = CASE
            WHEN @EndDate IS NULL THEN NULL
            ELSE DATEADD(second, -1, DATEADD(day, 1, CAST(@EndDate AS date)))
        END;

        SELECT TOP (@Top)
            a.Id,
            a.LocationName,
            a.LocationType,
            a.AuditDate,
            a.ReportDate,
            a.ReportNo,
            a.AuditorId,
            a.Manager,
            a.Directorate,
            a.IsFinalized,
            a.FinalizedAt,
            TotalItems   = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id),
            PassedItems  = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 1),
            FailedItems  = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 0),
            TotalCount   = COUNT(*) OVER()
        FROM audit.Audits a
        WHERE (@LocationName IS NULL OR a.LocationName LIKE '%' + @LocationName + '%')
          AND (@StartDate    IS NULL OR a.AuditDate >= @StartDate)
          AND (@bitis        IS NULL OR a.AuditDate <= @bitis)
          AND (@IsFinalized  IS NULL OR a.IsFinalized = @IsFinalized)
        ORDER BY a.AuditDate DESC, a.Id DESC;
    END TRY
    BEGIN CATCH
        THROW;   -- mesaj EZILMEZ
    END CATCH
END
GO
