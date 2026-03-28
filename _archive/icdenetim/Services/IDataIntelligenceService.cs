namespace BkmArgus.Services;

/// <summary>
/// Denetim sonuçları için veri zekası servisi.
/// Tekrar eden bulgular, sistemik sorunlar ve risk eskalasyonu tespit eder.
/// </summary>
public interface IDataIntelligenceService
{
    /// <summary>
    /// Denetim kesinleştirildikten sonra tüm başarısız sonuçları analiz eder.
    /// Tekrar, sistemik ve risk eskalasyonu hesaplar.
    /// </summary>
    Task AnalyzeAuditAsync(int auditId);

    /// <summary>
    /// Belirli bir sonucun tekrar edip etmediğini tespit eder.
    /// Aynı madde + aynı lokasyon, daha önce başarısız mı?
    /// </summary>
    Task<RepeatInfo> DetectRepeatAsync(int auditResultId);

    /// <summary>
    /// Belirli bir maddenin sistemik sorun olup olmadığını tespit eder.
    /// Son 12 ayda 3+ farklı lokasyonda başarısız -> sistemik.
    /// </summary>
    Task<SystemicInfo> DetectSystemicAsync(int auditItemId);

    /// <summary>
    /// Tekrar ve sistemik duruma göre risk eskalasyonu hesaplar.
    /// </summary>
    Task<RiskEscalation> CalculateRiskEscalationAsync(int auditResultId);
}

/// <summary>Tekrar tespit sonucu.</summary>
public class RepeatInfo
{
    public int AuditResultId { get; set; }
    public int RepeatCount { get; set; }
    public DateTime? FirstSeenAt { get; set; }
    public DateTime? LastSeenAt { get; set; }
    public bool IsRepeat => RepeatCount > 0;
}

/// <summary>Sistemik sorun tespit sonucu.</summary>
public class SystemicInfo
{
    public int AuditItemId { get; set; }
    public bool IsSystemic { get; set; }
    public int AffectedLocationCount { get; set; }
    public List<string> AffectedLocations { get; set; } = [];
}

/// <summary>Risk eskalasyon hesabı sonucu.</summary>
public class RiskEscalation
{
    public int AuditResultId { get; set; }
    public int OriginalRisk { get; set; }
    public double EscalatedRisk { get; set; }
    public string EscalationReason { get; set; } = string.Empty;
    public List<string> Factors { get; set; } = [];
}
