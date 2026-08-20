using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using BkmArgus.Infrastructure;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Web.Features.Ai;

/// <summary>
/// LLM saglayici yonetimi. Zincir artik kodda degil ai.LlmProviders'ta;
/// yeni bir AI eklemek buradan bir kayit acmakla olur.
/// API anahtari yaz-only: girilen deger sifrelenip saklanir, ekrana asla geri donmez.
/// </summary>
[Authorize(Policy = Security.Policies.AdminOnly)]
public sealed class ProvidersModel(SqlDb db, IConfiguration configuration, ILogger<ProvidersModel> logger) : PageModel
{
    public IReadOnlyList<ProviderRow> Providers { get; private set; } = [];

    /// <summary>Ana sifreleme anahtari tanimli mi — degilse anahtar kaydedilemez.</summary>
    public bool SecretsConfigured { get; private set; }

    [BindProperty]
    public ProviderInput Input { get; set; } = new();

    public async Task OnGetAsync() => await LoadAsync();

    // Saglayici ekler veya gunceller
    public async Task<IActionResult> OnPostKaydetAsync()
    {
        if (!ModelState.IsValid)
        {
            await LoadAsync();
            return Page();
        }

        try
        {
            await db.ExecuteAsync("ai.sp_LlmProvider_Upsert", new
            {
                SaglayiciId    = Input.ProviderId,
                Ad             = Input.Name.Trim().ToLowerInvariant(),
                Tur            = Input.Kind,
                GorunenAd      = Input.DisplayName.Trim(),
                TemelAdres     = Input.BaseUrl.Trim(),
                IstekYolu      = Input.RequestPath?.Trim() ?? string.Empty,
                AnahtarAdi     = string.IsNullOrWhiteSpace(Input.ApiKeyRef) ? null : Input.ApiKeyRef.Trim(),
                AnahtarGerekli = Input.RequiresApiKey,
                Model          = Input.Model.Trim(),
                YedekModel     = string.IsNullOrWhiteSpace(Input.FallbackModel) ? null : Input.FallbackModel.Trim(),
                Oncelik        = Input.Priority,
                Aktif          = Input.IsActive,
                Not            = Input.Notes,
                KullaniciId    = CurrentUserId
            });

            TempData["StatusMessage"] = "Saglayici kaydedildi.";
        }
        catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
        {
            // SP'nin Turkce is kurali mesaji dogrudan gosterilebilir
            TempData["Error"] = sqlEx.Message;
        }
        catch (SqlException sqlEx)
        {
            logger.LogError(sqlEx, "Saglayici kaydedilemedi. Id={Id}", Input.ProviderId);
            TempData["Error"] = "Veritabani isleminde hata olustu.";
        }

        return RedirectToPage();
    }

    // API anahtarini sifreleyip saklar. Duz deger hicbir yere loglanmaz.
    public async Task<IActionResult> OnPostAnahtarAsync(int saglayiciId, string? apiKey)
    {
        if (!SecretProtector.IsConfigured(configuration))
        {
            TempData["Error"] = "BKM_SECRET_KEY tanimli degil — anahtar sifrelenemez.";
            return RedirectToPage();
        }

        try
        {
            // Bos gonderim anahtari siler; ortam degiskeni yoluna geri donulur
            var encrypted = string.IsNullOrWhiteSpace(apiKey)
                ? null
                : SecretProtector.Protect(configuration, apiKey.Trim());

            await db.ExecuteAsync("ai.sp_LlmProvider_SetApiKey", new
            {
                SaglayiciId  = saglayiciId,
                SifreliDeger = encrypted,
                KullaniciId  = CurrentUserId
            });

            TempData["StatusMessage"] = encrypted is null
                ? "Anahtar silindi."
                : "Anahtar sifrelenerek kaydedildi.";
        }
        catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
        {
            TempData["Error"] = sqlEx.Message;
        }
        catch (SqlException sqlEx)
        {
            logger.LogError(sqlEx, "Anahtar kaydedilemedi. SaglayiciId={Id}", saglayiciId);
            TempData["Error"] = "Veritabani isleminde hata olustu.";
        }

        return RedirectToPage();
    }

    // Aktif/pasif — zincire girip girmeyecegini belirler
    public async Task<IActionResult> OnPostDurumAsync(int saglayiciId, bool aktif)
    {
        try
        {
            await db.ExecuteAsync("ai.sp_LlmProvider_SetActive", new
            {
                SaglayiciId = saglayiciId,
                Aktif       = aktif,
                KullaniciId = CurrentUserId
            });

            TempData["StatusMessage"] = aktif ? "Saglayici aktif edildi." : "Saglayici pasife alindi.";
        }
        catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
        {
            TempData["Error"] = sqlEx.Message;
        }
        catch (SqlException sqlEx)
        {
            logger.LogError(sqlEx, "Saglayici durumu degistirilemedi. Id={Id}", saglayiciId);
            TempData["Error"] = "Veritabani isleminde hata olustu.";
        }

        return RedirectToPage();
    }

    private async Task LoadAsync()
    {
        SecretsConfigured = SecretProtector.IsConfigured(configuration);

        var rows = await db.QueryAsync<ProviderRaw>("ai.sp_LlmProvider_List", new { SadeceAktif = false });

        Providers = rows.Select(r => new ProviderRow(
            r.ProviderId,
            r.Name,
            r.Kind,
            r.DisplayName,
            r.BaseUrl,
            r.RequestPath,
            r.ApiKeyRef,
            r.RequiresApiKey,
            r.HasStoredKey,
            // Ortam degiskeni yolu da gecerli bir anahtar kaynagi
            !string.IsNullOrWhiteSpace(r.ApiKeyRef)
                && !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(r.ApiKeyRef) ?? configuration[r.ApiKeyRef]),
            r.ApiKeySetAt,
            r.Model,
            r.FallbackModel,
            r.Priority,
            r.IsActive,
            r.Notes)).ToList();
    }

    private int CurrentUserId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;

    public sealed record ProviderRow(
        int Id, string Name, string Kind, string DisplayName, string BaseUrl, string? RequestPath,
        string? ApiKeyRef, bool RequiresApiKey, bool HasStoredKey, bool HasEnvKey, DateTime? ApiKeySetAt,
        string Model, string? FallbackModel, int Priority, bool IsActive, string? Notes)
    {
        /// <summary>Anahtar iki yoldan biriyle cozulebiliyor mu?</summary>
        public bool KeyAvailable => !RequiresApiKey || HasStoredKey || HasEnvKey;

        public string KeySource => !RequiresApiKey ? "gerekmiyor"
                                 : HasEnvKey       ? "ortam degiskeni"
                                 : HasStoredKey    ? "sifreli kayit"
                                 : "tanimsiz";
    }

    private sealed class ProviderRaw
    {
        public int ProviderId { get; init; }
        public string Name { get; init; } = string.Empty;
        public string Kind { get; init; } = string.Empty;
        public string DisplayName { get; init; } = string.Empty;
        public string BaseUrl { get; init; } = string.Empty;
        public string? RequestPath { get; init; }
        public string? ApiKeyRef { get; init; }
        public bool RequiresApiKey { get; init; }
        public bool HasStoredKey { get; init; }
        public DateTime? ApiKeySetAt { get; init; }
        public string Model { get; init; } = string.Empty;
        public string? FallbackModel { get; init; }
        public int Priority { get; init; }
        public bool IsActive { get; init; }
        public string? Notes { get; init; }
    }

    public sealed class ProviderInput
    {
        public int? ProviderId { get; set; }

        [Required(ErrorMessage = "Ad zorunlu.")]
        [RegularExpression("^[a-zA-Z0-9_-]+$", ErrorMessage = "Ad yalnizca harf, rakam, tire ve alt cizgi icerebilir.")]
        public string Name { get; set; } = string.Empty;

        [Required(ErrorMessage = "Tur zorunlu.")]
        public string Kind { get; set; } = "openai";

        [Required(ErrorMessage = "Gorunen ad zorunlu.")]
        public string DisplayName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Adres zorunlu.")]
        [Url(ErrorMessage = "Gecerli bir adres girin.")]
        public string BaseUrl { get; set; } = string.Empty;

        public string? RequestPath { get; set; } = "/v1/chat/completions";
        public string? ApiKeyRef { get; set; }
        public bool RequiresApiKey { get; set; } = true;

        [Required(ErrorMessage = "Model zorunlu.")]
        public string Model { get; set; } = string.Empty;

        public string? FallbackModel { get; set; }

        [Range(1, 999, ErrorMessage = "Oncelik 1-999 arasinda olmali.")]
        public int Priority { get; set; } = 100;

        public bool IsActive { get; set; }

        [StringLength(500)]
        public string? Notes { get; set; }
    }
}
