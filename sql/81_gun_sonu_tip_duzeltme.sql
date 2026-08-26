/* =====================================================================
   81_gun_sonu_tip_duzeltme.sql — `DATEADD(second, ...)` `date` tipinde
                                  calismaz (hata 9810)
   Plan    : 06 (Denetci Bulgulari), Faz 5 / S7 duzeltmesi
   Tarih   : 2026-08-26
   Bagimli : 78_audit_trail.sql (audit.sp_AuditLog_List)
             79_audit_delete_scope.sql (audit.sp_Audit_List)
   Geri al : Iki SP de `CREATE OR ALTER`.

   NE OLDU
   -------
   Bitis tarihini gun sonuna cekmek icin sunu yazdim:

       DATEADD(second, -1, DATEADD(day, 1, CAST(@Bitis AS date)))

   `CAST(... AS date)` sonucu `date` tipindedir; `DATEADD(day, 1, <date>)` de
   `date` doner. `date` tipinde SANIYE DATEPART'I GECERSIZ:

       Msg 9810 — "date veri turu icin dateadd tarih islevi second
                   datepart'i gecersizdir"

   NASIL YAKALANDI: migration iki kez sorunsuz uygulandi (DDL derlendi),
   `/Audit` sayfasi da 200 dondu — cunku suzgec bosken bu satir hic
   calismiyor. Ancak `?EndDate=2026-08-26` ile deneyince sayfa **500**
   verdi. Yani "migration basarili" ve "sayfa aciliyor" kanitlarinin IKISI
   DE yesildi ve kod yine kirikti; kusuru yalniz PARAMETRELI smoke gosterdi.

   Ayni hatali kalip `sql/78`'deki `audit.sp_AuditLog_List` icinde de vardi
   ve orada hic tetiklenmemisti (o SP'yi henuz cagiran ekran yok). Ikisi
   birlikte duzeltiliyor — bir kusuru onarip ayni kalibin baska nerede
   oldugunu aramamak, bu oturumda ogrenilen derslerden biri.

   DOGRU KALIP
   -----------
       DATEADD(second, -1, CAST(DATEADD(day, 1, CAST(@Bitis AS date)) AS datetime2(0)))

   SARGable kalir: kolona fonksiyon uygulanmiyor, yalniz SINIR DEGERI
   hesaplaniyor.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) audit.sp_Audit_List — gun sonu hesabi duzeltildi.
   Geri kalan her sey sql/79'daki halin aynisi (TotalCount dahil).
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
        -- Gun sonu: date -> datetime2(0) donusumu ZORUNLU, yoksa 9810.
        DECLARE @bitis datetime2(0) = CASE
            WHEN @EndDate IS NULL THEN NULL
            ELSE DATEADD(second, -1,
                     CAST(DATEADD(day, 1, CAST(@EndDate AS date)) AS datetime2(0)))
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
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   2) audit.sp_AuditLog_List — ayni kalip, hic tetiklenmemis hali.
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

        DECLARE @bitis datetime2(0) = CASE
            WHEN @BitisTarih IS NULL THEN NULL
            ELSE DATEADD(second, -1,
                     CAST(DATEADD(day, 1, CAST(@BitisTarih AS date)) AS datetime2(0)))
        END;

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
