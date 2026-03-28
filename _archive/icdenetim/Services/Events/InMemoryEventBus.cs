using System.Collections.Concurrent;

namespace BkmArgus.Services.Events;

/// <summary>
/// In-memory event bus - olaylari toplar, sonra sirayla isler.
/// Thread-safe, async handler destegi.
/// </summary>
public class InMemoryEventBus : IEventBus
{
    private readonly ConcurrentQueue<AuditEvent> _queue = new();
    private readonly Dictionary<AuditEventType, List<Func<AuditEvent, Task>>> _handlers = new();
    private readonly ILogger<InMemoryEventBus> _logger;

    public InMemoryEventBus(ILogger<InMemoryEventBus> logger) => _logger = logger;

    public int PendingCount => _queue.Count;

    public void Publish(AuditEvent evt)
    {
        _queue.Enqueue(evt);
        _logger.LogDebug("Event published: {Type} for {EntityType}#{EntityId}", evt.Type, evt.EntityType, evt.EntityId);
    }

    public void Subscribe(AuditEventType type, Func<AuditEvent, Task> handler)
    {
        if (!_handlers.ContainsKey(type))
            _handlers[type] = new();
        _handlers[type].Add(handler);
    }

    public async Task ProcessPendingAsync()
    {
        while (_queue.TryDequeue(out var evt))
        {
            if (_handlers.TryGetValue(evt.Type, out var handlers))
            {
                foreach (var handler in handlers)
                {
                    try
                    {
                        await handler(evt);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Event handler failed for {Type}#{EntityId}", evt.Type, evt.EntityId);
                    }
                }
            }
        }
    }
}
