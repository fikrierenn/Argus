using System.Text.Json;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public sealed class DetayModel : PageModel
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly SqlDb _db;

    public IstekRow? Istek { get; private set; }
    public LlmDetayRow? Llm { get; private set; }

    public string KokNedenJson { get; private set; } = "-";
    public string DogrulamaJson { get; private set; } = "-";
    public string AksiyonJson { get; private set; } = "-";
    public string DofJson { get; private set; } = "-";
    public string YoneticiJson { get; private set; } = "-";
    public string EvidenceJson { get; private set; } = "-";

    public DetayModel(SqlDb db)
    {
        _db = db;
    }

    public async Task<IActionResult> OnGetAsync(long? id)
    {
        if (!id.HasValue || id.Value <= 0)
        {
            return NotFound();
        }

        Istek = await _db.QuerySingleAsync<IstekRow>(
            "ai.sp_AnalysisQueue_Get",
            new { IstekId = id.Value });

        if (Istek is null)
        {
            return NotFound();
        }

        Llm = await _db.QuerySingleAsync<LlmDetayRow>(
            "ai.sp_LlmResults_Get",
            new { IstekId = id.Value });

        if (Llm is not null)
        {
            KokNedenJson = FormatJson(Llm.KokNedenHipotezleri);
            DogrulamaJson = FormatJson(Llm.DogrulamaAdimlari);
            AksiyonJson = FormatJson(Llm.OnerilenAksiyonlar);
            DofJson = FormatJson(Llm.DofTaslakJson);
            YoneticiJson = FormatJson(Llm.YoneticiOzeti);
        }

        EvidenceJson = FormatJson(Istek.EvidenceJson);

        return Page();
    }

    private static string FormatJson(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "-";
        }

        var clean = value.Trim();
        if (!LooksLikeJson(clean))
        {
            return clean;
        }

        try
        {
            using var doc = JsonDocument.Parse(clean);
            return JsonSerializer.Serialize(doc.RootElement, JsonOptions);
        }
        catch
        {
            return clean;
        }
    }

    private static bool LooksLikeJson(string value)
    {
        return value.StartsWith("{", StringComparison.Ordinal) || value.StartsWith("[", StringComparison.Ordinal);
    }

    public sealed record IstekRow
    {
        public long IstekId { get; init; }
        public DateTime? KesimTarihi { get; init; }
        public string DonemKodu { get; init; } = string.Empty;
        public int MekanId { get; init; }
        public string? MekanAd { get; init; }
        public int StokId { get; init; }
        public string? UrunKod { get; init; }
        public string? UrunAd { get; init; }
        public int? RiskSkor { get; init; }
        public int Oncelik { get; init; }
        public string Durum { get; init; } = string.Empty;
        public string? EvidencePlan { get; init; }
        public string? EvidenceJson { get; init; }
        public string? LmNot { get; init; }
        public string? HataMesaji { get; init; }
        public DateTime? OlusturmaTarihi { get; init; }
        public DateTime? GuncellemeTarihi { get; init; }
    }

    public sealed record LlmDetayRow
    {
        public long IstekId { get; init; }
        public string? Model { get; init; }
        public string? PromptVersiyon { get; init; }
        public string? KokNedenHipotezleri { get; init; }
        public string? DogrulamaAdimlari { get; init; }
        public string? OnerilenAksiyonlar { get; init; }
        public string? DofTaslakJson { get; init; }
        public string? YoneticiOzeti { get; init; }
        public int? GuvenSkoru { get; init; }
        public DateTime? OlusturmaTarihi { get; init; }
    }
}
