using BkmArgus.Web.Features;
using Solum.Web.Components;

namespace BkmArgus.Web.Features.Audit;

/// <summary>
/// Saha denetim listesi sunum haritasi (plan: 05, Dalga 1).
/// Eski ekranda dort sinif-uretici Razor fonksiyonu vardi (ScorePercent,
/// ScoreBadge, StatusBadge, StatusText); hepsi buraya tasindi.
/// </summary>
public static class AuditView
{
    /// <summary>
    /// Gecen madde yuzdesi. Toplam sifirsa SIFIR doner — bolme yapilmaz.
    /// Not: "madde yok" ile "hicbiri gecmedi" ayni sey degil; ekranda
    /// gecen/toplam sayisi da gosteriliyor ki ayrim gorunur olsun.
    /// </summary>
    public static int ScorePercent(int gecen, int toplam) =>
        toplam > 0 ? (int)Math.Round(100.0 * gecen / toplam) : 0;

    /// <summary>Uyum orani IYI esigi — bu oranin ustu yesil.</summary>
    private const int UyumIyiEsik = 90;

    /// <summary>Uyum orani UYARI esigi — altina duserse kirmizi.</summary>
    private const int UyumUyariEsik = 70;

    /// <summary>
    /// Uyum yuzdesi rozeti — esikler eski ekrandan korundu (%90 / %70).
    /// `yuksekKotu: false` cunku YUKSEK uyum IYIdir (risk skorunun tersi).
    /// </summary>
    public static string ScoreBadgeClass(int yuzde) =>
        ArgusBadge.ForThreshold(yuzde, UyumIyiEsik, UyumUyariEsik, yuksekKotu: false);

    /// <summary>
    /// Durum rozeti. Kesinlestirilmis denetim IYI degil, TAMAMLANMIS'tir —
    /// bu yuzden yesil yerine notr ton; taslak da kotu degil, yalniz eksik.
    /// Eski ekran kesinlestirilmise yesil veriyordu ve "iyi denetim" izlenimi
    /// uretiyordu; uyum yuzdesi zaten ayri rozette.
    /// </summary>
    public static string StatusBadgeClass(bool kesinlestirildi) =>
        ArgusBadge.Class(kesinlestirildi ? SolumTone.Neutral : SolumTone.Warn);

    /// <summary>Durum metni.</summary>
    public static string StatusText(bool kesinlestirildi) =>
        kesinlestirildi ? "Kesinleştirildi" : "Taslak";

    /// <summary>
    /// Suzgec panelinde gosterilecek ETKIN olcut etiketleri (plan 07, Faz 4).
    /// Gerekce ve neyi saymadigi icin bkz. <see cref="RiskView.AktifSuzgecler"/> —
    /// iki ekranda ayni kural gecerli: yalnizca listeyi DARALTAN secim sayilir.
    /// </summary>
    public static IReadOnlyList<string> AktifSuzgecler(IndexModel m)
    {
        var etkin = new List<string>();

        if (!string.IsNullOrWhiteSpace(m.Search)) etkin.Add($"Magaza: {m.Search}");
        if (m.StartDate.HasValue) etkin.Add($"{m.StartDate:dd.MM.yyyy} sonrasi");
        if (m.EndDate.HasValue) etkin.Add($"{m.EndDate:dd.MM.yyyy} oncesi");
        if (m.IsFinalized.HasValue) etkin.Add(StatusText(m.IsFinalized.Value));

        return etkin;
    }
}
