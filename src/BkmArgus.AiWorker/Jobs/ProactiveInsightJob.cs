using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Data;
using Microsoft.Data.SqlClient;

namespace BkmArgus.AiWorker.Jobs;

/// <summary>
/// Proactive Insight Job - Generates proactive audit insights:
/// 1. DENETIM_PLANLA: Suggests audit plans based on risk thresholds
/// 2. TREND_UYARI: Warns about declining trends
/// 3. ANOMALI_TESPIT: Detects statistical anomalies
/// </summary>
public class ProactiveInsightJob : BaseAiJob
{
    public ProactiveInsightJob(ILogger<ProactiveInsightJob> logger, IOptions<AiWorkerOptions> options)
        : base(logger, options)
    {
    }

    public override async Task<JobResult> ExecuteAsync(CancellationToken cancellationToken = default)
    {
        var startTime = DateTime.Now;
        var phaseResults = new Dictionary<string, object>();
        var totalInsights = 0;

        try
        {
            _logger.LogInformation("ProactiveInsightJob starting - 3 phases: DENETIM_PLANLA, TREND_UYARI, ANOMALI_TESPIT");

            // Phase 1: DENETIM_PLANLA
            var phase1 = await ExecutePhaseAsync(
                "DENETIM_PLANLA",
                "ai.sp_Insight_DenetimPlanla",
                new Dictionary<string, object>
                {
                    ["GunEsik"] = 30,
                    ["RiskEsik"] = 60
                },
                cancellationToken);

            phaseResults["DENETIM_PLANLA"] = phase1;
            if (phase1.Success && phase1.Data != null && phase1.Data.TryGetValue("InsightCount", out var count1))
                totalInsights += Convert.ToInt32(count1);

            // Phase 2: TREND_UYARI
            var phase2 = await ExecutePhaseAsync(
                "TREND_UYARI",
                "ai.sp_Insight_TrendUyari",
                new Dictionary<string, object>
                {
                    ["DusisEsik"] = 10.0m
                },
                cancellationToken);

            phaseResults["TREND_UYARI"] = phase2;
            if (phase2.Success && phase2.Data != null && phase2.Data.TryGetValue("InsightCount", out var count2))
                totalInsights += Convert.ToInt32(count2);

            // Phase 3: ANOMALI_TESPIT
            var phase3 = await ExecutePhaseAsync(
                "ANOMALI_TESPIT",
                "ai.sp_Insight_AnomaliTespit",
                new Dictionary<string, object>
                {
                    ["SapmaCarpani"] = 2.0m
                },
                cancellationToken);

            phaseResults["ANOMALI_TESPIT"] = phase3;
            if (phase3.Success && phase3.Data != null && phase3.Data.TryGetValue("InsightCount", out var count3))
                totalInsights += Convert.ToInt32(count3);

            // Check if any phase failed
            var allSuccess = phase1.Success && phase2.Success && phase3.Success;

            // Send notifications to admin users if there are insights
            if (totalInsights > 0)
            {
                await SendAdminNotificationsAsync(totalInsights, cancellationToken);
            }

            var duration = DateTime.Now - startTime;

            _logger.LogInformation(
                "ProactiveInsightJob completed in {Duration}ms. Total insights: {TotalInsights}. All phases success: {AllSuccess}",
                duration.TotalMilliseconds, totalInsights, allSuccess);

            return new JobResult
            {
                JobName = nameof(ProactiveInsightJob),
                Success = allSuccess,
                Message = allSuccess
                    ? $"Proactive insight job completed. {totalInsights} insights generated."
                    : $"Proactive insight job completed with errors. {totalInsights} insights generated.",
                RecordsProcessed = totalInsights,
                ExecutionTime = duration,
                Data = phaseResults
            };
        }
        catch (Exception ex)
        {
            var duration = DateTime.Now - startTime;
            _logger.LogError(ex, "ProactiveInsightJob failed after {Duration}ms", duration.TotalMilliseconds);

            return new JobResult
            {
                JobName = nameof(ProactiveInsightJob),
                Success = false,
                Message = $"Proactive insight job failed: {ex.Message}",
                ExecutionTime = duration,
                Exception = ex,
                Data = phaseResults
            };
        }
    }

    private async Task<StoredProcedureResult> ExecutePhaseAsync(
        string phaseName,
        string storedProcedure,
        Dictionary<string, object> parameters,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Phase {PhaseName} starting - SP: {StoredProcedure}", phaseName, storedProcedure);

        var result = await ExecuteStoredProcedureAsync(storedProcedure, parameters, cancellationToken);

        if (result.Success)
        {
            _logger.LogInformation("Phase {PhaseName} completed successfully", phaseName);
        }
        else
        {
            _logger.LogWarning("Phase {PhaseName} failed: {Error}", phaseName, result.ErrorMessage);
        }

        return result;
    }

    private async Task SendAdminNotificationsAsync(int totalInsights, CancellationToken cancellationToken)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);

            var title = $"Proaktif AI Analizi: {totalInsights} yeni bulgu";
            var message = $"{totalInsights} adet proaktif insight tespit edildi. Detaylar için AI sayfasını inceleyin.";

            using var command = new SqlCommand(@"
                INSERT INTO log.Notifications (UserId, NotificationType, Title, Message, Link)
                SELECT u.UserId, 'AI_INSIGHT', @Title, @Message, '/Ai?tab=insights'
                FROM audit.Users u
                WHERE u.Rol = 'ADMIN' AND u.IsActive = 1", connection)
            {
                CommandTimeout = 30
            };

            command.Parameters.AddWithValue("@Title", title);
            command.Parameters.AddWithValue("@Message", message);

            var rowsAffected = await command.ExecuteNonQueryAsync(cancellationToken);
            _logger.LogInformation("Admin notifications sent to {Count} users", rowsAffected);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to send admin notifications - non-critical, continuing");
        }
    }
}
