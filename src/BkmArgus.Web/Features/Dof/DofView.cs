namespace BkmArgus.Web.Features.Dof;

/// <summary>
/// DOF panosu sunum haritasi (plan: 05, Dalga 1).
/// Eski ekranda dort sinif-uretici Razor fonksiyonu vardi (RiskBorderClass,
/// RiskBadgeClass, SlaBadge, SlaText); hepsi buraya tasindi.
///
/// POLITIKA burada: risk etiketi -> ton, SLA gunu -> ton ve metin. Pano
/// MEKANIZMASI (surukleme, klavye, DOM tasima) argus-board.js'te.
/// </summary>
public static class DofView
{
    /// <summary>Risk etiketi -> kart sol kenar tonu.</summary>
    public static string RiskToneClass(string? riskEtiketi) => riskEtiketi switch
    {
        "Kritik" => "argus-board-card-bad",
        "Yuksek" or "Yüksek" => "argus-board-card-warn",
        "Orta" => "argus-board-card-warn",
        _ => "argus-board-card-good"
    };

    /// <summary>Risk etiketi -> rozet tonu.</summary>
    public static string RiskBadgeClass(string? riskEtiketi) => riskEtiketi switch
    {
        "Kritik" => "solum-badge solum-badge-bad",
        "Yuksek" or "Yüksek" => "solum-badge solum-badge-warn",
        "Orta" => "solum-badge solum-badge-warn",
        _ => "solum-badge solum-badge-good"
    };

    /// <summary>
    /// SLA rozeti. Esikler eski ekrandan korundu: gecmis = kotu, iki gun ve
    /// alti = uyari, otesi notr.
    /// </summary>
    public static string SlaBadgeClass(int kalanGun) => kalanGun switch
    {
        < 0 => "solum-badge solum-badge-num solum-badge-bad",
        <= 2 => "solum-badge solum-badge-num solum-badge-warn",
        _ => "solum-badge solum-badge-num"
    };

    /// <summary>SLA metni. Gecikme mutlak deger olarak yazilir, isaret metne girmez.</summary>
    public static string SlaText(int kalanGun) => kalanGun switch
    {
        < 0 => $"{Math.Abs(kalanGun)} gün gecikme",
        0 => "Bugün son gün",
        _ => $"{kalanGun} gün kaldı"
    };
}
