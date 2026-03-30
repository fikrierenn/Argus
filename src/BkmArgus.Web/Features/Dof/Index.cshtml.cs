using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Dof;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;
    public IndexModel(SqlDb db) => _db = db;

    public IReadOnlyList<FindingRow> Findings { get; private set; } = Array.Empty<FindingRow>();
    public DofKpiRow? Kpi { get; private set; }

    // Kanban columns
    public IEnumerable<FindingRow> Draft => Findings.Where(f => f.Status == "DRAFT");
    public IEnumerable<FindingRow> Open => Findings.Where(f => f.Status == "OPEN");
    public IEnumerable<FindingRow> InProgress => Findings.Where(f => f.Status == "IN_PROGRESS");
    public IEnumerable<FindingRow> PendingValidation => Findings.Where(f => f.Status == "PENDING_VALIDATION");
    public IEnumerable<FindingRow> Closed => Findings.Where(f => f.Status is "CLOSED" or "REJECTED");

    public async Task OnGetAsync()
    {
        Findings = await _db.QueryAsync<FindingRow>("dof.sp_Finding_List", new { Top = 100 });
        var kpi = await _db.QuerySingleAsync<DofKpiRow>("dof.sp_Finding_Dashboard");
        Kpi = kpi ?? new DofKpiRow();
    }

    public sealed record FindingRow
    {
        public long DofId { get; init; }
        public string Title { get; init; } = "";
        public string? Description { get; init; }
        public int RiskLevel { get; init; }
        public string Status { get; init; } = "";
        public string? AssignedTo { get; init; }
        public DateTime? SlaDueDate { get; init; }
        public string? FindingSignature { get; init; }
        public DateTime CreatedAt { get; init; }

        public string RiskLabel => RiskLevel switch
        {
            >= 5 => "Kritik",
            >= 4 => "Yuksek",
            >= 3 => "Orta",
            _ => "Dusuk"
        };

        public int SlaDaysLeft => SlaDueDate.HasValue
            ? (int)(SlaDueDate.Value.Date - DateTime.Today).TotalDays
            : 0;
    }

    public sealed record DofKpiRow
    {
        public int TotalCount { get; init; }
        public int DraftCount { get; init; }
        public int OpenCount { get; init; }
        public int InProgressCount { get; init; }
        public int PendingValidationCount { get; init; }
        public int ClosedCount { get; init; }
        public int RejectedCount { get; init; }
        public int OverdueCount { get; init; }
        public decimal AvgResolutionDays { get; init; }
    }
}
