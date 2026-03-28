namespace BkmArgus.Services.Events;

/// <summary>In-process event bus - olay yayinlama ve dinleme.</summary>
public interface IEventBus
{
    void Publish(AuditEvent evt);
    void Subscribe(AuditEventType type, Func<AuditEvent, Task> handler);
    Task ProcessPendingAsync();
    int PendingCount { get; }
}
