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

    /// <summary>Hareket gecmisi tablosu.</summary>
    public static TableModel<UrunModel.HareketRow> HareketTable(IReadOnlyList<UrunModel.HareketRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<UrunModel.HareketRow>()
            .Text(r => r.Tarih.ToString("dd.MM.yyyy"), "Tarih")
            .Text(r => r.MekanAd, "Mekan")
            .Text(r => r.HareketTipi, "Hareket tipi")
            .Text(r => r.Tip, "Tip")
            .Text(r => r.EvrakNo, "Evrak")
            .Numeric(r => Para(r.BirimFiyat), "Birim fiyat")
            .Numeric(r => Adet(r.Giris), "Giriş")
            .Numeric(r => Adet(r.Cikis), "Çıkış")
            .Numeric(r => ArgusFormat.Quantity(r.Kalan), "Kalan")
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
        >= 15 => ArgusBadge.Class(SolumTone.Bad),
        >= 10 => ArgusBadge.Class(SolumTone.Warn),
        _ => ArgusBadge.Class(SolumTone.Neutral)
    };

    /// <summary>Risk skoru seviyesine gore rozet tonu.</summary>
    public static string SeviyeBadgeClass(string? seviye) => (seviye ?? "").ToUpperInvariant() switch
    {
        "KRITIK" or "YUKSEK" => ArgusBadge.Class(SolumTone.Bad),
        "ORTA" => ArgusBadge.Class(SolumTone.Warn),
        "DUSUK" => ArgusBadge.Class(SolumTone.Good),
        // "YOK" ve bilinmeyen kod NOTR — renk bir yargidir, uydurulmaz.
        _ => ArgusBadge.Class(SolumTone.Neutral)
    };

    // Bos deger tabloda "-" gosterilir; sifir ile bos ayni sey degildir.
    private static string Para(decimal? deger) => ArgusFormat.Money(deger);

    // Miktar ondaligi KORUNUR (denetim bulgusu 6.1): giris/cikis decimal(18,3);
    // "N0" ile 2,5 -> "3" oluyordu ve ERP dokumuyle kiyaslama tutmuyordu.
    private static string Adet(decimal? deger) => ArgusFormat.Quantity(deger);
}
