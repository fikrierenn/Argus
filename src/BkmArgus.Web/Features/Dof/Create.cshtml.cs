using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Dof;

public class CreateModel : PageModel
{
    private readonly SqlDb _db;
    public CreateModel(SqlDb db) => _db = db;

    [BindProperty] public DofInput Input { get; set; } = new();

    public void OnGet()
    {
        Input.SlaDueDate = DateTime.Today.AddDays(14);
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");

        var result = await _db.QuerySingleAsync<InsertResult>("dof.sp_Finding_Create", new
        {
            Input.Title,
            Input.Description,
            Input.RiskLevel,
            Input.SlaDueDate,
            Input.SourceKey,
            AssignedToPersonnelId = (long?)null,
            CreatedByUserId = userId
        });

        if (result?.DofId > 0)
            return RedirectToPage("Detail", new { id = result.DofId });

        ModelState.AddModelError("", "DOF olusturulamadi.");
        return Page();
    }

    public class DofInput
    {
        public string Title { get; set; } = "";
        public string? Description { get; set; }
        public int RiskLevel { get; set; } = 3;
        public DateTime SlaDueDate { get; set; }
        public string? SourceKey { get; set; }
    }

    private sealed record InsertResult
    {
        public long DofId { get; init; }
    }
}
