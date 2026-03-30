using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Audit;

public class ItemsModel : PageModel
{
    private readonly SqlDb _db;
    public ItemsModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)] public string? Group { get; set; }
    [BindProperty] public ItemInput Input { get; set; } = new();
    [BindProperty(SupportsGet = true)] public int? EditId { get; set; }

    public IReadOnlyList<ItemRow> Items { get; private set; } = Array.Empty<ItemRow>();
    public IReadOnlyList<string> Groups { get; private set; } = Array.Empty<string>();

    public async Task OnGetAsync()
    {
        await LoadAsync();
        if (EditId.HasValue)
        {
            var item = await _db.QuerySingleAsync<ItemRow>("audit.sp_Item_Get", new { ItemId = EditId.Value });
            if (item != null)
            {
                Input = new ItemInput
                {
                    AuditGroup = item.AuditGroup,
                    Area = item.Area,
                    RiskType = item.RiskType,
                    ItemText = item.ItemText,
                    SortOrder = item.SortOrder,
                    FindingType = item.FindingType,
                    Probability = item.Probability,
                    Impact = item.Impact
                };
            }
        }
    }

    public async Task<IActionResult> OnPostCreateAsync()
    {
        await _db.ExecuteAsync("audit.sp_Item_Insert", new
        {
            LocationType = "Store",
            Input.AuditGroup,
            Input.Area,
            Input.RiskType,
            Input.ItemText,
            Input.SortOrder,
            Input.FindingType,
            Input.Probability,
            Input.Impact,
            SkillId = (int?)null
        });
        TempData["StatusMessage"] = "Madde eklendi.";
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostUpdateAsync(int itemId)
    {
        await _db.ExecuteAsync("audit.sp_Item_Update", new
        {
            ItemId = itemId,
            LocationType = "Store",
            Input.AuditGroup,
            Input.Area,
            Input.RiskType,
            Input.ItemText,
            Input.SortOrder,
            Input.FindingType,
            Input.Probability,
            Input.Impact,
            SkillId = (int?)null
        });
        TempData["StatusMessage"] = "Madde guncellendi.";
        return RedirectToPage();
    }

    private async Task LoadAsync()
    {
        Items = await _db.QueryAsync<ItemRow>("audit.sp_Item_List", new
        {
            LocationType = (string?)null,
            AuditGroup = Group
        });
        Groups = Items.Select(i => i.AuditGroup ?? "").Where(g => g != "").Distinct().OrderBy(g => g).ToList();
    }

    public class ItemInput
    {
        public string? AuditGroup { get; set; }
        public string? Area { get; set; }
        public string? RiskType { get; set; }
        public string? ItemText { get; set; }
        public int SortOrder { get; set; } = 1;
        public string? FindingType { get; set; }
        public int Probability { get; set; } = 3;
        public int Impact { get; set; } = 3;
    }

    public sealed record ItemRow
    {
        public int Id { get; init; }
        public string? LocationType { get; init; }
        public string? AuditGroup { get; init; }
        public string? Area { get; init; }
        public string? RiskType { get; init; }
        public string ItemText { get; init; } = "";
        public int SortOrder { get; init; }
        public string? FindingType { get; init; }
        public int Probability { get; init; }
        public int Impact { get; init; }
        public int RiskScore { get; init; }
        public DateTime? CreatedAt { get; init; }
    }
}
