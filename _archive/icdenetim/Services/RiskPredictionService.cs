using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;

namespace BkmArgus.Services;

/// <summary>
/// Lokasyon bazli risk tahmin servisi.
/// Gecmis denetim verilerinden risk skoru, trend ve yuksek riskli lokasyon analizi yapar.
/// AI yapilandirilmissa Claude API ile zenginlestirilmis analiz sunar.
/// </summary>
public class RiskPredictionService : IRiskPredictionService
{
    private readonly IClaudeApiService _claudeApi;
    private readonly IConfiguration _config;
    private readonly ILogger<RiskPredictionService> _logger;

    public RiskPredictionService(
        IClaudeApiService claudeApi,
        IConfiguration config,
        ILogger<RiskPredictionService> logger)
    {
        _claudeApi = claudeApi;
        _config = config;
        _logger = logger;
    }

    public async Task<RiskPrediction> PredictLocationRiskAsync(string locationName)
    {
        _logger.LogInformation("Risk tahmini yapiliyor. Lokasyon: {Location}", locationName);

        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        // Lokasyonun tum denetim istatistiklerini al
        var stats = await conn.QuerySingleOrDefaultAsync<LocationStats>(
            @"SELECT
                COUNT(DISTINCT a.Id) AS AuditCount,
                COUNT(ar.Id) AS TotalItems,
                SUM(CASE WHEN ar.IsPassed = 0 THEN 1 ELSE 0 END) AS FailedCount,
                AVG(CASE WHEN ar.IsPassed = 0 THEN CAST(ar.RiskScore AS FLOAT) ELSE NULL END) AS AvgFailedRiskScore,
                MAX(CASE WHEN ar.IsPassed = 0 THEN ar.RiskScore ELSE 0 END) AS MaxRiskScore,
                SUM(CASE WHEN ar.IsPassed = 0 AND ar.RepeatCount > 0 THEN 1 ELSE 0 END) AS RepeatCount,
                SUM(CASE WHEN ar.IsPassed = 0 AND ar.IsSystemic = 1 THEN 1 ELSE 0 END) AS SystemicCount
              FROM Audits a
              INNER JOIN AuditResults ar ON ar.AuditId = a.Id
              WHERE a.LocationName = @LocationName AND a.IsFinalized = 1
              GROUP BY a.LocationName",
            new { LocationName = locationName });

        if (stats == null || stats.AuditCount == 0)
        {
            return new RiskPrediction
            {
                LocationName = locationName,
                RiskScore = 0m,
                RiskLevel = "Bilinmiyor",
                RiskFactors = new List<string> { "Bu lokasyon icin kesinlesmis denetim verisi bulunamadi." },
                Summary = $"{locationName} icin yeterli denetim verisi yok.",
                PredictedAt = DateTime.UtcNow
            };
        }

        // Risk skoru hesapla
        // Formula: (failRate * 40 + normalizedAvgRisk * 30 + repeatFactor * 20 + systemicFactor * 10) / 100
        var failRate = stats.TotalItems > 0
            ? (decimal)stats.FailedCount / stats.TotalItems
            : 0m;

        // AvgFailedRiskScore 1-25 araliginda, 0-1 araligina normalize et
        var normalizedAvgRisk = stats.AvgFailedRiskScore > 0
            ? (decimal)stats.AvgFailedRiskScore / 25.0m
            : 0m;

        // Tekrar faktoru: tekrar eden bulgu orani (basarisiz maddeler icerisinde)
        var repeatFactor = stats.FailedCount > 0
            ? (decimal)stats.RepeatCount / stats.FailedCount
            : 0m;

        // Sistemik faktor: sistemik bulgu orani
        var systemicFactor = stats.FailedCount > 0
            ? (decimal)stats.SystemicCount / stats.FailedCount
            : 0m;

        var riskScore = (failRate * 40m + normalizedAvgRisk * 30m + repeatFactor * 20m + systemicFactor * 10m) / 100m;
        riskScore = Math.Min(1.0m, Math.Max(0m, riskScore)); // Clamp 0-1

        var riskLevel = riskScore switch
        {
            <= 0.25m => "Dusuk",
            <= 0.50m => "Orta",
            <= 0.75m => "Yuksek",
            _ => "Kritik"
        };

        // Risk faktorlerini belirle
        var factors = new List<string>();
        if (failRate > 0.3m)
            factors.Add($"Yuksek basarisizlik orani: %{failRate * 100:F1}");
        if (normalizedAvgRisk > 0.5m)
            factors.Add($"Yuksek ortalama risk skoru: {stats.AvgFailedRiskScore:F1}/25");
        if (stats.RepeatCount > 0)
            factors.Add($"Tekrar eden bulgular: {stats.RepeatCount} adet");
        if (stats.SystemicCount > 0)
            factors.Add($"Sistemik sorunlar: {stats.SystemicCount} adet");
        if (stats.MaxRiskScore > 15)
            factors.Add($"Yuksek riskli bulgu mevcut (maks skor: {stats.MaxRiskScore})");
        if (factors.Count == 0)
            factors.Add("Genel risk seviyesi kabul edilebilir duzeyde.");

        var summary = $"{locationName}: {stats.AuditCount} denetim, " +
            $"%{failRate * 100:F1} basarisizlik orani, " +
            $"risk seviyesi {riskLevel} ({riskScore:F2}).";

        var prediction = new RiskPrediction
        {
            LocationName = locationName,
            RiskScore = riskScore,
            RiskLevel = riskLevel,
            RiskFactors = factors,
            Summary = summary,
            PredictedAt = DateTime.UtcNow
        };

        // AI varsa ozeti zenginlestir
        if (_claudeApi.IsConfigured)
        {
            try
            {
                var aiSummary = await _claudeApi.AnalyzeAsync(
                    "Sen bir ic denetim risk analisti olarak calisiyorsun. Kisa ve oneriye odakli risk degerlendirmesi yap.",
                    $"Lokasyon: {locationName}\nRisk Skoru: {riskScore:F2} ({riskLevel})\n" +
                    $"Denetim Sayisi: {stats.AuditCount}\nBasarisizlik Orani: %{failRate * 100:F1}\n" +
                    $"Tekrar: {stats.RepeatCount}, Sistemik: {stats.SystemicCount}\n" +
                    $"Faktorler: {string.Join("; ", factors)}\n\n" +
                    "Bu verilere dayanarak kisa bir risk degerlendirmesi ve oneri yaz.");
                prediction.Summary = aiSummary;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "AI risk ozeti basarisiz, veri ozeti kullaniliyor.");
            }
        }

        return prediction;
    }

    public async Task<List<RiskTrend>> GetRiskTrendsAsync(string locationName, int months = 12)
    {
        _logger.LogInformation("Risk trendi hesaplaniyor. Lokasyon: {Location}, Ay: {Months}", locationName, months);

        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        var trends = await conn.QueryAsync<RiskTrend>(
            @"SELECT
                @LocationName AS LocationName,
                DATEFROMPARTS(YEAR(a.AuditDate), MONTH(a.AuditDate), 1) AS [Month],
                AVG(CASE WHEN ar.IsPassed = 0 THEN CAST(ar.RiskScore AS DECIMAL(10,2)) ELSE NULL END) AS RiskScore,
                COUNT(DISTINCT a.Id) AS AuditCount,
                SUM(CASE WHEN ar.IsPassed = 0 THEN 1 ELSE 0 END) AS FindingCount
              FROM Audits a
              INNER JOIN AuditResults ar ON ar.AuditId = a.Id
              WHERE a.LocationName = @LocationName
                AND a.IsFinalized = 1
                AND a.AuditDate >= DATEADD(MONTH, -@Months, GETDATE())
              GROUP BY YEAR(a.AuditDate), MONTH(a.AuditDate)
              ORDER BY YEAR(a.AuditDate), MONTH(a.AuditDate)",
            new { LocationName = locationName, Months = months });

        return trends.ToList();
    }

    public async Task<List<string>> GetHighRiskLocationsAsync(int topN = 10)
    {
        _logger.LogInformation("Yuksek riskli lokasyonlar belirleniyor. TopN: {TopN}", topN);

        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        // Lokasyonlari basarisiz maddelerinin ortalama risk skoruna gore sirala
        var locations = await conn.QueryAsync<string>(
            @"SELECT TOP (@TopN) a.LocationName
              FROM Audits a
              INNER JOIN AuditResults ar ON ar.AuditId = a.Id
              WHERE a.IsFinalized = 1 AND ar.IsPassed = 0
              GROUP BY a.LocationName
              HAVING COUNT(ar.Id) > 0
              ORDER BY AVG(CAST(ar.RiskScore AS FLOAT)) DESC",
            new { TopN = topN });

        return locations.ToList();
    }

    // ─── Internal DTOs ──────────────────────────────────────────────────

    private class LocationStats
    {
        public int AuditCount { get; set; }
        public int TotalItems { get; set; }
        public int FailedCount { get; set; }
        public double AvgFailedRiskScore { get; set; }
        public int MaxRiskScore { get; set; }
        public int RepeatCount { get; set; }
        public int SystemicCount { get; set; }
    }
}
