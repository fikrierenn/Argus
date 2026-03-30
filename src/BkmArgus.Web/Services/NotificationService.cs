using BkmArgus.Web.Data;

namespace BkmArgus.Web.Services;

public sealed class NotificationService
{
    private readonly SqlDb _db;

    public NotificationService(SqlDb db) => _db = db;

    public async Task<int> GetUnreadCountAsync(int userId)
    {
        var result = await _db.QuerySingleAsync<CountRow>(
            "log.sp_Notification_UnreadCount", new { UserId = userId });
        return result?.Count ?? 0;
    }

    public async Task<List<NotificationRow>> GetLatestAsync(int userId, bool onlyUnread = false)
    {
        return await _db.QueryAsync<NotificationRow>(
            "log.sp_Notification_List",
            new { UserId = userId, OnlyUnread = onlyUnread, Top = 20 });
    }

    public async Task MarkReadAsync(int notificationId, int userId)
        => await _db.ExecuteAsync(
            "log.sp_Notification_MarkRead",
            new { NotificationId = notificationId, UserId = userId });

    public async Task MarkAllReadAsync(int userId)
        => await _db.ExecuteAsync(
            "log.sp_Notification_MarkAllRead",
            new { UserId = userId });

    public async Task CreateAsync(int userId, string type, string title,
        string? message = null, string? link = null)
        => await _db.ExecuteAsync(
            "log.sp_Notification_Create",
            new { UserId = userId, Type = type, Title = title, Message = message, Link = link });

    // ---------- Row types ----------

    public sealed record NotificationRow
    {
        public int Id { get; init; }
        public string Type { get; init; } = "";
        public string Title { get; init; } = "";
        public string? Message { get; init; }
        public string? Link { get; init; }
        public bool IsRead { get; init; }
        public DateTime CreatedAt { get; init; }
    }

    private sealed record CountRow
    {
        public int Count { get; init; }
    }
}
