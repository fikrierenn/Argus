-- Add MustChangePassword column for force-change-on-first-login
IF COL_LENGTH('audit.Users', 'MustChangePassword') IS NULL
    ALTER TABLE audit.Users ADD MustChangePassword bit NOT NULL DEFAULT 1;
GO

-- Set existing users: if no password change date, force change
UPDATE audit.Users SET MustChangePassword = 1 WHERE LastPasswordChangeAt IS NULL;
GO

-- Update sp_Auth_Login to include MustChangePassword in output
IF OBJECT_ID('audit.sp_Auth_Login', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_Login;
GO
CREATE PROCEDURE audit.sp_Auth_Login
    @Username nvarchar(50),
    @IpAddress varchar(45) = NULL,
    @UserAgent nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Username, FullName, Email, PasswordHash, RoleCode, IsLocked, FailedLoginCount, MustChangePassword
        FROM audit.Users
        WHERE Username = @Username AND IsActive = 1;
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO

-- Update sp_Auth_ChangePassword to clear MustChangePassword
IF OBJECT_ID('audit.sp_Auth_ChangePassword', 'P') IS NOT NULL DROP PROCEDURE audit.sp_Auth_ChangePassword;
GO
CREATE PROCEDURE audit.sp_Auth_ChangePassword
    @UserId int,
    @NewPasswordHash nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE audit.Users
        SET PasswordHash = @NewPasswordHash,
            LastPasswordChangeAt = SYSDATETIME(),
            MustChangePassword = 0
        WHERE Id = @UserId;
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO
