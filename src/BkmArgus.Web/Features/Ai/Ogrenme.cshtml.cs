using System.Security.Claims;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Web.Features.Ai;

/// <summary>
/// Ogrenme ekrani. AI'in verideki tutarsizliklari sorup cevabi kalici bilgiye
/// cevirdigi yer.
///
/// Tarama tamamen deterministik SQL'dir (ai.sp_Consistency_Scan) — LLM
/// cagrilmaz, maliyeti sifirdir. Sorular TOPLU sorulur: 91 notsuz madde icin
/// 91 soru degil bir soru cikar, verilen cevap POLITIKA olur ve sonraki tum
/// skill calistirmalarinin baglamina girer.
/// </summary>
[Authorize(Policy = Security.Policies.YonetimVeUstu)]
public sealed class OgrenmeModel(SqlDb db, ILogger<OgrenmeModel> logger) : PageModel
{
    public IReadOnlyList<QuestionRow> Questions { get; private set; } = [];
    public IReadOnlyList<FactRow> Facts { get; private set; } = [];
    public IReadOnlyList<AnsweredRow> Answered { get; private set; } = [];

    public async Task OnGetAsync() => await LoadAsync();

    /// <summary>Tutarsizlik taramasini elle tetikler (deterministik, ucretsiz).</summary>
    public async Task<IActionResult> OnPostTaraAsync()
    {
        try
        {
            var uid = CurrentUserId();
            var rows = await db.QueryAsync<QuestionRow>("ai.sp_Consistency_Scan", new { KullaniciId = uid });

            TempData["StatusMessage"] = rows.Count == 0
                ? "Tarama tamamlandi — acik tutarsizlik bulunamadi."
                : $"Tarama tamamlandi — {rows.Count} acik soru var.";
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "Tutarsizlik taramasi basarisiz.");
            TempData["Error"] = "Tarama sirasinda veritabani hatasi olustu.";
        }

        return RedirectToPage();
    }

    /// <summary>Soruyu cevaplar; cevap ai.LearningFacts'e dusup prompt'a girer.</summary>
    public async Task<IActionResult> OnPostCevaplaAsync(int soruId, string? cevap, string? serbestCevap)
    {
        // Is kurali: serbest metin doluysa o gecerli — kullanici secenegi
        // begenmeyip kendi kararini yazmis demektir.
        var nihai = !string.IsNullOrWhiteSpace(serbestCevap) ? serbestCevap : cevap;

        if (string.IsNullOrWhiteSpace(nihai))
        {
            TempData["Error"] = "Bir secenek isaretleyin veya kendi cevabinizi yazin.";
            return RedirectToPage();
        }

        return await AnswerAsync(soruId, nihai, yoksay: false,
            basari: "Cevap kaydedildi — bundan sonraki AI calistirmalarinda dikkate alinacak.");
    }

    /// <summary>Soruyu yoksayar. Yoksayilan soru bilgi uretmez.</summary>
    public async Task<IActionResult> OnPostYoksayAsync(int soruId)
        => await AnswerAsync(soruId, "(kullanici yoksaydi)", yoksay: true,
               basari: "Soru yoksayildi.");

    /// <summary>
    /// Yanlis ogrenilmis bir bilgiyi pasife ceker. Enjeksiyon veya hatali
    /// karar durumunda geri donusun tek yolu budur — kayit silinmez,
    /// izlenebilir kalir.
    /// </summary>
    public async Task<IActionResult> OnPostBilgiKaldirAsync(int bilgiId)
    {
        try
        {
            await db.ExecuteAsync("ai.sp_LearningFact_SetActive",
                new { BilgiId = bilgiId, Aktif = false, KullaniciId = CurrentUserId() });

            TempData["StatusMessage"] = "Bilgi kaldirildi — AI bundan sonra dikkate almayacak.";
        }
        catch (SqlException ex) when (ex.Number is >= 50000 and < 60000)
        {
            TempData["Error"] = ex.Message;
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "Ogrenilen bilgi kaldirilamadi. BilgiId={BilgiId}", bilgiId);
            TempData["Error"] = "Veritabani isleminde hata olustu.";
        }

        return RedirectToPage();
    }

    private async Task<IActionResult> AnswerAsync(int soruId, string cevap, bool yoksay, string basari)
    {
        try
        {
            await db.ExecuteAsync("ai.sp_LearningQuestion_Answer", new
            {
                SoruId      = soruId,
                Cevap       = cevap,
                KullaniciId = CurrentUserId(),
                Yoksay      = yoksay
            });

            TempData["StatusMessage"] = basari;
        }
        catch (SqlException ex) when (ex.Number is >= 50000 and < 60000)
        {
            // Is kurali hatasi — SP Turkce yazdi, kullaniciya gosterilebilir
            TempData["Error"] = ex.Message;
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "Soru cevaplanamadi. SoruId={SoruId}", soruId);
            TempData["Error"] = "Veritabani isleminde hata olustu.";
        }

        return RedirectToPage();
    }

    private async Task LoadAsync()
    {
        Questions = await db.QueryAsync<QuestionRow>("ai.sp_LearningQuestion_List", new { Durum = "ACIK" });
        Answered  = await db.QueryAsync<AnsweredRow>("ai.sp_LearningQuestion_List", new { Durum = "CEVAPLANDI" });

        Facts = await db.QueryAsync<FactRow>(
            "ai.sp_LearningFact_List", new { SadeceAktif = true });
    }

    private int CurrentUserId()
        => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;

    /// <summary>Secenekleri JSON dizisinden cozer; bozuksa bos liste doner.</summary>
    public static IReadOnlyList<string> ParseOptions(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return [];
        }

        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<List<string>>(json) ?? [];
        }
        catch (System.Text.Json.JsonException)
        {
            return [];
        }
    }

    public sealed class QuestionRow
    {
        public int QuestionId { get; init; }
        public string Signature { get; init; } = "";
        public string Category { get; init; } = "";
        public string Severity { get; init; } = "";
        public string QuestionText { get; init; } = "";
        public int AffectedCount { get; init; }
        public string? EvidenceSample { get; init; }
        public string? OptionsJson { get; init; }
        public string Status { get; init; } = "";
    }

    public sealed class AnsweredRow
    {
        public int QuestionId { get; init; }
        public string QuestionText { get; init; } = "";
        public string? AnswerText { get; init; }
        public DateTime? AnsweredAt { get; init; }
    }

    public sealed class FactRow
    {
        public int FactId { get; init; }
        public string? SkillId { get; init; }
        public string FactText { get; init; } = "";
        public string SourceType { get; init; } = "";
        public DateTime CreatedAt { get; init; }
    }
}
