/*
 * 30_sps_ref_rpt_english.sql
 * ─────────────────────────────────────────────────────────────────────────────
 * Drop old Turkish-named ref.* and rpt.* stored procedures and recreate them
 * with English table/column names. SP parameter names stay Turkish (convention).
 * src.* views are NEVER changed — aliases are used where needed.
 *
 * Generated: 2026-03-29
 * ─────────────────────────────────────────────────────────────────────────────
 */

-- ===========================================================================
-- DROP OLD SPs
-- ===========================================================================
IF OBJECT_ID('ref.sp_MekanKapsam_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_MekanKapsam_Kaydet;
IF OBJECT_ID('ref.sp_MekanKapsam_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_MekanKapsam_Liste;
IF OBJECT_ID('ref.sp_IrsTipMap_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_IrsTipMap_Kaydet;
IF OBJECT_ID('ref.sp_IrsTipMap_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_IrsTipMap_Liste;
IF OBJECT_ID('ref.sp_IrsTipGrupMap_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_IrsTipGrupMap_Liste;
IF OBJECT_ID('ref.sp_RiskParam_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParam_Kaydet;
IF OBJECT_ID('ref.sp_RiskParam_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParam_Liste;
IF OBJECT_ID('ref.sp_RiskSkorAgirlik_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskSkorAgirlik_Kaydet;
IF OBJECT_ID('ref.sp_RiskSkorAgirlik_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskSkorAgirlik_Liste;
IF OBJECT_ID('ref.sp_KaynakSistem_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakSistem_Kaydet;
IF OBJECT_ID('ref.sp_KaynakSistem_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakSistem_Liste;
IF OBJECT_ID('ref.sp_KaynakNesne_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakNesne_Kaydet;
IF OBJECT_ID('ref.sp_KaynakNesne_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_KaynakNesne_Liste;
IF OBJECT_ID('ref.sp_Personel_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Personel_Kaydet;
IF OBJECT_ID('ref.sp_Personel_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Personel_Liste;
IF OBJECT_ID('ref.sp_Kullanici_Kaydet', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Kullanici_Kaydet;
IF OBJECT_ID('ref.sp_Kullanici_Liste', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Kullanici_Liste;
IF OBJECT_ID('rpt.sp_RiskListe', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_RiskListe;
IF OBJECT_ID('rpt.sp_RiskMekan_Liste', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_RiskMekan_Liste;
IF OBJECT_ID('rpt.sp_StokBakiyeTarihGetir', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_StokBakiyeTarihGetir;
GO

-- Also drop new names if they already exist (idempotent)
IF OBJECT_ID('ref.sp_LocationSettings_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_LocationSettings_Save;
IF OBJECT_ID('ref.sp_LocationSettings_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_LocationSettings_List;
IF OBJECT_ID('ref.sp_TransactionTypeMap_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_TransactionTypeMap_Save;
IF OBJECT_ID('ref.sp_TransactionTypeMap_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_TransactionTypeMap_List;
IF OBJECT_ID('ref.sp_TransactionTypeMap_GroupList', 'P') IS NOT NULL DROP PROCEDURE ref.sp_TransactionTypeMap_GroupList;
IF OBJECT_ID('ref.sp_RiskParameters_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParameters_Save;
IF OBJECT_ID('ref.sp_RiskParameters_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParameters_List;
IF OBJECT_ID('ref.sp_RiskScoreWeights_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskScoreWeights_Save;
IF OBJECT_ID('ref.sp_RiskScoreWeights_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskScoreWeights_List;
IF OBJECT_ID('ref.sp_SourceSystems_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceSystems_Save;
IF OBJECT_ID('ref.sp_SourceSystems_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceSystems_List;
IF OBJECT_ID('ref.sp_SourceObjects_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceObjects_Save;
IF OBJECT_ID('ref.sp_SourceObjects_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceObjects_List;
IF OBJECT_ID('ref.sp_Personnel_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Personnel_Save;
IF OBJECT_ID('ref.sp_Personnel_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Personnel_List;
IF OBJECT_ID('ref.sp_Users_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Users_Save;
IF OBJECT_ID('ref.sp_Users_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Users_List;
IF OBJECT_ID('rpt.sp_RiskList', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_RiskList;
IF OBJECT_ID('rpt.sp_RiskByLocation_List', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_RiskByLocation_List;
IF OBJECT_ID('rpt.sp_StockBalance_GetByDate', 'P') IS NOT NULL DROP PROCEDURE rpt.sp_StockBalance_GetByDate;
GO


-- ===========================================================================
-- ref.sp_LocationSettings_Save  (was: ref.sp_MekanKapsam_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_LocationSettings_Save
    @MekanId int,
    @AktifMi bit = 1,
    @Aciklama nvarchar(100) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @MekanId IS NULL OR @MekanId <= 0
        THROW 50000, 'MekanId zorunludur', 1;

    MERGE ref.LocationSettings AS t
    USING (SELECT @MekanId AS LocationId) AS s
    ON t.LocationId = s.LocationId
    WHEN MATCHED THEN
        UPDATE SET
            t.IsActive = @AktifMi,
            t.Description = @Aciklama,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (LocationId, IsActive, Description, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@MekanId, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_LocationSettings_List  (was: ref.sp_MekanKapsam_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_LocationSettings_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        LocationId,
        IsActive,
        Description
    FROM ref.LocationSettings
    ORDER BY LocationId;
END
GO


-- ===========================================================================
-- ref.sp_TransactionTypeMap_Save  (was: ref.sp_IrsTipMap_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_TransactionTypeMap_Save
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

    MERGE ref.TransactionTypeMap AS t
    USING (SELECT @TipId AS TypeId) AS s
    ON t.TypeId = s.TypeId
    WHEN MATCHED THEN
        UPDATE SET
            t.GroupCode = @GrupKodu,
            t.GroupName = @GrupAdi,
            t.OperationName = @IslemAdi,
            t.IsActive = @AktifMi,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (TypeId, GroupCode, GroupName, OperationName, IsActive, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@TipId, @GrupKodu, @GrupAdi, @IslemAdi, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_TransactionTypeMap_List  (was: ref.sp_IrsTipMap_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_TransactionTypeMap_List
    @SadeceEksik bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        TypeId      = t.TipId,
        TipAdi      = t.TipAdi,
        GroupCode   = m.GroupCode,
        GroupName   = m.GroupName,
        OperationName = m.OperationName,
        IsActive    = COALESCE(m.IsActive, 0),
        EslesmisMi  = CASE WHEN m.TypeId IS NULL THEN 0 ELSE 1 END
    FROM src.vw_IrsTip t
    LEFT JOIN ref.TransactionTypeMap m ON m.TypeId = t.TipId AND m.IsActive = 1
    WHERE (@SadeceEksik = 0 OR m.TypeId IS NULL)
    ORDER BY t.TipId;
END
GO


-- ===========================================================================
-- ref.sp_TransactionTypeMap_GroupList  (was: ref.sp_IrsTipGrupMap_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_TransactionTypeMap_GroupList
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        TypeId,
        GroupCode,
        GroupName,
        OperationName,
        IsActive
    FROM ref.TransactionTypeMap
    ORDER BY TypeId;
END
GO


-- ===========================================================================
-- ref.sp_RiskParameters_Save  (was: ref.sp_RiskParam_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_RiskParameters_Save
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

    MERGE ref.RiskParameters AS t
    USING (SELECT @ParamKodu AS ParamCode) AS s
    ON t.ParamCode = s.ParamCode
    WHEN MATCHED THEN
        UPDATE SET
            t.IntValue = @DegerInt,
            t.DecValue = @DegerDec,
            t.StrValue = @DegerStr,
            t.IsActive = @AktifMi,
            t.Description = @Aciklama,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ParamCode, IntValue, DecValue, StrValue, IsActive, Description, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@ParamKodu, @DegerInt, @DegerDec, @DegerStr, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_RiskParameters_List  (was: ref.sp_RiskParam_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_RiskParameters_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ParamCode,
        IntValue,
        DecValue,
        StrValue,
        IsActive,
        Description
    FROM ref.RiskParameters
    ORDER BY ParamCode;
END
GO


-- ===========================================================================
-- ref.sp_RiskScoreWeights_Save  (was: ref.sp_RiskSkorAgirlik_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_RiskScoreWeights_Save
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

    MERGE ref.RiskScoreWeights AS t
    USING (SELECT @FlagKodu AS FlagCode) AS s
    ON t.FlagCode = s.FlagCode
    WHEN MATCHED THEN
        UPDATE SET
            t.Points = @Puan,
            t.Priority = @Oncelik,
            t.IsActive = @AktifMi,
            t.Description = @Aciklama,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (FlagCode, Points, Priority, IsActive, Description, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@FlagKodu, @Puan, @Oncelik, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_RiskScoreWeights_List  (was: ref.sp_RiskSkorAgirlik_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_RiskScoreWeights_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FlagCode,
        Points,
        Priority,
        IsActive,
        Description
    FROM ref.RiskScoreWeights
    ORDER BY Priority, FlagCode;
END
GO


-- ===========================================================================
-- ref.sp_SourceSystems_Save  (was: ref.sp_KaynakSistem_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_SourceSystems_Save
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

    MERGE ref.SourceSystems AS t
    USING (SELECT @SistemKodu AS SystemCode) AS s
    ON t.SystemCode = s.SystemCode
    WHEN MATCHED THEN
        UPDATE SET
            t.SystemName = @SistemAdi,
            t.IsActive = @AktifMi,
            t.Description = @Aciklama,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (SystemCode, SystemName, IsActive, Description, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@SistemKodu, @SistemAdi, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_SourceSystems_List  (was: ref.sp_KaynakSistem_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_SourceSystems_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SystemCode,
        SystemName,
        IsActive,
        Description
    FROM ref.SourceSystems
    ORDER BY SystemCode;
END
GO


-- ===========================================================================
-- ref.sp_SourceObjects_Save  (was: ref.sp_KaynakNesne_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_SourceObjects_Save
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

    MERGE ref.SourceObjects AS t
    USING (SELECT @NesneKodu AS ObjectCode) AS s
    ON t.ObjectCode = s.ObjectCode
    WHEN MATCHED THEN
        UPDATE SET
            t.ObjectName = @NesneAdi,
            t.IsActive = @AktifMi,
            t.Description = @Aciklama,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ObjectCode, ObjectName, IsActive, Description, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@NesneKodu, @NesneAdi, @AktifMi, @Aciklama, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_SourceObjects_List  (was: ref.sp_KaynakNesne_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_SourceObjects_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ObjectCode,
        ObjectName,
        IsActive,
        Description
    FROM ref.SourceObjects
    ORDER BY ObjectCode;
END
GO


-- ===========================================================================
-- ref.sp_Personnel_Save  (was: ref.sp_Personel_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_Personnel_Save
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
        INSERT INTO ref.Personnel
            (PersonnelCode, FirstName, LastName, JobTitle, Department, SupervisorId, Email, Phone, IsActive, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES
            (NULL, @Ad, @Soyad, @Unvan, @Birim, @UstPersonelId, @Eposta, @Telefon, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
        RETURN;
    END

    MERGE ref.Personnel AS t
    USING (SELECT @PersonelKodu AS PersonnelCode) AS s
    ON t.PersonnelCode = s.PersonnelCode
    WHEN MATCHED THEN
        UPDATE SET
            t.FirstName = @Ad,
            t.LastName = @Soyad,
            t.JobTitle = @Unvan,
            t.Department = @Birim,
            t.SupervisorId = @UstPersonelId,
            t.Email = @Eposta,
            t.Phone = @Telefon,
            t.IsActive = @AktifMi,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (PersonnelCode, FirstName, LastName, JobTitle, Department, SupervisorId, Email, Phone, IsActive, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@PersonelKodu, @Ad, @Soyad, @Unvan, @Birim, @UstPersonelId, @Eposta, @Telefon, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_Personnel_List  (was: ref.sp_Personel_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_Personnel_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PersonnelId,
        PersonnelCode,
        FirstName,
        LastName,
        JobTitle,
        Department,
        SupervisorId,
        Email,
        Phone,
        IsActive
    FROM ref.Personnel
    ORDER BY PersonnelId;
END
GO


-- ===========================================================================
-- ref.sp_Users_Save  (was: ref.sp_Kullanici_Kaydet)
-- ===========================================================================
CREATE PROCEDURE ref.sp_Users_Save
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

    MERGE ref.Users AS t
    USING (SELECT @KullaniciAdi AS Username) AS s
    ON t.Username = s.Username
    WHEN MATCHED THEN
        UPDATE SET
            t.PersonnelId = @PersonelId,
            t.RoleCode = @RolKodu,
            t.IsActive = @AktifMi,
            t.UpdatedByUserId = @KullaniciId,
            t.UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (Username, PersonnelId, RoleCode, IsActive, CreatedByUserId, UpdatedByUserId, CreatedAt, UpdatedAt)
        VALUES (@KullaniciAdi, @PersonelId, @RolKodu, @AktifMi, @KullaniciId, @KullaniciId, SYSDATETIME(), SYSDATETIME());
END
GO


-- ===========================================================================
-- ref.sp_Users_List  (was: ref.sp_Kullanici_Liste)
-- ===========================================================================
CREATE PROCEDURE ref.sp_Users_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        Username,
        PersonnelId,
        RoleCode,
        IsActive
    FROM ref.Users
    ORDER BY Username;
END
GO


-- ===========================================================================
-- rpt.sp_RiskList  (was: rpt.sp_RiskListe)
-- Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
-- View:  rpt.vw_RiskUrunOzet_Stok stays as-is (src view convention)
-- ===========================================================================
CREATE PROCEDURE rpt.sp_RiskList
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
        SELECT @Kesim = MAX(CONVERT(date, SnapshotDate))
        FROM rpt.DailyProductRisk
        WHERE CONVERT(date, SnapshotDate) BETWEEN @Bas AND @Bit;
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


-- ===========================================================================
-- rpt.sp_RiskByLocation_List  (was: rpt.sp_RiskMekan_Liste)
-- src.vw_Mekan stays as-is (src view)
-- ===========================================================================
CREATE PROCEDURE rpt.sp_RiskByLocation_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT MekanId, MekanAd
    FROM src.vw_Mekan
    ORDER BY MekanAd, MekanId;
END
GO


-- ===========================================================================
-- rpt.sp_StockBalance_GetByDate  (was: rpt.sp_StokBakiyeTarihGetir)
-- Table: rpt.DailyStockBalance (was: rpt.StokBakiyeGunluk)
-- ===========================================================================
CREATE PROCEDURE rpt.sp_StockBalance_GetByDate
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
        SELECT DISTINCT s.LocationId, s.ProductId
        FROM rpt.DailyStockBalance s
        JOIN Mekan m ON m.MekanId = s.LocationId
        WHERE (@StokId IS NULL OR s.ProductId = @StokId)
    )
    SELECT
        h.LocationId  AS MekanId,
        h.ProductId   AS StokId,
        BakiyeninTarihi = x.[Date],
        StokMiktar      = x.StockQty
    FROM Hedef h
    OUTER APPLY (
        SELECT TOP (1) s.[Date], s.StockQty
        FROM rpt.DailyStockBalance s
        WHERE s.LocationId=h.LocationId AND s.ProductId=h.ProductId AND s.[Date] <= @Tarih
        ORDER BY s.[Date] DESC
    ) x
    ORDER BY h.LocationId, h.ProductId;
END
GO


PRINT '--- 30_sps_ref_rpt_english.sql complete: 21 SPs migrated ---';
GO
