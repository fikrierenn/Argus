using BkmArgus.Web.Data;
using BkmArgus.Web.Domain;
using BkmArgus.Web.Services;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class RiskModel : PageModel
{
    private readonly SqlDb _db;
    private readonly ExcelExportService _export;
    private readonly ILogger<RiskModel> _logger;
    private readonly AuditTrail _iz;

    private static readonly IReadOnlyList<string> TipList = new[]
    {
        "GIRISSIZSATIS",
        "STOKYOK",
        "NETBIRIKIM",
        "IADEYUKSEK",
        "SAYIMDUZELTME",
        "HIZLIDEVIR"
    };

    public IReadOnlyList<OptionItem> MekanOptions { get; private set; } = Array.Empty<OptionItem>();
    public IReadOnlyList<string> TipOptions => TipList;

    public IReadOnlyList<RiskRow> Rows { get; private set; } = Array.Empty<RiskRow>();
    public IReadOnlyList<string> SelectedMekan { get; private set; } = Array.Empty<string>();
    public IReadOnlyList<string> SelectedTip { get; private set; } = Array.Empty<string>();
    public string? Search { get; private set; }
    public int? MinSkor { get; private set; }
    public int? MaxSkor { get; private set; }
    public DateTime? KesimBas { get; private set; }
    public DateTime? KesimBit { get; private set; }
    public string OrderBy { get; private set; } = "SKOR";
    public string OrderDir { get; private set; } = "DESC";
    public int PageIndex { get; private set; } = 1;
    public int PageSize { get; private set; } = 50;

    public IReadOnlyList<OptionItem> OrderOptions { get; } = new[]
    {
        new OptionItem("SKOR", "Skor"),
        new OptionItem("MEKAN", "Mekan"),
        new OptionItem("URUN", "Urun"),
        new OptionItem("STOK", "Stok"),
        new OptionItem("SONHAREKET", "Son hareket")
    };
    public IReadOnlyList<int> PageSizeOptions { get; } = new[] { 20, 50, 100, 200 };

    public bool HasPrevPage => PageIndex > 1;
    public bool HasNextPage => Rows.Count == PageSize;

    /// <summary>
    /// `rpt.sp_RiskList` icindeki sert sayfa siniri (`IF @PageSize > 200 SET
    /// @PageSize = 200`). Disa aktarim bu yuzden tek cagrida en fazla 200 satir
    /// alabiliyordu — 5000 istemek hicbir sey degistirmiyordu.
    /// </summary>
    private const int SpSayfaSiniri = 200;

    /// <summary>Disa aktarimin sert ust siniri — asilirsa dosya adinda GORUNUR.</summary>
    private const int DisaAktarimUstSinir = 5000;

    /// <summary>
    /// Bos sayfa mi (veri bitti) yoksa gercekten kayit yok mu. Ikisi ayni
    /// mesaji gorurse kullanici suzgecini suclar; oysa veri bitmistir
    /// (denetim bulgusu 3.4).
    /// </summary>
    public bool SayfaBos => Rows.Count == 0 && PageIndex > 1;

    /// <summary>
    /// Secenek listesinde KARSILIGI OLMAYAN suzgec degerleri. Bunlar SP'ye
    /// gonderilmeye devam eder (sonuc degistirilmez) ama artik GORUNUR:
    /// eskiden onay kutusu isaretlenmedigi icin aktif ama gorunmez bir suzgec
    /// olusuyor ve kullanici "hic veri yok" sonucuna variyordu (bulgu 1.3).
    /// Erisilebilir yol: Korelasyon ekranindan /Risk?mekan={id} tiklamasi.
    /// </summary>
    public IReadOnlyList<string> TaninmayanSuzgecler { get; private set; } = Array.Empty<string>();

    public RiskModel(SqlDb db, ExcelExportService export, ILogger<RiskModel> logger, AuditTrail iz)
    {
        _db = db;
        _export = export;
        _logger = logger;
        _iz = iz;
    }

    public async Task OnGetAsync(
        string? search,
        int? minSkor,
        int? maxSkor,
        DateTime? kesimBas,
        DateTime? kesimBit,
        string[] mekan,
        string[] tip,
        string? orderBy,
        string? orderDir,
        int? sayfa,
        int? pageSize)
    {
        Search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        MinSkor = minSkor;
        MaxSkor = maxSkor;
        KesimBas = kesimBas?.Date;
        KesimBit = kesimBit?.Date;
        SelectedMekan = mekan ?? Array.Empty<string>();
        SelectedTip = tip ?? Array.Empty<string>();
        OrderBy = NormalizeOrderBy(orderBy);
        OrderDir = NormalizeOrderDir(orderDir);
        PageIndex = sayfa.GetValueOrDefault(1);
        if (PageIndex < 1)
        {
            PageIndex = 1;
        }

        PageSize = NormalizePageSize(pageSize);

        var mekanRows = await _db.QueryAsync<MekanRow>("rpt.sp_RiskByLocation_List");
        MekanOptions = mekanRows
            .Select(row => new OptionItem(
                row.MekanId.ToString(),
                string.IsNullOrWhiteSpace(row.MekanAd) ? $"Mekan-{row.MekanId}" : row.MekanAd))
            .ToList();

        TaninmayanSuzgecler = TaninmayanlariBul();

        var mekanCsv = SelectedMekan.Count > 0 ? string.Join(",", SelectedMekan) : null;
        var tipCsv = SelectedTip.Count > 0 ? string.Join(",", SelectedTip) : null;

        var data = await _db.QueryAsync<RiskRowRaw>(
            "rpt.sp_RiskList",
            new
            {
                Top = 500,
                Search,
                MinSkor,
                MaxSkor,
                KesimBas,
                KesimBit,
                MekanCSV = mekanCsv,
                TipCSV = tipCsv,
                OrderBy,
                OrderDir,
                Page = PageIndex,
                PageSize
            });

        Rows = data.Select(row => new RiskRow(
            row.StokId,
            row.MekanId,
            string.IsNullOrWhiteSpace(row.MekanAd) ? $"Mekan-{row.MekanId}" : row.MekanAd,
            string.IsNullOrWhiteSpace(row.UrunAd) ? $"Urun-{row.StokId}" : row.UrunAd,
            string.IsNullOrWhiteSpace(row.UrunKod) ? $"BK-{row.StokId}" : row.UrunKod,
            row.DonemKodu,
            row.RiskSkor,
            row.StokMiktar,
            row.SonHareketGun ?? 0,
            BuildFlags(row)))
            .ToList();
    }

    public async Task<IActionResult> OnGetExportAsync(
        string? search,
        int? minSkor,
        int? maxSkor,
        DateTime? kesimBas,
        DateTime? kesimBit,
        string[]? mekan,
        string[]? tip,
        string? orderBy,
        string? orderDir)
    {
        var mekanCsv = mekan is { Length: > 0 } ? string.Join(",", mekan) : null;
        var tipCsv = tip is { Length: > 0 } ? string.Join(",", tip) : null;

        // KRITIK BULGU (2026-08-26): burada `Top = 5000, PageSize = 5000`
        // yaziliydi ve SESSIZCE 200 satir donuyordu. Sebep SP'de:
        //   SET @PageSize = COALESCE(@PageSize, @Top, 50);   -- 5000
        //   IF @PageSize > 200 SET @PageSize = 200;          -- kirpiliyor
        // @Top da inert: COALESCE @PageSize dolu oldugu icin ona hic bakmiyor.
        // Sonuc: denetci 3.400 satirlik suzgecle "Excel indir"e basiyor, 200
        // satirlik dosya aliyor ve bunu TAM liste sanip rapor yaziyordu.
        // Cozum: SP'yi degistirmeden sayfa dongusu (SP tarafi plan 06 Faz 5).
        var tumSatirlar = new List<RiskRowRaw>();
        var sayfa = 1;
        var kirpildi = false;

        while (true)
        {
            var dilim = await _db.QueryAsync<RiskRowRaw>(
                "rpt.sp_RiskList",
                new
                {
                    Top = SpSayfaSiniri,
                    Search = string.IsNullOrWhiteSpace(search) ? null : search.Trim(),
                    MinSkor = minSkor,
                    MaxSkor = maxSkor,
                    KesimBas = kesimBas?.Date,
                    KesimBit = kesimBit?.Date,
                    MekanCSV = mekanCsv,
                    TipCSV = tipCsv,
                    OrderBy = NormalizeOrderBy(orderBy),
                    OrderDir = NormalizeOrderDir(orderDir),
                    Page = sayfa,
                    PageSize = SpSayfaSiniri
                });

            tumSatirlar.AddRange(dilim);

            // Son sayfa: SP sinirindan az satir dondu.
            if (dilim.Count < SpSayfaSiniri)
            {
                break;
            }

            // Ust sinir: sonsuz donguye karsi. Asilirsa SESSIZ KALMAZ —
            // hem loglanir hem DOSYA ADINDA gorunur.
            if (tumSatirlar.Count >= DisaAktarimUstSinir)
            {
                kirpildi = true;
                _logger.LogWarning(
                    "Risk disa aktarimi ust sinira dayandi: {Satir} satir, suzgec search={Search} mekan={Mekan} tip={Tip}",
                    tumSatirlar.Count, search, mekanCsv, tipCsv);
                break;
            }

            sayfa++;
        }

        var data = tumSatirlar;

        var bytes = _export.Export(data, "Risk Listesi", new Dictionary<string, Func<RiskRowRaw, object?>>
        {
            ["Mekan"] = r => r.MekanAd,
            ["Urun Kodu"] = r => r.UrunKod,
            ["Urun Adi"] = r => r.UrunAd,
            ["Donem"] = r => r.DonemKodu,
            ["Risk Skoru"] = r => r.RiskSkor,
            ["Stok"] = r => r.StokMiktar,
            ["Son Hareket (Gun)"] = r => r.SonHareketGun
        });

        // Kirpma DOSYA ADINDA gorunur: tarayici indirmesinde toast gosterilemez,
        // kullanici indirdigi seyin tam olmadigini dosyaya bakarak anlar.
        var ad = kirpildi
            ? $"risk_listesi_{DateTime.Today:yyyyMMdd}_ILK{data.Count}_KIRPILDI.xlsx"
            : $"risk_listesi_{DateTime.Today:yyyyMMdd}_{data.Count}satir.xlsx";

        _logger.LogInformation("Risk disa aktarimi: {Satir} satir, kirpildi={Kirpildi}", data.Count, kirpildi);

        // Denetim izi: veri kurumsal sinirin DISINA cikiyor (5000 satira kadar
        // risk verisi). Guvenlik denetimi bunu izsiz buldu (2026-08-26).
        // @KayitId = 0 — tek kayda bagli degil (SP sozlesmesi).
        await _iz.YazAsync(AuditAction.DisaAktarim, "rpt.DailyProductRisk",
            int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var izUid) ? izUid : null,
            0,
            yeniDeger: $"Excel · {data.Count} satir · kirpildi={kirpildi} · " +
                       $"suzgec: arama={search ?? "—"} mekan={mekanCsv ?? "—"} tip={tipCsv ?? "—"} " +
                       $"skor={minSkor?.ToString() ?? "—"}..{maxSkor?.ToString() ?? "—"}");

        return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ad);
    }

    public record RiskRow(
        int Id,
        int MekanId,
        string Mekan,
        string Urun,
        string UrunKod,
        string Donem,
        int Skor,
        decimal StokAdet,
        int SonHareketGun,
        string[] Flags)
    {
        public bool StokVar => StokAdet > 0;
    }

    public record OptionItem(string Value, string Label);

    private static string[] BuildFlags(RiskRowRaw row)
    {
        var flags = new List<string>();
        if (row.FlagGirissizSatis)
        {
            flags.Add("GIRISSIZSATIS");
        }
        if (row.FlagStokYok)
        {
            flags.Add("STOKYOK");
        }
        if (row.FlagNetBirikim)
        {
            flags.Add("NETBIRIKIM");
        }
        if (row.FlagIadeYuksek)
        {
            flags.Add("IADEYUKSEK");
        }
        if (row.FlagSayimDuzeltme)
        {
            flags.Add("SAYIMDUZELTME");
        }
        if (row.FlagHizliDevir)
        {
            flags.Add("HIZLIDEVIR");
        }

        return flags.ToArray();
    }

    public sealed record MekanRow
    {
        public int MekanId { get; init; }
        public string? MekanAd { get; init; }
    }

    public sealed record RiskRowRaw
    {
        public int MekanId { get; init; }
        public string? MekanAd { get; init; }
        public int StokId { get; init; }
        public string? UrunKod { get; init; }
        public string? UrunAd { get; init; }
        public string DonemKodu { get; init; } = string.Empty;
        public int RiskSkor { get; init; }
        public bool FlagGirissizSatis { get; init; }
        public bool FlagStokYok { get; init; }
        public bool FlagNetBirikim { get; init; }
        public bool FlagIadeYuksek { get; init; }
        public bool FlagSayimDuzeltme { get; init; }
        public bool FlagHizliDevir { get; init; }
        public decimal StokMiktar { get; init; }
        public int? SonHareketGun { get; init; }
    }

    /// <summary>
    /// Secenek listesinde bulunmayan suzgec degerlerini toplar. Deger
    /// ATILMAZ — sonucu degistirmek daha buyuk surpriz olurdu; yalnizca
    /// ekranda GORUNUR hale gelir.
    /// </summary>
    private List<string> TaninmayanlariBul()
    {
        var liste = new List<string>();

        foreach (var deger in SelectedMekan)
        {
            if (string.IsNullOrWhiteSpace(deger))
            {
                continue;
            }

            var bulundu = MekanOptions.Any(o =>
                string.Equals(o.Value, deger, StringComparison.OrdinalIgnoreCase));
            if (!bulundu)
            {
                liste.Add($"mekan={deger}");
            }
        }

        foreach (var deger in SelectedTip)
        {
            if (string.IsNullOrWhiteSpace(deger))
            {
                continue;
            }

            var bulundu = TipList.Any(t =>
                string.Equals(t, deger, StringComparison.OrdinalIgnoreCase));
            if (!bulundu)
            {
                liste.Add($"tip={deger}");
            }
        }

        return liste;
    }

    private static string NormalizeOrderBy(string? orderBy)
    {
        if (string.IsNullOrWhiteSpace(orderBy))
        {
            return "SKOR";
        }

        return orderBy.Trim().ToUpperInvariant() switch
        {
            "SKOR" => "SKOR",
            "MEKAN" => "MEKAN",
            "URUN" => "URUN",
            "STOK" => "STOK",
            "SONHAREKET" => "SONHAREKET",
            _ => "SKOR"
        };
    }

    private static string NormalizeOrderDir(string? orderDir)
    {
        if (string.IsNullOrWhiteSpace(orderDir))
        {
            return "DESC";
        }

        return orderDir.Trim().ToUpperInvariant() == "ASC" ? "ASC" : "DESC";
    }

    private int NormalizePageSize(int? pageSize)
    {
        var size = pageSize.GetValueOrDefault(50);
        if (!PageSizeOptions.Contains(size))
        {
            return 50;
        }

        return size;
    }
}
