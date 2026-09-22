using BkmArgus.Web.Data;
using Solum.Web.Components;

namespace BkmArgus.Web.Services;

public sealed class NotificationService
{
    private readonly SqlDb _db;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(SqlDb db, ILogger<NotificationService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<int> GetUnreadCountAsync(int userId)
    {
        var result = await _db.QuerySingleAsync<CountRow>(
            "log.sp_Notification_UnreadCount", new { UserId = userId });
        return result?.Count ?? 0;
    }

    /// <summary>
    /// Son bildirimler. Adres denetimi BURADA yapilir, gorunumde degil.
    ///
    /// NEDEN SERVISTE: `Link` DB'den geliyor ve Razor niteligi HTML kacirir
    /// ama SEMA denetlemez — `javascript:` oldugu gibi gecerdi. Karar tek
    /// yerde olmali; gorunum yalniz cizer.
    ///
    /// NEDEN `TryCreate`, `Create` DEGIL (Solum'un kendi ayrimi, 2026-09):
    /// kaynakta YAZILI adres icin `Create` dogru — yazim hatasi gurultulu
    /// patlamali. DISARIDAN gelen deger icin `TryCreate` — cunku bu parca
    /// ust cubukta HER sayfada calisiyor ve tek bozuk satir `/Error` dahil
    /// butun siteyi 500 yapardi.
    ///
    /// SESSIZ DEGIL: dusurulen adresin SEBEBI loglanir (`kutuphane-disiplini §5`).
    /// Eski hal `UrlGuard.IsAllowed` ile yalniz true/false biliyordu; artik
    /// "neden dusuruldu" da kayitli.
    /// </summary>
    public async Task<List<NotificationRow>> GetLatestAsync(int userId, bool onlyUnread = false)
    {
        var satirlar = await _db.QueryAsync<NotificationRow>(
            "log.sp_Notification_List",
            new { UserId = userId, OnlyUnread = onlyUnread, Top = 20 });

        var sonuc = new List<NotificationRow>(satirlar.Count);

        foreach (var satir in satirlar)
        {
            if (SafeUrl.TryCreate(satir.Link, out var adres, out var sebep))
            {
                sonuc.Add(satir with { GuvenliLink = adres });
                continue;
            }

            _logger.LogWarning(
                "Bildirim adresi dusuruldu. BildirimId={BildirimId} Sebep={Sebep}",
                satir.Id, sebep);

            // Adres dusuruldu ama BILDIRIM DUSMEDI: metin hala gosterilir,
            // yalniz tiklanamaz. Kaydi gizlemek kullaniciya bilgi kaybettirirdi.
            sonuc.Add(satir with { GuvenliLink = null });
        }

        return sonuc;
    }

    /// <summary>
    /// Bildirimi okundu isaretler ve ETKILENEN SATIR SAYISINI dondurur.
    ///
    /// Eskiden donus yutuluyordu (denetim bulgusu 4.1): 0 satir "bu bildirim
    /// sana ait degil" demektir ve bu bilgi hicbir yere gitmiyordu.
    /// NOT: SP'de `SET NOCOUNT ON` varsa donus -1 olur (bilinmiyor) — cagiran
    /// bu ikisini AYIRMAK zorunda, 0 ile -1 ayni sey degil.
    /// </summary>
    public async Task<int> MarkReadAsync(int notificationId, int userId)
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
        /// <summary>DB'den gelen HAM adres — dogrudan href'e yazilmaz.</summary>
        public string? Link { get; init; }

        /// <summary>
        /// Denetlenmis adres. `null` = "baglanti CIZILMEZ" (adres yok ya da
        /// reddedildi). Gorunum yalniz buna bakar.
        /// </summary>
        public SafeUrl? GuvenliLink { get; init; }
        public bool IsRead { get; init; }
        public DateTime CreatedAt { get; init; }
    }

    private sealed record CountRow
    {
        public int Count { get; init; }
    }
}
