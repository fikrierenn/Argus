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
    /// <summary>Kritik skor esigi — rozet KIRMIZI olur.</summary>
    private const int KritikEsik = 90;

    /// <summary>Uyari skor esigi — rozet SARI olur.</summary>
    private const int UyariEsik = 70;

    /// <summary>Risk skoru rozeti — YUKSEK skor KOTU.</summary>
    public static string ScoreBadgeClass(int skor) =>
        ArgusBadge.ForThreshold(skor, KritikEsik, UyariEsik, yuksekKotu: true);

    /// <summary>Stok rozeti — stok VARSA iyi, yoksa kotu.</summary>
    public static string StockBadgeClass(bool stokVar) =>
        ArgusBadge.Class(stokVar ? SolumTone.Good : SolumTone.Bad, numeric: true);

    /// <summary>
    /// Risk bayragi rozeti. Bilinmeyen kod NOTR kalir — kirmizi gostermek
    /// yanlis alarm uretir ve danismanin "yanlis pozitif guveni yikar"
    /// uyarisi tam bunu soyluyor.
    /// </summary>
    public static string FlagBadgeClass(string? bayrak) => (bayrak ?? "").ToUpperInvariant() switch
    {
        "GIRISSIZSATIS" or "STOKYOK" => ArgusBadge.Class(SolumTone.Bad),
        "IADEYUKSEK" or "SAYIMDUZELTME" => ArgusBadge.Class(SolumTone.Warn),
        _ => ArgusBadge.Class(SolumTone.Neutral)
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

    /// <summary>
    /// Risk listesi tablosu.
    ///
    /// <paramref name="sayfaBos"/>: veri BITTI mi (sayfa 2+ bos dondu) yoksa
    /// suzgec gercekten hicbir sey bulamadi mi. Eskiden ikisi de "Risk kaydi
    /// bulunamadi. Suzgeci genisletin" diyordu; kullanici saglam suzgecini
    /// bozuyordu (denetim bulgusu 3.4).
    /// </summary>
    public static TableModel<RiskModel.RiskRow> Table(RiskModel m) => new()
    {
        Columns = new ColumnBuilder<RiskModel.RiskRow>()
            .Text(r => r.Mekan, "Mekan")
            .Text(r => r.Urun, "Ürün")
            // Kimlik kolonu GERCEK baglanti: klavyeyle erisilebilir, orta
            // tik/yeni sekme calisir. `RowUrl` olu kancaydi (asagidaki nota bak).
            .Linked(r => $"/Urun/Index?id={r.Id}&mekanId={r.MekanId}")
            .Text(r => r.UrunKod, "Kod")
            .Numeric(r => r.Skor, "Skor")
            .Text(r => string.Join(" · ", r.Flags.Select(FlagText)), "Bayraklar")
            // ONDALIK KORUNUR: stok decimal(18,3). "N0" ile 0,4 -> "0" ve
            // 2,5 -> "3" oluyordu; denetci ekrani ERP dokumuyle kiyaslayip
            // farki "veri tutarsizligi bulgusu" diye yaziyordu (bulgu 6.1).
            .Numeric(r => ArgusFormat.Quantity(r.StokAdet), "Stok")
            .Numeric(r => $"{r.SonHareketGun} gün", "Son hareket")
            .Build(),
        // GERCEK toplam veriliyor (plan 06 S6). Eskiden `satirlar.Count`
        // yaziliyordu, yani "toplam" = sayfadaki satir sayisi; PageCount 1
        // cikiyor ve Solum'un sayfalayicisi HIC cizilmiyordu. Olculdu:
        // suzgecsiz kume 32.980 satir, ekran "50 satir" diyordu.
        // Siralama GERCEKTEN uygulandi: SP @OrderBy/@OrderDir aliyor ve
        // OrderBy dali ORDER BY'da kosuyor. SortDecision.None yazmak YALAN
        // olurdu — Solum bu ayrimi tam bunun icin tipe koydu.
        Page = new PagedResult<RiskModel.RiskRow>(m.Rows, m.GercekToplam, m.PageIndex, m.PageSize,
            new SortDecision(m.OrderBy, m.OrderDir == "DESC")),
        EmptyTitle = m.SayfaBos ? "Bu sayfada kayıt yok." : "Risk kaydı bulunamadı.",
        EmptyHint = m.SayfaBos
            ? "Veri bitti — önceki sayfaya dönün. Süzgeciniz çalışıyor."
            : "Süzgeci genişletin. Kesim günü seçtiyseniz o güne ait snapshot olmayabilir."
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

        // Bos deger URL'e girmez — "?search=" gibi anlamsiz parca kalmasin.
        var temiz = veri.Where(p => !string.IsNullOrEmpty(p.Value))
                        .ToDictionary(p => p.Key, p => p.Value);

        // Coklu secim dizi olarak baglanir: mekan[0], mekan[1] ...
        //
        // BOSLARI INDEKSLEMEDEN ONCE AYIKLA (bulgu 1.6): eskiden dizi once
        // kuruluyor, sonra genel "bos degeri at" filtresi mekan[0]'i
        // dusurebiliyordu. Indeks 0'dan baslamayan dizi model baglamada HIC
        // baglanmaz, yani suzgec TUMDEN sifirlanir. ?mekan=&mekan=12 gibi elle
        // duzenlenmis bir URL bunu tam olarak uretir.
        var mekanlar = m.SelectedMekan.Where(v => !string.IsNullOrWhiteSpace(v)).ToList();
        for (var i = 0; i < mekanlar.Count; i++)
        {
            temiz[$"mekan[{i}]"] = mekanlar[i];
        }

        var tipler = m.SelectedTip.Where(v => !string.IsNullOrWhiteSpace(v)).ToList();
        for (var i = 0; i < tipler.Count; i++)
        {
            temiz[$"tip[{i}]"] = tipler[i];
        }

        return temiz;
    }
}
