using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using BkmArgus.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Denetimler;

/// <summary>
/// Denetim detay görüntüleme.
/// </summary>
public class DetailModel : PageModel
{
    private readonly IConfiguration _config;
    private readonly IAuditProcessingService _processing;

    public DetailModel(IConfiguration config, IAuditProcessingService processing)
    {
        _config = config;
        _processing = processing;
    }

    [BindProperty(SupportsGet = true)]
    public int Id { get; set; }

    public Audit? Audit { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        Audit = await conn.QuerySingleOrDefaultAsync<Audit>(
            "SELECT Id, LocationName, LocationType, AuditDate, ReportDate, ReportNo, AuditorId, Manager, Directorate, CreatedAt, IsFinalized, FinalizedAt FROM Audits WHERE Id = @Id",
            new { Id });
        return Audit == null ? NotFound() : Page();
    }

    /// <summary>
    /// Denetimi kesinleştirir - pipeline tetiklenir, rapor sayfasına yönlendirir.
    /// </summary>
    public async Task<IActionResult> OnPostFinalizeAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var audit = await conn.QuerySingleOrDefaultAsync<Audit>(
            "SELECT Id, IsFinalized FROM Audits WHERE Id = @Id", new { Id });
        if (audit == null || audit.IsFinalized) return NotFound();

        await conn.ExecuteAsync(
            "UPDATE Audits SET IsFinalized = 1, FinalizedAt = GETDATE() WHERE Id = @Id",
            new { Id });

        // Pipeline: Data Intelligence + Insight Generation
        await _processing.ProcessAuditAsync(Id);

        return RedirectToPage("/Raporlar/KarneDetay", new { id = Id });
    }
}
