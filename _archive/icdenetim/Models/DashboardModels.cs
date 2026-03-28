namespace BkmArgus.Models;

/// <summary>
/// Lokasyon risk skoru - son 12 ayda en riskli lokasyonlar.
/// </summary>
public class LocationRisk
{
    public string LocationName { get; set; } = string.Empty;
    public int AuditCount { get; set; }
    public int TotalFindings { get; set; }
    public int FailedFindings { get; set; }
    public decimal? AvgFailedRiskScore { get; set; }
    public decimal FailureRate { get; set; }
}

/// <summary>
/// Tekrarlayan bulgu - aynı maddenin farklı denetimlerde kaç kez başarısız olduğu.
/// </summary>
public class RepeatedFinding
{
    public int AuditItemId { get; set; }
    public string ItemText { get; set; } = string.Empty;
    public string AuditGroup { get; set; } = string.Empty;
    public string Area { get; set; } = string.Empty;
    public string RiskType { get; set; } = string.Empty;
    public int FailCount { get; set; }
    public int DistinctLocationCount { get; set; }
    public int DistinctAuditCount { get; set; }
    public decimal AvgRiskScore { get; set; }
    public bool IsSystemic { get; set; }
}

/// <summary>
/// Düzeltici faaliyet (DOF) durum özeti.
/// </summary>
public class ActionSummary
{
    public int Open { get; set; }
    public int InProgress { get; set; }
    public int PendingValidation { get; set; }
    public int Closed { get; set; }
    public int Rejected { get; set; }
    public int Overdue { get; set; }
    public int Total { get; set; }
}

/// <summary>
/// Aylık ortalama denetim skoru - trend grafiği için.
/// </summary>
public class MonthlyScore
{
    public int Year { get; set; }
    public int Month { get; set; }
    public decimal AverageScore { get; set; }
    public int AuditCount { get; set; }

    /// <summary>Grafik etiketi: "2025-03" formatında.</summary>
    public string Label => $"{Year}-{Month:D2}";
}

/// <summary>
/// Departman (Directorate) bazlı risk skorları.
/// </summary>
public class DepartmentRisk
{
    public string Department { get; set; } = string.Empty;
    public int AuditCount { get; set; }
    public int TotalFindings { get; set; }
    public int FailedFindings { get; set; }
    public decimal AvgRiskScore { get; set; }
    public decimal FailureRate { get; set; }
    public decimal AverageScore { get; set; }
}

/// <summary>
/// AI analiz/uyarı kaydı - dashboard'da son AI aktivitelerini gösterir.
/// </summary>
public class AiAlert
{
    public int Id { get; set; }
    public string EntityType { get; set; } = string.Empty;
    public int EntityId { get; set; }
    public string AnalysisType { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public decimal Confidence { get; set; }
    public string? Severity { get; set; }
    public bool IsActionable { get; set; }
    public bool ActionTaken { get; set; }
    public DateTime CreatedAt { get; set; }
}
