-- =============================================================================
-- 39_notifications.sql - Bildirim Sistemi (FAZ 5.2)
-- =============================================================================

-- Tablo: log.Notifications
IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'log' AND t.name = 'Notifications')
BEGIN
    CREATE TABLE log.Notifications
    (
        Id          int           IDENTITY(1,1) PRIMARY KEY,
        UserId      int           NOT NULL,
        Type        varchar(30)   NOT NULL,   -- DOF_SLA, AUDIT_FINALIZED, AI_REPORT_READY, RISK_CRITICAL, SYSTEM
        Title       nvarchar(200) NOT NULL,
        Message     nvarchar(1000) NULL,
        Link        nvarchar(400) NULL,       -- clickable URL (e.g., /Dof/Detail?id=5)
        IsRead      bit           NOT NULL DEFAULT 0,
        CreatedAt   datetime2(0)  NOT NULL DEFAULT SYSDATETIME(),

        CONSTRAINT FK_Notifications_Users FOREIGN KEY (UserId) REFERENCES ref.Users(UserId)
    );

    CREATE NONCLUSTERED INDEX IX_Notifications_UserId_IsRead
        ON log.Notifications (UserId, IsRead)
        INCLUDE (Type, Title, CreatedAt);

    PRINT 'Table log.Notifications created.';
END
ELSE
    PRINT 'Table log.Notifications already exists.';
GO

-- SP: log.sp_Notification_List
IF OBJECT_ID('log.sp_Notification_List', 'P') IS NOT NULL DROP PROCEDURE log.sp_Notification_List;
GO
CREATE PROCEDURE log.sp_Notification_List
    @UserId    int,
    @OnlyUnread bit = 0,
    @Top       int = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        Id, Type, Title, Message, Link, IsRead, CreatedAt
    FROM log.Notifications
    WHERE UserId = @UserId
      AND (@OnlyUnread = 0 OR IsRead = 0)
    ORDER BY CreatedAt DESC;
END
GO
PRINT 'SP log.sp_Notification_List created.';
GO

-- SP: log.sp_Notification_UnreadCount
IF OBJECT_ID('log.sp_Notification_UnreadCount', 'P') IS NOT NULL DROP PROCEDURE log.sp_Notification_UnreadCount;
GO
CREATE PROCEDURE log.sp_Notification_UnreadCount
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS [Count]
    FROM log.Notifications
    WHERE UserId = @UserId AND IsRead = 0;
END
GO
PRINT 'SP log.sp_Notification_UnreadCount created.';
GO

-- SP: log.sp_Notification_MarkRead
IF OBJECT_ID('log.sp_Notification_MarkRead', 'P') IS NOT NULL DROP PROCEDURE log.sp_Notification_MarkRead;
GO
CREATE PROCEDURE log.sp_Notification_MarkRead
    @NotificationId int,
    @UserId         int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE log.Notifications
    SET IsRead = 1
    WHERE Id = @NotificationId AND UserId = @UserId;
END
GO
PRINT 'SP log.sp_Notification_MarkRead created.';
GO

-- SP: log.sp_Notification_MarkAllRead
IF OBJECT_ID('log.sp_Notification_MarkAllRead', 'P') IS NOT NULL DROP PROCEDURE log.sp_Notification_MarkAllRead;
GO
CREATE PROCEDURE log.sp_Notification_MarkAllRead
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE log.Notifications
    SET IsRead = 1
    WHERE UserId = @UserId AND IsRead = 0;
END
GO
PRINT 'SP log.sp_Notification_MarkAllRead created.';
GO

-- SP: log.sp_Notification_Create
IF OBJECT_ID('log.sp_Notification_Create', 'P') IS NOT NULL DROP PROCEDURE log.sp_Notification_Create;
GO
CREATE PROCEDURE log.sp_Notification_Create
    @UserId  int,
    @Type    varchar(30),
    @Title   nvarchar(200),
    @Message nvarchar(1000) = NULL,
    @Link    nvarchar(400)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO log.Notifications (UserId, Type, Title, Message, Link)
    VALUES (@UserId, @Type, @Title, @Message, @Link);

    SELECT SCOPE_IDENTITY() AS Id;
END
GO
PRINT 'SP log.sp_Notification_Create created.';
GO

PRINT '=== 39_notifications.sql COMPLETE ===';
GO
