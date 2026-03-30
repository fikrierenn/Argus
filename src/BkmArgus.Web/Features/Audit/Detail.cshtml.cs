using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using System.Security.Claims;

namespace BkmArgus.Web.Features.Audit;

public class DetailModel : PageModel
{
    private readonly SqlDb _db;
    public DetailModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)] public int Id { get; set; }

    public EditModel.AuditHeader? Audit { get; private set; }
    public IReadOnlyList<EditModel.ResultRow> Results { get; private set; } = Array.Empty<EditModel.ResultRow>();
    public ILookup<string, EditModel.ResultRow> GroupedResults => Results.ToLookup(r => r.AuditGroup ?? "Diger");
    public ReportSummary? Summary { get; private set; }

    public async Task<IActionResult> OnGetAsync()
    {
        Audit = await _db.QuerySingleAsync<EditModel.AuditHeader>("audit.sp_Audit_Get", new { AuditId = Id });
        if (Audit is null) return NotFound();

        Results = await _db.QueryAsync<EditModel.ResultRow>("audit.sp_Result_ListByAudit", new { AuditId = Id });

        if (Audit.IsFinalized)
        {
            Summary = await _db.QuerySingleAsync<ReportSummary>("audit.sp_Report_AuditSummary", new { DenetimId = Id });
        }

        return Page();
    }

    public async Task<IActionResult> OnPostCreateDofAsync(int resultId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");
        await _db.ExecuteAsync("audit.sp_Analysis_CreateDofForResult", new
        {
            AuditResultId = resultId,
            CreatedByUserId = userId
        });
        TempData["StatusMessage"] = "DOF olusturuldu.";
        return RedirectToPage("Detail", new { id = Id });
    }

    public async Task<IActionResult> OnPostCreateAllDofAsync()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");
        await _db.ExecuteAsync("audit.sp_Analysis_CreateDofFromFindings", new
        {
            AuditId = Id,
            MinRiskScore = 9,
            CreatedByUserId = userId
        });
        TempData["StatusMessage"] = "DOF'lar olusturuldu.";
        return RedirectToPage("Detail", new { id = Id });
    }

    public sealed record ReportSummary
    {
        public string? LocationName { get; init; }
        public DateTime AuditDate { get; init; }
        public string? ReportNo { get; init; }
        public int TotalItems { get; init; }
        public int PassedItems { get; init; }
        public int FailedItems { get; init; }
        public decimal ComplianceRate { get; init; }
        public decimal AvgRiskScore { get; init; }
        public int HighRiskCount { get; init; }
    }
}
