using System.ComponentModel.DataAnnotations;
using Dapper;
using BkmArgus.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Maddeler;

/// <summary>
/// Yeni denetim maddesi ekler.
/// </summary>
public class CreateModel : PageModel
{
    private readonly IConfiguration _config;

    public CreateModel(IConfiguration config) => _config = config;

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

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            @"INSERT INTO AuditItems (LocationType, AuditGroup, Area, RiskType, ItemText, SortOrder, FindingType, Probability, Impact, CreatedAt)
              VALUES (@LocationType, @AuditGroup, @Area, @RiskType, @ItemText, @SortOrder, @FindingType, @Probability, @Impact, GETDATE())",
            new
            {
                Input.LocationType,
                Input.AuditGroup,
                Input.Area,
                Input.RiskType,
                Input.ItemText,
                Input.SortOrder,
                Input.FindingType,
                Input.Probability,
                Input.Impact
            });
        return RedirectToPage("Index");
    }
}
