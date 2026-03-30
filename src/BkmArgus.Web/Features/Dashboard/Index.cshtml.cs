using System.Globalization;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class DashboardModel : PageModel
{
    private static readonly CultureInfo TrCulture = CultureInfo.GetCultureInfo("tr-TR");
    private readonly SqlDb _db;

    public string KritikRiskDeger { get; private set; } = "0";
    public string KritikRiskNot { get; private set; } = "Esik 80+";
    public string BekleyenDofDeger { get; private set; } = "0";
    public string BekleyenDofNot { get; private set; } = "SLA takibi";
    public string TarananStokDeger { get; private set; } = "0";
    public string TarananStokNot { get; private set; } = "Son gece";
    public string SistemDurum { get; private set; } = "PASS";
    public string SistemNot { get; private set; } = "Joblar tamam";
    public string SistemDurumClass { get; private set; } = "text-emerald-600";
    public string TrendPoints { get; private set; } = "0,90 400,90";

    public IReadOnlyList<RiskRow> RiskPano { get; private set; } = Array.Empty<RiskRow>();
    public IReadOnlyList<DofRow> DofList { get; private set; } = Array.Empty<DofRow>();
    public IReadOnlyList<HealthRow> HealthChecks { get; private set; } = Array.Empty<HealthRow>();
    public IReadOnlyList<RefSummary> RefNotes { get; private set; } = Array.Empty<RefSummary>();

    public DashboardModel(SqlDb db)
    {
        _db = db;
    }

    public async Task OnGetAsync()
    {
        var kpis = await _db.QueryAsync<KpiRow>("rpt.sp_Dashboard_Kpi");
        ApplyKpis(kpis);

        var healthRows = await _db.QueryAsync<HealthRowRaw>("log.sp_HealthCheck_Run");
        ApplyHealth(healthRows);

        var trendRows = await _db.QueryAsync<TrendRow>("rpt.sp_Dashboard_RiskTrend");
        TrendPoints = BuildTrendPoints(trendRows);

        var riskRows = await _db.QueryAsync<RiskRowRaw>("rpt.sp_Dashboard_TopRisk", new { Top = 10 });
        RiskPano = riskRows.Select(r => new RiskRow(
                r.StokId,
                r.MekanId,
                string.IsNullOrWhiteSpace(r.MekanAd) ? $"Mekan-{r.MekanId}" : r.MekanAd,
                string.IsNullOrWhiteSpace(r.UrunAd) ? $"Urun-{r.StokId}" : r.UrunAd,
                r.DonemKodu,
                r.RiskSkor,
                r.Flag,
                string.Empty))
            .ToList();

        var dofRows = await _db.QueryAsync<DofRow>("dof.sp_Dashboard_Dof_List", new { Top = 5 });
        DofList = dofRows.ToList();

        var refRows = await _db.QueryAsync<RefSummaryRow>("ref.sp_Dashboard_Ref_Summary");
        RefNotes = refRows.Select(r => new RefSummary(r.Baslik, r.Deger, r.NotAciklama)).ToList();
    }

    private void ApplyKpis(IEnumerable<KpiRow> rows)
    {
        foreach (var row in rows)
        {
            switch (row.Kodu)
            {
                case "KRITIK_RISK":
                    KritikRiskDeger = FormatNumber(row.Deger);
                    KritikRiskNot = row.NotAciklama;
                    break;
                case "BEKLEYEN_DOF":
                    BekleyenDofDeger = FormatNumber(row.Deger);
                    BekleyenDofNot = row.NotAciklama;
                    break;
                case "TARANAN_STOK":
                    TarananStokDeger = FormatNumber(row.Deger);
                    TarananStokNot = row.NotAciklama;
                    break;
            }
        }
    }

    private void ApplyHealth(IReadOnlyList<HealthRowRaw> rows)
    {
        HealthChecks = rows.Select(row => new HealthRow(
            row.KontrolKodu ?? string.Empty,
            row.Durum ?? "WARN",
            BuildHealthNote(row)))
            .ToList();

        if (rows.Any(r => string.Equals(r.Durum, "FAIL", StringComparison.OrdinalIgnoreCase)))
        {
            SistemDurum = "FAIL";
            SistemNot = "Hata var";
            SistemDurumClass = "text-bkm-red";
        }
        else if (rows.Any(r => string.Equals(r.Durum, "WARN", StringComparison.OrdinalIgnoreCase)))
        {
            SistemDurum = "WARN";
            SistemNot = "Uyari var";
            SistemDurumClass = "text-amber-600";
        }
        else
        {
            SistemDurum = "PASS";
            SistemNot = "Joblar tamam";
            SistemDurumClass = "text-emerald-600";
        }
    }

    private static string BuildHealthNote(HealthRowRaw row)
    {
        if (row.TarihDeger.HasValue)
        {
            return $"{row.TarihDeger:HH:mm} tamamlandi";
        }

        return string.IsNullOrWhiteSpace(row.Detay) ? "-" : row.Detay;
    }

    private static string BuildTrendPoints(IReadOnlyList<TrendRow> rows)
    {
        if (rows.Count == 0)
        {
            return "0,90 400,90";
        }

        var max = rows.Max(r => (double)r.OrtalamaSkor);
        if (max <= 0)
        {
            max = 1;
        }

        const double width = 400;
        const double top = 20;
        const double bottom = 100;
        var span = bottom - top;
        var stepX = rows.Count == 1 ? 0 : width / (rows.Count - 1);

        var points = new List<string>(rows.Count);
        for (var i = 0; i < rows.Count; i++)
        {
            var x = stepX * i;
            var y = bottom - ((double)rows[i].OrtalamaSkor / max) * span;
            points.Add(FormattableString.Invariant($"{x:0.#},{y:0.#}"));
        }

        return string.Join(" ", points);
    }

    private static string FormatNumber(int value) => value.ToString("N0", TrCulture);

    public record RiskRow(int UrunId, int MekanId, string Mekan, string Urun, string Donem, int Skor, string Flag, string Stok);
    public record DofRow(string Baslik, string Sorumlu, string SLA, string Durum);
    public record HealthRow(string Kod, string Durum, string Not);
    public record RefSummary(string Baslik, string Deger, string Not);

    public sealed record KpiRow
    {
        public string Kodu { get; init; } = string.Empty;
        public int Deger { get; init; }
        public string NotAciklama { get; init; } = string.Empty;
    }

    public sealed record TrendRow
    {
        public DateTime Tarih { get; init; }
        public decimal OrtalamaSkor { get; init; }
    }

    public sealed record RiskRowRaw
    {
        public int MekanId { get; init; }
        public string? MekanAd { get; init; }
        public int StokId { get; init; }
        public string? UrunKod { get; init; }
        public string? UrunAd { get; init; }
        public string DonemKodu { get; init; } = string.Empty;
        public int RiskSkor { get; init; }
        public string Flag { get; init; } = string.Empty;
    }

    public sealed record HealthRowRaw
    {
        public string? KontrolKodu { get; init; }
        public string? Durum { get; init; }
        public string? Detay { get; init; }
        public decimal? SayisalDeger { get; init; }
        public DateTime? TarihDeger { get; init; }
    }

    public sealed record RefSummaryRow
    {
        public string Baslik { get; init; } = string.Empty;
        public string Deger { get; init; } = string.Empty;
        public string NotAciklama { get; init; } = string.Empty;
    }
}
