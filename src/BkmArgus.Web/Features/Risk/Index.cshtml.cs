using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class RiskModel : PageModel
{
    private readonly SqlDb _db;

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

    public RiskModel(SqlDb db)
    {
        _db = db;
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
        int? page,
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
        PageIndex = page.GetValueOrDefault(1);
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
