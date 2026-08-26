using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class UrunModel : PageModel
{
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
    // "Yok" DEGIL "—": bu iki alan hicbir zaman doldurulmuyor (asagidaki
    // DofVeriYoluVar notu). "Yok" bir OLGU iddiasiydi ve yanlisti.
    public string DofDurum { get; private set; } = "—";
    public string DofSorumlu { get; private set; } = "—";

    /// <summary>
    /// Risk snapshot'i BULUNAMADI mi. Eskiden bu durumda uydurma kimlik
    /// uretiliyordu (`BK-88123`, `Urun-88123`, `Mekan-?`, `Donem = "Son30Gun"`)
    /// ve ekran DOLU gorunuyordu; tek uyari AI ozeti kutusundaki bir cumleydi,
    /// o da AI sonucu gelirse SILINIYORDU (denetim bulgusu 5.2).
    /// `evidence-discipline.md` ile dogrudan celisiyordu.
    /// </summary>
    public bool KayitYok { get; private set; }

    /// <summary>
    /// DOF gecmisi veri yolu HENUZ YOK — `Doflar` hicbir yerde doldurulmuyor.
    ///
    /// KRITIK BULGU (2026-08-26): sekme "Bu urun icin acilmis duzeltici
    /// faaliyet bulunmuyor" yaziyordu. Denetci bunu OLGU sanip ayni urune
    /// ikinci bir DOF aciyordu; oysa uc ay once acilmis, hala IN_PROGRESS bir
    /// DOF olabilir. Veri yolu (urun bazli DOF listesi SP'si) plan 06 Faz 5'te;
    /// o gelene kadar ekran HICBIR IDDIADA BULUNMUYOR.
    /// </summary>
    public bool DofVeriYoluVar => false;

    public IReadOnlyList<FlagRow> Flaglar { get; private set; } = Array.Empty<FlagRow>();
    public IReadOnlyList<HareketRow> Hareketler { get; private set; } = Array.Empty<HareketRow>();
    public IReadOnlyList<DofRow> Doflar { get; private set; } = Array.Empty<DofRow>();

    public UrunModel(SqlDb db)
    {
        _db = db;
    }

    public async Task<IActionResult> OnGetAsync(int? id, int? mekanId, string? tab)
    {
        UrunId = id ?? 0;
        MekanId = mekanId;
        ActiveTab = NormalizeTab(tab);

        // Guard: id'siz istekte eskiden TAM kabuk cizilip "Risk bayragi yok."
        // gibi OLGUSAL ifadeler basiliyordu. Kayit yoksa sayfa da yok.
        if (UrunId <= 0)
        {
            return NotFound();
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
            // ESIK TAMAMLANDI (denetim bulgusu 6.2): eskiden alt dal `_ => "ORTA"`
            // idi, yani skor 3 olan urun de "ORTA" (sari) gorunuyordu ve
            // UrunView'de tanimli "DUSUK" yesil tonu HIC uretilemiyordu.
            // "ORTA enflasyonu" etikete olan guveni yiyor.
            // (Esiklerin ref.RiskParameters'a tasinmasi TODO B11.)
            SkorSeviye = Skor switch
            {
                >= 90 => "KRITIK",
                >= 75 => "YUKSEK",
                >= 50 => "ORTA",
                > 0 => "DUSUK",
                _ => "YOK"
            };
            AiOzet = BuildAiOzet(detay.RiskYorum);

            StokMiktarText = FormatNumber(detay.StokMiktar);
            StokNot = detay.StokBakiyeTarihi.HasValue
                ? detay.StokBakiyeTarihi.Value.ToString("yyyy-MM-dd")
                : "Kesim-1 gun";

            IadeOranText = detay.IadeOraniYuzde.HasValue
                ? $"%{detay.IadeOraniYuzde.Value.ToString("N1", ArgusFormat.Tr)}"
                : "-";
            // Esik 0 mesru olabilir ("her iade anormaldir"). Eskiden `> 0`
            // kontrolu 0'i "esik tanimlanmamis" gibi gosteriyordu — kendi
            // "sifir ile bos ayni sey degildir" kuralimizla celisiyordu
            // (denetim bulgusu 6.4).
            IadeNot = detay.IadeOranEsik.HasValue
                ? $"Eşik %{detay.IadeOranEsik.Value.ToString("N1", ArgusFormat.Tr)}"
                : "Eşik tanımsız";
        }
        else
        {
            // UYDURMA YOK: kod/ad/mekan/donem URETILMEZ. Ozellikle `Donem`:
            // uydurulmus "Son30Gun" ile AI sorgusu kosuluyordu ve BASKA bir
            // donemin anlatisi bu urune aitmis gibi gosterilebiliyordu.
            KayitYok = true;
            UrunKod = "—";
            UrunAd = "Bilinmeyen ürün";
            Kategori3 = "—";
            Mekan = "—";
            Donem = string.Empty;
            SkorSeviye = "YOK";
        }

        // Donem bos ise (kayit yok) AI sorgusu HIC kosulmaz — uydurma anahtarla
        // sorgulanan sonuc yanlis urune baglanir.
        var aiSonuc = KayitYok
            ? null
            : await _db.QuerySingleAsync<AiSonucRow>(
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

        // NOT: burada eskiden `if (Doflar.Count > 0)` blogu vardi ve OLU koddu —
        // `Doflar` hicbir yerde doldurulmuyor. Veri yolu gelince (plan 06 Faz 5)
        // bu blok geri gelir; simdi ekran DofVeriYoluVar ile dogruyu soyluyor.
        return Page();
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

    // Miktar ondalik KORUNUR — stok decimal(18,3) (denetim bulgusu 6.1).
    private static string FormatNumber(decimal value) => ArgusFormat.Quantity(value);

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
        // Nullable: "esik 0" ile "esik tanimsiz" ayrilabilsin.
        public decimal? IadeOranEsik { get; init; }
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
