namespace BkmArgus.Models;

/// <summary>
/// Denetim madde sonucu - snapshot olarak madde bilgisi saklanır.
/// Madde listesi değişse bile eski denetimler aynı kalır.
/// </summary>
public class AuditResult
{
    public int Id { get; set; }
    public int AuditId { get; set; }
    public int AuditItemId { get; set; }
    public string AuditGroup { get; set; } = string.Empty;
    public string Area { get; set; } = string.Empty;
    public string RiskType { get; set; } = string.Empty;
    public string ItemText { get; set; } = string.Empty;
    public int SortOrder { get; set; }
    public bool IsPassed { get; set; }                     // true=EVET, false=HAYIR
    public string? FindingType { get; set; }
    public int Probability { get; set; }
    public int Impact { get; set; }
    public int RiskScore { get; set; }
    public string? RiskLevel { get; set; }
    public string? Remark { get; set; }

    // Data Intelligence alanları
    /// <summary>Bu maddenin aynı lokasyonda ilk başarısız görüldüğü tarih.</summary>
    public DateTime? FirstSeenAt { get; set; }
    /// <summary>Bu denetimden önceki en son başarısızlık tarihi.</summary>
    public DateTime? LastSeenAt { get; set; }
    /// <summary>Aynı madde + aynı lokasyonda kaç kez başarısız olduğu.</summary>
    public int RepeatCount { get; set; }
    /// <summary>Son 12 ayda 3+ farklı lokasyonda başarısız -> sistemik sorun.</summary>
    public bool IsSystemic { get; set; }
}
