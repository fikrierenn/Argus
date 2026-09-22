using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using Microsoft.Data.SqlClient;
using System.Security.Claims;

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
    public bool Kirpildi => GercekToplam > Audits.Count;

    /// <summary>
    /// Suzgece uyan GERCEK kayit sayisi — SP artik `COUNT(*) OVER()` ile
    /// donduruyor (plan 06 S7). Onceden bilinmiyordu; ekran sayfa satir
    /// sayisini toplam sanip gosteriyordu. Olculdu: risk tarafinda ayni kusur
    /// 50 satiri 32.980'in yerine koyuyordu.
    /// </summary>
    public int GercekToplam { get; private set; }

    public async Task OnGetAsync()
    {
        // BITIS TARIHI: gun sonuna cekme isi artik SP'ye ait (sql/81).
        //
        // OLCULDU (sql-sp-reviewer, 2026-08-27): burada da gun sonu
        // uygulaniyordu ve IKI KEZ uygulanmis oluyordu. Dapper
        // `...23:59:59.9999999` gonderiyor, SP parametresi datetime2(0) ve
        // hassasiyet daraltmasi YUVARLIYOR -> ertesi gun 00:00:00; SP onun
        // uzerine kendi gun-sonunu koyunca ust sinir ERTESI GUN 23:59:59
        // oluyordu. Yani "bitis = 25.08" suzgeci 26.08 denetimlerini de
        // gosteriyordu — az once duzelttigimiz hatanin ters yonu.
        //
        // Tek sahip SP; C# yalniz TARIHI gecer.
        var bitis = EndDate?.Date;

        Audits = await _db.QueryAsync<AuditRow>("audit.sp_Audit_List", new
        {
            LocationName = Search,
            StartDate = StartDate?.Date,
            EndDate = bitis,
            IsFinalized,
            Top = Limit
        });

        // Gercek toplam her satirda ayni deger (pencere fonksiyonu); bos kumede 0.
        GercekToplam = Audits.Count > 0 ? Audits[0].TotalCount : 0;
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
            // Kapsam kapisi ve DENETIM IZI artik SP'de (sql/79): kimlik + rol
            // gecirilir, karar ve kayit SQL'de olur.
            //
            // BURADA ESKIDEN IKINCI BIR IZ YAZIMI VARDI ve olculdu (2026-08-26):
            // ayni silme icin AuditLog'a IKI satir dusuyordu — Id 9 (SP, tam
            // detay: mekan/tarih/rapor no/silinen madde+fotograf/rol) ve Id 10
            // (C#, bos). Mukerrer iz, izin kendisine olan guveni bozar: "kac
            // kez silindi" sorusunun cevabi yanlis cikar. Tek yazan SP.
            await _db.ExecuteAsync("audit.sp_Audit_Delete", new
            {
                AuditId = id,
                KullaniciId = KullaniciId(),
                RolKodu = User.FindFirstValue(ClaimTypes.Role)
            });

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

    /// <summary>Oturumdaki kullanici kimligi; yoksa null (iz sistem eylemi sayar).</summary>
    private int? KullaniciId() =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var uid) ? uid : null;

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

        /// <summary>Suzgece uyan toplam kayit (SP: COUNT(*) OVER()).</summary>
        public int TotalCount { get; init; }
    }
}
