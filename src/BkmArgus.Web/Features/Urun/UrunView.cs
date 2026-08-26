using Solum.Core.Crud;
using Solum.Web.Components;

namespace BkmArgus.Web.Features;

/// <summary>
/// Urun detay ekraninin sunum haritasi: model satirlarini Solum ilkellerine
/// cevirir (plan: 05, Dalga 1).
///
/// Dashboard'daki DashboardView ile ayni desen — hesap YOK, yalniz esleme.
/// Sayfalama bu ekranda kullanilmiyor (hareket listesi SP tarafinda TOP-N);
/// sayfalama sozlesmesi kurulunca burasi da pager alir.
/// </summary>
public static class UrunView
{
    private static readonly System.Globalization.CultureInfo TrCulture =
        System.Globalization.CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>Hareket gecmisi tablosu.</summary>
    public static TableModel<UrunModel.HareketRow> HareketTable(IReadOnlyList<UrunModel.HareketRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<UrunModel.HareketRow>()
            .Text(r => r.Tarih.ToString("dd.MM.yyyy"), "Tarih")
            .Text(r => r.MekanAd, "Mekan")
            .Text(r => r.HareketTipi, "Hareket tipi")
            .Text(r => r.Tip, "Tip")
            .Text(r => r.EvrakNo, "Evrak")
            .Number(r => Para(r.BirimFiyat), "Birim fiyat")
            .Number(r => Adet(r.Giris), "Giriş")
            .Number(r => Adet(r.Cikis), "Çıkış")
            .Number(r => r.Kalan.ToString("N0", TrCulture), "Kalan")
            .Build(),
        Page = new PagedResult<UrunModel.HareketRow>(satirlar, satirlar.Count, 1, Math.Max(1, satirlar.Count)),
        EmptyTitle = "Hareket kaydı yok.",
        EmptyHint = "Seçili dönemde bu ürün için stok hareketi görünmüyor."
    };

    /// <summary>
    /// Risk flag'inin skora etkisine gore rozet tonu.
    /// Esikler eski ekrandan korundu (15 ve 10 puan).
    /// </summary>
    public static string EtkiBadgeClass(int etki) => etki switch
    {
        >= 15 => "solum-badge solum-badge-bad",
        >= 10 => "solum-badge solum-badge-warn",
        _ => "solum-badge"
    };

    /// <summary>Risk skoru seviyesine gore rozet tonu.</summary>
    public static string SeviyeBadgeClass(string? seviye) => (seviye ?? "").ToUpperInvariant() switch
    {
        "KRITIK" or "YUKSEK" => "solum-badge solum-badge-bad",
        "ORTA" => "solum-badge solum-badge-warn",
        "DUSUK" => "solum-badge solum-badge-good",
        _ => "solum-badge"
    };

    // Bos deger tabloda "-" gosterilir; sifir ile bos ayni sey degildir.
    private static string Para(decimal? deger) => deger?.ToString("N2", TrCulture) ?? "—";

    private static string Adet(decimal? deger) => deger?.ToString("N0", TrCulture) ?? "—";
}
