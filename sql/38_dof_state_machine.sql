/*
 * 38_dof_state_machine.sql
 * ---------------------------------------------------------------------------
 * FAZ 5.1: DOF State Machine — tables, seed data, stored procedures
 *
 * Tables:
 *   dof.StatusHistory   - State transition log
 *   dof.Comments        - Discussion thread per DOF
 *   dof.StatusRules     - Allowed state transitions + required role
 *
 * SPs:
 *   dof.sp_Finding_Get           - Full finding + history + comments
 *   dof.sp_Finding_List          - Filtered list
 *   dof.sp_Finding_Create        - Insert + auto FindingSignature + StatusHistory
 *   dof.sp_Finding_Transition    - Validate + update status + log
 *   dof.sp_Finding_AddComment    - Insert comment
 *   dof.sp_Finding_Dashboard     - KPI counts
 *   dof.sp_Finding_Overdue       - Overdue findings list
 *
 * Rules:
 *   - SET NOCOUNT ON first line
 *   - TRY-CATCH where applicable
 *   - datetime2(0), SYSDATETIME()
 *   - Idempotent: IF NOT EXISTS for tables, IF OBJECT_ID DROP+CREATE for SPs
 *
 * Generated: 2026-03-30
 * ---------------------------------------------------------------------------
 */
USE BKMDenetim;
GO

PRINT '=== 38_dof_state_machine START ===';
GO


-- ===========================================================================
-- 1. TABLES (IF NOT EXISTS)
-- ===========================================================================

-- dof.StatusHistory
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dof' AND TABLE_NAME='StatusHistory')
BEGIN
    CREATE TABLE dof.StatusHistory (
        Id              int           IDENTITY(1,1) PRIMARY KEY,
        DofId           bigint        NOT NULL,
        FromStatus      varchar(20)   NULL,
        ToStatus        varchar(20)   NOT NULL,
        ChangedByUserId int           NOT NULL,
        Reason          nvarchar(500) NULL,
        CreatedAt       datetime2(0)  NOT NULL DEFAULT SYSDATETIME(),

        CONSTRAINT FK_StatusHistory_Findings FOREIGN KEY (DofId)
            REFERENCES dof.Findings(DofId)
    );
    CREATE NONCLUSTERED INDEX IX_StatusHistory_DofId ON dof.StatusHistory(DofId);
    PRINT 'Created dof.StatusHistory';
END
ELSE
    PRINT 'dof.StatusHistory already exists — skipped';
GO

-- dof.Comments
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dof' AND TABLE_NAME='Comments')
BEGIN
    CREATE TABLE dof.Comments (
        Id              int            IDENTITY(1,1) PRIMARY KEY,
        DofId           bigint         NOT NULL,
        AuthorUserId    int            NOT NULL,
        CommentText     nvarchar(2000) NOT NULL,
        CreatedAt       datetime2(0)   NOT NULL DEFAULT SYSDATETIME(),

        CONSTRAINT FK_Comments_Findings FOREIGN KEY (DofId)
            REFERENCES dof.Findings(DofId)
    );
    CREATE NONCLUSTERED INDEX IX_Comments_DofId ON dof.Comments(DofId);
    PRINT 'Created dof.Comments';
END
ELSE
    PRINT 'dof.Comments already exists — skipped';
GO

-- dof.StatusRules
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dof' AND TABLE_NAME='StatusRules')
BEGIN
    CREATE TABLE dof.StatusRules (
        Id              int          IDENTITY(1,1) PRIMARY KEY,
        FromStatus      varchar(20)  NOT NULL,
        ToStatus        varchar(20)  NOT NULL,
        RequiredRole    varchar(20)  NULL,   -- NULL = any role
        IsActive        bit          NOT NULL DEFAULT 1
    );
    PRINT 'Created dof.StatusRules';
END
ELSE
    PRINT 'dof.StatusRules already exists — skipped';
GO


-- ===========================================================================
-- 2. SEED StatusRules (idempotent — skip if rows exist)
-- ===========================================================================
IF NOT EXISTS (SELECT 1 FROM dof.StatusRules)
BEGIN
    INSERT INTO dof.StatusRules (FromStatus, ToStatus, RequiredRole) VALUES
        ('DRAFT',              'OPEN',               'DENETCI'),
        ('OPEN',               'IN_PROGRESS',         NULL),
        ('IN_PROGRESS',        'PENDING_VALIDATION',  NULL),
        ('PENDING_VALIDATION', 'CLOSED',             'YONETICI'),
        ('PENDING_VALIDATION', 'REJECTED',           'YONETICI'),
        ('REJECTED',           'IN_PROGRESS',         NULL),
        ('*',                  'DRAFT',              'ADMIN');   -- any → DRAFT (admin reset)
    PRINT 'Seeded 7 StatusRules';
END
ELSE
    PRINT 'StatusRules already seeded — skipped';
GO


-- ===========================================================================
-- 3. STORED PROCEDURES
-- ===========================================================================

-- Drop all SPs first (idempotent)
IF OBJECT_ID('dof.sp_Finding_Get', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_Get;
IF OBJECT_ID('dof.sp_Finding_List', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_List;
IF OBJECT_ID('dof.sp_Finding_Create', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_Create;
IF OBJECT_ID('dof.sp_Finding_Transition', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_Transition;
IF OBJECT_ID('dof.sp_Finding_AddComment', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_AddComment;
IF OBJECT_ID('dof.sp_Finding_Dashboard', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_Dashboard;
IF OBJECT_ID('dof.sp_Finding_Overdue', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_Overdue;
GO


-- ===========================================================================
-- 3.1  dof.sp_Finding_Get
--      Full finding + status history + comments + last 5 transitions
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_Get
    @DofId bigint
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Finding
    SELECT f.DofId,
           f.FindingSignature,
           f.SourceSystemCode,
           f.SourceObjectCode,
           f.SourceKey,
           f.Title,
           f.Description,
           f.RiskLevel,
           f.SlaDueDate,
           f.Status,
           f.CreatedBy,
           f.AssignedTo,
           f.ApprovedBy,
           f.CreatedByUserId,
           f.AssignedToPersonnelId,
           f.ApprovedByPersonnelId,
           f.CreatedAt,
           f.UpdatedAt,
           f.IsEffective,
           f.EffectivenessScore,
           f.EffectivenessNote
    FROM dof.Findings f
    WHERE f.DofId = @DofId;

    -- Result set 2: Last 5 transitions
    SELECT TOP 5
           sh.Id,
           sh.FromStatus,
           sh.ToStatus,
           sh.ChangedByUserId,
           sh.Reason,
           sh.CreatedAt
    FROM dof.StatusHistory sh
    WHERE sh.DofId = @DofId
    ORDER BY sh.CreatedAt DESC;

    -- Result set 3: Comments (all, newest first)
    SELECT c.Id,
           c.AuthorUserId,
           c.CommentText,
           c.CreatedAt
    FROM dof.Comments c
    WHERE c.DofId = @DofId
    ORDER BY c.CreatedAt DESC;
END
GO


-- ===========================================================================
-- 3.2  dof.sp_Finding_List
--      Filtered list of findings
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_List
    @Status     varchar(20) = NULL,
    @AssignedTo int         = NULL,
    @Top        int         = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
           f.DofId,
           f.FindingSignature,
           f.Title,
           f.RiskLevel,
           f.SlaDueDate,
           f.Status,
           f.AssignedTo,
           f.AssignedToPersonnelId,
           f.CreatedAt,
           f.UpdatedAt
    FROM dof.Findings f
    WHERE (@Status IS NULL OR f.Status = @Status)
      AND (@AssignedTo IS NULL OR f.AssignedToPersonnelId = @AssignedTo)
    ORDER BY f.CreatedAt DESC;
END
GO


-- ===========================================================================
-- 3.3  dof.sp_Finding_Create
--      Insert finding + auto-generate FindingSignature + log to StatusHistory
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_Create
    @Title                nvarchar(200),
    @Description          nvarchar(MAX)  = NULL,
    @RiskLevel            tinyint,
    @SlaDueDate           date           = NULL,
    @SourceKey            varchar(120)   = NULL,
    @AssignedToPersonnelId int           = NULL,
    @CreatedByUserId      int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Generate next FindingSignature: DOF-00001, DOF-00002, ...
        DECLARE @NextSeq int;
        SELECT @NextSeq = ISNULL(MAX(DofId), 0) + 1 FROM dof.Findings;

        DECLARE @Signature varchar(120) = 'DOF-' + RIGHT('00000' + CAST(@NextSeq AS varchar(10)), 5);

        -- Lookup creator name from audit.Users
        DECLARE @CreatedByName nvarchar(80);
        SELECT @CreatedByName = ISNULL(FullName, Username)
        FROM audit.Users
        WHERE Id = @CreatedByUserId;

        IF @CreatedByName IS NULL SET @CreatedByName = N'System';

        -- Lookup assigned name
        DECLARE @AssignedToName nvarchar(80) = NULL;
        IF @AssignedToPersonnelId IS NOT NULL
        BEGIN
            SELECT @AssignedToName = ISNULL(FullName, Username)
            FROM audit.Users
            WHERE Id = @AssignedToPersonnelId;
        END

        INSERT INTO dof.Findings (
            FindingSignature, SourceSystemCode, SourceObjectCode, SourceKey,
            Title, Description, RiskLevel, SlaDueDate, Status,
            CreatedBy, AssignedTo, CreatedByUserId, AssignedToPersonnelId,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @Signature, 'DOF', 'FINDING', @SourceKey,
            @Title, @Description, @RiskLevel, @SlaDueDate, 'DRAFT',
            @CreatedByName, @AssignedToName, @CreatedByUserId, @AssignedToPersonnelId,
            SYSDATETIME(), SYSDATETIME()
        );

        DECLARE @NewDofId bigint = SCOPE_IDENTITY();

        -- Log initial status
        INSERT INTO dof.StatusHistory (DofId, FromStatus, ToStatus, ChangedByUserId, Reason)
        VALUES (@NewDofId, NULL, 'DRAFT', @CreatedByUserId, N'Finding created');

        COMMIT;

        -- Return the created finding
        SELECT @NewDofId AS DofId, @Signature AS FindingSignature;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 3.4  dof.sp_Finding_Transition
--      Validate transition against StatusRules, update, log to StatusHistory
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_Transition
    @DofId      bigint,
    @NewStatus  varchar(20),
    @UserId     int,
    @UserRole   varchar(20),
    @Reason     nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Get current status
        DECLARE @CurrentStatus varchar(20);
        SELECT @CurrentStatus = Status
        FROM dof.Findings
        WHERE DofId = @DofId;

        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR('Finding not found: DofId=%d', 16, 1, @DofId);
            RETURN;
        END

        IF @CurrentStatus = @NewStatus
        BEGIN
            RAISERROR('Finding is already in status %s', 16, 1, @CurrentStatus);
            RETURN;
        END

        -- Validate against StatusRules
        -- Match exact FromStatus OR wildcard '*' (admin reset)
        DECLARE @RuleId int;
        SELECT TOP 1 @RuleId = Id
        FROM dof.StatusRules
        WHERE IsActive = 1
          AND (FromStatus = @CurrentStatus OR FromStatus = '*')
          AND ToStatus = @NewStatus
          AND (RequiredRole IS NULL OR RequiredRole = @UserRole);

        IF @RuleId IS NULL
        BEGIN
            DECLARE @ErrMsg nvarchar(200) = CONCAT(
                'Invalid transition: ', @CurrentStatus, ' -> ', @NewStatus,
                ' (role: ', @UserRole, ')'
            );
            RAISERROR('%s', 16, 1, @ErrMsg);
            RETURN;
        END

        -- Update finding status
        UPDATE dof.Findings
        SET Status    = @NewStatus,
            UpdatedAt = SYSDATETIME()
        WHERE DofId = @DofId;

        -- Log transition
        INSERT INTO dof.StatusHistory (DofId, FromStatus, ToStatus, ChangedByUserId, Reason)
        VALUES (@DofId, @CurrentStatus, @NewStatus, @UserId, @Reason);

        COMMIT;

        SELECT @DofId AS DofId, @CurrentStatus AS FromStatus, @NewStatus AS ToStatus;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO


-- ===========================================================================
-- 3.5  dof.sp_Finding_AddComment
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_AddComment
    @DofId          bigint,
    @AuthorUserId   int,
    @CommentText    nvarchar(2000)
AS
BEGIN
    SET NOCOUNT ON;

    -- Verify finding exists
    IF NOT EXISTS (SELECT 1 FROM dof.Findings WHERE DofId = @DofId)
    BEGIN
        RAISERROR('Finding not found: DofId=%d', 16, 1, @DofId);
        RETURN;
    END

    INSERT INTO dof.Comments (DofId, AuthorUserId, CommentText)
    VALUES (@DofId, @AuthorUserId, @CommentText);

    SELECT SCOPE_IDENTITY() AS CommentId;
END
GO


-- ===========================================================================
-- 3.6  dof.sp_Finding_Dashboard
--      KPI: counts by status, overdue count, avg resolution days
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_Dashboard
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Counts by status
    SELECT Status,
           COUNT(*) AS Cnt
    FROM dof.Findings
    GROUP BY Status;

    -- Result set 2: Overdue count
    SELECT COUNT(*) AS OverdueCount
    FROM dof.Findings
    WHERE SlaDueDate < CAST(SYSDATETIME() AS date)
      AND Status NOT IN ('CLOSED', 'REJECTED');

    -- Result set 3: Average resolution days (DRAFT->CLOSED)
    SELECT AVG(CAST(DATEDIFF(DAY, f.CreatedAt, sh.CreatedAt) AS decimal(10,1))) AS AvgResolutionDays
    FROM dof.Findings f
    INNER JOIN dof.StatusHistory sh ON sh.DofId = f.DofId AND sh.ToStatus = 'CLOSED'
    WHERE f.Status = 'CLOSED';
END
GO


-- ===========================================================================
-- 3.7  dof.sp_Finding_Overdue
--      List overdue findings
-- ===========================================================================
CREATE PROCEDURE dof.sp_Finding_Overdue
    @Top int = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
           f.DofId,
           f.FindingSignature,
           f.Title,
           f.RiskLevel,
           f.SlaDueDate,
           f.Status,
           f.AssignedTo,
           f.AssignedToPersonnelId,
           DATEDIFF(DAY, f.SlaDueDate, CAST(SYSDATETIME() AS date)) AS OverdueDays
    FROM dof.Findings f
    WHERE f.SlaDueDate < CAST(SYSDATETIME() AS date)
      AND f.Status NOT IN ('CLOSED', 'REJECTED')
    ORDER BY f.SlaDueDate ASC;
END
GO


PRINT '=== 38_dof_state_machine COMPLETE ===';
GO
