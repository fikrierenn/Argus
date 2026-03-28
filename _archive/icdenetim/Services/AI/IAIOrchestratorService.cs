using BkmArgus.Services.Events;

namespace BkmArgus.Services.AI;

/// <summary>
/// AI Orchestrator - merkezi karar motoru.
/// Event'leri dinler, rules + AI hybrid karar verir, aksiyonlari tetikler.
/// </summary>
public interface IAIOrchestratorService
{
    /// <summary>Event bus'a subscribe olur.</summary>
    void Initialize(IEventBus eventBus);

    /// <summary>Tek bir olayi manuel isler (test icin).</summary>
    Task HandleEventAsync(AuditEvent evt);
}
