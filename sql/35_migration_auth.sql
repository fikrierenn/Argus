/*
 * 35_migration_auth.sql
 * ---------------------------------------------------------------------------
 * FAZ 4: RBAC + Authentication infrastructure
 *
 * Changes:
 *   1. Extend audit.Users with auth columns (Username, RoleCode, lock, etc.)
 *   2. Create log.LoginHistory table
 *   3. Seed default admin user
 *
 * Convention: IF NOT EXISTS / COL_LENGTH pattern (idempotent)
 * Generated: 2026-03-30
 * ---------------------------------------------------------------------------
 */
USE BKMDenetim;
GO

PRINT '=== 35_migration_auth START ===';
GO

/* ===== 1. Extend audit.Users with auth columns ===== */

IF COL_LENGTH('audit.Users', 'Username') IS NULL
    ALTER TABLE audit.Users ADD Username nvarchar(50) NULL;
GO

IF COL_LENGTH('audit.Users', 'RoleCode') IS NULL
    ALTER TABLE audit.Users ADD RoleCode varchar(20) NOT NULL CONSTRAINT DF_Users_RoleCode DEFAULT('DENETCI');
GO

IF COL_LENGTH('audit.Users', 'FailedLoginCount') IS NULL
    ALTER TABLE audit.Users ADD FailedLoginCount int NOT NULL CONSTRAINT DF_Users_FailedLoginCount DEFAULT(0);
GO

IF COL_LENGTH('audit.Users', 'IsLocked') IS NULL
    ALTER TABLE audit.Users ADD IsLocked bit NOT NULL CONSTRAINT DF_Users_IsLocked DEFAULT(0);
GO

IF COL_LENGTH('audit.Users', 'LastLoginAt') IS NULL
    ALTER TABLE audit.Users ADD LastLoginAt datetime2(0) NULL;
GO

IF COL_LENGTH('audit.Users', 'LastPasswordChangeAt') IS NULL
    ALTER TABLE audit.Users ADD LastPasswordChangeAt datetime2(0) NULL;
GO

IF COL_LENGTH('audit.Users', 'IsActive') IS NULL
    ALTER TABLE audit.Users ADD IsActive bit NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT(1);
GO

IF COL_LENGTH('audit.Users', 'UpdatedAt') IS NULL
    ALTER TABLE audit.Users ADD UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT(SYSDATETIME());
GO

IF COL_LENGTH('audit.Users', 'CreatedByUserId') IS NULL
    ALTER TABLE audit.Users ADD CreatedByUserId int NULL;
GO

IF COL_LENGTH('audit.Users', 'UpdatedByUserId') IS NULL
    ALTER TABLE audit.Users ADD UpdatedByUserId int NULL;
GO

-- Unique index on Username (only non-null values)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Users_Username' AND object_id = OBJECT_ID('audit.Users'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Users_Username ON audit.Users (Username) WHERE Username IS NOT NULL;
GO

PRINT '  audit.Users auth columns added';
GO


/* ===== 2. log.LoginHistory ===== */

IF OBJECT_ID('log.LoginHistory', 'U') IS NULL
BEGIN
    CREATE TABLE log.LoginHistory
    (
        Id              int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        UserId          int           NOT NULL,
        LoginTime       datetime2(0)  NOT NULL CONSTRAINT DF_LoginHistory_LoginTime DEFAULT(SYSDATETIME()),
        IpAddress       varchar(45)   NULL,
        UserAgent       nvarchar(500) NULL,
        IsSuccess       bit           NOT NULL CONSTRAINT DF_LoginHistory_IsSuccess DEFAULT(1),
        FailureReason   nvarchar(200) NULL,

        CONSTRAINT FK_LoginHistory_Users FOREIGN KEY (UserId) REFERENCES audit.Users(Id)
    );

    CREATE INDEX IX_LoginHistory_UserId ON log.LoginHistory (UserId, LoginTime DESC);
    CREATE INDEX IX_LoginHistory_LoginTime ON log.LoginHistory (LoginTime DESC);

    PRINT '  log.LoginHistory created';
END
ELSE
    PRINT '  log.LoginHistory already exists';
GO


/* ===== 3. Seed default admin user ===== */

IF NOT EXISTS (SELECT 1 FROM audit.Users WHERE Username = 'admin')
BEGIN
    INSERT INTO audit.Users (FullName, Email, Username, PasswordHash, RoleCode, IsActive, CreatedAt, UpdatedAt)
    VALUES (
        N'Sistem Admin',
        'admin@bkmkitap.com',
        'admin',
        '$2a$11$PLACEHOLDER_MUST_BE_SET_BY_APP',
        'ADMIN',
        1,
        SYSDATETIME(),
        SYSDATETIME()
    );
    PRINT '  Default admin user seeded';
END
ELSE
    PRINT '  Admin user already exists';
GO


PRINT '=== 35_migration_auth COMPLETE ===';
GO
