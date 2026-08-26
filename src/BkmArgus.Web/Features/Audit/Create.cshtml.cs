using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using Microsoft.Data.SqlClient;
using System.Security.Claims;

namespace BkmArgus.Web.Features.Audit;

public class CreateModel : PageModel
{
    private readonly SqlDb _db;
    private readonly ILogger<CreateModel> _logger;

    public CreateModel(SqlDb db, ILogger<CreateModel> logger)
    {
        _db = db;
        _logger = logger;
    }

    [BindProperty] public AuditInput Input { get; set; } = new();

    public void OnGet()
    {
        Input.AuditDate = DateTime.Today;
        Input.ReportDate = DateTime.Today;
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        // KIRIK OLDUGU OLCULDU (2026-08-26): burada dokuz ozellik
        // gonderiliyordu — LocationId, AuditorUserId, CreatedByUserId — ama
        // canli SP YEDI farkli ad bekliyor (@LocationName, @LocationType,
        // @AuditDate, @ReportDate, @AuditorId, @Manager, @Directorate).
        // Dapper stored procedure cagrisinda verdigi her ozelligi parametre
        // olarak GONDERIR, dolayisiyla SQL Server hata 8144 doneriyordu:
        // "sp_Audit_Insert yordami veya islevi icin cok fazla bagimsiz
        // degisken belirtilmis". Yani "Yeni denetim" TAMAMEN CALISMIYORDU.
        // Kanit: ayni parametre kumesiyle EXEC -> 8144 (transaction'li,
        // rollback'li kuru kosum).
        //
        // Ayrica AuditorId ELLE 1 yaziliyordu: denetim kimin adina
        // olusturuldugu kaybediliyordu ve silme kapsam kapisi (plan 06 Faz 2)
        // bu alana dayaniyor.
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var kullaniciId))
        {
            // Fail-closed: kimlik yoksa baskasinin adina kayit acilmaz.
            _logger.LogWarning("Denetim olusturulamadi: oturumda kullanici kimligi yok.");
            ModelState.AddModelError("", "Oturum bilgisi okunamadi. Yeniden giris yapin.");
            return Page();
        }

        try
        {
            var result = await _db.QuerySingleAsync<InsertResult>("audit.sp_Audit_Insert", new
            {
                Input.LocationName,
                LocationType = "Store",
                Input.AuditDate,
                Input.ReportDate,
                AuditorId = kullaniciId,
                Input.Manager,
                Input.Directorate
            });

            if (result?.Id > 0)
            {
                // Maddeler sonuclara kopyalanir (denetim iskeleti)
                await _db.ExecuteAsync("audit.sp_Result_StartAudit", new
                {
                    AuditId = result.Id,
                    LocationType = "Store"
                });
                return RedirectToPage("Edit", new { id = result.Id });
            }

            ModelState.AddModelError("", "Denetim olusturulamadi.");
            return Page();
        }
        catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
        {
            // Is kurali hatasi — SP Turkce yazdi.
            ModelState.AddModelError("", sqlEx.Message);
            return Page();
        }
        catch (SqlException sqlEx)
        {
            _logger.LogError(sqlEx, "Denetim olusturma SQL hatasi. Mekan={Mekan}", Input.LocationName);
            ModelState.AddModelError("", "Denetim olusturulamadi: veritabani hatasi.");
            return Page();
        }
    }

    public class AuditInput
    {
        public string LocationName { get; set; } = "";
        public DateTime AuditDate { get; set; }
        public DateTime ReportDate { get; set; }
        public string? Manager { get; set; }
        public string? Directorate { get; set; }
    }

    private sealed record InsertResult { public int Id { get; init; } }
}
