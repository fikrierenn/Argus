/* 12_sps_risk.sql
   Risk gezgini liste ve filtreler
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'rpt.sp_RiskMekan_Liste', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_RiskMekan_Liste;
GO
CREATE PROCEDURE rpt.sp_RiskMekan_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT MekanId, MekanAd
    FROM src.vw_Mekan
    ORDER BY MekanAd, MekanId;
END
GO

IF OBJECT_ID(N'rpt.sp_RiskListe', N'P') IS NOT NULL DROP PROCEDURE rpt.sp_RiskListe;
GO
CREATE PROCEDURE rpt.sp_RiskListe
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
    @PageSize int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Bas date = COALESCE(@KesimBas, '19000101');
    DECLARE @Bit date = COALESCE(@KesimBit, '99991231');
    DECLARE @Kesim date = @KesimGunu;
    IF @Kesim IS NULL
    BEGIN
        SELECT @Kesim = MAX(KesimGunu)
        FROM rpt.RiskUrunOzet_Gunluk
        WHERE KesimGunu BETWEEN @Bas AND @Bit;
    END
    IF @Kesim IS NULL
        RETURN;

    IF @Page IS NULL OR @Page < 1
        SET @Page = 1;

    SET @PageSize = COALESCE(@PageSize, @Top, 50);
    IF @PageSize < 10
        SET @PageSize = 10;
    IF @PageSize > 200
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
        END
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
