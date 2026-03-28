using BkmArgus.Models;

namespace BkmArgus.Services;

/// <summary>
/// Insight motoru - denetim sonuclarina gore otomatik uyari/oneri uretir.
/// Kural-tabanli + AI destekli insight uretimi yapar.
/// Sonuclar AiAnalyses tablosuna kaydedilir.
/// </summary>
public interface IInsightService
{
    /// <summary>
    /// Denetim kesinlestirildikten sonra insight uretir.
    /// DataIntelligenceService SONRASI cagrilmalidir (repeat/systemic verileri hazir olmali).
    /// </summary>
    Task GenerateInsightsForAuditAsync(int auditId);

    /// <summary>Son insight'lari getirir.</summary>
    Task<List<AiAnalysis>> GetRecentInsightsAsync(int count = 20);

    /// <summary>Aksiyon gerektiren insight'lari getirir.</summary>
    Task<List<AiAnalysis>> GetActionableInsightsAsync();

    /// <summary>Insight'i "aksiyon alindi" olarak isaretler.</summary>
    Task MarkActionTakenAsync(int insightId);
}
