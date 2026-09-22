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
        "YUKSEK_YUKSEK" => ArgusBadge.Class(SolumTone.Bad),
        "YUKSEK_DUSUK" or "DUSUK_YUKSEK" => ArgusBadge.Class(SolumTone.Warn),
        "DUSUK_DUSUK" => ArgusBadge.Class(SolumTone.Good),
        _ => ArgusBadge.Class(SolumTone.Neutral)
    };

    /// <summary>Risk skoru rozeti — YUKSEK skor KOTU (esikler 70/50, eski ekrandan).</summary>
    public static string RiskBadgeClass(decimal skor) =>
        ArgusBadge.ForThreshold(skor, 70m, 50m, yuksekKotu: true, numeric: false);

    /// <summary>
    /// Uyum orani rozeti — YUKSEK oran IYI (risk skorunun TERSI yon).
    /// Ayni sinif ureticiyi ikisi icin kullanmak yanlis renk uretirdi;
    /// eski ekranda iki ayri fonksiyon vardi, ayrimi koruyoruz.
    /// </summary>
    public static string ComplianceBadgeClass(decimal oran) =>
        ArgusBadge.ForThreshold(oran, 50m, 80m, yuksekKotu: false, numeric: false);

    /// <summary>Korelasyon tablosu.</summary>
    public static TableModel<IndexModel.CorrelationRow> Table(
        IReadOnlyList<IndexModel.CorrelationRow> satirlar, bool yenidenHesaplandi = false) => new()
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
        Page = new PagedResult<IndexModel.CorrelationRow>(satirlar, satirlar.Count, 1, Math.Max(1, satirlar.Count), SortDecision.None),
        // Satir tiklanabilir: mekanin risk kirilimina gider (eski "Detay" bagi).
        RowUrl = r => $"/Risk?mekan={r.LocationId}",
        // Hesaplama SONRASI bos sonuc ile "hic hesaplanmamis" AYRI seydir
        // (denetim bulgusu 5.3): eskiden ikisi de ayni ipucunu gosteriyordu ve
        // kullanici dugmeye tekrar tekrar basiyordu.
        EmptyTitle = yenidenHesaplandi ? "Hesaplama sonuç üretmedi." : "Veri bulunamadı.",
        EmptyHint = yenidenHesaplandi
            ? "Hesaplama çalıştı ama eşleşme çıkmadı: bugüne ait ERP snapshot'ı ya da denetim kaydı gerekiyor."
            : "Hesaplama henüz çalıştırılmamış olabilir — \"Yeniden hesapla\" düğmesini deneyin."
    };
}
