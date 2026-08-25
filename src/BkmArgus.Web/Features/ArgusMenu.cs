using BkmArgus.Web.Security;
using Solum.Web.Menu;

namespace BkmArgus.Web.Features;

/// <summary>
/// BkmArgus yan menusu. Solum'un katki modeline gore tek kaynak burasidir —
/// _Layout icinde elle yazilmis 20+ bagalanti bu sinifa tasindi (plan: 04, Faz 2).
///
/// YETKI NOTU: RequiredPermission yalniz GORUNURLUK suzer. Asil kapi sayfa
/// attribute'udur (@attribute [Authorize(Policy = ...)]). Menude gizlemek
/// yetki degildir (security-principles.md §4).
///
/// Menu DUZ tutuldu (alt oge yok): Solum'un _SolumNav partial'i alt ogeleri
/// isim-bazli ic ice partial cagrisiyla ciziyor; RootDirectory = "/Features"
/// oldugu icin bu cozumleme dogrulanmadi. Grup ihtiyaci dogarsa once o
/// dogrulanir.
/// </summary>
public sealed class ArgusMenu : IMenuContributor
{
    // Ikonlar satir ici SVG (CDN bagimliligi yok, razor-conventions.md).
    // Gelistirici yazimi — kullanici verisi DEGIL (Solum _SolumNav bunu Html.Raw ile basar).
    private const string IcoHome =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3 11.5L12 4l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-8.5Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>""";

    private const string IcoDashboard =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 13v6h6v-6H4Zm10-8v14h6V5h-6ZM4 5v6h6V5H4Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>""";

    private const string IcoRisk =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3 2.5 20.5h19L12 3Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 9v5M12 17.5h.01" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>""";

    private const string IcoDof =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M9 4h6l3 3v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h3Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M8 11h8M8 15h6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>""";

    private const string IcoAudit =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M9 2H5a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8l-6-6Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 13l2 2 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>""";

    private const string IcoAi =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3v4M12 17v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M3 12h4M17 12h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z" stroke="currentColor" stroke-width="1.5"/></svg>""";

    private const string IcoLearn =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 4 3 8l9 4 9-4-9-4Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M7 10v5c0 1.1 2.24 2 5 2s5-.9 5-2v-5M21 8v6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>""";

    private const string IcoProvider =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M8 5v4M14 10v4M10 15v4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>""";

    private const string IcoCorrelation =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.5"/><circle cx="12" cy="12" r="4" stroke="currentColor" stroke-width="1.5"/><path d="M12 3v4M12 17v4M3 12h4M17 12h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>""";

    private const string IcoRef =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M8 6v6M16 12v6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>""";

    private const string IcoUsers =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M16 14a4 4 0 1 1-8 0" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M4 20a8 8 0 0 1 16 0" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><path d="M12 3.5a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z" stroke="currentColor" stroke-width="1.5"/></svg>""";

    private const string IcoSettings =
        """<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 8.5a3.5 3.5 0 1 1 0 7 3.5 3.5 0 0 1 0-7Z" stroke="currentColor" stroke-width="1.5"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.5"/></svg>""";

    /// <inheritdoc />
    public void Contribute(MenuBuilderContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        context.Add(new MenuItem("home", "Genel Bakış") { Url = "/", Icon = IcoHome, Order = 10 });
        context.Add(new MenuItem("dashboard", "Dashboard") { Url = "/Dashboard", Icon = IcoDashboard, Order = 20 });
        context.Add(new MenuItem("risk", "Risk Gezgini") { Url = "/Risk", Icon = IcoRisk, Order = 30 });
        context.Add(new MenuItem("dof", "DÖF Yönetimi") { Url = "/Dof", Icon = IcoDof, Order = 40 });
        context.Add(new MenuItem("audit", "Saha Denetim") { Url = "/Audit", Icon = IcoAudit, Order = 50 });

        // AI ve korelasyon LLM maliyeti uretir -> YONETICI ve ustu.
        context.Add(new MenuItem("ai", "AI Analiz")
        {
            Url = "/Ai", Icon = IcoAi, Order = 60, RequiredPermission = ArgusPermissions.Yonetim
        });
        context.Add(new MenuItem("ai-learn", "AI Öğrenme")
        {
            Url = "/Ai/Ogrenme", Icon = IcoLearn, Order = 70, RequiredPermission = ArgusPermissions.Yonetim
        });
        context.Add(new MenuItem("correlation", "Korelasyon")
        {
            Url = "/Correlation", Icon = IcoCorrelation, Order = 80, RequiredPermission = ArgusPermissions.Yonetim
        });

        // Saglayici anahtarlari, referans tanimlari, kullanici yonetimi -> yalniz ADMIN.
        context.Add(new MenuItem("ai-providers", "AI Sağlayıcıları")
        {
            Url = "/Ai/Providers", Icon = IcoProvider, Order = 90, RequiredPermission = ArgusPermissions.Admin
        });
        context.Add(new MenuItem("ref", "Tanımlar")
        {
            Url = "/Ref", Icon = IcoRef, Order = 100, RequiredPermission = ArgusPermissions.Admin
        });
        context.Add(new MenuItem("yonetim", "Yönetim")
        {
            Url = "/Yonetim", Icon = IcoUsers, Order = 110, RequiredPermission = ArgusPermissions.Admin
        });
        context.Add(new MenuItem("ayarlar", "Ayarlar")
        {
            Url = "/Ayarlar", Icon = IcoSettings, Order = 120, RequiredPermission = ArgusPermissions.Admin
        });
    }
}

/// <summary>
/// Rol kodunu kullaniciya gosterilecek Turkce etikete cevirir.
/// Eski _Layout'ta iki ayri yerde kopyaydi ve YONETICI karsiligi YOKTU
/// (var olmayan "MUDUR" rolu vardi) — tek yere alindi ve Roles sabitlerine baglandi.
/// </summary>
public static class RoleLabel
{
    /// <summary>Rol kodu -> Turkce etiket. Bilinmeyen kod oldugu gibi doner.</summary>
    public static string For(string? roleCode) => roleCode switch
    {
        Roles.Admin => "Sistem Yöneticisi",
        Roles.Yonetici => "Yönetici",
        Roles.Denetci => "Denetçi",
        _ => roleCode ?? string.Empty
    };
}
