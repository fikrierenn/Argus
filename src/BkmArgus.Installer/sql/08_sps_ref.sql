/* 08_sps_ref.sql
   Ref SP'ler: Irs tip map liste/kaydet
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'ref.sp_IrsTipMap_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_IrsTipMap_Liste;
GO
CREATE PROCEDURE ref.sp_IrsTipMap_Liste
    @SadeceEksik bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        TipId = t.TipId,
        TipAdi = t.TipAdi,
        GrupKodu = m.GrupKodu,
        GrupAdi = m.GrupAdi,
        IslemAdi = m.IslemAdi,
        AktifMi = COALESCE(m.AktifMi, 0),
        EslesmisMi = CASE WHEN m.TipId IS NULL THEN 0 ELSE 1 END
    FROM src.vw_IrsTip t
    LEFT JOIN ref.IrsTipGrupMap m ON m.TipId = t.TipId AND m.AktifMi = 1
    WHERE (@SadeceEksik = 0 OR m.TipId IS NULL)
    ORDER BY t.TipId;
END
GO

IF OBJECT_ID(N'ref.sp_IrsTipMap_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_IrsTipMap_Kaydet;
GO
CREATE PROCEDURE ref.sp_IrsTipMap_Kaydet
    @TipId tinyint,
    @GrupKodu varchar(30),
    @GrupAdi nvarchar(60),
    @IslemAdi nvarchar(60) = NULL,
    @AktifMi bit = 1,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TipId IS NULL
        THROW 50000, 'TipId zorunludur', 1;

    IF LTRIM(RTRIM(COALESCE(@GrupKodu, ''))) = ''
        THROW 50000, 'GrupKodu zorunludur', 1;

    IF LTRIM(RTRIM(COALESCE(@GrupAdi, ''))) = ''
        THROW 50000, 'GrupAdi zorunludur', 1;

    MERGE ref.IrsTipGrupMap AS t
    USING (SELECT @TipId AS TipId) AS s
    ON t.TipId = s.TipId
    WHEN MATCHED THEN
        UPDATE SET
            t.GrupKodu = @GrupKodu,
            t.GrupAdi = @GrupAdi,
            t.IslemAdi = @IslemAdi,
            t.AktifMi = @AktifMi,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (TipId, GrupKodu, GrupAdi, IslemAdi, AktifMi, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@TipId, @GrupKodu, @GrupAdi, @IslemAdi, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_IrsTipGrupMap_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_IrsTipGrupMap_Liste;
GO
CREATE PROCEDURE ref.sp_IrsTipGrupMap_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        TipId,
        GrupKodu,
        GrupAdi,
        IslemAdi,
        AktifMi
    FROM ref.IrsTipGrupMap
    ORDER BY TipId;
END
GO

IF OBJECT_ID(N'ref.sp_MekanKapsam_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_MekanKapsam_Liste;
GO
CREATE PROCEDURE ref.sp_MekanKapsam_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        MekanId,
        AktifMi,
        Aciklama
    FROM ref.AyarMekanKapsam
    ORDER BY MekanId;
END
GO

IF OBJECT_ID(N'ref.sp_MekanKapsam_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_MekanKapsam_Kaydet;
GO
CREATE PROCEDURE ref.sp_MekanKapsam_Kaydet
    @MekanId int,
    @AktifMi bit = 1,
    @Aciklama nvarchar(100) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @MekanId IS NULL OR @MekanId <= 0
        THROW 50000, 'MekanId zorunludur', 1;

    MERGE ref.AyarMekanKapsam AS t
    USING (SELECT @MekanId AS MekanId) AS s
    ON t.MekanId = s.MekanId
    WHEN MATCHED THEN
        UPDATE SET
            t.AktifMi = @AktifMi,
            t.Aciklama = @Aciklama,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (MekanId, AktifMi, Aciklama, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@MekanId, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_RiskParam_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParam_Liste;
GO
CREATE PROCEDURE ref.sp_RiskParam_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ParamKodu,
        DegerInt,
        DegerDec,
        DegerStr,
        AktifMi,
        Aciklama
    FROM ref.RiskParam
    ORDER BY ParamKodu;
END
GO

IF OBJECT_ID(N'ref.sp_RiskParam_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParam_Kaydet;
GO
CREATE PROCEDURE ref.sp_RiskParam_Kaydet
    @ParamKodu varchar(50),
    @DegerInt int = NULL,
    @DegerDec decimal(18,6) = NULL,
    @DegerStr nvarchar(200) = NULL,
    @AktifMi bit = 1,
    @Aciklama nvarchar(200) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(COALESCE(@ParamKodu, ''))) = ''
        THROW 50000, 'ParamKodu zorunludur', 1;

    MERGE ref.RiskParam AS t
    USING (SELECT @ParamKodu AS ParamKodu) AS s
    ON t.ParamKodu = s.ParamKodu
    WHEN MATCHED THEN
        UPDATE SET
            t.DegerInt = @DegerInt,
            t.DegerDec = @DegerDec,
            t.DegerStr = @DegerStr,
            t.AktifMi = @AktifMi,
            t.Aciklama = @Aciklama,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ParamKodu, DegerInt, DegerDec, DegerStr, AktifMi, Aciklama, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@ParamKodu, @DegerInt, @DegerDec, @DegerStr, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_RiskSkorAgirlik_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskSkorAgirlik_Liste;
GO
CREATE PROCEDURE ref.sp_RiskSkorAgirlik_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FlagKodu,
        Puan,
        Oncelik,
        AktifMi,
        Aciklama
    FROM ref.RiskSkorAgirlik
    ORDER BY Oncelik, FlagKodu;
END
GO

IF OBJECT_ID(N'ref.sp_RiskSkorAgirlik_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskSkorAgirlik_Kaydet;
GO
CREATE PROCEDURE ref.sp_RiskSkorAgirlik_Kaydet
    @FlagKodu varchar(50),
    @Puan int,
    @Oncelik int,
    @AktifMi bit = 1,
    @Aciklama nvarchar(200) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(COALESCE(@FlagKodu, ''))) = ''
        THROW 50000, 'FlagKodu zorunludur', 1;

    IF @Puan <= 0 OR @Oncelik <= 0
        THROW 50000, 'Puan ve Oncelik pozitif olmali', 1;

    MERGE ref.RiskSkorAgirlik AS t
    USING (SELECT @FlagKodu AS FlagKodu) AS s
    ON t.FlagKodu = s.FlagKodu
    WHEN MATCHED THEN
        UPDATE SET
            t.Puan = @Puan,
            t.Oncelik = @Oncelik,
            t.AktifMi = @AktifMi,
            t.Aciklama = @Aciklama,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (FlagKodu, Puan, Oncelik, AktifMi, Aciklama, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@FlagKodu, @Puan, @Oncelik, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_KaynakSistem_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakSistem_Liste;
GO
CREATE PROCEDURE ref.sp_KaynakSistem_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SistemKodu,
        SistemAdi,
        AktifMi,
        Aciklama
    FROM ref.KaynakSistem
    ORDER BY SistemKodu;
END
GO

IF OBJECT_ID(N'ref.sp_KaynakSistem_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakSistem_Kaydet;
GO
CREATE PROCEDURE ref.sp_KaynakSistem_Kaydet
    @SistemKodu varchar(30),
    @SistemAdi nvarchar(80),
    @AktifMi bit = 1,
    @Aciklama nvarchar(200) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(COALESCE(@SistemKodu, ''))) = ''
        THROW 50000, 'SistemKodu zorunludur', 1;

    IF LTRIM(RTRIM(COALESCE(@SistemAdi, ''))) = ''
        THROW 50000, 'SistemAdi zorunludur', 1;

    MERGE ref.KaynakSistem AS t
    USING (SELECT @SistemKodu AS SistemKodu) AS s
    ON t.SistemKodu = s.SistemKodu
    WHEN MATCHED THEN
        UPDATE SET
            t.SistemAdi = @SistemAdi,
            t.AktifMi = @AktifMi,
            t.Aciklama = @Aciklama,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (SistemKodu, SistemAdi, AktifMi, Aciklama, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@SistemKodu, @SistemAdi, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_KaynakNesne_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakNesne_Liste;
GO
CREATE PROCEDURE ref.sp_KaynakNesne_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        NesneKodu,
        NesneAdi,
        AktifMi,
        Aciklama
    FROM ref.KaynakNesne
    ORDER BY NesneKodu;
END
GO

IF OBJECT_ID(N'ref.sp_KaynakNesne_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakNesne_Kaydet;
GO
CREATE PROCEDURE ref.sp_KaynakNesne_Kaydet
    @NesneKodu varchar(50),
    @NesneAdi nvarchar(80),
    @AktifMi bit = 1,
    @Aciklama nvarchar(200) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(COALESCE(@NesneKodu, ''))) = ''
        THROW 50000, 'NesneKodu zorunludur', 1;

    IF LTRIM(RTRIM(COALESCE(@NesneAdi, ''))) = ''
        THROW 50000, 'NesneAdi zorunludur', 1;

    MERGE ref.KaynakNesne AS t
    USING (SELECT @NesneKodu AS NesneKodu) AS s
    ON t.NesneKodu = s.NesneKodu
    WHEN MATCHED THEN
        UPDATE SET
            t.NesneAdi = @NesneAdi,
            t.AktifMi = @AktifMi,
            t.Aciklama = @Aciklama,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (NesneKodu, NesneAdi, AktifMi, Aciklama, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@NesneKodu, @NesneAdi, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_Personel_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_Personel_Liste;
GO
CREATE PROCEDURE ref.sp_Personel_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PersonelId,
        PersonelKodu,
        Ad,
        Soyad,
        Unvan,
        Birim,
        UstPersonelId,
        Eposta,
        Telefon,
        AktifMi
    FROM ref.Personel
    ORDER BY PersonelId;
END
GO

IF OBJECT_ID(N'ref.sp_Personel_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_Personel_Kaydet;
GO
CREATE PROCEDURE ref.sp_Personel_Kaydet
    @PersonelKodu varchar(30) = NULL,
    @Ad nvarchar(60),
    @Soyad nvarchar(60),
    @Unvan nvarchar(80) = NULL,
    @Birim nvarchar(80) = NULL,
    @UstPersonelId int = NULL,
    @Eposta nvarchar(120) = NULL,
    @Telefon nvarchar(30) = NULL,
    @AktifMi bit = 1,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(COALESCE(@Ad, ''))) = ''
        THROW 50000, 'Ad zorunludur', 1;

    IF LTRIM(RTRIM(COALESCE(@Soyad, ''))) = ''
        THROW 50000, 'Soyad zorunludur', 1;

    IF @PersonelKodu IS NULL
    BEGIN
        INSERT INTO ref.Personel
            (PersonelKodu, Ad, Soyad, Unvan, Birim, UstPersonelId, Eposta, Telefon, AktifMi, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES
            (NULL, @Ad, @Soyad, @Unvan, @Birim, @UstPersonelId, @Eposta, @Telefon, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
        RETURN;
    END

    MERGE ref.Personel AS t
    USING (SELECT @PersonelKodu AS PersonelKodu) AS s
    ON t.PersonelKodu = s.PersonelKodu
    WHEN MATCHED THEN
        UPDATE SET
            t.Ad = @Ad,
            t.Soyad = @Soyad,
            t.Unvan = @Unvan,
            t.Birim = @Birim,
            t.UstPersonelId = @UstPersonelId,
            t.Eposta = @Eposta,
            t.Telefon = @Telefon,
            t.AktifMi = @AktifMi,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (PersonelKodu, Ad, Soyad, Unvan, Birim, UstPersonelId, Eposta, Telefon, AktifMi, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@PersonelKodu, @Ad, @Soyad, @Unvan, @Birim, @UstPersonelId, @Eposta, @Telefon, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO

IF OBJECT_ID(N'ref.sp_Kullanici_Liste', N'P') IS NOT NULL DROP PROCEDURE ref.sp_Kullanici_Liste;
GO
CREATE PROCEDURE ref.sp_Kullanici_Liste
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        KullaniciId,
        KullaniciAdi,
        PersonelId,
        RolKodu,
        AktifMi
    FROM ref.Kullanici
    ORDER BY KullaniciAdi;
END
GO

IF OBJECT_ID(N'ref.sp_Kullanici_Kaydet', N'P') IS NOT NULL DROP PROCEDURE ref.sp_Kullanici_Kaydet;
GO
CREATE PROCEDURE ref.sp_Kullanici_Kaydet
    @KullaniciAdi varchar(60),
    @PersonelId int = NULL,
    @RolKodu varchar(30) = NULL,
    @AktifMi bit = 1,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(COALESCE(@KullaniciAdi, ''))) = ''
        THROW 50000, 'KullaniciAdi zorunludur', 1;

    MERGE ref.Kullanici AS t
    USING (SELECT @KullaniciAdi AS KullaniciAdi) AS s
    ON t.KullaniciAdi = s.KullaniciAdi
    WHEN MATCHED THEN
        UPDATE SET
            t.PersonelId = @PersonelId,
            t.RolKodu = @RolKodu,
            t.AktifMi = @AktifMi,
            t.GuncelleyenKullaniciId = @KullaniciId,
            t.GuncellemeTarihi = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (KullaniciAdi, PersonelId, RolKodu, AktifMi, OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (@KullaniciAdi, @PersonelId, @RolKodu, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO
