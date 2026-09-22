using Microsoft.AspNetCore.Authorization;
using Solum.Core.Extensibility;
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

    /// <summary>
    /// Izin verili mi.
    ///
    /// <paramref name="resource"/> Solum'un 2026-09 sozlesmesiyle geldi: dolu
    /// ise soru TEK KAYIT icindir ("BU siparisi gorebilir mi"), null ise AD
    /// seviyesindedir ("siparis gorebilir mi").
    ///
    /// BkmArgus'ta bu kontrol YALNIZ MENU GORUNURLUGU icin cagriliyor, yani
    /// soru daima ad seviyesinde. Kayit-bazli kapsam kontrolu bizde SP'de
    /// (ornek: `audit.sp_Audit_Delete` kapsam kapisi) — orasi tek boğaz.
    /// Dolayisiyla `resource` BILINCLI olarak DEGERLENDIRILMIYOR; kayit-bazli
    /// bir cagri gelirse ad seviyesinde cevaplanir ve bu YANILTICI olurdu,
    /// o yuzden log'a uyari dusuyor.
    /// </summary>
    public async Task<bool> IsGrantedAsync(
        string permissionName,
        RecordRef? resource,
        CancellationToken ct = default)
    {
        // Kayit-bazli soru bu uygulamada desteklenmiyor — sessiz "evet" demek
        // yerine gorunur kaliyor (fail-loud niyet beyani).
        if (resource is not null)
        {
            logger.LogWarning(
                "Kayit-bazli izin sorusu ad seviyesinde cevaplandi. Izin={Izin} Varlik={Varlik} KayitId={KayitId}",
                permissionName, resource.Value.EntityName, resource.Value.RecordId);
        }

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
