using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using System.Security.Claims;
using System.Text.Json;

namespace BkmArgus.Web.Features.Audit;

public class EditModel : PageModel
{
    private readonly SqlDb _db;
    public EditModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)] public int Id { get; set; }

    public AuditHeader? Audit { get; private set; }
    public IReadOnlyList<ResultRow> Results { get; private set; } = Array.Empty<ResultRow>();
    public ILookup<string, ResultRow> GroupedResults => Results.ToLookup(r => r.AuditGroup ?? "Diger");

    public async Task<IActionResult> OnGetAsync()
    {
        Audit = await _db.QuerySingleAsync<AuditHeader>("audit.sp_Audit_Get", new { AuditId = Id });
        if (Audit is null) return NotFound();
        if (Audit.IsFinalized) return RedirectToPage("Detail", new { id = Id });

        Results = await _db.QueryAsync<ResultRow>("audit.sp_Result_ListByAudit", new { AuditId = Id });
        return Page();
    }

    public async Task<IActionResult> OnPostSaveAsync()
    {
        var formResults = new List<object>();
        foreach (var key in Request.Form.Keys.Where(k => k.StartsWith("result_")))
        {
            var resultId = int.Parse(key.Replace("result_", ""));
            var isPassed = Request.Form[key].ToString() == "true";
            formResults.Add(new { ResultId = resultId, IsPassed = isPassed });
        }

        if (formResults.Any())
        {
            var json = JsonSerializer.Serialize(formResults);
            await _db.ExecuteAsync("audit.sp_Result_BulkUpdate", new { AuditId = Id, JsonData = json });
        }

        TempData["StatusMessage"] = "Sonuclar kaydedildi.";
        return RedirectToPage("Edit", new { id = Id });
    }

    public async Task<IActionResult> OnPostFinalizeAsync()
    {
        // First save current form state
        await OnPostSaveAsync();

        // Then finalize
        await _db.ExecuteAsync("audit.sp_Audit_Finalize", new { AuditId = Id });

        // Run analysis pipeline
        await _db.ExecuteAsync("audit.sp_Analysis_FullPipeline", new { AuditId = Id });

        TempData["StatusMessage"] = "Denetim kesinlestirildi ve analiz pipeline tamamlandi.";
        return RedirectToPage("Detail", new { id = Id });
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
        return RedirectToPage("Edit", new { id = Id });
    }

    public sealed record AuditHeader
    {
        public int Id { get; init; }
        public string LocationName { get; init; } = "";
        public string? LocationType { get; init; }
        public DateTime AuditDate { get; init; }
        public DateTime? ReportDate { get; init; }
        public string? ReportNo { get; init; }
        public string? Manager { get; init; }
        public string? Directorate { get; init; }
        public bool IsFinalized { get; init; }
        public DateTime? FinalizedAt { get; init; }
        public int TotalItems { get; init; }
        public int PassedItems { get; init; }
        public int FailedItems { get; init; }
        public decimal ComplianceRate { get; init; }
    }

    public sealed record ResultRow
    {
        public int Id { get; init; }
        public int AuditItemId { get; init; }
        public string? AuditGroup { get; init; }
        public string? Area { get; init; }
        public string? RiskType { get; init; }
        public string ItemText { get; init; } = "";
        public int SortOrder { get; init; }
        public string? FindingType { get; init; }
        public int Probability { get; init; }
        public int Impact { get; init; }
        public int RiskScore { get; init; }
        public string? RiskLevel { get; init; }
        public bool IsPassed { get; init; }
        public string? Remark { get; init; }
        public int RepeatCount { get; init; }
        public bool IsSystemic { get; init; }
        public int PhotoCount { get; init; }
    }
}
