namespace BkmArgus.Services;

/// <summary>
/// Denetim kesinlestirme sonrasi pipeline orchestrator.
/// Tum analiz ve insight uretim adimlarini sirayla calistirir.
/// </summary>
public interface IAuditProcessingService
{
    /// <summary>
    /// Denetim kesinlestirildikten sonra tum pipeline'i calistirir:
    /// 1. Data Intelligence (repeat, systemic, DOF effectiveness)
    /// 2. Insight Generation (uyari, oneri uretimi)
    /// </summary>
    Task ProcessAuditAsync(int auditId);
}
