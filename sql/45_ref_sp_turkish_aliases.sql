-- ============================================================================
-- Fix: Ref SP outputs aliased to Turkish property names for C# compatibility
-- C# models use Turkish names (MekanId, AktifMi, etc.)
-- DB columns are English (LocationId, IsActive, etc.)
-- Solution: SP output aliases match C# property names
-- ============================================================================

-- 1. LocationSettings_List
IF OBJECT_ID('ref.sp_LocationSettings_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_LocationSettings_List;
GO
CREATE PROCEDURE ref.sp_LocationSettings_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT LocationId AS MekanId, IsActive AS AktifMi, Description AS Aciklama
    FROM ref.LocationSettings
    ORDER BY LocationId;
END
GO

-- 2. TransactionTypeMap_GroupList
IF OBJECT_ID('ref.sp_TransactionTypeMap_GroupList', 'P') IS NOT NULL DROP PROCEDURE ref.sp_TransactionTypeMap_GroupList;
GO
CREATE PROCEDURE ref.sp_TransactionTypeMap_GroupList
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TypeId AS TipId, GroupCode AS GrupKodu, GroupName AS GrupAdi, OperationName AS IslemAdi, IsActive AS AktifMi
    FROM ref.TransactionTypeMap
    ORDER BY GroupCode, TypeId;
END
GO

-- 3. TransactionTypeMap_List (IrsTip — for sidebar)
IF OBJECT_ID('ref.sp_TransactionTypeMap_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_TransactionTypeMap_List;
GO
CREATE PROCEDURE ref.sp_TransactionTypeMap_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT t.TipId AS TipId, t.TipAdi AS TipAdi
    FROM src.vw_IrsTip t
    ORDER BY t.TipId;
END
GO

-- 4. RiskParameters_List
IF OBJECT_ID('ref.sp_RiskParameters_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParameters_List;
GO
CREATE PROCEDURE ref.sp_RiskParameters_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ParamCode AS ParamKodu, IntValue AS DegerInt, DecValue AS DegerDec, StrValue AS DegerStr, IsActive AS AktifMi, Description AS Aciklama
    FROM ref.RiskParameters
    ORDER BY ParamCode;
END
GO

-- 5. RiskScoreWeights_List
IF OBJECT_ID('ref.sp_RiskScoreWeights_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskScoreWeights_List;
GO
CREATE PROCEDURE ref.sp_RiskScoreWeights_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT FlagCode AS FlagKodu, Points AS Puan, Priority AS Oncelik, IsActive AS AktifMi, Description AS Aciklama
    FROM ref.RiskScoreWeights
    ORDER BY Priority, FlagCode;
END
GO

-- 6. SourceSystems_List
IF OBJECT_ID('ref.sp_SourceSystems_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceSystems_List;
GO
CREATE PROCEDURE ref.sp_SourceSystems_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SystemCode AS SistemKodu, SystemName AS SistemAdi, IsActive AS AktifMi, Description AS Aciklama
    FROM ref.SourceSystems
    ORDER BY SystemCode;
END
GO

-- 7. SourceObjects_List
IF OBJECT_ID('ref.sp_SourceObjects_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceObjects_List;
GO
CREATE PROCEDURE ref.sp_SourceObjects_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ObjectCode AS NesneKodu, ObjectName AS NesneAdi, IsActive AS AktifMi, Description AS Aciklama
    FROM ref.SourceObjects
    ORDER BY ObjectCode;
END
GO

-- 8. Personnel_List
IF OBJECT_ID('ref.sp_Personnel_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Personnel_List;
GO
CREATE PROCEDURE ref.sp_Personnel_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PersonnelId AS PersonelId, PersonnelCode AS PersonelKodu, FirstName AS Ad, LastName AS Soyad,
           JobTitle AS Unvan, Department AS Birim, SupervisorId AS UstPersonelId,
           Email AS Eposta, Phone AS Telefon, IsActive AS AktifMi
    FROM ref.Personnel
    ORDER BY FirstName, LastName;
END
GO

-- 9. Users_List
IF OBJECT_ID('ref.sp_Users_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Users_List;
GO
CREATE PROCEDURE ref.sp_Users_List
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId AS KullaniciId, Username AS KullaniciAdi, PersonnelId AS PersonelId, RoleCode AS RolKodu, IsActive AS AktifMi
    FROM ref.Users
    ORDER BY Username;
END
GO

-- 10. Fix Save SPs — params are Turkish, columns are English
-- LocationSettings_Save
IF OBJECT_ID('ref.sp_LocationSettings_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_LocationSettings_Save;
GO
CREATE PROCEDURE ref.sp_LocationSettings_Save
    @MekanId int, @AktifMi bit, @Aciklama nvarchar(500) = NULL, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.LocationSettings AS t
        USING (SELECT @MekanId AS LocationId) AS s ON t.LocationId = s.LocationId
        WHEN MATCHED THEN UPDATE SET IsActive = @AktifMi, Description = @Aciklama, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (LocationId, IsActive, Description, CreatedByUserId, CreatedAt) VALUES (@MekanId, @AktifMi, @Aciklama, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- TransactionTypeMap_Save
IF OBJECT_ID('ref.sp_TransactionTypeMap_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_TransactionTypeMap_Save;
GO
CREATE PROCEDURE ref.sp_TransactionTypeMap_Save
    @TipId int, @GrupKodu varchar(30), @GrupAdi nvarchar(100) = NULL, @IslemAdi nvarchar(100) = NULL, @AktifMi bit = 1, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.TransactionTypeMap AS t
        USING (SELECT @TipId AS TypeId, @GrupKodu AS GroupCode) AS s ON t.TypeId = s.TypeId AND t.GroupCode = s.GroupCode
        WHEN MATCHED THEN UPDATE SET GroupName = @GrupAdi, OperationName = @IslemAdi, IsActive = @AktifMi, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (TypeId, GroupCode, GroupName, OperationName, IsActive, CreatedByUserId, CreatedAt) VALUES (@TipId, @GrupKodu, @GrupAdi, @IslemAdi, @AktifMi, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- RiskParameters_Save
IF OBJECT_ID('ref.sp_RiskParameters_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskParameters_Save;
GO
CREATE PROCEDURE ref.sp_RiskParameters_Save
    @ParamKodu varchar(50), @DegerInt int = NULL, @DegerDec decimal(18,4) = NULL, @DegerStr nvarchar(200) = NULL, @AktifMi bit = 1, @Aciklama nvarchar(500) = NULL, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.RiskParameters AS t
        USING (SELECT @ParamKodu AS ParamCode) AS s ON t.ParamCode = s.ParamCode
        WHEN MATCHED THEN UPDATE SET IntValue = @DegerInt, DecValue = @DegerDec, StrValue = @DegerStr, IsActive = @AktifMi, Description = @Aciklama, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (ParamCode, IntValue, DecValue, StrValue, IsActive, Description, CreatedByUserId, CreatedAt) VALUES (@ParamKodu, @DegerInt, @DegerDec, @DegerStr, @AktifMi, @Aciklama, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- RiskScoreWeights_Save
IF OBJECT_ID('ref.sp_RiskScoreWeights_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_RiskScoreWeights_Save;
GO
CREATE PROCEDURE ref.sp_RiskScoreWeights_Save
    @FlagKodu varchar(50), @Puan int, @Oncelik int, @AktifMi bit = 1, @Aciklama nvarchar(500) = NULL, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.RiskScoreWeights AS t
        USING (SELECT @FlagKodu AS FlagCode) AS s ON t.FlagCode = s.FlagCode
        WHEN MATCHED THEN UPDATE SET Points = @Puan, Priority = @Oncelik, IsActive = @AktifMi, Description = @Aciklama, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (FlagCode, Points, Priority, IsActive, Description, CreatedByUserId, CreatedAt) VALUES (@FlagKodu, @Puan, @Oncelik, @AktifMi, @Aciklama, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- SourceSystems_Save
IF OBJECT_ID('ref.sp_SourceSystems_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceSystems_Save;
GO
CREATE PROCEDURE ref.sp_SourceSystems_Save
    @SistemKodu varchar(30), @SistemAdi nvarchar(100), @AktifMi bit = 1, @Aciklama nvarchar(500) = NULL, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.SourceSystems AS t
        USING (SELECT @SistemKodu AS SystemCode) AS s ON t.SystemCode = s.SystemCode
        WHEN MATCHED THEN UPDATE SET SystemName = @SistemAdi, IsActive = @AktifMi, Description = @Aciklama, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (SystemCode, SystemName, IsActive, Description, CreatedByUserId, CreatedAt) VALUES (@SistemKodu, @SistemAdi, @AktifMi, @Aciklama, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- SourceObjects_Save
IF OBJECT_ID('ref.sp_SourceObjects_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SourceObjects_Save;
GO
CREATE PROCEDURE ref.sp_SourceObjects_Save
    @NesneKodu varchar(30), @NesneAdi nvarchar(100), @AktifMi bit = 1, @Aciklama nvarchar(500) = NULL, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.SourceObjects AS t
        USING (SELECT @NesneKodu AS ObjectCode) AS s ON t.ObjectCode = s.ObjectCode
        WHEN MATCHED THEN UPDATE SET ObjectName = @NesneAdi, IsActive = @AktifMi, Description = @Aciklama, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (ObjectCode, ObjectName, IsActive, Description, CreatedByUserId, CreatedAt) VALUES (@NesneKodu, @NesneAdi, @AktifMi, @Aciklama, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- Personnel_Save
IF OBJECT_ID('ref.sp_Personnel_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Personnel_Save;
GO
CREATE PROCEDURE ref.sp_Personnel_Save
    @PersonelKodu varchar(30), @Ad nvarchar(50), @Soyad nvarchar(50), @Unvan nvarchar(100) = NULL, @Birim nvarchar(100) = NULL, @UstPersonelId int = NULL, @Eposta nvarchar(200) = NULL, @Telefon varchar(20) = NULL, @AktifMi bit = 1, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.Personnel AS t
        USING (SELECT @PersonelKodu AS PersonnelCode) AS s ON t.PersonnelCode = s.PersonnelCode
        WHEN MATCHED THEN UPDATE SET FirstName = @Ad, LastName = @Soyad, JobTitle = @Unvan, Department = @Birim, SupervisorId = @UstPersonelId, Email = @Eposta, Phone = @Telefon, IsActive = @AktifMi, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (PersonnelCode, FirstName, LastName, JobTitle, Department, SupervisorId, Email, Phone, IsActive, CreatedByUserId, CreatedAt) VALUES (@PersonelKodu, @Ad, @Soyad, @Unvan, @Birim, @UstPersonelId, @Eposta, @Telefon, @AktifMi, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- Users_Save
IF OBJECT_ID('ref.sp_Users_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_Users_Save;
GO
CREATE PROCEDURE ref.sp_Users_Save
    @KullaniciAdi nvarchar(50), @PersonelId int = NULL, @RolKodu varchar(20) = NULL, @AktifMi bit = 1, @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        MERGE ref.Users AS t
        USING (SELECT @KullaniciAdi AS Username) AS s ON t.Username = s.Username
        WHEN MATCHED THEN UPDATE SET PersonnelId = @PersonelId, RoleCode = @RolKodu, IsActive = @AktifMi, UpdatedByUserId = @KullaniciId, UpdatedAt = SYSDATETIME()
        WHEN NOT MATCHED THEN INSERT (Username, PersonnelId, RoleCode, IsActive, CreatedByUserId, CreatedAt) VALUES (@KullaniciAdi, @PersonelId, @RolKodu, @AktifMi, @KullaniciId, SYSDATETIME());
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

PRINT '=== Ref SP Turkish aliases complete ===';
GO
