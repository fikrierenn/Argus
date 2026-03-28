using BkmArgus.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Maddeler;

/// <summary>
/// Excel'den denetim maddeleri import sayfası.
/// </summary>
public class ImportModel : PageModel
{
    private readonly IConfiguration _config;

    public ImportModel(IConfiguration config) => _config = config;

    public bool Success { get; set; }
    public int ImportCount { get; set; }
    public string? Error { get; set; }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync()
    {
        try
        {
            ImportCount = await ExcelSeed.SeedAuditItemsFromExcelAsync(_config);
            Success = true;
        }
        catch (FileNotFoundException)
        {
            Error = "denetim.xlsx bulunamadı. Dosyayı proje kök dizinine (BkmArgus klasörünün üst dizinine) kopyalayın.";
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }

        return Page();
    }
}
