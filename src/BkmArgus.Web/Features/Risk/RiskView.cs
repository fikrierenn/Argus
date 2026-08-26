using Solum.Core.Crud;
using Solum.Web.Components;

namespace BkmArgus.Web.Features;

/// <summary>
/// Risk gezgini sunum haritasi (plan: 05, Dalga 1).
/// Eski ekranda bes sinif-uretici Razor fonksiyonu vardi (ScoreBadge,
/// StokBadge, FlagBadge, FlagText, Initials); hepsi buraya tasindi.
///
/// ESIK NOTU (bkmargus-risk-model danismani, 2026-08-26): asagidaki 90/70
/// SUNUM esikleridir — rozetin rengini secer, SKORU HESAPLAMAZ. Skor
/// hesabi SQL'de (rpt.DailyProductRisk.RiskScore), agirliklar
/// ref.RiskScoreWeights'te; bu dosya onlara DOKUNMAZ.
///
/// Yine de borc: semantik katmanda 'KritikSkorEsik' tanimi VAR
/// (sql/47_semantic_definitions.sql:91, ornek degerler 70/80/90) ve dogrusu
/// bu rengin o esikten beslenmesi. Eski ekran degerleri Razor icine gomuyordu;
/// burada en azindan TEK yere geldi. ref.RiskParameters'tan okumak icin
/// TODO — danisman kuralı "esigi kodda sabitleme" diyor ve bu satir o borcun
/// bilincli kaydidir.
/// </summary>
public static class RiskView
{
    /// <summary>Risk skoru rozeti — YUKSEK skor KOTU.</summary>
    public static string ScoreBadgeClass(int skor) => skor switch
    {
        >= 90 => "solum-badge solum-badge-num solum-badge-bad",
        >= 70 => "solum-badge solum-badge-num solum-badge-warn",
        _ => "solum-badge solum-badge-num"
    };

    /// <summary>Stok rozeti — stok VARSA iyi, yoksa kotu.</summary>
    public static string StockBadgeClass(bool stokVar) =>
        stokVar ? "solum-badge solum-badge-num solum-badge-good"
                : "solum-badge solum-badge-num solum-badge-bad";

    /// <summary>
    /// Risk bayragi rozeti. Bilinmeyen kod NOTR kalir — kirmizi gostermek
    /// yanlis alarm uretir ve danismanin "yanlis pozitif guveni yikar"
    /// uyarisi tam bunu soyluyor.
    /// </summary>
    public static string FlagBadgeClass(string? bayrak) => (bayrak ?? "").ToUpperInvariant() switch
    {
        "GIRISSIZSATIS" or "STOKYOK" => "solum-badge solum-badge-bad",
        "IADEYUKSEK" or "SAYIMDUZELTME" => "solum-badge solum-badge-warn",
        _ => "solum-badge"
    };

    /// <summary>Bayrak kodu -> okunur Turkce etiket.</summary>
    public static string FlagText(string? bayrak) => (bayrak ?? "").ToUpperInvariant() switch
    {
        "GIRISSIZSATIS" => "Girişsiz satış",
        "STOKYOK" => "Stok yok",
        "NETBIRIKIM" => "Net birikim",
        "IADEYUKSEK" => "İade yüksek",
        "SAYIMDUZELTME" => "Sayım düzeltme",
        "HIZLIDEVIR" => "Hızlı devir",
        _ => bayrak ?? "—"
    };

    /// <summary>Risk listesi tablosu.</summary>
    public static TableModel<RiskModel.RiskRow> Table(IReadOnlyList<RiskModel.RiskRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<RiskModel.RiskRow>()
            .Text(r => r.Mekan, "Mekan")
            .Text(r => r.Urun, "Ürün")
            .Text(r => r.UrunKod, "Kod")
            .Text(r => r.Donem, "Dönem")
            .Numeric(r => r.Skor, "Skor")
            .Text(r => string.Join(" · ", r.Flags.Select(FlagText)), "Bayraklar")
            .Numeric(r => r.StokAdet.ToString("N0", TrCulture), "Stok")
            .Numeric(r => $"{r.SonHareketGun} gün", "Son hareket")
            .Build(),
        Page = new PagedResult<RiskModel.RiskRow>(satirlar, satirlar.Count, 1, Math.Max(1, satirlar.Count)),
        RowUrl = r => $"/Urun/Index?id={r.Id}&mekanId={r.MekanId}",
        EmptyTitle = "Risk kaydı bulunamadı.",
        EmptyHint = "Süzgeci genişletin ya da kesim tarih aralığını kontrol edin."
    };

    /// <summary>
    /// Aktif suzgec durumunu rota verisi olarak uretir — sayfalama ve dis
    /// aktarim bagalantilari bunu kullanir.
    ///
    /// NEDEN: eski ekran ayni durumu UC ayri formda ~30 gizli input ile
    /// tekrarliyordu. Birinde eksik kalan alan suzgeci SESSIZCE sifirliyordu
    /// (sayfa degistirince arama kaybolabilirdi). Tek uretim yeri o riski
    /// bitirir.
    ///
    /// ANAHTAR ADI "sayfa": "page" Razor Pages'te AYRILMIS rota anahtaridir
    /// (sayfa yolunu tasir). Hem handler parametresine BAGLANMIYOR hem
    /// asp-all-route-data icinden sessizce DUSUYOR — olculdu 2026-08-26:
    /// /Risk?page=2 istegi PageIndex'i 1 birakiyordu ve uretilen "Sonraki"
    /// bagalantisinda page parcasi hic yoktu. Eski ekran da ayni adi
    /// kullaniyordu, yani ONCEKI/SONRAKI dugmeleri MUHTEMELEN HIC CALISMIYORDU.
    /// </summary>
    public static Dictionary<string, string?> RouteData(RiskModel m, int? sayfa = null)
    {
        var veri = new Dictionary<string, string?>
        {
            ["search"] = m.Search,
            ["minSkor"] = m.MinSkor?.ToString(),
            ["maxSkor"] = m.MaxSkor?.ToString(),
            ["kesimBas"] = m.KesimBas?.ToString("yyyy-MM-dd"),
            ["kesimBit"] = m.KesimBit?.ToString("yyyy-MM-dd"),
            ["orderBy"] = m.OrderBy,
            ["orderDir"] = m.OrderDir,
            ["pageSize"] = m.PageSize.ToString(),
            ["sayfa"] = (sayfa ?? m.PageIndex).ToString()
        };

        // Coklu secim dizi olarak baglanir: mekan[0], mekan[1] ...
        for (var i = 0; i < m.SelectedMekan.Count; i++)
        {
            veri[$"mekan[{i}]"] = m.SelectedMekan[i];
        }

        for (var i = 0; i < m.SelectedTip.Count; i++)
        {
            veri[$"tip[{i}]"] = m.SelectedTip[i];
        }

        // Bos deger URL'e girmez — "?search=" gibi anlamsiz parca kalmasin.
        return veri.Where(p => !string.IsNullOrEmpty(p.Value))
                   .ToDictionary(p => p.Key, p => p.Value);
    }

    private static readonly System.Globalization.CultureInfo TrCulture =
        System.Globalization.CultureInfo.GetCultureInfo("tr-TR");
}
