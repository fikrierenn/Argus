namespace BkmArgus.Services;

/// <summary>
/// AI destekli rapor olusturma arayuzu.
/// Denetim verilerinden anlatimsal rapor, aksiyon plani ve yonetici ozeti uretir.
/// </summary>
public interface IReportGeneratorService
{
    Task<string> GenerateNarrativeReportAsync(int auditId);
    Task<string> GenerateActionPlanAsync(int auditId);
    Task<string> GenerateExecutiveSummaryAsync(int auditId);
}
