/*
 * 36_sps_auth.sql
 * ---------------------------------------------------------------------------
 * FAZ 4: Authentication stored procedures
 *
 * SPs:
 *   audit.sp_Auth_Login           - Lookup user by username for login
 *   audit.sp_Auth_LoginSuccess    - Record successful login
 *   audit.sp_Auth_LoginFail       - Record failed login, lock after 5
 *   audit.sp_Auth_GetUser         - Full user profile by Id
 *   audit.sp_Auth_ChangePassword  - Update password hash
 *   audit.sp_Auth_UnlockUser      - Admin unlock locked user
 *   audit.sp_Auth_UserList        - All users for admin panel
 *
 * Rules:
 *   - SP names:     audit.sp_Auth_Action (English)
 *   - Parameters:   @ prefix
 *   - SET NOCOUNT ON first line
 *   - TRY-CATCH where applicable
 *   - datetime2(0), SYSDATETIME()
 *   - Idempotent: IF OBJECT_ID DROP + CREATE
 *
 * Generated: 2026-03-30
 * ---------------------------------------------------------------------------
 */
USE BKMDenetim;
GO

PRINT '=== 36_sps_auth START ===';
GO


-- ===========================================================================
-- DROP existing SPs (idempotent)
-- ===========================================================================
IF OBJECT_ID('audit.sp_Auth_Login', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_Login;
IF OBJECT_ID('audit.sp_Auth_LoginSuccess', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_LoginSuccess;
IF OBJECT_ID('audit.sp_Auth_LoginFail', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_LoginFail;
IF OBJECT_ID('audit.sp_Auth_GetUser', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_GetUser;
IF OBJECT_ID('audit.sp_Auth_ChangePassword', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_ChangePassword;
IF OBJECT_ID('audit.sp_Auth_UnlockUser', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_UnlockUser;
IF OBJECT_ID('audit.sp_Auth_UserList', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_UserList;
GO


-- ===========================================================================
-- 1. audit.sp_Auth_Login
--    Lookup user by Username for login. Returns user row if found.
--    BCrypt verification happens in application layer.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_Login
    @Username       nvarchar(50),
    @IpAddress      varchar(45)   = NULL,
    @UserAgent      nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Username,
        FullName,
        Email,
        PasswordHash,
        RoleCode,
        IsLocked,
        FailedLoginCount,
        IsActive,
        LastLoginAt
    FROM audit.Users
    WHERE Username = @Username
      AND IsActive = 1;
END;
GO


-- ===========================================================================
-- 2. audit.sp_Auth_LoginSuccess
--    Reset failed count, update LastLoginAt, log success.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_LoginSuccess
    @UserId         int,
    @IpAddress      varchar(45)   = NULL,
    @UserAgent      nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Reset failed count, update last login
        UPDATE audit.Users
        SET FailedLoginCount = 0,
            IsLocked         = 0,
            LastLoginAt      = SYSDATETIME(),
            UpdatedAt        = SYSDATETIME()
        WHERE Id = @UserId;

        -- Log successful login
        INSERT INTO log.LoginHistory (UserId, IpAddress, UserAgent, IsSuccess)
        VALUES (@UserId, @IpAddress, @UserAgent, 1);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- ===========================================================================
-- 3. audit.sp_Auth_LoginFail
--    Increment failed count, lock after 5 failures, log failure.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_LoginFail
    @UserId         int,
    @IpAddress      varchar(45)   = NULL,
    @UserAgent      nvarchar(500) = NULL,
    @Reason         nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Increment failed login count
        UPDATE audit.Users
        SET FailedLoginCount = FailedLoginCount + 1,
            IsLocked         = CASE WHEN FailedLoginCount + 1 >= 5 THEN 1 ELSE IsLocked END,
            UpdatedAt        = SYSDATETIME()
        WHERE Id = @UserId;

        -- Log failed login
        INSERT INTO log.LoginHistory (UserId, IpAddress, UserAgent, IsSuccess, FailureReason)
        VALUES (@UserId, @IpAddress, @UserAgent, 0, @Reason);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- ===========================================================================
-- 4. audit.sp_Auth_GetUser
--    Full user profile by Id.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_GetUser
    @UserId         int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Username,
        FullName,
        Email,
        PasswordHash,
        RoleCode,
        IsLocked,
        FailedLoginCount,
        IsActive,
        LastLoginAt,
        LastPasswordChangeAt,
        CreatedAt,
        UpdatedAt
    FROM audit.Users
    WHERE Id = @UserId;
END;
GO


-- ===========================================================================
-- 5. audit.sp_Auth_ChangePassword
--    Update password hash and LastPasswordChangeAt.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_ChangePassword
    @UserId             int,
    @NewPasswordHash    nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE audit.Users
    SET PasswordHash          = @NewPasswordHash,
        LastPasswordChangeAt  = SYSDATETIME(),
        UpdatedAt             = SYSDATETIME()
    WHERE Id = @UserId;
END;
GO


-- ===========================================================================
-- 6. audit.sp_Auth_UnlockUser
--    Admin action: reset lock and failed count.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_UnlockUser
    @UserId         int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE audit.Users
    SET IsLocked         = 0,
        FailedLoginCount = 0,
        UpdatedAt        = SYSDATETIME()
    WHERE Id = @UserId;
END;
GO


-- ===========================================================================
-- 7. audit.sp_Auth_UserList
--    All users for admin panel.
-- ===========================================================================
CREATE PROCEDURE audit.sp_Auth_UserList
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Username,
        FullName,
        Email,
        RoleCode,
        IsLocked,
        FailedLoginCount,
        IsActive,
        LastLoginAt,
        LastPasswordChangeAt,
        CreatedAt,
        UpdatedAt
    FROM audit.Users
    ORDER BY FullName;
END;
GO


PRINT '=== 36_sps_auth COMPLETE ===';
GO
