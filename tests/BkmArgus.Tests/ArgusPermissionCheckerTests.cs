using System.Security.Claims;
using BkmArgus.Web.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace BkmArgus.Tests;

/// <summary>
/// Yetki adaptorunun FAIL-CLOSED davranis sozlesmesi (plan: 04, Faz 4).
///
/// NEDEN TEST: adaptorun en kritik ozelligi "eslemesi olmayan izin adi
/// REDDEDILIR". Birisi iyi niyetle bilinmeyen izne true dondurse hicbir sey
/// kirilmazdi — guvenlik denetimi (2026-08-25) bu bosluga isaret etti.
/// </summary>
public class ArgusPermissionCheckerTests
{
    private static ArgusPermissionChecker Kur(ClaimsPrincipal? kullanici, bool policySonucu = true)
    {
        var accessor = new HttpContextAccessor();
        if (kullanici is not null)
        {
            accessor.HttpContext = new DefaultHttpContext { User = kullanici };
        }

        return new ArgusPermissionChecker(
            accessor,
            new SabitYetkiServisi(policySonucu),
            NullLogger<ArgusPermissionChecker>.Instance);
    }

    private static ClaimsPrincipal Kimlikli(string rol) =>
        new(new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, "1"), new Claim(ClaimTypes.Role, rol)],
            "TestSema"));

    [Fact]
    public async Task Kimligi_dogrulanmamis_kullaniciya_hicbir_izin_verilmez()
    {
        var checker = Kur(new ClaimsPrincipal(new ClaimsIdentity()), policySonucu: true);

        // Policy servisi "evet" dese bile kimlik yoksa reddedilir.
        Assert.False(await checker.IsGrantedAsync(ArgusPermissions.Admin));
        Assert.False(await checker.IsGrantedAsync(ArgusPermissions.Yonetim));
    }

    [Fact]
    public async Task HttpContext_yoksa_izin_verilmez()
    {
        var checker = Kur(kullanici: null, policySonucu: true);

        Assert.False(await checker.IsGrantedAsync(ArgusPermissions.Admin));
    }

    [Fact]
    public async Task Eslemesi_olmayan_izin_adi_FAIL_CLOSED_reddedilir()
    {
        // Yazim hatasi ya da kaldirilmis izin adi: policy servisine hic
        // gidilmez, sonuc false. Sessiz true en tehlikeli hata olurdu.
        var checker = Kur(Kimlikli("ADMIN"), policySonucu: true);

        Assert.False(await checker.IsGrantedAsync("Argus.OlmayanIzin"));
        Assert.False(await checker.IsGrantedAsync(""));
    }

    [Fact]
    public async Task Eslemeli_izin_karari_policy_servisine_devredilir()
    {
        // Karar adaptorde DEGIL, IAuthorizationService'te — iki ayri yetki
        // gercegi dogmasin. Servis ne derse o.
        var izinli = Kur(Kimlikli("ADMIN"), policySonucu: true);
        var izinsiz = Kur(Kimlikli("DENETCI"), policySonucu: false);

        Assert.True(await izinli.IsGrantedAsync(ArgusPermissions.Admin));
        Assert.False(await izinsiz.IsGrantedAsync(ArgusPermissions.Admin));
    }

    [Fact]
    public async Task Izin_adi_buyuk_kucuk_harf_duyarsiz_eslesir()
    {
        var checker = Kur(Kimlikli("ADMIN"), policySonucu: true);

        Assert.True(await checker.IsGrantedAsync("argus.admin"));
    }

    /// <summary>Testte gercek policy motoru yerine sabit cevap veren servis.</summary>
    private sealed class SabitYetkiServisi(bool sonuc) : IAuthorizationService
    {
        public Task<AuthorizationResult> AuthorizeAsync(
            ClaimsPrincipal user, object? resource, IEnumerable<IAuthorizationRequirement> requirements) =>
            Task.FromResult(sonuc ? AuthorizationResult.Success() : AuthorizationResult.Failed());

        public Task<AuthorizationResult> AuthorizeAsync(
            ClaimsPrincipal user, object? resource, string policyName) =>
            Task.FromResult(sonuc ? AuthorizationResult.Success() : AuthorizationResult.Failed());
    }
}
