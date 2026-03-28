namespace BkmArgus.Models;

/// <summary>
/// AI analiz sonucu kaydı.
/// Denetim, lokasyon veya bulgu bazında yapılan AI analizlerini saklar.
/// </summary>
public class AiAnalysis
{
    public int Id { get; set; }
    public string EntityType { get; set; } = string.Empty;   // Audit, Location, AuditResult
    public int EntityId { get; set; }
    public string AnalysisType { get; set; } = string.Empty;  // RiskPrediction, NarrativeReport, ActionPlan, ExecutiveSummary
    public string? InputData { get; set; }
    public string Result { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public decimal Confidence { get; set; }
    public string? Severity { get; set; }                      // Low, Medium, High, Critical
    public bool IsActionable { get; set; }
    public bool ActionTaken { get; set; }
    public DateTime CreatedAt { get; set; }
}
