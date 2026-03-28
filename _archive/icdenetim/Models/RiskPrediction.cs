namespace BkmArgus.Models;

/// <summary>
/// Lokasyon bazlı risk tahmin sonucu.
/// </summary>
public class RiskPrediction
{
    public string LocationName { get; set; } = string.Empty;
    public decimal RiskScore { get; set; }                     // 0.0 - 1.0
    public string RiskLevel { get; set; } = "Medium";          // Low, Medium, High, Critical
    public List<string> RiskFactors { get; set; } = new();
    public string Summary { get; set; } = string.Empty;
    public DateTime PredictedAt { get; set; }
}
