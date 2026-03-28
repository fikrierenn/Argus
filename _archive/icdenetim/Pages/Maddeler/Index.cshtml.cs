using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Maddeler;

/// <summary>
/// Denetim maddeleri listesi - master madde listesini gösterir.
/// </summary>
public class IndexModel : PageModel
{
    private readonly IConfiguration _config;

    public IndexModel(IConfiguration config) => _config = config;

    public List<AuditItem> Items { get; set; } = [];

    public async Task OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        Items = (await conn.QueryAsync<AuditItem>(
            @"SELECT Id, LocationType, AuditGroup, Area, RiskType, ItemText, SortOrder, FindingType, Probability, Impact, CreatedAt
              FROM AuditItems ORDER BY LocationType, AuditGroup, SortOrder")).ToList();
    }
}
