using Microsoft.AspNetCore.Antiforgery;

namespace BkmArgus.Web.Security;

/// <summary>
/// `/api/*` uç noktaları için tek kapı: CSRF doğrulaması + JSON gövde okuma.
///
/// NEDEN VAR (güvenlik denetimi 2026-08-26, IMP-2, confidence 88):
/// üç durum değiştiren uç nokta (`dof/transition`,
/// `notifications/mark-read`, `mark-all-read`) yalnız `SameSite=Lax` çerez
/// davranışına güveniyordu. Token yok, custom header yok, parametreler
/// **sorgu dizesinden** okunuyordu — yani düz bir HTML formu yeterliydi.
/// `Lax` çapraz-site POST'u keser AMA **aynı site farklı alt alan adı** için
/// çerez gider: kurum içinde `*.bkmkitap.local` altında saldırganın HTML
/// koyabildiği ikinci bir uygulama varsa, sayfayı açan YONETICI'nin
/// kimliğiyle DÖF kapanıyor ve izde o kullanıcı görünüyordu.
///
/// Üç uç noktada üç ayrı desen yazmak yasak (plan 06 Faz 4): kapı burada.
/// </summary>
public static class ApiGuard
{
    /// <summary>İstemcinin token'ı taşıdığı başlık. `Program.cs` bunu kaydeder.</summary>
    public const string TokenHeader = "RequestVerificationToken";

    /// <summary>
    /// CSRF token'ını doğrular. Geçerliyse <c>null</c> döner (akış devam eder),
    /// geçersizse döndürülecek sonucu verir.
    ///
    /// Neden `403` ve neden gövdede `success:false`: istemci JS'i zaten bu
    /// şekli okuyor; `error` alanı kullanıcıya gösterilebilir Türkçe metin
    /// taşır (`error-handling.md` — iç hata detayı sızmaz).
    /// </summary>
    public static async Task<IResult?> TokenDogrulaAsync(
        HttpContext ctx, IAntiforgery antiforgery, ILogger logger)
    {
        try
        {
            await antiforgery.ValidateRequestAsync(ctx);
            return null;
        }
        catch (AntiforgeryValidationException ex)
        {
            // Guvenlik olayi: SESSIZ gecmez. Kullaniciya ic detay verilmez.
            logger.LogWarning(ex,
                "Antiforgery dogrulamasi basarisiz. Yol={Yol} Kullanici={Kullanici} Kaynak={Kaynak}",
                ctx.Request.Path,
                ctx.User.Identity?.Name ?? "-",
                ctx.Request.Headers.Referer.ToString());

            return Results.Json(
                new { success = false, error = "Oturum doğrulaması başarısız. Sayfayı yenileyip tekrar deneyin." },
                statusCode: StatusCodes.Status403Forbidden);
        }
    }

    /// <summary>
    /// JSON gövdeyi okur. Gövde yok/bozuksa <c>null</c> döner.
    ///
    /// Parametreler sorgu dizesinden GÖVDEYE taşındı: sorgu dizesi tarayıcı
    /// geçmişine, sunucu erişim loguna ve Referer başlığına yazılır
    /// (`security-principles.md §Privacy` — kişisel/iş verisi URL'de olmaz).
    /// </summary>
    public static async Task<T?> GovdeOkuAsync<T>(HttpContext ctx) where T : class
    {
        if (!ctx.Request.HasJsonContentType())
        {
            return null;
        }

        try
        {
            return await ctx.Request.ReadFromJsonAsync<T>();
        }
        catch (System.Text.Json.JsonException)
        {
            // Bozuk JSON bir istemci hatasidir; cagiran BadRequest doner.
            return null;
        }
    }
}
