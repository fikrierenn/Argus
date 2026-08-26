/* =====================================================================
   80_risk_total_export.sql — Gercek toplam + disa aktarim kipi
                              + iz SP'sinin sonuc kumesi kusuru
   Plan    : 06 (Denetci Bulgulari), Faz 5 / S6 + I7 ve Faz 1 duzeltmesi
   Tarih   : 2026-08-26
   Bagimli : 30_sps_ref_rpt_english.sql (rpt.sp_RiskList)
             78_audit_trail.sql (audit.sp_AuditLog_Write)
   Geri al : Iki SP de `CREATE OR ALTER`; onceki tanimlar sirasiyla
             sql/30 ve sql/78 icinde. Veri kaybi yok.

   BU DOSYA UC SEY YAPIYOR
   -----------------------
   1) `audit.sp_AuditLog_Write` artik SONUC KUMESI DONDURMUYOR.
      OLCUM (2026-08-26): sql/79'un `sp_Audit_Delete`'i icinden bu SP
      cagrilinca, SP'nin `SELECT SCOPE_IDENTITY()` satiri cagiranin ILK
      sonuc kumesi oldu ve benim tani amacli SELECT'imi GIZLEDI. Dapper
      `ExecuteAsync` icin zararsiz ama `QuerySingle` kullanan bir cagiran
      YANLIS kumeyi okur. Bu, Faz 1'de benim urettigim bir kusur; LogId
      artik OUTPUT parametresi.

   2) `rpt.sp_RiskList` gercek toplami donduruyor (`TotalCount`).
      OLCUM: `PagedResult`'a sayfanin satir sayisi veriliyordu, yani
      `TotalCount = 50` ve `PageCount = 1`; Solum'un sayfalayicisi hic
      cizilmiyordu ve ekran "50 satir" derken gercek kume 10.000+ satirdi.
      Kullanici "Sonraki"ye basip bos sayfaya varinca "Risk kaydi bulunamadi.
      Suzgeci genisletin" okuyor ve saglam suzgecini bozuyordu.

   3) `rpt.sp_RiskList` DISA AKTARIM kipi (`@Export`).
      OLCUM: SP `IF @PageSize > 200 SET @PageSize = 200` ile kirpiyor ve
      `@Top` `COALESCE` yuzunden inert. Excel disa aktarimi bu yuzden
      SESSIZCE 200 satir donduruyordu (KRITIK bulgu). C# tarafi gecici
      olarak 25 cagrilik sayfa dongusu kurdu — olculdu: 5000 satir 28 sn.
      `@Export = 1` kirpmayi atlar, dongu tek cagriya iner.

   NEDEN AYNI DOSYADA: ucu de "sayi dogru mu" sorusunun ayni yuzu ve
   ikisi ayni cagri zincirinde (disa aktarim -> iz).
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1) audit.sp_AuditLog_Write — LogId artik OUTPUT, sonuc kumesi YOK.
   Geriye uyum: `@LogId` opsiyonel; vermeyen cagiranlar (C# AuditTrail)
   etkilenmez.
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE audit.sp_AuditLog_Write
    @Eylem       nvarchar(100),
    @TabloAdi    nvarchar(200),
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
        -- Is kurali: eylem kodu ve tablo adi zorunlu. Bos gecmek programlama
        -- hatasidir; "bir sey oldu" diyen iz, hic olmayan izden daha kotudur.
        IF @Eylem IS NULL OR LTRIM(RTRIM(@Eylem)) = N''
            THROW 55001, N'Denetim izi yazilamadi: eylem kodu bos.', 1;

        IF @TabloAdi IS NULL OR LTRIM(RTRIM(@TabloAdi)) = N''
            THROW 55002, N'Denetim izi yazilamadi: tablo adi bos.', 1;

        INSERT INTO audit.AuditLog (UserId, Operation, TableName, RecordId,
                                    OldValues, NewValues, CreatedAt)
        VALUES (@KullaniciId,
                LEFT(@Eylem, 100),
                LEFT(@TabloAdi, 200),
                ISNULL(@KayitId, 0),
                @EskiDeger,
                @YeniDeger,
                SYSDATETIME());

        -- SONUC KUMESI YOK (bkz. dosya basi, madde 1).
        SET @LogId = CAST(SCOPE_IDENTITY() AS int);
    END TRY
    BEGIN CATCH
        THROW;   -- yutma yok; cagiran (AuditTrail) loglar, isi dusurmez
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   2) rpt.sp_RiskList — TotalCount + @Export kipi
   Tanim sql/30'daki halin BIREBIR uzerine kuruldu (canli tanim okundu);
   filtreler, siralama ve alias'lar DEGISMEDI. Eklenen: @Export parametresi,
   kirpma atlamasi ve TotalCount kolonu.
--------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE rpt.sp_RiskList
    @Top int = 500,
    @KesimGunu date = NULL,
    @KesimBas date = NULL,
    @KesimBit date = NULL,
    @Search nvarchar(80) = NULL,
    @MinSkor int = NULL,
    @MaxSkor int = NULL,
    @MekanCSV varchar(max) = NULL,
    @TipCSV varchar(max) = NULL,
    @OrderBy varchar(20) = NULL,
    @OrderDir varchar(4) = NULL,
    @Page int = 1,
    @PageSize int = NULL,
    @Export bit = 0            -- 1: 200 satir kirpmasi ATLANIR (Excel)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Bas date = COALESCE(@KesimBas, '19000101');
    DECLARE @Bit date = COALESCE(@KesimBit, '99991231');
    DECLARE @Kesim date = @KesimGunu;
    IF @Kesim IS NULL
    BEGIN
        SELECT @Kesim = MAX(CONVERT(date, SnapshotDate))
        FROM rpt.DailyProductRisk
        WHERE CONVERT(date, SnapshotDate) BETWEEN @Bas AND @Bit;
    END

    -- NOT: burada `IF @Kesim IS NULL RETURN;` duruyor ve SONUC KUMESI HIC
    -- DONMUYOR. Ekran bunu "kayit yok" diye okuyup "suzgeci genisletin"
    -- diyor; kullanici ETL'in hic kosmadigini ogrenemiyor (plan 06 I11).
    -- Bu dosyada DEGISTIRILMEDI cunku bayrak dondurmek cagiran sozlesmesini
    -- degistirir ve I11 ayri kalem.
    IF @Kesim IS NULL
        RETURN;

    IF @Page IS NULL OR @Page < 1
        SET @Page = 1;

    SET @PageSize = COALESCE(@PageSize, @Top, 50);
    IF @PageSize < 10
        SET @PageSize = 10;

    -- 200 satir kirpmasi: ekran icin korunuyor (sayfa boyutu secenekleri
    -- 20/50/100/200), disa aktarimda ATLANIYOR. Eskiden kosulsuzdu ve Excel
    -- indirmeyi SESSIZCE 200 satira dusuruyordu.
    IF @Export = 1
    BEGIN
        SET @PageSize = 1000000;
        SET @Page = 1;
    END
    ELSE IF @PageSize > 200
        SET @PageSize = 200;

    DECLARE @Offset int = (@Page - 1) * @PageSize;

    DECLARE @SearchTerm nvarchar(80) = NULLIF(LTRIM(RTRIM(@Search)), '');
    DECLARE @OrderByClean varchar(20) = UPPER(LTRIM(RTRIM(COALESCE(@OrderBy, ''))));
    DECLARE @OrderDirClean varchar(4) = CASE WHEN UPPER(@OrderDir) = 'ASC' THEN 'ASC' ELSE 'DESC' END;

    IF @OrderByClean NOT IN ('SKOR', 'MEKAN', 'URUN', 'STOK', 'SONHAREKET')
        SET @OrderByClean = 'SKOR';

    IF @MinSkor IS NOT NULL AND @MaxSkor IS NOT NULL AND @MinSkor > @MaxSkor
    BEGIN
        DECLARE @tmp int = @MinSkor;
        SET @MinSkor = @MaxSkor;
        SET @MaxSkor = @tmp;
    END

    DECLARE @Tip TABLE (TipKodu varchar(30) PRIMARY KEY);
    IF LTRIM(RTRIM(COALESCE(@TipCSV, ''))) <> ''
    BEGIN
        INSERT INTO @Tip (TipKodu)
        SELECT DISTINCT UPPER(LTRIM(RTRIM(value)))
        FROM STRING_SPLIT(@TipCSV, ',')
        WHERE LTRIM(RTRIM(COALESCE(value, ''))) <> '';
    END

    ;WITH Mekan AS (
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
    )
    SELECT
        r.MekanId,
        MekanAd = COALESCE(mk.MekanAd, CONCAT('Mekan-', r.MekanId)),
        r.StokId,
        UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', r.StokId)),
        UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)),
        r.DonemKodu,
        r.RiskSkor,
        FlagGirissizSatis = r.FlagGirissizSatis,
        FlagStokYok = CONVERT(bit, CASE WHEN r.FlagStokKaydiYok=1 OR r.FlagStokSifir=1 THEN 1 ELSE 0 END),
        FlagNetBirikim = r.FlagNetBirikim,
        FlagIadeYuksek = r.FlagIadeYuksek,
        FlagSayimDuzeltme = r.FlagSayimDuzeltmeYuk,
        FlagHizliDevir = r.FlagHizliDevir,
        StokMiktar = COALESCE(r.StokMiktar, 0),
        SonHareketGun = CASE
            WHEN r.SonSatisTarihi IS NULL THEN NULL
            ELSE DATEDIFF(day, CONVERT(date, r.SonSatisTarihi), @Kesim)
        END,
        -- GERCEK TOPLAM: pencere fonksiyonu sayfalamadan ONCE, tum suzulmus
        -- kume uzerinde hesaplanir. Ayni taramada geliyor, ikinci sorgu yok.
        TotalCount = COUNT(*) OVER()
    FROM rpt.vw_RiskUrunOzet_Stok r
    JOIN Mekan m ON m.MekanId = r.MekanId
    LEFT JOIN src.vw_Mekan mk ON mk.MekanId = r.MekanId
    LEFT JOIN src.vw_Urun u ON u.StokId = r.StokId
    WHERE r.KesimGunu = @Kesim
      AND r.DonemKodu = 'Son30Gun'
      AND (@MinSkor IS NULL OR r.RiskSkor >= @MinSkor)
      AND (@MaxSkor IS NULL OR r.RiskSkor <= @MaxSkor)
      AND (
          @SearchTerm IS NULL
          OR CAST(r.MekanId AS varchar(20)) = @SearchTerm
          OR CAST(r.StokId AS varchar(20)) = @SearchTerm
          OR COALESCE(mk.MekanAd, CONCAT('Mekan-', r.MekanId)) LIKE '%' + @SearchTerm + '%'
          OR COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)) LIKE '%' + @SearchTerm + '%'
          OR COALESCE(u.UrunKod, CONCAT('BK-', r.StokId)) LIKE '%' + @SearchTerm + '%'
      )
      AND (
          NOT EXISTS (SELECT 1 FROM @Tip)
          OR EXISTS (
              SELECT 1
              FROM @Tip t
              WHERE (t.TipKodu='GIRISSIZSATIS' AND r.FlagGirissizSatis=1)
                 OR (t.TipKodu='STOKYOK' AND (r.FlagStokKaydiYok=1 OR r.FlagStokSifir=1))
                 OR (t.TipKodu='NETBIRIKIM' AND r.FlagNetBirikim=1)
                 OR (t.TipKodu='IADEYUKSEK' AND r.FlagIadeYuksek=1)
                 OR (t.TipKodu='SAYIMDUZELTME' AND r.FlagSayimDuzeltmeYuk=1)
                 OR (t.TipKodu='HIZLIDEVIR' AND r.FlagHizliDevir=1)
          )
      )
    ORDER BY
        CASE WHEN @OrderByClean='SKOR' AND @OrderDirClean='ASC' THEN r.RiskSkor END ASC,
        CASE WHEN @OrderByClean='SKOR' AND @OrderDirClean='DESC' THEN r.RiskSkor END DESC,
        CASE WHEN @OrderByClean='MEKAN' AND @OrderDirClean='ASC' THEN COALESCE(mk.MekanAd, CONCAT('Mekan-', r.MekanId)) END ASC,
        CASE WHEN @OrderByClean='MEKAN' AND @OrderDirClean='DESC' THEN COALESCE(mk.MekanAd, CONCAT('Mekan-', r.MekanId)) END DESC,
        CASE WHEN @OrderByClean='URUN' AND @OrderDirClean='ASC' THEN COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)) END ASC,
        CASE WHEN @OrderByClean='URUN' AND @OrderDirClean='DESC' THEN COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)) END DESC,
        CASE WHEN @OrderByClean='STOK' AND @OrderDirClean='ASC' THEN COALESCE(r.StokMiktar, 0) END ASC,
        CASE WHEN @OrderByClean='STOK' AND @OrderDirClean='DESC' THEN COALESCE(r.StokMiktar, 0) END DESC,
        CASE WHEN @OrderByClean='SONHAREKET' AND @OrderDirClean='ASC' THEN COALESCE(DATEDIFF(day, CONVERT(date, r.SonSatisTarihi), @Kesim), 999999) END ASC,
        CASE WHEN @OrderByClean='SONHAREKET' AND @OrderDirClean='DESC' THEN COALESCE(DATEDIFF(day, CONVERT(date, r.SonSatisTarihi), @Kesim), -1) END DESC,
        r.RiskSkor DESC,
        r.MekanId,
        r.StokId
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
