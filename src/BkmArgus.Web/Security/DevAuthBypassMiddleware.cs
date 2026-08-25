using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace BkmArgus.Web.Security;

/// <summary>
/// GELISTIRME ORTAMI ICIN oturum atlama. Kimligi dogrulanmamis istegi,
/// yapilandirmada belirtilen rolde sanal bir kullanici olarak isaretler —
/// boylece gelistirici her calistirmada giris ekranindan gecmez.
///
/// ⚠ GUVENLIK YUZEYI. Iki kapi birlikte acilmadikca CALISMAZ:
///   1. Ortam Development olmali (Program.cs kaydi bunu zorluyor).
///   2. Yapilandirmada "Auth:DevBypassRole" DOLU olmali.
///
/// Bayrak varsayilan olarak YOK: takipli appsettings dosyalarina yazilmaz,
/// yalnizca gitignore'lu appsettings.Local.json ya da ortam degiskeninden
/// gelir (BKM sir yonetimi deseni). Boylece depoya bakan biri bu yolu
/// kazara acik bulamaz.
///
/// Uretimde bayrak ayarliysa uygulama ACILISTA HATA VERIR
/// (<see cref="UretimdeKapaliOldugunuDogrula"/>) — sessizce calismaz.
/// Sessiz calisan bir kimlik atlama, kimsenin fark etmedigi acik kapidir.
/// </summary>
public sealed class DevAuthBypassMiddleware(
    RequestDelegate next,
    ILogger<DevAuthBypassMiddleware> logger,
    DevAuthBypassOptions options)
{
    /// <summary>Istek hattinda kimligi olmayan kullaniciyi sanal gelistiriciye baglar.</summary>
    public async Task InvokeAsync(HttpContext context)
    {
        // Is kurali: gercek oturum varsa ona dokunulmaz — gelistirici normal
        // giris yaptiysa kendi rolunde kalir.
        if (context.User.Identity?.IsAuthenticated == true)
        {
            await next(context);
            return;
        }

        var kimlik = new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, options.UserId.ToString()),
            new Claim(ClaimTypes.Name, options.UserName),
            new Claim("FullName", options.UserName),
            new Claim(ClaimTypes.Role, options.Role)
        ], CookieAuthenticationDefaults.AuthenticationScheme);

        context.User = new ClaimsPrincipal(kimlik);

        // Her istekte log gurultu yapar; ayrintiyi Debug seviyesine biraktim,
        // acik oldugu bilgisi acilista Warning olarak zaten basiliyor.
        logger.LogDebug("Dev oturum atlama: {Rol} rolunde {Yol}", options.Role, context.Request.Path);

        await next(context);
    }

    /// <summary>
    /// Uretimde bayragin ayarli OLMADIGINI dogrular. Ayarliysa firlatir —
    /// yanlis ortama sizmis bir kimlik atlama, calisir halde birakilmaktansa
    /// uygulamayi hic baslatmamasi gerekir.
    /// </summary>
    public static void UretimdeKapaliOldugunuDogrula(IConfiguration config, IWebHostEnvironment env)
    {
        if (env.IsDevelopment())
        {
            return;
        }

        if (!string.IsNullOrWhiteSpace(config["Auth:DevBypassRole"]))
        {
            throw new InvalidOperationException(
                "Auth:DevBypassRole yalniz Development ortaminda kullanilabilir. " +
                $"Aktif ortam: {env.EnvironmentName}. Ayari kaldirin.");
        }
    }
}

/// <summary>Dev oturum atlama ayarlari (yalniz Development'ta okunur).</summary>
public sealed class DevAuthBypassOptions
{
    /// <summary>Sanal kullanicinin rolu — <see cref="Roles"/> degerlerinden biri.</summary>
    public required string Role { get; init; }

    /// <summary>audit.Users.Id karsiligi; bildirim/denetim izi bu kimlige yazilir.</summary>
    public int UserId { get; init; } = 1;

    /// <summary>Arayuzde gorunecek ad — atlamanin acik oldugu belli olsun.</summary>
    public string UserName { get; init; } = "Gelistirici (DEV)";
}
