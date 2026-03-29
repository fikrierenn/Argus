/* 21_sps_audit.sql
   Saha Denetim (Field Audit) CRUD + Analysis stored procedures
   Tables: audit.Audits, audit.AuditItems, audit.AuditResults, audit.AuditResultPhotos
   Convention: English table/column names, Turkish SP parameter names
*/
USE BKMDenetim;
GO

/* =====================================================================
   1. audit.sp_Audit_List - Denetim listesi
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Audit_List', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Audit_List;
GO
CREATE PROCEDURE audit.sp_Audit_List
    @LocationName   nvarchar(100) = NULL,
    @StartDate      datetime2(0)  = NULL,
    @EndDate        datetime2(0)  = NULL,
    @IsFinalized    bit           = NULL,
    @Top            int           = 50
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Top)
            a.Id,
            a.LocationName,
            a.LocationType,
            a.LocationId,
            a.AuditDate,
            a.ReportDate,
            a.ReportNo,
            a.AuditorUserId,
            a.Manager,
            a.Directorate,
            a.IsFinalized,
            a.FinalizedAt,
            TotalItems   = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id),
            PassedItems  = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 1),
            FailedItems  = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 0)
        FROM audit.Audits a
        WHERE (@LocationName IS NULL OR a.LocationName LIKE '%' + @LocationName + '%')
          AND (@StartDate    IS NULL OR a.AuditDate >= @StartDate)
          AND (@EndDate      IS NULL OR a.AuditDate <= @EndDate)
          AND (@IsFinalized  IS NULL OR a.IsFinalized = @IsFinalized)
        ORDER BY a.AuditDate DESC, a.Id DESC;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg1 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg1, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   2. audit.sp_Audit_Get - Tek denetim detay
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Audit_Get', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Audit_Get;
GO
CREATE PROCEDURE audit.sp_Audit_Get
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        SELECT
            a.Id,
            a.LocationName,
            a.LocationType,
            a.LocationId,
            a.AuditDate,
            a.ReportDate,
            a.ReportNo,
            a.AuditorUserId,
            a.Manager,
            a.Directorate,
            a.IsFinalized,
            a.FinalizedAt,
            a.CreatedByUserId,
            a.UpdatedByUserId,
            a.CreatedAt,
            a.UpdatedAt,
            TotalItems     = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id),
            PassedItems    = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 1),
            FailedItems    = (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 0),
            ComplianceRate = CASE
                WHEN (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id) = 0 THEN 0.0
                ELSE CAST((SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 1) AS decimal(5,2))
                     / CAST((SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id) AS decimal(5,2)) * 100.0
            END
        FROM audit.Audits a
        WHERE a.Id = @AuditId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg2 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg2, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   3. audit.sp_Audit_Insert - Yeni denetim ekle
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Audit_Insert', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Audit_Insert;
GO
CREATE PROCEDURE audit.sp_Audit_Insert
    @LocationName       nvarchar(100),
    @LocationType       varchar(20)   = 'Store',
    @LocationId         int           = NULL,
    @AuditDate          datetime2(0),
    @ReportDate         datetime2(0),
    @AuditorUserId      int           = NULL,
    @Manager            nvarchar(100) = NULL,
    @Directorate        nvarchar(100) = NULL,
    @CreatedByUserId    int           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Auto-generate ReportNo: RYD-00001
        DECLARE @NextId int;
        SELECT @NextId = ISNULL(MAX(Id), 0) + 1 FROM audit.Audits;

        DECLARE @ReportNo varchar(30);
        SET @ReportNo = 'RYD-' + RIGHT('00000' + CAST(@NextId AS varchar(10)), 5);

        INSERT INTO audit.Audits
        (
            LocationName, LocationType, LocationId,
            AuditDate, ReportDate, ReportNo,
            AuditorUserId, Manager, Directorate,
            IsFinalized, CreatedByUserId, UpdatedByUserId,
            CreatedAt, UpdatedAt
        )
        VALUES
        (
            @LocationName, @LocationType, @LocationId,
            @AuditDate, @ReportDate, @ReportNo,
            @AuditorUserId, @Manager, @Directorate,
            0, @CreatedByUserId, @CreatedByUserId,
            SYSDATETIME(), SYSDATETIME()
        );

        SELECT SCOPE_IDENTITY() AS Id;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg3 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg3, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   4. audit.sp_Audit_Update - Denetim guncelle (sadece finalize edilmemis)
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Audit_Update', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Audit_Update;
GO
CREATE PROCEDURE audit.sp_Audit_Update
    @AuditId            int,
    @LocationName       nvarchar(100) = NULL,
    @LocationType       varchar(20)   = NULL,
    @LocationId         int           = NULL,
    @AuditDate          datetime2(0)  = NULL,
    @ReportDate         datetime2(0)  = NULL,
    @AuditorUserId      int           = NULL,
    @Manager            nvarchar(100) = NULL,
    @Directorate        nvarchar(100) = NULL,
    @UpdatedByUserId    int           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
        BEGIN
            RAISERROR('Finalize edilmis denetim guncellenemez. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        UPDATE audit.Audits
        SET LocationName    = COALESCE(@LocationName,    LocationName),
            LocationType    = COALESCE(@LocationType,    LocationType),
            LocationId      = COALESCE(@LocationId,      LocationId),
            AuditDate       = COALESCE(@AuditDate,       AuditDate),
            ReportDate      = COALESCE(@ReportDate,      ReportDate),
            AuditorUserId   = COALESCE(@AuditorUserId,   AuditorUserId),
            Manager         = COALESCE(@Manager,         Manager),
            Directorate     = COALESCE(@Directorate,     Directorate),
            UpdatedByUserId = COALESCE(@UpdatedByUserId, UpdatedByUserId),
            UpdatedAt       = SYSDATETIME()
        WHERE Id = @AuditId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg4 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg4, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   5. audit.sp_Audit_Finalize - Denetimi kilitle
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Audit_Finalize', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Audit_Finalize;
GO
CREATE PROCEDURE audit.sp_Audit_Finalize
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
        BEGIN
            RAISERROR('Denetim zaten finalize edilmis. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        UPDATE audit.Audits
        SET IsFinalized = 1,
            FinalizedAt = SYSDATETIME(),
            UpdatedAt   = SYSDATETIME()
        WHERE Id = @AuditId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg5 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg5, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   6. audit.sp_Audit_Delete - Denetim sil (sadece finalize edilmemis)
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Audit_Delete', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Audit_Delete;
GO
CREATE PROCEDURE audit.sp_Audit_Delete
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
        BEGIN
            RAISERROR('Finalize edilmis denetim silinemez. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        -- CASCADE siler AuditResults ve AuditResultPhotos
        DELETE FROM audit.Audits WHERE Id = @AuditId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg6 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg6, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   7. audit.sp_Item_List - Denetim maddeleri listesi
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Item_List', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Item_List;
GO
CREATE PROCEDURE audit.sp_Item_List
    @LocationType   varchar(20)   = NULL,
    @AuditGroup     nvarchar(100) = NULL,
    @IsActive       bit           = 1
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
        WHERE (@IsActive     IS NULL OR i.IsActive = @IsActive)
          AND (@LocationType IS NULL OR i.LocationType = @LocationType OR i.LocationType = 'Both')
          AND (@AuditGroup   IS NULL OR i.AuditGroup = @AuditGroup)
        ORDER BY i.AuditGroup, i.SortOrder, i.Id;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg7 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg7, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   8. audit.sp_Item_Get - Tek denetim maddesi
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Item_Get', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Item_Get;
GO
CREATE PROCEDURE audit.sp_Item_Get
    @ItemId     int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.AuditItems WHERE Id = @ItemId)
        BEGIN
            RAISERROR('Denetim maddesi bulunamadi. ItemId: %d', 16, 1, @ItemId);
            RETURN;
        END

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
            i.CreatedByUserId,
            i.UpdatedByUserId,
            i.CreatedAt,
            i.UpdatedAt
        FROM audit.AuditItems i
        WHERE i.Id = @ItemId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg8 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg8, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   9. audit.sp_Item_Insert - Yeni denetim maddesi ekle
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Item_Insert', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Item_Insert;
GO
CREATE PROCEDURE audit.sp_Item_Insert
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
    @IsActive           bit           = 1,
    @CreatedByUserId    int           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        INSERT INTO audit.AuditItems
        (
            LocationType, AuditGroup, Area, RiskType, ItemText,
            SortOrder, FindingType, Probability, Impact,
            SkillId, IsActive,
            CreatedByUserId, UpdatedByUserId,
            CreatedAt, UpdatedAt
        )
        VALUES
        (
            @LocationType, @AuditGroup, @Area, @RiskType, @ItemText,
            @SortOrder, @FindingType, @Probability, @Impact,
            @SkillId, @IsActive,
            @CreatedByUserId, @CreatedByUserId,
            SYSDATETIME(), SYSDATETIME()
        );

        SELECT SCOPE_IDENTITY() AS Id;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg9 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg9, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   10. audit.sp_Item_Update - Denetim maddesi guncelle
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Item_Update', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Item_Update;
GO
CREATE PROCEDURE audit.sp_Item_Update
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
    @IsActive           bit           = NULL,
    @UpdatedByUserId    int           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.AuditItems WHERE Id = @ItemId)
        BEGIN
            RAISERROR('Denetim maddesi bulunamadi. ItemId: %d', 16, 1, @ItemId);
            RETURN;
        END

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
            IsActive        = COALESCE(@IsActive,        IsActive),
            UpdatedByUserId = COALESCE(@UpdatedByUserId, UpdatedByUserId),
            UpdatedAt       = SYSDATETIME()
        WHERE Id = @ItemId;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg10 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg10, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   11. audit.sp_Result_ListByAudit - Denetim sonuclari listesi
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Result_ListByAudit', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Result_ListByAudit;
GO
CREATE PROCEDURE audit.sp_Result_ListByAudit
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            r.Id,
            r.AuditId,
            r.AuditItemId,
            r.AuditGroup,
            r.Area,
            r.RiskType,
            r.ItemText,
            r.SortOrder,
            r.FindingType,
            r.Probability,
            r.Impact,
            r.RiskScore,
            r.RiskLevel,
            r.IsPassed,
            r.Remark,
            r.FirstSeenAt,
            r.LastSeenAt,
            r.RepeatCount,
            r.IsSystemic,
            PhotoCount = (SELECT COUNT(*) FROM audit.AuditResultPhotos p WHERE p.AuditResultId = r.Id)
        FROM audit.AuditResults r
        WHERE r.AuditId = @AuditId
        ORDER BY r.AuditGroup, r.SortOrder, r.Id;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg11 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg11, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   12. audit.sp_Result_StartAudit - Snapshot: AuditItems -> AuditResults
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Result_StartAudit', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Result_StartAudit;
GO
CREATE PROCEDURE audit.sp_Result_StartAudit
    @AuditId        int,
    @LocationType   varchar(20) = 'Store'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
        BEGIN
            RAISERROR('Finalize edilmis denetime madde eklenemez. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        -- Zaten sonuc varsa tekrar ekleme
        IF EXISTS (SELECT 1 FROM audit.AuditResults WHERE AuditId = @AuditId)
        BEGIN
            RAISERROR('Bu denetim icin sonuclar zaten olusturulmus. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

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
        WHERE i.IsActive = 1
          AND (i.LocationType = @LocationType OR i.LocationType = 'Both')
        ORDER BY i.AuditGroup, i.SortOrder;

        -- Kac madde eklendi
        SELECT @@ROWCOUNT AS InsertedCount;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg12 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg12, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   13. audit.sp_Result_Update - Tek sonuc guncelle
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Result_Update', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Result_Update;
GO
CREATE PROCEDURE audit.sp_Result_Update
    @ResultId   int,
    @IsPassed   bit,
    @Remark     nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Finalize kontrolu
        IF EXISTS (
            SELECT 1
            FROM audit.AuditResults r
            INNER JOIN audit.Audits a ON a.Id = r.AuditId
            WHERE r.Id = @ResultId AND a.IsFinalized = 1
        )
        BEGIN
            RAISERROR('Finalize edilmis denetim sonucu guncellenemez. ResultId: %d', 16, 1, @ResultId);
            RETURN;
        END

        UPDATE audit.AuditResults
        SET IsPassed = @IsPassed,
            Remark   = @Remark
        WHERE Id = @ResultId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Sonuc bulunamadi. ResultId: %d', 16, 1, @ResultId);
            RETURN;
        END
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg13 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg13, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   14. audit.sp_Result_BulkUpdate - Toplu sonuc guncelle (OPENJSON)
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Result_BulkUpdate', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Result_BulkUpdate;
GO
CREATE PROCEDURE audit.sp_Result_BulkUpdate
    @AuditId    int,
    @JsonData   nvarchar(max)   -- [{Id, IsPassed, Remark}]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Finalize kontrolu
        IF EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId AND IsFinalized = 1)
        BEGIN
            RAISERROR('Finalize edilmis denetim toplu guncellenemez. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        UPDATE r
        SET r.IsPassed = j.IsPassed,
            r.Remark   = j.Remark
        FROM audit.AuditResults r
        INNER JOIN OPENJSON(@JsonData)
            WITH (
                Id       int            '$.Id',
                IsPassed bit            '$.IsPassed',
                Remark   nvarchar(500)  '$.Remark'
            ) j ON j.Id = r.Id
        WHERE r.AuditId = @AuditId;

        SELECT @@ROWCOUNT AS UpdatedCount;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg14 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg14, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   ANALYSIS PROCEDURES
   ===================================================================== */

/* =====================================================================
   15. audit.sp_Analysis_DetectRepeats - Tekrar eden bulgulari tespit et
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Analysis_DetectRepeats', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Analysis_DetectRepeats;
GO
CREATE PROCEDURE audit.sp_Analysis_DetectRepeats
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @LocationName nvarchar(100);
        DECLARE @AuditDate   datetime2(0);

        SELECT @LocationName = LocationName, @AuditDate = AuditDate
        FROM audit.Audits
        WHERE Id = @AuditId;

        IF @LocationName IS NULL
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        -- Basarisiz sonuclar icin onceki basarisizliklari bul
        ;WITH PreviousFailures AS
        (
            SELECT
                cr.AuditItemId,
                RepeatCount  = COUNT(*),
                FirstSeenAt  = MIN(pa.AuditDate),
                LastSeenAt   = MAX(pa.AuditDate)
            FROM audit.AuditResults cr
            INNER JOIN audit.AuditResults pr ON pr.AuditItemId = cr.AuditItemId AND pr.IsPassed = 0
            INNER JOIN audit.Audits pa ON pa.Id = pr.AuditId
                AND pa.LocationName = @LocationName
                AND pa.AuditDate < @AuditDate
                AND pa.IsFinalized = 1
            WHERE cr.AuditId = @AuditId
              AND cr.IsPassed = 0
            GROUP BY cr.AuditItemId
        )
        UPDATE r
        SET r.RepeatCount = pf.RepeatCount,
            r.FirstSeenAt = pf.FirstSeenAt,
            r.LastSeenAt  = pf.LastSeenAt
        FROM audit.AuditResults r
        INNER JOIN PreviousFailures pf ON pf.AuditItemId = r.AuditItemId
        WHERE r.AuditId = @AuditId
          AND r.IsPassed = 0;

        SELECT @@ROWCOUNT AS UpdatedCount;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg15 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg15, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   16. audit.sp_Analysis_DetectSystemic - Sistemik bulgulari tespit et
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Analysis_DetectSystemic', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Analysis_DetectSystemic;
GO
CREATE PROCEDURE audit.sp_Analysis_DetectSystemic
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @AuditDate datetime2(0);
        SELECT @AuditDate = AuditDate FROM audit.Audits WHERE Id = @AuditId;

        IF @AuditDate IS NULL
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        DECLARE @CutoffDate datetime2(0) = DATEADD(MONTH, -12, @AuditDate);

        -- Son 12 ayda 3+ farkli lokasyonda basarisiz olan maddeler
        ;WITH SystemicItems AS
        (
            SELECT
                r.AuditItemId,
                LocationCount = COUNT(DISTINCT a.LocationName)
            FROM audit.AuditResults r
            INNER JOIN audit.Audits a ON a.Id = r.AuditId
                AND a.IsFinalized = 1
                AND a.AuditDate >= @CutoffDate
            WHERE r.IsPassed = 0
              AND r.AuditItemId IN (
                  SELECT AuditItemId FROM audit.AuditResults WHERE AuditId = @AuditId AND IsPassed = 0
              )
            GROUP BY r.AuditItemId
            HAVING COUNT(DISTINCT a.LocationName) >= 3
        )
        -- Mevcut denetim dahil tum son basarisizliklari IsSystemic=1 yap
        UPDATE r
        SET r.IsSystemic = 1
        FROM audit.AuditResults r
        INNER JOIN audit.Audits a ON a.Id = r.AuditId
            AND a.AuditDate >= @CutoffDate
        INNER JOIN SystemicItems si ON si.AuditItemId = r.AuditItemId
        WHERE r.IsPassed = 0;

        SELECT @@ROWCOUNT AS UpdatedCount;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg16 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg16, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   17. audit.sp_Analysis_DofEffectiveness - DOF etkinlik analizi
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Analysis_DofEffectiveness', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Analysis_DofEffectiveness;
GO
CREATE PROCEDURE audit.sp_Analysis_DofEffectiveness
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- dof.DofKayit tablosu yoksa cik
        IF OBJECT_ID(N'dof.DofKayit', N'U') IS NULL
            RETURN;

        DECLARE @LocationName nvarchar(100);
        DECLARE @AuditDate   datetime2(0);

        SELECT @LocationName = LocationName, @AuditDate = AuditDate
        FROM audit.Audits
        WHERE Id = @AuditId;

        IF @LocationName IS NULL
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        -- Basarisiz sonuclar icin: ayni madde + ayni lokasyon icin
        -- daha once kapatilmis DOF'lari bul ve etkinligini dusur
        ;WITH FailedWithClosedDof AS
        (
            SELECT
                d.DofId,
                FailCount = COUNT(DISTINCT r.AuditId)
            FROM audit.AuditResults r
            INNER JOIN audit.Audits a ON a.Id = r.AuditId
            INNER JOIN dof.DofKayit d ON d.KaynakSistemKodu = 'SAHA_DENETIM'
                AND d.Durum = 'KAPANDI'
                -- KaynakAnahtar formatinda item+location eslestir
                AND d.KaynakAnahtar LIKE CONCAT('%ItemId:', CAST(r.AuditItemId AS varchar(20)), '%')
                AND d.KaynakAnahtar LIKE CONCAT('%Loc:', @LocationName, '%')
                AND d.GuncellemeTarihi < @AuditDate
            WHERE r.AuditId = @AuditId
              AND r.IsPassed = 0
            GROUP BY d.DofId
        )
        UPDATE d
        SET d.IsEffective       = 0,
            d.EffectivenessScore = CASE
                WHEN (1.0 - fcd.FailCount * 0.25) < 0 THEN 0
                ELSE (1.0 - fcd.FailCount * 0.25)
            END,
            d.EffectivenessNote  = CONCAT(
                N'Saha denetim tekrar tespiti - AuditId: ', @AuditId,
                N', Lokasyon: ', @LocationName,
                N', Tarih: ', CONVERT(varchar(10), @AuditDate, 120)
            ),
            d.GuncellemeTarihi   = SYSDATETIME()
        FROM dof.DofKayit d
        INNER JOIN FailedWithClosedDof fcd ON fcd.DofId = d.DofId;

        SELECT @@ROWCOUNT AS UpdatedCount;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg17 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg17, 16, 1);
    END CATCH
END
GO

/* =====================================================================
   18. audit.sp_Analysis_FullPipeline - Tam analiz pipeline
   ===================================================================== */

IF OBJECT_ID(N'audit.sp_Analysis_FullPipeline', N'P') IS NOT NULL DROP PROCEDURE audit.sp_Analysis_FullPipeline;
GO
CREATE PROCEDURE audit.sp_Analysis_FullPipeline
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        -- 1. Tekrar eden bulgulari tespit et
        EXEC audit.sp_Analysis_DetectRepeats @AuditId;

        -- 2. Sistemik bulgulari tespit et
        EXEC audit.sp_Analysis_DetectSystemic @AuditId;

        -- 3. DOF etkinlik analizi
        EXEC audit.sp_Analysis_DofEffectiveness @AuditId;

        -- 4. AI analiz istegi olustur (tablo mevcutsa)
        IF OBJECT_ID(N'ai.AiAnalizIstegi', N'U') IS NOT NULL
        BEGIN
            DECLARE @AuditDate datetime2(0);
            DECLARE @LocationName nvarchar(100);
            DECLARE @LocationId int;

            SELECT
                @AuditDate    = AuditDate,
                @LocationName = LocationName,
                @LocationId   = ISNULL(LocationId, 0)
            FROM audit.Audits
            WHERE Id = @AuditId;

            INSERT INTO ai.AiAnalizIstegi
            (
                KesimTarihi, DonemKodu, MekanId, StokId,
                KaynakTip, KaynakAnahtar, Oncelik, Durum,
                OlusturmaTarihi, GuncellemeTarihi
            )
            VALUES
            (
                @AuditDate,
                FORMAT(@AuditDate, 'yyyyMM'),
                @LocationId,
                0,  -- StokId: saha denetimde yok, 0 varsayilan
                'SAHA_DENETIM',
                CONCAT('AuditId:', @AuditId, '|Loc:', @LocationName),
                3,  -- yuksek oncelik
                'NEW',
                SYSDATETIME(),
                SYSDATETIME()
            );
        END

        -- Ozet bilgi don
        SELECT
            AuditId       = @AuditId,
            TotalResults  = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId),
            FailedResults = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId AND IsPassed = 0),
            RepeatResults = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId AND RepeatCount > 0),
            SystemicResults = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId AND IsSystemic = 1),
            PipelineStatus = 'COMPLETED';
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg18 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg18, 16, 1);
    END CATCH
END
GO

PRINT '21_sps_audit.sql completed successfully.';
GO
