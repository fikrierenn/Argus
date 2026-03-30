-- DOF History + Comments SPs for Detail page
IF OBJECT_ID('dof.sp_Finding_History', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_History;
GO
CREATE PROCEDURE dof.sp_Finding_History @DofId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT h.FromStatus, h.ToStatus, h.Reason, u.FullName AS ChangedByName, h.CreatedAt AS ChangedAt
    FROM dof.StatusHistory h
    LEFT JOIN audit.Users u ON u.Id = h.ChangedByUserId
    WHERE h.DofId = @DofId
    ORDER BY h.CreatedAt DESC;
END
GO

IF OBJECT_ID('dof.sp_Finding_Comments', 'P') IS NOT NULL DROP PROCEDURE dof.sp_Finding_Comments;
GO
CREATE PROCEDURE dof.sp_Finding_Comments @DofId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id, c.DofId, u.FullName AS AuthorName, c.CommentText, c.CreatedAt
    FROM dof.Comments c
    LEFT JOIN audit.Users u ON u.Id = c.AuthorUserId
    WHERE c.DofId = @DofId
    ORDER BY c.CreatedAt ASC;
END
GO
