using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Raporlar;

/// <summary>
/// Karne raporları listesi - denetim seçimi.
/// </summary>
public class KarneModel : PageModel
{
    private readonly IConfiguration _config;

    public KarneModel(IConfiguration config) => _config = config;

    public List<Audit> Audits { get; set; } = [];

    public async Task OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        Audits = (await conn.QueryAsync<Audit>(
            "SELECT Id, LocationName, LocationType, AuditDate, ReportDate, ReportNo, AuditorId, Manager, Directorate, CreatedAt, IsFinalized, FinalizedAt FROM Audits ORDER BY AuditDate DESC")).ToList();
    }
}
