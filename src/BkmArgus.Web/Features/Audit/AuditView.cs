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

    /// <summary>Uyum yuzdesi rozeti — esikler eski ekrandan korundu (%90 / %70).</summary>
    public static string ScoreBadgeClass(int yuzde) => yuzde switch
    {
        >= 90 => "solum-badge solum-badge-num solum-badge-good",
        >= 70 => "solum-badge solum-badge-num solum-badge-warn",
        _ => "solum-badge solum-badge-num solum-badge-bad"
    };

    /// <summary>
    /// Durum rozeti. Kesinlestirilmis denetim IYI degil, TAMAMLANMIS'tir —
    /// bu yuzden yesil yerine notr ton; taslak da kotu degil, yalniz eksik.
    /// Eski ekran kesinlestirilmise yesil veriyordu ve "iyi denetim" izlenimi
    /// uretiyordu; uyum yuzdesi zaten ayri rozette.
    /// </summary>
    public static string StatusBadgeClass(bool kesinlestirildi) =>
        kesinlestirildi ? "solum-badge" : "solum-badge solum-badge-warn";

    /// <summary>Durum metni.</summary>
    public static string StatusText(bool kesinlestirildi) =>
        kesinlestirildi ? "Kesinleştirildi" : "Taslak";
}
