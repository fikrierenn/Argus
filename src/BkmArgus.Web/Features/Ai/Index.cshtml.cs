using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class AiModel : PageModel
{
    private readonly SqlDb _db;

    public string ActiveTab { get; private set; } = "queue";
    public string? Search { get; private set; }
    public string? Durum { get; private set; }
    public DateTime? KesimBas { get; private set; }
    public DateTime? KesimBit { get; private set; }
    public int Top { get; private set; } = 200;
    public int ResetTop { get; private set; } = 200;
    public int ResetMinSkor { get; private set; } = 80;

    public IReadOnlyList<IstekRow> Istekler { get; private set; } = Array.Empty<IstekRow>();
    public IReadOnlyList<LlmRow> Sonuclar { get; private set; } = Array.Empty<LlmRow>();

    public IReadOnlyList<OptionItem> DurumOptions { get; } = new[]
    {
        new OptionItem(string.Empty, "Hepsi"),
        new OptionItem("NEW", "NEW"),
        new OptionItem("BEKLEMEDE", "BEKLEMEDE"),
        new OptionItem("LM_RUNNING", "LM_RUNNING"),
        new OptionItem("LM_DONE", "LM_DONE"),
        new OptionItem("LLM_RUNNING", "LLM_RUNNING"),
        new OptionItem("LLM_DONE", "LLM_DONE"),
        new OptionItem("ERROR", "ERROR")
    };

    public AiModel(SqlDb db)
    {
        _db = db;
    }

    public async Task OnGetAsync(
        string? tab,
        string? search,
        string? durum,
        DateTime? kesimBas,
        DateTime? kesimBit,
        int? top)
    {
        ActiveTab = NormalizeTab(tab);
        Search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        Durum = string.IsNullOrWhiteSpace(durum) ? null : durum.Trim();
        KesimBas = kesimBas?.Date;
        KesimBit = kesimBit?.Date;
        Top = NormalizeTop(top);

        ResetTop = 200;
        ResetMinSkor = 80;

        if (ActiveTab == "sonuc")
        {
            Sonuclar = await _db.QueryAsync<LlmRow>(
                "ai.sp_LlmResults_List",
                new { Top, Search });
            return;
        }

        Istekler = await _db.QueryAsync<IstekRow>(
            "ai.sp_AnalysisQueue_List",
            new
            {
                Top,
                Durum,
                Search,
                KesimBas,
                KesimBit
            });
    }

    public async Task<IActionResult> OnPostResetAsync(int? top, int? minSkor, bool? silVektor)
    {
        var safeTop = NormalizeTop(top);
        var safeMinSkor = NormalizeSkor(minSkor);
        var deleteVectors = silVektor.GetValueOrDefault(false);

        await _db.ExecuteAsync(
            "ai.sp_AnalysisQueue_ResetAndTrigger",
            new
            {
                Top = safeTop,
                MinSkor = safeMinSkor,
                SilVektor = deleteVectors
            });

        TempData["Status"] = $"Sifirlandi. Top={safeTop}, MinSkor={safeMinSkor}, SilVektor={(deleteVectors ? "1" : "0")}.";
        return RedirectToPage("/Ai/Index", new { tab = "queue" });
    }

    private static string NormalizeTab(string? tab)
    {
        if (string.IsNullOrWhiteSpace(tab))
        {
            return "queue";
        }

        return tab.Trim().ToLowerInvariant() switch
        {
            "sonuc" => "sonuc",
            _ => "queue"
        };
    }

    private static int NormalizeTop(int? top)
    {
        var value = top.GetValueOrDefault(200);
        if (value < 10)
        {
            return 10;
        }

        return value > 2000 ? 2000 : value;
    }

    private static int NormalizeSkor(int? skor)
    {
        var value = skor.GetValueOrDefault(80);
        if (value < 0)
        {
            return 0;
        }

        return value > 100 ? 100 : value;
    }

    public sealed record OptionItem(string Value, string Label);

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
        public string? LmNot { get; init; }
        public string? HataMesaji { get; init; }
        public DateTime? OlusturmaTarihi { get; init; }
        public DateTime? GuncellemeTarihi { get; init; }
    }

    public sealed record LlmRow
    {
        public long IstekId { get; init; }
        public string? Model { get; init; }
        public string? PromptVersiyon { get; init; }
        public string? YoneticiOzeti { get; init; }
        public int? GuvenSkoru { get; init; }
        public DateTime? OlusturmaTarihi { get; init; }
        public string DonemKodu { get; init; } = string.Empty;
        public int MekanId { get; init; }
        public string? MekanAd { get; init; }
        public int StokId { get; init; }
        public string? UrunKod { get; init; }
        public string? UrunAd { get; init; }
        public string Durum { get; init; } = string.Empty;
    }
}
