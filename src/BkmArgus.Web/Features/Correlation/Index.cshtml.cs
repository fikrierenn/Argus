using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features.Correlation;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;
    private readonly ILogger<IndexModel> _logger;

    /// <summary>SP'nin cektigi kayit siniri — asilirsa toplam TOPLAM DEGILDIR.</summary>
    private const int Limit = 100;

    public IndexModel(SqlDb db, ILogger<IndexModel> logger)
    {
        _db = db;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public string? Quadrant { get; set; }

    public IReadOnlyList<CorrelationRow> Items { get; private set; } = Array.Empty<CorrelationRow>();
    public CorrelationSummary Summary { get; private set; } = new();

    /// <summary>Liste sinira dayandi mi — dayandiysa "Toplam" gercek toplam degil.</summary>
    public bool Kirpildi => Items.Count >= Limit;

    /// <summary>Kadran suzgeci aktif mi — aktifse ortalama SUZGECLI ortalamadir.</summary>
    public bool SuzgecAktif => !string.IsNullOrWhiteSpace(Quadrant);

    /// <summary>Bu istek bir "Yeniden hesapla" sonrasi mi (bos sonucu ayirt etmek icin).</summary>
    public bool YenidenHesaplandi { get; private set; }

    public async Task OnGetAsync()
    {
        Items = await _db.QueryAsync<CorrelationRow>(
            "rpt.sp_CrossCorrelation_List",
            new { Quadrant, Top = Limit });

        Summary = new CorrelationSummary
        {
            Total = Items.Count,
            UrgentCount = Items.Count(x => x.Quadrant == "YUKSEK_YUKSEK"),
            AvgCombinedScore = Items.Any()
                ? Math.Round(Items.Average(x => x.CombinedScore), 1)
                : 0
        };

        // Hesaplamadan hemen sonraki istek mi? Bos sonuc bu bilgi olmadan
        // "hic hesaplanmamis" ile ayni gorunuyordu (denetim bulgusu 5.3).
        YenidenHesaplandi = TempData["YenidenHesaplandi"] is not null;

        if (YenidenHesaplandi)
        {
            TempData["StatusMessage"] = Items.Count > 0
                ? $"Hesaplama tamamlandı — {ArgusFormat.Count(Items.Count)} mekan listelendi."
                : "Hesaplama çalıştı ama sonuç üretmedi: bugüne ait ERP snapshot'ı ya da denetim kaydı yok.";
        }
    }

    /// <summary>
    /// Korelasyonu yeniden hesaplar.
    ///
    /// ESKI HALI SESSIZDI (denetim bulgusu 5.3): `ExecuteAsync` cagirip
    /// dogrudan RedirectToPage yapiyordu — ne mesaj, ne try/catch, ne log.
    /// Bos tablonun ipucu "'Yeniden hesapla' dugmesini deneyin" dedigi icin
    /// kullanici dugmeye basiyor, ayni bos tabloyu ve AYNI ipucunu goruyordu:
    /// dugmenin calisip calismadigini ayirt etmesi imkansizdi (sonsuz dongu).
    /// </summary>
    public async Task<IActionResult> OnPostRecalculateAsync()
    {
        try
        {
            await _db.ExecuteAsync("rpt.sp_CrossCorrelation_Calculate");
            TempData["YenidenHesaplandi"] = true;
        }
        catch (Microsoft.Data.SqlClient.SqlException sqlEx)
            when (sqlEx.Number is >= 50000 and < 60000)
        {
            // Is kurali hatasi — SP Turkce yazdi, kullaniciya gosterilebilir.
            TempData["Error"] = sqlEx.Message;
        }
        catch (Microsoft.Data.SqlClient.SqlException sqlEx)
        {
            _logger.LogError(sqlEx, "Korelasyon hesaplamasi basarisiz: {Sp}", "rpt.sp_CrossCorrelation_Calculate");
            TempData["Error"] = "Hesaplama sırasında veritabanı hatası oluştu.";
        }

        return RedirectToPage();
    }

    public sealed record CorrelationRow
    {
        public int Id { get; init; }
        public int LocationId { get; init; }
        public string LocationName { get; init; } = string.Empty;
        public DateTime SnapshotDate { get; init; }
        public decimal ErpRiskScore { get; init; }
        public decimal AuditComplianceRate { get; init; }
        public decimal RepeatFactor { get; init; }
        public decimal CombinedScore { get; init; }
        public string Quadrant { get; init; } = string.Empty;
        public int AuditCount { get; init; }
        public DateTime? LastAuditDate { get; init; }
    }

    public sealed record CorrelationSummary
    {
        public int Total { get; init; }
        public int UrgentCount { get; init; }
        public decimal AvgCombinedScore { get; init; }
    }
}
