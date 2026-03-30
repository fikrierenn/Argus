using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Audit;

public class CreateModel : PageModel
{
    private readonly SqlDb _db;
    public CreateModel(SqlDb db) => _db = db;

    [BindProperty] public AuditInput Input { get; set; } = new();

    public void OnGet()
    {
        Input.AuditDate = DateTime.Today;
        Input.ReportDate = DateTime.Today;
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var result = await _db.QuerySingleAsync<InsertResult>("audit.sp_Audit_Insert", new
        {
            Input.LocationName,
            LocationType = "Store",
            LocationId = 0,
            Input.AuditDate,
            Input.ReportDate,
            AuditorUserId = 1,
            Input.Manager,
            Input.Directorate,
            CreatedByUserId = 1
        });

        if (result?.Id > 0)
        {
            // Snapshot items to results
            await _db.ExecuteAsync("audit.sp_Result_StartAudit", new
            {
                AuditId = result.Id,
                LocationType = "Store"
            });
            return RedirectToPage("Edit", new { id = result.Id });
        }

        ModelState.AddModelError("", "Denetim olusturulamadi.");
        return Page();
    }

    public class AuditInput
    {
        public string LocationName { get; set; } = "";
        public DateTime AuditDate { get; set; }
        public DateTime ReportDate { get; set; }
        public string? Manager { get; set; }
        public string? Directorate { get; set; }
    }

    private sealed record InsertResult { public int Id { get; init; } }
}
