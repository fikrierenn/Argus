using Dapper;
using BkmArgus.Data;
using BkmArgus.Services.AI;
using BkmArgus.Services.Events;

namespace BkmArgus.Services;

/// <summary>
/// Pipeline orchestrator - denetim sonrasi tum analiz + AI karar adimlarini yonetir.
/// Event-driven: her adim event publish eder, AI Orchestrator dinler ve karar verir.
/// </summary>
public class AuditProcessingService : IAuditProcessingService
{
    private readonly IDataIntelligenceService _intelligence;
    private readonly IInsightService _insights;
    private readonly IEventBus _eventBus;
    private readonly IAIOrchestratorService _orchestrator;
    private readonly IConfiguration _config;
    private readonly ILogger<AuditProcessingService> _logger;

    public AuditProcessingService(
        IDataIntelligenceService intelligence,
        IInsightService insights,
        IEventBus eventBus,
        IAIOrchestratorService orchestrator,
        IConfiguration config,
        ILogger<AuditProcessingService> logger)
    {
        _intelligence = intelligence;
        _insights = insights;
        _eventBus = eventBus;
        _orchestrator = orchestrator;
        _config = config;
        _logger = logger;

        // AI Orchestrator'u event bus'a bagla
        _orchestrator.Initialize(_eventBus);
    }

    public async Task ProcessAuditAsync(int auditId)
    {
        _logger.LogInformation("Denetim #{AuditId}: Pipeline baslatiliyor...", auditId);

        // 1. Event: Audit Finalized
        _eventBus.Publish(AuditEvent.AuditFinalized(auditId));

        // 2. Data Intelligence: repeat + systemic + DOF effectiveness
        try
        {
            await _intelligence.AnalyzeAuditAsync(auditId);
            _logger.LogInformation("Denetim #{AuditId}: Tekrar/Sistemik/DOF analizi tamamlandi.", auditId);

            // Analiz sonuclarini oku ve event publish et
            await PublishDetectionEventsAsync(auditId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Denetim #{AuditId}: Data Intelligence HATASI - pipeline devam ediyor.", auditId);
        }

        // 3. Insight Generation
        try
        {
            await _insights.GenerateInsightsForAuditAsync(auditId);
            _logger.LogInformation("Denetim #{AuditId}: Insight uretimi tamamlandi.", auditId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Denetim #{AuditId}: Insight uretimi HATASI.", auditId);
        }

        // 4. AI Orchestrator: tum event'leri isle
        try
        {
            await _eventBus.ProcessPendingAsync();
            _logger.LogInformation("Denetim #{AuditId}: AI Orchestrator {Count} event isledi.", auditId, 0);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Denetim #{AuditId}: AI Orchestrator HATASI.", auditId);
        }

        _logger.LogInformation("Denetim #{AuditId}: Pipeline tamamlandi.", auditId);
    }

    /// <summary>DataIntelligence sonuclarindan event'ler uretir.</summary>
    private async Task PublishDetectionEventsAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);

        // Repeat detected events
        var repeats = await conn.QueryAsync<dynamic>(
            @"SELECT ar.Id, ar.ItemText, ar.RepeatCount
              FROM AuditResults ar WHERE ar.AuditId = @AuditId AND ar.IsPassed = 0 AND ar.RepeatCount >= 2",
            new { AuditId = auditId });

        foreach (var r in repeats)
            _eventBus.Publish(AuditEvent.RepeatDetected((int)r.Id, (int)r.RepeatCount, (string)r.ItemText));

        // Systemic detected events
        var systemics = await conn.QueryAsync<dynamic>(
            @"SELECT ar.AuditItemId, COUNT(DISTINCT a.LocationName) AS LocCount
              FROM AuditResults ar INNER JOIN Audits a ON a.Id = ar.AuditId
              WHERE ar.AuditId = @AuditId AND ar.IsSystemic = 1 AND ar.IsPassed = 0
              GROUP BY ar.AuditItemId",
            new { AuditId = auditId });

        foreach (var s in systemics)
            _eventBus.Publish(AuditEvent.SystemicDetected((int)s.AuditItemId, (int)s.LocCount));

        // DOF ineffective events
        var ineffective = await conn.QueryAsync<dynamic>(
            @"SELECT ca.Id, ca.EffectivenessScore
              FROM CorrectiveActions ca
              WHERE ca.AuditId = @AuditId AND ca.IsEffective = 0",
            new { AuditId = auditId });

        foreach (var d in ineffective)
            _eventBus.Publish(AuditEvent.DofIneffective((int)d.Id, (decimal)(d.EffectivenessScore ?? 0m)));

        // Risk escalation events
        var highRisk = await conn.QueryAsync<dynamic>(
            @"SELECT ar.Id, ar.RiskScore, ar.RepeatCount, ar.IsSystemic
              FROM AuditResults ar WHERE ar.AuditId = @AuditId AND ar.IsPassed = 0
              AND (ar.RiskScore * (1.0 + ar.RepeatCount * 0.15) * (CASE WHEN ar.IsSystemic = 1 THEN 1.3 ELSE 1.0 END)) > 20",
            new { AuditId = auditId });

        foreach (var h in highRisk)
        {
            double escalated = (int)h.RiskScore * (1.0 + (int)h.RepeatCount * 0.15) * ((bool)h.IsSystemic ? 1.3 : 1.0);
            _eventBus.Publish(AuditEvent.RiskEscalated((int)h.Id, escalated));
        }
    }
}
