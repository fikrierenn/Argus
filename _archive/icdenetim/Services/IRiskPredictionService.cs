using BkmArgus.Models;

namespace BkmArgus.Services;

/// <summary>
/// AI destekli risk tahmin arayuzu.
/// Lokasyon bazli risk skoru, trend ve yuksek riskli lokasyon analizi yapar.
/// </summary>
public interface IRiskPredictionService
{
    Task<RiskPrediction> PredictLocationRiskAsync(string locationName);
    Task<List<RiskTrend>> GetRiskTrendsAsync(string locationName, int months = 12);
    Task<List<string>> GetHighRiskLocationsAsync(int topN = 10);
}
