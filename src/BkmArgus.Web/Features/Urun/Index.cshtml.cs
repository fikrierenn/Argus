using System.Globalization;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class UrunModel : PageModel
{
    private static readonly CultureInfo TrCulture = CultureInfo.GetCultureInfo("tr-TR");
    private readonly SqlDb _db;

    public int UrunId { get; private set; }
    public int? MekanId { get; private set; }
    public string UrunKod { get; private set; } = string.Empty;
    public string UrunAd { get; private set; } = string.Empty;
    public string Kategori3 { get; private set; } = "-";
    public string Mekan { get; private set; } = string.Empty;
    public string Donem { get; private set; } = string.Empty;
    public int Skor { get; private set; }
    public string SkorSeviye { get; private set; } = string.Empty;
    public string AiOzet { get; private set; } = string.Empty;
    public long? AiIstekId { get; private set; }
    public string ActiveTab { get; private set; } = "risk";
    public string StokMiktarText { get; private set; } = "-";
    public string StokNot { get; private set; } = "Kesim-1 gun";
    public string IadeOranText { get; private set; } = "-";
    public string IadeNot { get; private set; } = "Esik -";
    public string SonHareketGunText { get; private set; } = "-";
    public string SonHareketTip { get; private set; } = "-";
    public string KritikFlag { get; private set; } = "-";
    public string DofDurum { get; private set; } = "Yok";
    public string DofSorumlu { get; private set; } = "-";

    public IReadOnlyList<FlagRow> Flaglar { get; private set; } = Array.Empty<FlagRow>();
    public IReadOnlyList<HareketRow> Hareketler { get; private set; } = Array.Empty<HareketRow>();
    public IReadOnlyList<DofRow> Doflar { get; private set; } = Array.Empty<DofRow>();

    public UrunModel(SqlDb db)
    {
        _db = db;
    }

    public async Task OnGetAsync(int? id, int? mekanId, string? tab)
    {
        UrunId = id ?? 0;
        MekanId = mekanId;
        ActiveTab = NormalizeTab(tab);

        if (UrunId <= 0)
        {
            AiOzet = "Urun bulunamadi.";
            return;
        }

        var detay = await _db.QuerySingleAsync<UrunDetayRow>(
            "rpt.sp_ProductDetail_Get",
            new { StokId = UrunId, MekanId = mekanId });

        if (detay is not null)
        {
            MekanId = detay.MekanId;
            Mekan = detay.MekanAd;
            UrunKod = detay.UrunKod;
            UrunAd = detay.UrunAd;
            Kategori3 = string.IsNullOrWhiteSpace(detay.Kategori3) ? "-" : detay.Kategori3;
            Donem = detay.DonemKodu;
            Skor = detay.RiskSkor;
            SkorSeviye = Skor switch
            {
                >= 90 => "KRITIK",
                >= 75 => "YUKSEK",
                _ => "ORTA"
            };
            AiOzet = BuildAiOzet(detay.RiskYorum);

            StokMiktarText = FormatNumber(detay.StokMiktar);
            StokNot = detay.StokBakiyeTarihi.HasValue
                ? detay.StokBakiyeTarihi.Value.ToString("yyyy-MM-dd")
                : "Kesim-1 gun";

            IadeOranText = detay.IadeOraniYuzde.HasValue
                ? $"%{detay.IadeOraniYuzde.Value.ToString("N1", TrCulture)}"
                : "-";
            IadeNot = detay.IadeOranEsik > 0
                ? $"Esik %{detay.IadeOranEsik.ToString("N1", TrCulture)}"
                : "Esik -";
        }
        else
        {
            UrunKod = $"BK-{UrunId}";
            UrunAd = $"Urun-{UrunId}";
            Kategori3 = "-";
            Mekan = mekanId.HasValue ? $"Mekan-{mekanId}" : "Mekan-?";
            Donem = "Son30Gun";
            AiOzet = "Risk kaydi bulunamadi.";
        }

        var aiSonuc = await _db.QuerySingleAsync<AiSonucRow>(
            "ai.sp_LlmResults_Latest",
            new { StokId = UrunId, MekanId = MekanId, DonemKodu = Donem });

        if (aiSonuc is not null)
        {
            AiIstekId = aiSonuc.IstekId;
            var ozet = !string.IsNullOrWhiteSpace(aiSonuc.YoneticiOzeti)
                ? aiSonuc.YoneticiOzeti
                : aiSonuc.KokNedenHipotezleri;

            if (!string.IsNullOrWhiteSpace(ozet))
            {
                AiOzet = NormalizeAiText(ozet);
            }
        }

        var flags = await _db.QueryAsync<FlagRow>("rpt.sp_ProductRiskFlag_List", new { StokId = UrunId, MekanId = MekanId });
        Flaglar = flags.ToList();

        var hareket = await _db.QueryAsync<HareketRow>("rpt.sp_ProductMovement_List", new { StokId = UrunId, MekanId = MekanId, Top = 30 });
        Hareketler = hareket.ToList();

        if (Hareketler.Count > 0)
        {
            var son = Hareketler[0];
            var gun = (DateTime.Today - son.Tarih.Date).Days;
            if (gun < 0)
            {
                gun = 0;
            }

            SonHareketGunText = $"{gun} gun";
            SonHareketTip = string.IsNullOrWhiteSpace(son.HareketTipi) ? son.Tip : son.HareketTipi;
        }

        if (Flaglar.Count > 0)
        {
            var kritik = Flaglar.OrderByDescending(f => f.Etki).First();
            KritikFlag = kritik.Flag;
        }

        if (Doflar.Count > 0)
        {
            var ilk = Doflar[0];
            DofDurum = ilk.Durum;
            DofSorumlu = ilk.Sorumlu;
        }
    }

    private static string NormalizeTab(string? tab)
    {
        if (string.IsNullOrWhiteSpace(tab))
        {
            return "risk";
        }

        return tab.ToLowerInvariant() switch
        {
            "risk" => "risk",
            "hareket" => "hareket",
            "dof" => "dof",
            _ => "risk"
        };
    }

    private static string FormatNumber(decimal value) => value.ToString("N0", TrCulture);

    private static string BuildAiOzet(string? riskYorum)
    {
        if (string.IsNullOrWhiteSpace(riskYorum))
        {
            return "Ozet bulunamadi.";
        }

        return riskYorum.Replace(" | ", ". ").Trim();
    }

    private static string NormalizeAiText(string text) => text.Trim();

    public record FlagRow(string Flag, string Aciklama, int Etki);
    public sealed class HareketRow
    {
        public DateTime Tarih { get; init; }
        public string MekanAd { get; init; } = string.Empty;
        public string HareketTipi { get; init; } = string.Empty;
        public string Tip { get; init; } = string.Empty;
        public string? Islem { get; init; }
        public string EvrakNo { get; init; } = string.Empty;
        public decimal? BirimFiyat { get; init; }
        public decimal? Giris { get; init; }
        public decimal? Cikis { get; init; }
        public decimal Kalan { get; init; }
        public decimal Tutar { get; init; }
        public decimal Maliyet { get; init; }
        public string Not { get; init; } = string.Empty;
    }
    public record DofRow(string Baslik, string Durum, string Tarih, string Sorumlu);

    public sealed record UrunDetayRow
    {
        public int StokId { get; init; }
        public int MekanId { get; init; }
        public string MekanAd { get; init; } = string.Empty;
        public string UrunKod { get; init; } = string.Empty;
        public string UrunAd { get; init; } = string.Empty;
        public string? Kategori3 { get; init; }
        public string DonemKodu { get; init; } = string.Empty;
        public int RiskSkor { get; init; }
        public string? RiskYorum { get; init; }
        public decimal IadeOranEsik { get; init; }
        public decimal? IadeOraniYuzde { get; init; }
        public decimal StokMiktar { get; init; }
        public DateTime? StokBakiyeTarihi { get; init; }
        public DateTime? SonSatisTarihi { get; init; }
        public bool FlagStokYok { get; init; }
    }

    public sealed record AiSonucRow
    {
        public long IstekId { get; init; }
        public string? YoneticiOzeti { get; init; }
        public string? KokNedenHipotezleri { get; init; }
        public int? GuvenSkoru { get; init; }
        public DateTime? OlusturmaTarihi { get; init; }
    }
}
