using Solum.Core.Crud;
using Solum.Web.Components;

namespace BkmArgus.Web.Features.Correlation;

/// <summary>
/// Capraz korelasyon ekraninin sunum haritasi (plan: 05, Dalga 1).
/// Hesap YOK — birlesik skor ve kadran SQL'de hesaplaniyor
/// (sql/40_cross_correlation.sql); burada yalniz esleme var.
/// </summary>
public static class CorrelationView
{
    /// <summary>Kadran kodu -> kullaniciya gosterilen Turkce etiket.</summary>
    public static string QuadrantLabel(string? kadran) => kadran switch
    {
        "YUKSEK_YUKSEK" => "Acil müdahale",
        "YUKSEK_DUSUK" => "ERP riski yüksek",
        "DUSUK_YUKSEK" => "Saha riski yüksek",
        "DUSUK_DUSUK" => "Düşük risk",
        _ => kadran ?? "—"
    };

    /// <summary>
    /// Kadran rozeti. Iki kanalin da yuksek oldugu kadran en kotu; tek kanal
    /// yuksekse uyari; ikisi de dusukse iyi.
    /// </summary>
    public static string QuadrantBadgeClass(string? kadran) => kadran switch
    {
        "YUKSEK_YUKSEK" => "solum-badge solum-badge-bad",
        "YUKSEK_DUSUK" or "DUSUK_YUKSEK" => "solum-badge solum-badge-warn",
        "DUSUK_DUSUK" => "solum-badge solum-badge-good",
        _ => "solum-badge"
    };

    /// <summary>Risk skoru rozeti — YUKSEK skor KOTU (esikler 70/50, eski ekrandan).</summary>
    public static string RiskBadgeClass(decimal skor) => skor switch
    {
        >= 70m => "solum-badge solum-badge-bad",
        >= 50m => "solum-badge solum-badge-warn",
        _ => "solum-badge solum-badge-good"
    };

    /// <summary>
    /// Uyum orani rozeti — YUKSEK oran IYI (risk skorunun TERSI yon).
    /// Ayni sinif ureticiyi ikisi icin kullanmak yanlis renk uretirdi;
    /// eski ekranda iki ayri fonksiyon vardi, ayrimi koruyoruz.
    /// </summary>
    public static string ComplianceBadgeClass(decimal oran) => oran switch
    {
        < 50m => "solum-badge solum-badge-bad",
        < 80m => "solum-badge solum-badge-warn",
        _ => "solum-badge solum-badge-good"
    };

    /// <summary>Korelasyon tablosu.</summary>
    public static TableModel<IndexModel.CorrelationRow> Table(IReadOnlyList<IndexModel.CorrelationRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<IndexModel.CorrelationRow>()
            .Text(r => r.LocationName, "Mekan")
            .Numeric(r => r.ErpRiskScore.ToString("0.0"), "ERP risk")
            .Numeric(r => $"%{r.AuditComplianceRate:0.0}", "Denetim uyumu")
            .Numeric(r => r.CombinedScore.ToString("0.0"), "Birleşik skor")
            .Text(r => QuadrantLabel(r.Quadrant), "Kadran")
            .Numeric(r => r.AuditCount, "Denetim")
            .Text(r => r.LastAuditDate?.ToString("dd.MM.yyyy") ?? "—", "Son denetim")
            .Build(),
        Page = new PagedResult<IndexModel.CorrelationRow>(satirlar, satirlar.Count, 1, Math.Max(1, satirlar.Count)),
        // Satir tiklanabilir: mekanin risk kirilimina gider (eski "Detay" bagi).
        RowUrl = r => $"/Risk?mekan={r.LocationId}",
        EmptyTitle = "Veri bulunamadı.",
        EmptyHint = "Hesaplama henüz çalıştırılmamış olabilir — \"Yeniden hesapla\" düğmesini deneyin."
    };
}
