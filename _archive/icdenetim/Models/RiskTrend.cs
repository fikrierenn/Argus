namespace BkmArgus.Models;

/// <summary>
/// Lokasyon bazlı risk trendi - aylık risk skoru degisimi.
/// </summary>
public class RiskTrend
{
    public string LocationName { get; set; } = string.Empty;
    public DateTime Month { get; set; }
    public decimal RiskScore { get; set; }
    public int AuditCount { get; set; }
    public int FindingCount { get; set; }
}
