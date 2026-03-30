-- =============================================
-- 43: Audit -> DOF Pipeline
-- Denetim bulgularindan otomatik DOF olusturma
-- =============================================

SET NOCOUNT ON;
GO

-- =============================================
-- SP 1: Bulk - Bir denetimin tum yuksek riskli
--        basarisiz bulgulari icin DOF olustur
-- =============================================
IF OBJECT_ID('audit.sp_Analysis_CreateDofFromFindings', 'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Analysis_CreateDofFromFindings;
GO

CREATE PROCEDURE audit.sp_Analysis_CreateDofFromFindings
    @AuditId         int,
    @MinRiskScore    int = 9,
    @CreatedByUserId int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CreatedCount  int = 0;
    DECLARE @SkippedCount  int = 0;
    DECLARE @Now           datetime2(0) = SYSDATETIME();

    -- Validate audit exists
    IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @AuditId)
    BEGIN
        RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
        RETURN;
    END

    -- Get creator name for CreatedBy field
    DECLARE @CreatedByName nvarchar(80);
    SELECT @CreatedByName = ISNULL(FullName, Username)
    FROM audit.Users
    WHERE Id = @CreatedByUserId;

    IF @CreatedByName IS NULL
        SET @CreatedByName = N'Sistem';

    -- Get next DOF sequence number
    DECLARE @MaxDofNum int;
    SELECT @MaxDofNum = ISNULL(
        MAX(CAST(REPLACE(FindingSignature, 'DOF-', '') AS int)), 0
    )
    FROM dof.Findings
    WHERE FindingSignature LIKE 'DOF-[0-9][0-9][0-9][0-9][0-9]';

    -- Cursor through eligible results
    DECLARE @ResultId    int;
    DECLARE @ItemText    nvarchar(500);
    DECLARE @RiskScore   int;
    DECLARE @AuditGroup  nvarchar(100);
    DECLARE @Area        nvarchar(100);
    DECLARE @LocationName nvarchar(100);
    DECLARE @AuditDate   datetime2(0);
    DECLARE @Manager     nvarchar(100);
    DECLARE @SourceKey   varchar(120);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            r.Id,
            r.ItemText,
            r.RiskScore,
            r.AuditGroup,
            r.Area,
            a.LocationName,
            a.AuditDate,
            a.Manager
        FROM audit.AuditResults r
        INNER JOIN audit.Audits a ON a.Id = r.AuditId
        WHERE r.AuditId = @AuditId
          AND r.IsPassed = 0
          AND r.RiskScore >= @MinRiskScore
        ORDER BY r.RiskScore DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @ResultId, @ItemText, @RiskScore, @AuditGroup, @Area, @LocationName, @AuditDate, @Manager;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SourceKey = CONCAT('AUDIT_', @AuditId, '_RESULT_', @ResultId);

        -- Check if DOF already exists for this source
        IF EXISTS (SELECT 1 FROM dof.Findings WHERE SourceKey = @SourceKey)
        BEGIN
            SET @SkippedCount = @SkippedCount + 1;
        END
        ELSE
        BEGIN
            SET @MaxDofNum = @MaxDofNum + 1;

            DECLARE @Signature varchar(120) = CONCAT('DOF-', RIGHT('00000' + CAST(@MaxDofNum AS varchar(5)), 5));
            DECLARE @Title nvarchar(200) = LEFT(@ItemText, 200);
            DECLARE @Description nvarchar(max) = CONCAT(
                N'Denetim: ', @LocationName,
                N' (', FORMAT(@AuditDate, 'dd.MM.yyyy'), N')',
                N' - ', @AuditGroup, N'/', @Area,
                N' - RiskScore: ', @RiskScore
            );
            DECLARE @RiskLevel tinyint = CASE
                WHEN @RiskScore > 15 THEN 5
                WHEN @RiskScore > 8  THEN 3
                ELSE 1
            END;
            DECLARE @SlaDueDate date = CAST(CASE
                WHEN @RiskScore > 15 THEN DATEADD(DAY, 3, @Now)
                WHEN @RiskScore > 8  THEN DATEADD(DAY, 7, @Now)
                ELSE DATEADD(DAY, 14, @Now)
            END AS date);

            INSERT INTO dof.Findings
            (
                FindingSignature, SourceSystemCode, SourceObjectCode, SourceKey,
                Title, Description, RiskLevel, SlaDueDate, Status,
                CreatedBy, CreatedByUserId, AssignedTo,
                CreatedAt, UpdatedAt
            )
            VALUES
            (
                @Signature, 'SAHA_DENETIM', 'DENETIM_BULGU', @SourceKey,
                @Title, @Description, @RiskLevel, @SlaDueDate, 'DRAFT',
                @CreatedByName, @CreatedByUserId, @Manager,
                @Now, @Now
            );

            -- Insert status history
            DECLARE @NewDofId bigint = SCOPE_IDENTITY();

            INSERT INTO dof.StatusHistory (DofId, FromStatus, ToStatus, ChangedByUserId, Reason, CreatedAt)
            VALUES (@NewDofId, '', 'DRAFT', @CreatedByUserId,
                    N'Denetim bulgusundan otomatik olusturuldu', @Now);

            SET @CreatedCount = @CreatedCount + 1;
        END

        FETCH NEXT FROM cur INTO @ResultId, @ItemText, @RiskScore, @AuditGroup, @Area, @LocationName, @AuditDate, @Manager;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- Return summary
    SELECT
        CreatedCount  = @CreatedCount,
        SkippedCount  = @SkippedCount,
        TotalEligible = @CreatedCount + @SkippedCount;
END
GO

-- =============================================
-- SP 2: Single - Tek bir AuditResult icin DOF
--        Manuel "DOF Olustur" butonu icin
-- =============================================
IF OBJECT_ID('audit.sp_Analysis_CreateDofForResult', 'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Analysis_CreateDofForResult;
GO

CREATE PROCEDURE audit.sp_Analysis_CreateDofForResult
    @AuditResultId   int,
    @CreatedByUserId int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now datetime2(0) = SYSDATETIME();

    -- Validate result exists and is failed
    DECLARE @AuditId     int;
    DECLARE @ItemText    nvarchar(500);
    DECLARE @RiskScore   int;
    DECLARE @AuditGroup  nvarchar(100);
    DECLARE @Area        nvarchar(100);
    DECLARE @IsPassed    bit;

    SELECT
        @AuditId    = r.AuditId,
        @ItemText   = r.ItemText,
        @RiskScore  = r.RiskScore,
        @AuditGroup = r.AuditGroup,
        @Area       = r.Area,
        @IsPassed   = r.IsPassed
    FROM audit.AuditResults r
    WHERE r.Id = @AuditResultId;

    IF @AuditId IS NULL
    BEGIN
        RAISERROR('AuditResult bulunamadi. Id: %d', 16, 1, @AuditResultId);
        RETURN;
    END

    IF @IsPassed = 1
    BEGIN
        RAISERROR('Bu madde basarili (IsPassed=1), DOF olusturulamaz.', 16, 1);
        RETURN;
    END

    -- Check if DOF already exists
    DECLARE @SourceKey varchar(120) = CONCAT('AUDIT_', @AuditId, '_RESULT_', @AuditResultId);

    IF EXISTS (SELECT 1 FROM dof.Findings WHERE SourceKey = @SourceKey)
    BEGIN
        SELECT
            CreatedCount = 0,
            SkippedCount = 1,
            Message = N'Bu bulgu icin DOF zaten mevcut.';
        RETURN;
    END

    -- Get audit info
    DECLARE @LocationName nvarchar(100);
    DECLARE @AuditDate    datetime2(0);
    DECLARE @Manager      nvarchar(100);

    SELECT
        @LocationName = LocationName,
        @AuditDate    = AuditDate,
        @Manager      = Manager
    FROM audit.Audits
    WHERE Id = @AuditId;

    -- Get creator name
    DECLARE @CreatedByName nvarchar(80);
    SELECT @CreatedByName = ISNULL(FullName, Username)
    FROM audit.Users
    WHERE Id = @CreatedByUserId;

    IF @CreatedByName IS NULL
        SET @CreatedByName = N'Sistem';

    -- Generate signature
    DECLARE @MaxDofNum int;
    SELECT @MaxDofNum = ISNULL(
        MAX(CAST(REPLACE(FindingSignature, 'DOF-', '') AS int)), 0
    )
    FROM dof.Findings
    WHERE FindingSignature LIKE 'DOF-[0-9][0-9][0-9][0-9][0-9]';

    DECLARE @Signature varchar(120) = CONCAT('DOF-', RIGHT('00000' + CAST(@MaxDofNum + 1 AS varchar(5)), 5));
    DECLARE @Title nvarchar(200) = LEFT(@ItemText, 200);
    DECLARE @Description nvarchar(max) = CONCAT(
        N'Denetim: ', @LocationName,
        N' (', FORMAT(@AuditDate, 'dd.MM.yyyy'), N')',
        N' - ', @AuditGroup, N'/', @Area,
        N' - RiskScore: ', @RiskScore
    );
    DECLARE @RiskLevel tinyint = CASE
        WHEN @RiskScore > 15 THEN 5
        WHEN @RiskScore > 8  THEN 3
        ELSE 1
    END;
    DECLARE @SlaDueDate date = CAST(CASE
        WHEN @RiskScore > 15 THEN DATEADD(DAY, 3, @Now)
        WHEN @RiskScore > 8  THEN DATEADD(DAY, 7, @Now)
        ELSE DATEADD(DAY, 14, @Now)
    END AS date);

    INSERT INTO dof.Findings
    (
        FindingSignature, SourceSystemCode, SourceObjectCode, SourceKey,
        Title, Description, RiskLevel, SlaDueDate, Status,
        CreatedBy, CreatedByUserId, AssignedTo,
        CreatedAt, UpdatedAt
    )
    VALUES
    (
        @Signature, 'SAHA_DENETIM', 'DENETIM_BULGU', @SourceKey,
        @Title, @Description, @RiskLevel, @SlaDueDate, 'DRAFT',
        @CreatedByName, @CreatedByUserId, @Manager,
        @Now, @Now
    );

    DECLARE @NewDofId bigint = SCOPE_IDENTITY();

    INSERT INTO dof.StatusHistory (DofId, FromStatus, ToStatus, ChangedByUserId, Reason, CreatedAt)
    VALUES (@NewDofId, '', 'DRAFT', @CreatedByUserId,
            N'Denetim bulgusundan manuel olusturuldu', @Now);

    SELECT
        CreatedCount = 1,
        SkippedCount = 0,
        DofId        = @NewDofId,
        Signature    = @Signature;
END
GO

-- =============================================
-- SP 3: Update FullPipeline to include DOF step
-- =============================================
IF OBJECT_ID('audit.sp_Analysis_FullPipeline', 'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Analysis_FullPipeline;
GO

CREATE PROCEDURE audit.sp_Analysis_FullPipeline
    @AuditId int
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

            SELECT
                @AuditDate    = AuditDate,
                @LocationName = LocationName
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
                0,
                0,
                'SAHA_DENETIM',
                CONCAT('AuditId:', @AuditId, '|Loc:', @LocationName),
                3,
                'NEW',
                SYSDATETIME(),
                SYSDATETIME()
            );
        END

        -- 5. Yuksek riskli basarisiz bulgulardan otomatik DOF olustur
        DECLARE @DofCreated  int = 0;
        DECLARE @DofSkipped  int = 0;

        -- Use temp table to capture SP output
        DECLARE @DofResult TABLE (CreatedCount int, SkippedCount int, TotalEligible int);

        INSERT INTO @DofResult
        EXEC audit.sp_Analysis_CreateDofFromFindings
            @AuditId = @AuditId,
            @MinRiskScore = 9,
            @CreatedByUserId = 1;  -- Sistem kullanicisi

        SELECT
            @DofCreated = ISNULL(CreatedCount, 0),
            @DofSkipped = ISNULL(SkippedCount, 0)
        FROM @DofResult;

        -- Ozet bilgi don
        SELECT
            AuditId          = @AuditId,
            TotalResults     = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId),
            FailedResults    = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId AND IsPassed = 0),
            RepeatResults    = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId AND RepeatCount > 0),
            SystemicResults  = (SELECT COUNT(*) FROM audit.AuditResults WHERE AuditId = @AuditId AND IsSystemic = 1),
            DofCreatedCount  = @DofCreated,
            DofSkippedCount  = @DofSkipped,
            PipelineStatus   = 'COMPLETED';
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg18 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg18, 16, 1);
    END CATCH
END
GO

PRINT '43_audit_to_dof_pipeline: OK';
GO
