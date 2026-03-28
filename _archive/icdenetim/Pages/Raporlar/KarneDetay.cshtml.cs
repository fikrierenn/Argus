using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Raporlar;

/// <summary>
/// Denetim karne detayı - puan özeti ve grafikler.
/// Kesinleştirme sonrası otomatik bu sayfaya yönlendirilir.
/// </summary>
public class KarneDetayModel : PageModel
{
    private readonly IConfiguration _config;

    public KarneDetayModel(IConfiguration config) => _config = config;

    [BindProperty(SupportsGet = true)]
    public int Id { get; set; }

    public Audit? Audit { get; set; }
    public int ToplamMadde { get; set; }
    public int EvetSayisi { get; set; }
    public int HayirSayisi { get; set; }
    public decimal Puan { get; set; }
    /// <summary>Grup bazlı puan özeti - bar grafik için.</summary>
    public List<GrupOzetDto> GrupOzetleri { get; set; } = [];

    public async Task<IActionResult> OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        Audit = await conn.QuerySingleOrDefaultAsync<Audit>(
            "SELECT Id, LocationName, LocationType, AuditDate, ReportDate, ReportNo, AuditorId, Manager, Directorate, CreatedAt, IsFinalized, FinalizedAt FROM Audits WHERE Id = @Id",
            new { Id });
        if (Audit == null) return NotFound();

        var stats = await conn.QuerySingleAsync<(int Toplam, int Evet, int Hayir)>(
            @"SELECT COUNT(*), ISNULL(SUM(CASE WHEN IsPassed=1 THEN 1 ELSE 0 END),0), ISNULL(SUM(CASE WHEN IsPassed=0 THEN 1 ELSE 0 END),0)
              FROM AuditResults WHERE AuditId = @Id",
            new { Id });
        ToplamMadde = stats.Toplam;
        EvetSayisi = stats.Evet;
        HayirSayisi = stats.Hayir;
        Puan = ToplamMadde > 0 ? (decimal)EvetSayisi * 100 / ToplamMadde : 0;

        // Grup bazlı özet - grafik için
        GrupOzetleri = (await conn.QueryAsync<GrupOzetDto>(
            @"SELECT AuditGroup AS GrupAdi, COUNT(*) AS Toplam,
              SUM(CASE WHEN IsPassed=1 THEN 1 ELSE 0 END) AS Evet,
              CAST(SUM(CASE WHEN IsPassed=1 THEN 1.0 ELSE 0 END) * 100 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS Puan
              FROM AuditResults WHERE AuditId = @Id GROUP BY AuditGroup ORDER BY AuditGroup",
            new { Id })).ToList();

        return Page();
    }

    public record GrupOzetDto(string GrupAdi, int Toplam, int Evet, decimal Puan);
}
