namespace BkmArgus.Models;

/// <summary>
/// Zenginlestirilmis denetim bulgusu - AuditResult + context.
/// Yeni tablo yok, mevcut veriden compute edilir.
/// </summary>
public class Finding
{
    // AuditResult alanlari
    public int Id { get; set; }                          // AuditResult.Id
    public int AuditId { get; set; }
    public int AuditItemId { get; set; }
    public string AuditGroup { get; set; } = string.Empty;
    public string Area { get; set; } = string.Empty;
    public string RiskType { get; set; } = string.Empty;
    public string ItemText { get; set; } = string.Empty;
    public int SortOrder { get; set; }
    public bool IsPassed { get; set; }
    public string? FindingType { get; set; }
    public int Probability { get; set; }
    public int Impact { get; set; }
    public int RiskScore { get; set; }
    public string? RiskLevel { get; set; }
    public string? Remark { get; set; }

    // Data Intelligence alanlari (AuditResults tablosundan)
    public DateTime? FirstSeenAt { get; set; }
    public DateTime? LastSeenAt { get; set; }
    public int RepeatCount { get; set; }
    public bool IsSystemic { get; set; }

    // Zenginlestirme - Audit tablosundan JOIN
    public string LocationName { get; set; } = string.Empty;
    public DateTime AuditDate { get; set; }
    public string? Directorate { get; set; }

    // Zenginlestirme - Skill
    public int? SkillId { get; set; }
    public string? SkillCode { get; set; }

    // Zenginlestirme - DOF iliskisi (C# tarafinda doldurulur)
    public List<CorrectiveAction> RelatedDofs { get; set; } = [];

    // Computed properties
    /// <summary>Eskalasyon formuluyle hesaplanan risk skoru.</summary>
    public double EscalatedRiskScore =>
        RiskScore * (1.0 + RepeatCount * 0.15) * (IsSystemic ? 1.3 : 1.0);

    /// <summary>Acik (kapanmamis) DOF var mi?</summary>
    public bool HasOpenDof =>
        RelatedDofs.Any(d => d.Status != "Closed" && d.Status != "Rejected");

    /// <summary>Etkisiz olarak isaretlenmis DOF var mi?</summary>
    public bool HasIneffectiveDof =>
        RelatedDofs.Any(d => d.IsEffective == false);

    /// <summary>Risk trendi: sorun tekrarlaniyor mu?</summary>
    public string RiskTrend
    {
        get
        {
            if (RepeatCount >= 3) return "Rising";
            if (RepeatCount >= 1) return "Stable";
            return "New";
        }
    }

    /// <summary>Bulgu oncelik seviyesi (computed).</summary>
    public string SeverityLevel
    {
        get
        {
            if (IsSystemic || EscalatedRiskScore > 20) return "Critical";
            if (RepeatCount >= 3 || EscalatedRiskScore > 15) return "High";
            if (RepeatCount >= 1 || EscalatedRiskScore > 8) return "Medium";
            return "Low";
        }
    }
}
