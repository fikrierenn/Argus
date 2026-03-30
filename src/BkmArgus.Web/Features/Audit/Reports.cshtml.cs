using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Audit;

public class ReportsModel : PageModel
{
    private readonly SqlDb _db;
    public ReportsModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)] public string? Tab { get; set; }
    [BindProperty(SupportsGet = true)] public string? Location { get; set; }

    public IReadOnlyList<ScorecardRow> Scorecards { get; private set; } = Array.Empty<ScorecardRow>();
    public IReadOnlyList<TrendRow> Trends { get; private set; } = Array.Empty<TrendRow>();
    public IReadOnlyList<RepeatingRow> Repeating { get; private set; } = Array.Empty<RepeatingRow>();
    public IReadOnlyList<SystemicRow> Systemic { get; private set; } = Array.Empty<SystemicRow>();

    public async Task OnGetAsync()
    {
        Tab = string.IsNullOrWhiteSpace(Tab) ? "karne" : Tab.ToLowerInvariant();

        Scorecards = await _db.QueryAsync<ScorecardRow>("audit.sp_Report_Scorecard", new
        {
            MagazaAdi = Location,
            BaslangicTarihi = (DateTime?)null,
            BitisTarihi = (DateTime?)null
        });

        if (Tab == "trend")
        {
            Trends = await _db.QueryAsync<TrendRow>("audit.sp_Report_MonthlyTrend", new
            {
                MagazaAdi = Location,
                AySayisi = 12
            });
        }
        else if (Tab == "tekrar")
        {
            Repeating = await _db.QueryAsync<RepeatingRow>("audit.sp_Report_RepeatingFindings", new
            {
                MinTekrar = 2,
                Ust = 20
            });
        }
        else if (Tab == "sistemik")
        {
            Systemic = await _db.QueryAsync<SystemicRow>("audit.sp_Report_SystemicFindings");
        }
    }

    public sealed record ScorecardRow
    {
        public string LocationName { get; init; } = "";
        public int AuditCount { get; init; }
        public decimal AvgComplianceRate { get; init; }
        public DateTime? LastAuditDate { get; init; }
        public decimal LastComplianceRate { get; init; }
    }

    public sealed record TrendRow
    {
        public int Year { get; init; }
        public int Month { get; init; }
        public int AuditCount { get; init; }
        public decimal AvgComplianceRate { get; init; }
    }

    public sealed record RepeatingRow
    {
        public string ItemText { get; init; } = "";
        public int TotalFailures { get; init; }
        public int DistinctLocationCount { get; init; }
        public int DistinctAuditCount { get; init; }
        public decimal AvgRiskScore { get; init; }
        public bool IsSystemic { get; init; }
    }

    public sealed record SystemicRow
    {
        public string ItemText { get; init; } = "";
        public int DistinctLocationCount { get; init; }
        public int TotalFailures { get; init; }
        public DateTime? LastSeenDate { get; init; }
    }
}
