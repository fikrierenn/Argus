using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features.Correlation;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;

    public IndexModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)]
    public string? Quadrant { get; set; }

    public IReadOnlyList<CorrelationRow> Items { get; private set; } = Array.Empty<CorrelationRow>();
    public CorrelationSummary Summary { get; private set; } = new();

    public async Task OnGetAsync()
    {
        Items = await _db.QueryAsync<CorrelationRow>(
            "rpt.sp_CrossCorrelation_List",
            new { Quadrant, Top = 100 });

        Summary = new CorrelationSummary
        {
            Total = Items.Count,
            UrgentCount = Items.Count(x => x.Quadrant == "YUKSEK_YUKSEK"),
            AvgCombinedScore = Items.Any()
                ? Math.Round(Items.Average(x => x.CombinedScore), 1)
                : 0
        };
    }

    public async Task<IActionResult> OnPostRecalculateAsync()
    {
        await _db.ExecuteAsync("rpt.sp_CrossCorrelation_Calculate");
        return RedirectToPage();
    }

    public sealed record CorrelationRow
    {
        public int Id { get; init; }
        public int LocationId { get; init; }
        public string LocationName { get; init; } = string.Empty;
        public DateTime SnapshotDate { get; init; }
        public decimal ErpRiskScore { get; init; }
        public decimal AuditComplianceRate { get; init; }
        public decimal RepeatFactor { get; init; }
        public decimal CombinedScore { get; init; }
        public string Quadrant { get; init; } = string.Empty;
        public int AuditCount { get; init; }
        public DateTime? LastAuditDate { get; init; }
    }

    public sealed record CorrelationSummary
    {
        public int Total { get; init; }
        public int UrgentCount { get; init; }
        public decimal AvgCombinedScore { get; init; }
    }
}
