-- 44_dof_attachments.sql: DOF Document Attachments
-- Depends on: dof.Findings

IF OBJECT_ID('dof.Attachments', 'U') IS NULL
CREATE TABLE dof.Attachments (
    Id int IDENTITY(1,1) PRIMARY KEY,
    DofId bigint NOT NULL,
    FileName nvarchar(200) NOT NULL,
    FilePath nvarchar(400) NOT NULL,
    FileSize bigint DEFAULT 0,
    ContentType varchar(100),
    UploadedByUserId int,
    Description nvarchar(500),
    CreatedAt datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_DofAttachments_Findings FOREIGN KEY (DofId) REFERENCES dof.Findings(DofId)
);
GO

-- List attachments for a DOF
IF OBJECT_ID('dof.sp_Attachment_List', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Attachment_List;
GO
CREATE PROCEDURE dof.sp_Attachment_List
    @DofId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.Id, a.DofId, a.FileName, a.FilePath, a.FileSize, a.ContentType,
           a.Description, a.CreatedAt, a.UploadedByUserId,
           u.FullName AS UploadedByName
    FROM dof.Attachments a
    LEFT JOIN dbo.Users u ON u.Id = a.UploadedByUserId
    WHERE a.DofId = @DofId
    ORDER BY a.CreatedAt DESC;
END
GO

-- Add attachment
IF OBJECT_ID('dof.sp_Attachment_Add', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Attachment_Add;
GO
CREATE PROCEDURE dof.sp_Attachment_Add
    @DofId bigint,
    @FileName nvarchar(200),
    @FilePath nvarchar(400),
    @FileSize bigint = 0,
    @ContentType varchar(100) = NULL,
    @UploadedByUserId int = NULL,
    @Description nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dof.Attachments (DofId, FileName, FilePath, FileSize, ContentType, UploadedByUserId, Description)
    VALUES (@DofId, @FileName, @FilePath, @FileSize, @ContentType, @UploadedByUserId, @Description);

    SELECT SCOPE_IDENTITY() AS Id;
END
GO

-- Delete attachment (only uploader or admin)
IF OBJECT_ID('dof.sp_Attachment_Delete', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Attachment_Delete;
GO
CREATE PROCEDURE dof.sp_Attachment_Delete
    @AttachmentId int,
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;

    -- Allow delete if user is the uploader or has ADMIN role
    IF EXISTS (
        SELECT 1 FROM dof.Attachments a
        WHERE a.Id = @AttachmentId
          AND (a.UploadedByUserId = @UserId
               OR EXISTS (SELECT 1 FROM dbo.Users u WHERE u.Id = @UserId AND u.Role = 'ADMIN'))
    )
    BEGIN
        DECLARE @FilePath nvarchar(400);
        SELECT @FilePath = FilePath FROM dof.Attachments WHERE Id = @AttachmentId;

        DELETE FROM dof.Attachments WHERE Id = @AttachmentId;

        SELECT @FilePath AS DeletedFilePath;
    END
    ELSE
    BEGIN
        SELECT CAST(NULL AS nvarchar(400)) AS DeletedFilePath;
    END
END
GO
