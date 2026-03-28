using System.ComponentModel.DataAnnotations;
using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Denetimler;

/// <summary>
/// Yeni denetim oluşturur - temel bilgileri alır, AuditResults snapshot'larını oluşturur.
/// </summary>
public class CreateModel : PageModel
{
    private readonly IConfiguration _config;

    public CreateModel(IConfiguration config) => _config = config;

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required(ErrorMessage = "Lokasyon adı gerekli")]
        public string LocationName { get; set; } = string.Empty;

        public string LocationType { get; set; } = "Mağaza";

        [Required]
        public DateTime AuditDate { get; set; } = DateTime.Today;

        [Required]
        public DateTime ReportDate { get; set; } = DateTime.Today;

        /// <summary>Rapor no otomatik üretilir - formdan alınmaz.</summary>
        public string ReportNo { get; set; } = string.Empty;

        public string? Manager { get; set; }
        public string? Directorate { get; set; }
    }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? throw new UnauthorizedAccessException("Giriş yapılmamış.");

        using var conn = DbConnectionFactory.Create(_config);
        conn.Open();
        using var tx = conn.BeginTransaction();

        try
        {
            // Audit ekle - RaporNo otomatik: RYD-00001, RYD-00002 formatında (Id bazlı)
            var auditId = await conn.ExecuteScalarAsync<int>(
                @"INSERT INTO Audits (LocationName, LocationType, AuditDate, ReportDate, ReportNo, AuditorId, Manager, Directorate, CreatedAt)
                  VALUES (@LocationName, @LocationType, @AuditDate, @ReportDate, 'PLACEHOLDER', @AuditorId, @Manager, @Directorate, GETDATE());
                  DECLARE @id INT = SCOPE_IDENTITY();
                  UPDATE Audits SET ReportNo = 'RYD-' + RIGHT('00000' + CAST(@id AS NVARCHAR(10)), 5) WHERE Id = @id;
                  SELECT @id;",
                new
                {
                    Input.LocationName,
                    Input.LocationType,
                    Input.AuditDate,
                    Input.ReportDate,
                    AuditorId = int.Parse(userId),
                    Input.Manager,
                    Input.Directorate
                }, tx);

            // Mağaza maddelerini snapshot olarak AuditResults'a kopyala (Kafe kaldırıldı)
            var items = (await conn.QueryAsync<AuditItem>(
                @"SELECT Id, AuditGroup, Area, RiskType, ItemText, SortOrder, FindingType, Probability, Impact 
                  FROM AuditItems 
                  WHERE LocationType = N'Mağaza'
                  ORDER BY AuditGroup, SortOrder",
                transaction: tx)).ToList();

            if (items.Count == 0)
            {
                ModelState.AddModelError("", "Denetim maddesi bulunamadı. Önce Denetim Maddeleri sayfasından madde ekleyin.");
                return Page();
            }

            foreach (var item in items)
            {
                var riskScore = item.Probability * item.Impact;
                var riskLevel = riskScore <= 8 ? "Düşük Risk" : riskScore <= 15 ? "Orta Risk" : "Yüksek Risk";

                await conn.ExecuteAsync(
                    @"INSERT INTO AuditResults (AuditId, AuditItemId, AuditGroup, Area, RiskType, ItemText, SortOrder, IsPassed, FindingType, Probability, Impact, RiskScore, RiskLevel, Remark)
                      VALUES (@AuditId, @AuditItemId, @AuditGroup, @Area, @RiskType, @ItemText, @SortOrder, 0, @FindingType, @Probability, @Impact, @RiskScore, @RiskLevel, NULL)",
                    new
                    {
                        AuditId = auditId,
                        AuditItemId = item.Id,
                        item.AuditGroup,
                        item.Area,
                        item.RiskType,
                        item.ItemText,
                        item.SortOrder,
                        item.FindingType,
                        item.Probability,
                        item.Impact,
                        RiskScore = riskScore,
                        RiskLevel = riskLevel
                    }, tx);
            }

            tx.Commit();
            return RedirectToPage("Edit", new { id = auditId });
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }
}
