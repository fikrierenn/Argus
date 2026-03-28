using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using BkmArgus.Services.Events;
using System.Text.Json;

namespace BkmArgus.Services.AI;

/// <summary>
/// AI Orchestrator - hybrid karar motoru.
/// Rules engine + Claude API ile akilli kararlar verir.
/// </summary>
public class AIOrchestratorService : IAIOrchestratorService
{
    private readonly IConfiguration _config;
    private readonly IClaudeApiService _claudeApi;
    private readonly ILogger<AIOrchestratorService> _logger;

    public AIOrchestratorService(IConfiguration config, IClaudeApiService claudeApi, ILogger<AIOrchestratorService> logger)
    {
        _config = config;
        _claudeApi = claudeApi;
        _logger = logger;
    }

    public void Initialize(IEventBus eventBus)
    {
        eventBus.Subscribe(AuditEventType.AuditFinalized, HandleEventAsync);
        eventBus.Subscribe(AuditEventType.RepeatDetected, HandleEventAsync);
        eventBus.Subscribe(AuditEventType.SystemicDetected, HandleEventAsync);
        eventBus.Subscribe(AuditEventType.DofIneffective, HandleEventAsync);
        eventBus.Subscribe(AuditEventType.RiskEscalated, HandleEventAsync);
        _logger.LogInformation("AI Orchestrator initialized - listening to all events.");
    }

    public async Task HandleEventAsync(AuditEvent evt)
    {
        _logger.LogInformation("AI Orchestrator processing: {Type} for {EntityType}#{EntityId}", evt.Type, evt.EntityType, evt.EntityId);

        var decision = evt.Type switch
        {
            AuditEventType.RepeatDetected => await DecideOnRepeatAsync(evt),
            AuditEventType.SystemicDetected => await DecideOnSystemicAsync(evt),
            AuditEventType.DofIneffective => await DecideOnIneffectiveDofAsync(evt),
            AuditEventType.RiskEscalated => await DecideOnRiskEscalationAsync(evt),
            AuditEventType.AuditFinalized => new AIDecision { Action = "ANALYZE", Reason = "Audit finalized, pipeline triggered." },
            _ => new AIDecision { Action = "IGNORE", Reason = "No rule matched." }
        };

        if (decision.Action != "IGNORE")
        {
            await StoreDecisionAsync(evt, decision);
            _logger.LogInformation("AI Decision: {Action} - {Reason}", decision.Action, decision.Reason);
        }
    }

    private Task<AIDecision> DecideOnRepeatAsync(AuditEvent evt)
    {
        var repeatCount = (int)evt.Data.GetValueOrDefault("RepeatCount", 0);
        var itemText = evt.Data.GetValueOrDefault("ItemText", "")?.ToString() ?? "";

        // Rules engine
        if (repeatCount >= 5)
            return Task.FromResult(new AIDecision { Action = "ESCALATE_CRITICAL", Reason = $"'{itemText}' {repeatCount}x tekrarladi - kritik eskalasyon gerekli.", Severity = "Critical", ShouldCreateDof = true });
        if (repeatCount >= 3)
            return Task.FromResult(new AIDecision { Action = "ESCALATE_HIGH", Reason = $"'{itemText}' {repeatCount}x tekrarladi - yuksek oncelikli aksiyon gerekli.", Severity = "High", ShouldCreateDof = true });

        return Task.FromResult(new AIDecision { Action = "MONITOR", Reason = $"'{itemText}' {repeatCount}x tekrarladi - izlemeye devam.", Severity = "Medium" });
    }

    private Task<AIDecision> DecideOnSystemicAsync(AuditEvent evt)
    {
        var locationCount = (int)evt.Data.GetValueOrDefault("LocationCount", 0);

        return Task.FromResult(new AIDecision
        {
            Action = "ESCALATE_SYSTEMIC",
            Reason = $"Sistemik sorun: {locationCount} lokasyonda tekrar. Yapisal cozum gerekli.",
            Severity = "Critical",
            ShouldCreateDof = true,
            ShouldNotify = true
        });
    }

    private Task<AIDecision> DecideOnIneffectiveDofAsync(AuditEvent evt)
    {
        var score = Convert.ToDecimal(evt.Data.GetValueOrDefault("EffectivenessScore", 0m));

        return Task.FromResult(new AIDecision
        {
            Action = "DOF_REVIEW",
            Reason = $"DOF etkisiz (skor: {score:F2}). Kok neden analizi ve yeni aksiyon plani gerekli.",
            Severity = score <= 0.25m ? "Critical" : "High",
            ShouldCreateDof = true,
            ShouldNotify = true
        });
    }

    private Task<AIDecision> DecideOnRiskEscalationAsync(AuditEvent evt)
    {
        var escalatedScore = Convert.ToDouble(evt.Data.GetValueOrDefault("EscalatedScore", 0.0));

        if (escalatedScore > 25)
            return Task.FromResult(new AIDecision { Action = "ESCALATE_CRITICAL", Reason = $"Risk skoru {escalatedScore:F1} - acil mudahale.", Severity = "Critical", ShouldNotify = true });

        return Task.FromResult(new AIDecision { Action = "ESCALATE_HIGH", Reason = $"Risk skoru {escalatedScore:F1} - yuksek oncelik.", Severity = "High" });
    }

    private async Task StoreDecisionAsync(AuditEvent evt, AIDecision decision)
    {
        try
        {
            using var conn = DbConnectionFactory.Create(_config);
            await conn.ExecuteAsync(
                @"INSERT INTO AiAnalyses (EntityType, EntityId, AnalysisType, InputData, Result, Summary, Confidence, Severity, IsActionable, ActionTaken)
                  VALUES (@EntityType, @EntityId, 'AIDecision', @InputData, @Result, @Summary, @Confidence, @Severity, @IsActionable, 0)",
                new
                {
                    EntityType = evt.EntityType ?? "Unknown",
                    EntityId = evt.EntityId,
                    InputData = JsonSerializer.Serialize(evt.Data),
                    Result = decision.Reason,
                    Summary = $"[{decision.Action}] {decision.Reason}",
                    Confidence = 1.0m,
                    Severity = decision.Severity ?? "Medium",
                    IsActionable = decision.ShouldCreateDof || decision.ShouldNotify
                });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to store AI decision for {EntityType}#{EntityId}", evt.EntityType, evt.EntityId);
        }
    }
}

/// <summary>AI karar sonucu.</summary>
public class AIDecision
{
    public string Action { get; set; } = "IGNORE";
    public string Reason { get; set; } = "";
    public string? Severity { get; set; }
    public bool ShouldCreateDof { get; set; }
    public bool ShouldNotify { get; set; }
}
