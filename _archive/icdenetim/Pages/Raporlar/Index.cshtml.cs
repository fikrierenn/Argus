using Dapper;
using BkmArgus.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Raporlar;

/// <summary>
/// Raporlar ana sayfası - özet ve karne raporlarına giriş.
/// </summary>
public class IndexModel : PageModel
{
    private readonly IConfiguration _config;

    public IndexModel(IConfiguration config) => _config = config;

    public DateTime? Baslangic { get; set; }
    public DateTime? Bitis { get; set; }
    public OzetRaporDto? OzetRapor { get; set; }

    public async Task OnGetAsync()
    {
        Baslangic = DateTime.Today.AddMonths(-1);
        Bitis = DateTime.Today;
    }

    public async Task<IActionResult> OnGetOzetAsync(DateTime? baslangic, DateTime? bitis)
    {
        Baslangic = baslangic ?? DateTime.Today.AddMonths(-1);
        Bitis = bitis ?? DateTime.Today;

        using var conn = DbConnectionFactory.Create(_config);
        var toplam = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM Audits WHERE AuditDate >= @Baslangic AND AuditDate <= @Bitis",
            new { Baslangic, Bitis });

        // Basit puan hesaplama: EVET oranı
        var puanlar = await conn.QueryAsync<decimal>(
            @"SELECT CAST(SUM(CASE WHEN r.IsPassed = 1 THEN 1.0 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(10,2))
              FROM AuditResults r
              INNER JOIN Audits a ON r.AuditId = a.Id
              WHERE a.AuditDate >= @Baslangic AND a.AuditDate <= @Bitis",
            new { Baslangic, Bitis });
        var ortalama = puanlar.FirstOrDefault();

        OzetRapor = new OzetRaporDto(toplam, ortalama);
        return Page();
    }

    public record OzetRaporDto(int ToplamDenetim, decimal OrtalamaPuan);
}
