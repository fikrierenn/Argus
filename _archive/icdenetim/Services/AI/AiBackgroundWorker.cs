using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;

namespace BkmArgus.Services.AI;

/// <summary>
/// Background AI Worker - kuyruk-based AI isleme.
/// AiAnalyses tablosundaki IsActionable=1, ActionTaken=0 kayitlarini isler.
/// Periyodik olarak calisir, yeni insight'lari kontrol eder.
/// </summary>
public class AiBackgroundWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<AiBackgroundWorker> _logger;
    private readonly TimeSpan _pollInterval = TimeSpan.FromSeconds(30);

    public AiBackgroundWorker(IServiceProvider services, ILogger<AiBackgroundWorker> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("AI Background Worker baslatildi. Poll interval: {Seconds}s", _pollInterval.TotalSeconds);

        // Baslangicta biraz bekle (app tum servislerini yuklesin)
        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessQueueAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "AI Background Worker dongu hatasi.");
            }

            await Task.Delay(_pollInterval, stoppingToken);
        }

        _logger.LogInformation("AI Background Worker durduruldu.");
    }

    private async Task ProcessQueueAsync(CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var claudeApi = scope.ServiceProvider.GetRequiredService<IClaudeApiService>();

        if (!claudeApi.IsConfigured) return; // AI yoksa islenecek bir sey yok

        using var conn = DbConnectionFactory.Create(config);

        // Islenmeyi bekleyen actionable insight'lari al
        var pending = (await conn.QueryAsync<AiAnalysis>(
            @"SELECT TOP 5 * FROM AiAnalyses
              WHERE IsActionable = 1 AND ActionTaken = 0
                AND AnalysisType != 'PatternAnalysis'
                AND AnalysisType != 'AIDecision'
              ORDER BY CreatedAt ASC")).ToList();

        if (pending.Count == 0) return;

        _logger.LogInformation("AI Worker: {Count} bekleyen insight isleniyor.", pending.Count);

        foreach (var insight in pending)
        {
            if (ct.IsCancellationRequested) break;

            try
            {
                // AI ile oneri uret
                var suggestion = await GenerateActionSuggestionAsync(claudeApi, insight);

                if (!string.IsNullOrEmpty(suggestion))
                {
                    // Oneriyi yeni insight olarak kaydet
                    await conn.ExecuteAsync(
                        @"INSERT INTO AiAnalyses (EntityType, EntityId, AnalysisType, InputData, Result, Summary, Confidence, Severity, IsActionable, ActionTaken)
                          VALUES (@EntityType, @EntityId, 'ActionSuggestion', @InputData, @Result, @Summary, 0.85, @Severity, 1, 0)",
                        new
                        {
                            insight.EntityType,
                            insight.EntityId,
                            InputData = insight.Result,
                            Result = suggestion,
                            Summary = $"AI Oneri: {insight.Summary}",
                            insight.Severity
                        });

                    // Orijinal insight'i islenmis olarak isaretle
                    await conn.ExecuteAsync(
                        "UPDATE AiAnalyses SET ActionTaken = 1 WHERE Id = @Id",
                        new { insight.Id });

                    _logger.LogInformation("AI Worker: Insight #{Id} icin oneri uretildi.", insight.Id);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "AI Worker: Insight #{Id} islenirken hata.", insight.Id);
            }
        }
    }

    private static async Task<string?> GenerateActionSuggestionAsync(IClaudeApiService claudeApi, AiAnalysis insight)
    {
        var systemPrompt = @"Sen BKMKitap ic denetim AI asistanisin.
Sana bir denetim bulgusunu/uyarisini veriyorum.
Somut, olculebilir ve zamanli bir aksiyon onerisi yaz.
Kisa ve net ol. Turkce yaz.
Format: 1-3 madde, her madde icin sorumlu ve sure belirt.";

        var userMessage = $"Uyari Turu: {insight.AnalysisType}\nOnem: {insight.Severity}\nDetay: {insight.Result}\n\nBu uyari icin ne yapilmali?";

        var result = await claudeApi.AnalyzeAsync(systemPrompt, userMessage);

        if (string.IsNullOrEmpty(result) || result.StartsWith("[AI"))
            return null;

        return result;
    }
}
