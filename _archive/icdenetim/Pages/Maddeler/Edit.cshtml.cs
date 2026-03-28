using System.ComponentModel.DataAnnotations;
using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Maddeler;

/// <summary>
/// Denetim maddesi düzenleme.
/// </summary>
public class EditModel : PageModel
{
    private readonly IConfiguration _config;

    public EditModel(IConfiguration config) => _config = config;

    [BindProperty(SupportsGet = true)]
    public int Id { get; set; }

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        public string LocationType { get; set; } = "Mağaza";
        public string AuditGroup { get; set; } = string.Empty;
        [Required] public string Area { get; set; } = string.Empty;
        public string RiskType { get; set; } = string.Empty;
        [Required] public string ItemText { get; set; } = string.Empty;
        public int SortOrder { get; set; }
        public int Probability { get; set; } = 1;
        public int Impact { get; set; } = 1;
        public string? FindingType { get; set; }
    }

    public async Task<IActionResult> OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var item = await conn.QuerySingleOrDefaultAsync<AuditItem>(
            "SELECT Id, AuditGroup, Area, RiskType, ItemText, SortOrder, FindingType, Probability, Impact FROM AuditItems WHERE Id = @Id",
            new { Id });
        if (item == null) return NotFound();

        Input = new InputModel
        {
            AuditGroup = item.AuditGroup,
            Area = item.Area,
            RiskType = item.RiskType,
            ItemText = item.ItemText,
            SortOrder = item.SortOrder,
            Probability = item.Probability,
            Impact = item.Impact,
            FindingType = item.FindingType
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            @"UPDATE AuditItems SET LocationType=@LocationType, AuditGroup=@AuditGroup, Area=@Area, RiskType=@RiskType, ItemText=@ItemText,
              SortOrder=@SortOrder, FindingType=@FindingType, Probability=@Probability, Impact=@Impact
              WHERE Id=@Id",
            new { Id, LocationType = "Mağaza", Input.AuditGroup, Input.Area, Input.RiskType, Input.ItemText, Input.SortOrder, Input.FindingType, Input.Probability, Input.Impact });
        return RedirectToPage("Index");
    }
}
