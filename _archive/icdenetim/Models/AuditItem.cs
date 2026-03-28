namespace BkmArgus.Models;

/// <summary>
/// Denetim maddesi - master liste. Zamanla değiştirilebilir.
/// Yapılan değişiklikler eski denetimleri etkilemez (AuditResults snapshot tutar).
/// LocationType: Mağaza | Kafe | Herİkisi - madde hangi denetim tipinde kullanılır.
/// </summary>
public class AuditItem
{
    public int Id { get; set; }
    /// <summary>Mağaza, Kafe veya Herİkisi - madde hangi lokasyon tipine ait.</summary>
    public string LocationType { get; set; } = "Herİkisi";
    public string AuditGroup { get; set; } = string.Empty;   // Grup adı
    public string Area { get; set; } = string.Empty;         // Satış Alanı, Kasa, Depo vb.
    public string RiskType { get; set; } = string.Empty;    // Operasyonel Risk, Nakit Kaybı vb.
    public string ItemText { get; set; } = string.Empty;    // Kontrol sorusu
    public int SortOrder { get; set; }
    public string? FindingType { get; set; }                // H (Harici) | E (Exempt)
    public int Probability { get; set; }                     // 1-5
    public int Impact { get; set; }                          // 1-5
    public int RiskScore => Probability * Impact;
    public string RiskLevel => RiskScore switch
    {
        <= 8 => "Düşük Risk",
        <= 15 => "Orta Risk",
        _ => "Yüksek Risk"
    };
}
