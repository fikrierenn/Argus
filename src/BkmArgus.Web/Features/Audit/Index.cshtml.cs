using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Web.Features.Audit;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;
    private readonly ILogger<IndexModel> _logger;

    /// <summary>SP'nin cektigi kayit siniri — asilirsa "N kayit" TOPLAM DEGILDIR.</summary>
    public const int Limit = 100;

    public IndexModel(SqlDb db, ILogger<IndexModel> logger)
    {
        _db = db;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)] public string? Search { get; set; }
    // Suzgec TARIH alani: saat kismi anlamsiz. Niyet MODELDE duruyor —
    // gorunumde kind="Date" yazmak her cagri yerinde tekrar demekti (Solum
    // onerisi 2026-08-26). Solum cikarimi [DataType]'i okuyup type="date" uretir.
    [DataType(DataType.Date)]
    [BindProperty(SupportsGet = true)] public DateTime? StartDate { get; set; }
    [DataType(DataType.Date)]
    [BindProperty(SupportsGet = true)] public DateTime? EndDate { get; set; }
    [BindProperty(SupportsGet = true)] public bool? IsFinalized { get; set; }

    public IReadOnlyList<AuditRow> Audits { get; private set; } = Array.Empty<AuditRow>();

    /// <summary>
    /// Liste sinira dayandi mi. Baslik "@Audits.Count kayit" yaziyordu ve
    /// sayfalama YOKTU: 140 denetimlik bir suzgecte kullanici "100 kayit"
    /// goruyor, en eski 40'i hic gormuyordu — hicbir uyari da yoktu
    /// (denetim bulgusu 5.5).
    /// </summary>
    public bool Kirpildi => Audits.Count >= Limit;

    public async Task OnGetAsync()
    {
        // BITIS TARIHI GUN SONUNA cekilir. audit.Audits.AuditDate datetime2(0),
        // yani saat tasiyabilir; type="date" girdisi ise gece yarisini gonderir.
        // SP `AuditDate <= @Bitis` karsilastirdigi icin bugun 09:30'da
        // kaydedilmis denetim "bitis = bugun" suzgecinde DUSUYORDU ve kullanici
        // "bugunun denetimi girilmemis" saniyordu (denetim bulgusu 6.3).
        // Kalici cozum SP tarafinda (plan 06 Faz 5): AuditDate < DATEADD(day,1,...).
        var bitis = EndDate?.Date.AddDays(1).AddTicks(-1);

        Audits = await _db.QueryAsync<AuditRow>("audit.sp_Audit_List", new
        {
            LocationName = Search,
            StartDate = StartDate?.Date,
            EndDate = bitis,
            IsFinalized,
            Top = Limit
        });
    }

    /// <summary>
    /// Denetim siler (yalniz kesinlestirilmemis olan — kural SP'de).
    ///
    /// Eskiden ne try/catch ne log vardi: SP `RAISERROR('Finalize edilmis
    /// denetim silinemez', 16, 1)` attiginda kullanici Turkce is kurali mesajini
    /// degil GELISTIRICI HATA SAYFASINI goruyordu (denetim bulgusu / IMP-3).
    ///
    /// EKSIK KALAN (plan 06 Faz 2): kullanici-kapsam kontrolu ve
    /// `audit.AuditLog` kaydi SP tarafinda. Bu metot o kapiyi UYDURMUYOR.
    /// </summary>
    public async Task<IActionResult> OnPostDeleteAsync(int id)
    {
        try
        {
            await _db.ExecuteAsync("audit.sp_Audit_Delete", new { AuditId = id });
            TempData["StatusMessage"] = "Denetim silindi.";
        }
        catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
        {
            // Is kurali hatasi — SP Turkce yazdi, kullaniciya gosterilebilir.
            TempData["Error"] = sqlEx.Message;
        }
        catch (SqlException sqlEx)
        {
            _logger.LogError(sqlEx, "Denetim silme basarisiz. DenetimId={Id}", id);
            TempData["Error"] = "Denetim silinemedi: veritabanı hatası.";
        }

        return RedirectToPage();
    }

    public sealed record AuditRow
    {
        public int Id { get; init; }
        public string LocationName { get; init; } = "";
        public string? LocationType { get; init; }
        public DateTime AuditDate { get; init; }
        public DateTime? ReportDate { get; init; }
        public string? ReportNo { get; init; }
        public bool IsFinalized { get; init; }
        public DateTime? FinalizedAt { get; init; }
        public int TotalItems { get; init; }
        public int PassedItems { get; init; }
        public int FailedItems { get; init; }
    }
}
