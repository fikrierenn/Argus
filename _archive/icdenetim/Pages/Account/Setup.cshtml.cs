using Dapper;
using BkmArgus.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Pages.Account;

/// <summary>
/// Veritabanı kurulum sayfası - Schema.sql çalıştırır, admin kullanıcısı oluşturur.
/// </summary>
public class SetupModel : PageModel
{
    private readonly IConfiguration _config;

    public SetupModel(IConfiguration config) => _config = config;

    public bool Success { get; set; }
    public string? Error { get; set; }
    public int ExcelSeedCount { get; set; }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync()
    {
        try
        {
            await DbSetup.RunSchemaAsync(_config);
            await DbInitializer.SeedAsync(_config);

            // Excel'den denetim maddelerini seed et (denetim.xlsx proje kök dizininde olmalı)
            try
            {
                using var conn = DbConnectionFactory.Create(_config);
                var itemCount = await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM AuditItems");
                if (itemCount == 0)
                    ExcelSeedCount = await ExcelSeed.SeedAuditItemsFromExcelAsync(_config);
            }
            catch (FileNotFoundException)
            {
                // denetim.xlsx yok - atla, manuel import yapılabilir
            }

            Success = true;
        }
        catch (SqlException ex)
        {
            Error = $"Veritabanı hatası: {ex.Message}";
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }

        return Page();
    }
}
