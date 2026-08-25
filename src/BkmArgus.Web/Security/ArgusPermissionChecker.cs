using Microsoft.AspNetCore.Authorization;
using Solum.Core.Permissions;

namespace BkmArgus.Web.Security;

/// <summary>
/// Solum menu/izin sozlesmesinde kullanilan izin adlari.
/// Magic string yasagi (architecture.md §9): menu katkisi bu sabitleri kullanir.
/// </summary>
public static class ArgusPermissions
{
    /// <summary>Yalniz ADMIN — referans tanimlari, kullanici yonetimi, ayarlar.</summary>
    public const string Admin = "Argus.Admin";

    /// <summary>ADMIN veya YONETICI — AI, korelasyon, maliyetli ekranlar.</summary>
    public const string Yonetim = "Argus.Yonetim";
}

/// <summary>
/// Solum'un <see cref="IPermissionChecker"/> sozlesmesini BkmArgus policy'lerine baglar.
///
/// TEK YETKI GERCEGI: bu adaptor kendi kuralini TASIMAZ — karari
/// <see cref="IAuthorizationService"/>'e, yani Program.cs'te tanimli
/// <see cref="Policies"/> politikalarina devreder. Aksi halde iki ayri yetki
/// gercegi dogar ve biri gunceller, oteki bayatlar.
///
/// UYARI: bu kontrol yalniz MENU GORUNURLUGU icindir. Asil kapi sayfa
/// attribute'udur (<c>@attribute [Authorize(Policy = ...)]</c>) —
/// menuden gizlemek yetki degildir (security-principles.md §4).
/// </summary>
public sealed class ArgusPermissionChecker(
    IHttpContextAccessor accessor,
    IAuthorizationService authorization,
    ILogger<ArgusPermissionChecker> logger) : IPermissionChecker
{
    // Izin adi -> policy adi. Eslemesiz ad = yazim hatasi kabul edilir.
    private static readonly Dictionary<string, string> PolicyMap = new(StringComparer.OrdinalIgnoreCase)
    {
        [ArgusPermissions.Admin] = Policies.AdminOnly,
        [ArgusPermissions.Yonetim] = Policies.YonetimVeUstu
    };

    /// <inheritdoc />
    public async Task<bool> IsGrantedAsync(string permissionName, CancellationToken ct = default)
    {
        var user = accessor.HttpContext?.User;

        // Guard: kimligi dogrulanmamis kullaniciya hicbir izin verilmez.
        if (user?.Identity?.IsAuthenticated != true)
        {
            return false;
        }

        // Is kurali: eslemesi olmayan izin adi FAIL-CLOSED reddedilir ama SESSIZ
        // kalmaz. Denetim yazilimi oldugumuz icin varsayilan "kapali"; yazim
        // hatasinin fark edilmesi icin uyari loglanir (sessiz kayip yasak).
        if (!PolicyMap.TryGetValue(permissionName, out var policy))
        {
            logger.LogWarning(
                "Bilinmeyen Solum izin adi: {Izin}. Menu ogesi gizlendi. ArgusPermissions sabitlerini kontrol et.",
                permissionName);
            return false;
        }

        var result = await authorization.AuthorizeAsync(user, policy);
        return result.Succeeded;
    }
}
