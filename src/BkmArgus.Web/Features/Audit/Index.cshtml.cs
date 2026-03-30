using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Audit;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;
    public IndexModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)] public string? Search { get; set; }
    [BindProperty(SupportsGet = true)] public DateTime? StartDate { get; set; }
    [BindProperty(SupportsGet = true)] public DateTime? EndDate { get; set; }
    [BindProperty(SupportsGet = true)] public bool? IsFinalized { get; set; }

    public IReadOnlyList<AuditRow> Audits { get; private set; } = Array.Empty<AuditRow>();

    public async Task OnGetAsync()
    {
        Audits = await _db.QueryAsync<AuditRow>("audit.sp_Audit_List", new
        {
            LocationName = Search,
            StartDate,
            EndDate,
            IsFinalized,
            Top = 100
        });
    }

    public async Task<IActionResult> OnPostDeleteAsync(int id)
    {
        await _db.ExecuteAsync("audit.sp_Audit_Delete", new { AuditId = id });
        TempData["StatusMessage"] = "Denetim silindi.";
        return RedirectToPage();
    }

    public sealed record AuditRow
    {
        public int Id { get; init; }
        public string LocationName { get; init; } = "";
        public string? LocationType { get; init; }
        public DateTime AuditDate { get; init; }
        public DateTime? ReportDate { get; init; }
        public string? ReportNo { get; init; }
        public bool IsFinalized { get; init; }
        public DateTime? FinalizedAt { get; init; }
        public int TotalItems { get; init; }
        public int PassedItems { get; init; }
        public int FailedItems { get; init; }
    }
}
