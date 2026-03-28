using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using BkmArgus.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Denetimler;

/// <summary>
/// Denetim düzenleme - madde sonuçlarını EVET/HAYIR olarak işaretler.
/// Kesinleştirme sonrası rapor sayfasına yönlendirilir.
/// </summary>
public class EditModel : PageModel
{
    private readonly IConfiguration _config;
    private readonly IAuditProcessingService _processing;

    public EditModel(IConfiguration config, IAuditProcessingService processing)
    {
        _config = config;
        _processing = processing;
    }

    [BindProperty(SupportsGet = true)]
    public int Id { get; set; }

    public int AuditId => Id;
    public Audit? Audit { get; set; }
    public IEnumerable<IGrouping<string, AuditResult>> ResultsByGroup { get; set; } = [];

    public async Task<IActionResult> OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        Audit = await conn.QuerySingleOrDefaultAsync<Audit>(
            "SELECT Id, LocationName, LocationType, AuditDate, ReportDate, ReportNo, AuditorId, Manager, Directorate, CreatedAt, IsFinalized, FinalizedAt FROM Audits WHERE Id = @Id",
            new { Id });
        if (Audit == null) return NotFound();

        // Kesinleşmiş denetim - doğrudan rapora yönlendir
        if (Audit.IsFinalized)
            return RedirectToPage("/Raporlar/KarneDetay", new { id = Id });

        var results = await conn.QueryAsync<AuditResult>(
            @"SELECT Id, AuditId, AuditItemId, AuditGroup, Area, RiskType, ItemText, SortOrder, IsPassed, FindingType, Probability, Impact, RiskScore, RiskLevel, Remark
              FROM AuditResults WHERE AuditId = @Id ORDER BY AuditGroup, SortOrder",
            new { Id });
        ResultsByGroup = results.GroupBy(r => r.AuditGroup);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var audit = await conn.QuerySingleOrDefaultAsync<Audit>(
            "SELECT Id, IsFinalized FROM Audits WHERE Id = @Id", new { Id });
        if (audit == null || audit.IsFinalized) return NotFound();

        foreach (var key in Request.Form.Keys.Where(k => k.StartsWith("result_")))
        {
            var idStr = key.Replace("result_", "");
            if (!int.TryParse(idStr, out var resultId)) continue;
            var value = Request.Form[key].FirstOrDefault();
            var isPassed = value == "true";

            await conn.ExecuteAsync(
                "UPDATE AuditResults SET IsPassed = @IsPassed WHERE Id = @Id AND AuditId = @AuditId",
                new { Id = resultId, AuditId = Id, IsPassed = isPassed });
        }
        return RedirectToPage("Edit", new { id = Id });
    }

    /// <summary>
    /// Denetimi kesinleştirir - sonrasında rapor ve grafikler otomatik oluşur.
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

        // Kesinleştirme sonrası otomatik olarak rapor sayfasına yönlendir
        return RedirectToPage("/Raporlar/KarneDetay", new { id = Id });
    }
}
