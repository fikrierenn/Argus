using System.Security.Claims;
using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Denetimler;

/// <summary>
/// Denetim silme - onay sonrası kalıcı olarak siler.
/// AuditResults ve AuditResultPhotos CASCADE ile otomatik silinir.
/// </summary>
public class DeleteModel : PageModel
{
    private readonly IConfiguration _config;

    public DeleteModel(IConfiguration config) => _config = config;

    [BindProperty(SupportsGet = true)]
    public int Id { get; set; }

    public Audit? Audit { get; set; }

    private int GetCurrentUserId() =>
        int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public async Task<IActionResult> OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        Audit = await conn.QuerySingleOrDefaultAsync<Audit>(
            "SELECT Id, LocationName, LocationType, AuditDate, ReportDate, ReportNo, AuditorId FROM Audits WHERE Id = @Id",
            new { Id });

        if (Audit == null) return NotFound();
        if (Audit.AuditorId != GetCurrentUserId()) return Forbid();

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);

        var auditorId = await conn.ExecuteScalarAsync<int?>(
            "SELECT AuditorId FROM Audits WHERE Id = @Id", new { Id });
        if (auditorId == null) return NotFound();
        if (auditorId != GetCurrentUserId()) return Forbid();

        await conn.ExecuteAsync("DELETE FROM Audits WHERE Id = @Id", new { Id });
        return RedirectToPage("Index");
    }
}
