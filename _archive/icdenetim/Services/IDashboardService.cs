using BkmArgus.Models;

namespace BkmArgus.Services;

/// <summary>
/// Dashboard veri servisi - ana sayfa metrikleri ve grafikler için SQL sorguları.
/// </summary>
public interface IDashboardService
{
    /// <summary>
    /// Son 12 ayda en riskli lokasyonlar (ortalama başarısız madde risk skoru).
    /// </summary>
    Task<List<LocationRisk>> GetRiskiestLocationsAsync(int topN = 10);

    /// <summary>
    /// En çok tekrarlayan bulgular (aynı AuditItemId farklı denetimlerde en çok başarısız olan).
    /// </summary>
    Task<List<RepeatedFinding>> GetMostRepeatedFindingsAsync(int topN = 10);

    /// <summary>
    /// Açık düzeltici faaliyetlerin duruma göre dağılımı.
    /// </summary>
    Task<ActionSummary> GetCorrectiveActionSummaryAsync();

    /// <summary>
    /// Ortalama DOF çözüm süresi (oluşturulma -> kapatılma, gün cinsinden).
    /// </summary>
    Task<double> GetAverageResolutionTimeAsync();

    /// <summary>
    /// Son N aylık denetim puan trendi (aylık ortalama EVET oranı).
    /// </summary>
    Task<List<MonthlyScore>> GetScoreTrendAsync(int months = 12);

    /// <summary>
    /// Departman (Directorate) bazlı risk skorları.
    /// </summary>
    Task<List<DepartmentRisk>> GetDepartmentRisksAsync();

    /// <summary>
    /// Son AI analiz/uyarıları.
    /// </summary>
    Task<List<AiAlert>> GetRecentAiAlertsAsync(int count = 20);
}
