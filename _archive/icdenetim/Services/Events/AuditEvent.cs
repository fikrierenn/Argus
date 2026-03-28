namespace BkmArgus.Services.Events;

/// <summary>Denetim sistemi olay tipleri.</summary>
public enum AuditEventType
{
    AuditFinalized,
    FindingDetected,
    RepeatDetected,
    SystemicDetected,
    DofCreated,
    DofClosed,
    DofIneffective,
    RiskEscalated,
    InsightGenerated
}

/// <summary>Sistem olayi - tum pipeline olaylari icin.</summary>
public class AuditEvent
{
    public AuditEventType Type { get; init; }
    public int EntityId { get; init; }
    public string? EntityType { get; init; }
    public Dictionary<string, object> Data { get; init; } = new();
    public DateTime OccurredAt { get; init; } = DateTime.UtcNow;

    public static AuditEvent AuditFinalized(int auditId) => new()
    {
        Type = AuditEventType.AuditFinalized, EntityId = auditId, EntityType = "Audit"
    };

    public static AuditEvent RepeatDetected(int auditResultId, int repeatCount, string itemText) => new()
    {
        Type = AuditEventType.RepeatDetected, EntityId = auditResultId, EntityType = "AuditResult",
        Data = new() { ["RepeatCount"] = repeatCount, ["ItemText"] = itemText }
    };

    public static AuditEvent SystemicDetected(int auditItemId, int locationCount) => new()
    {
        Type = AuditEventType.SystemicDetected, EntityId = auditItemId, EntityType = "AuditItem",
        Data = new() { ["LocationCount"] = locationCount }
    };

    public static AuditEvent DofIneffective(int dofId, decimal score) => new()
    {
        Type = AuditEventType.DofIneffective, EntityId = dofId, EntityType = "CorrectiveAction",
        Data = new() { ["EffectivenessScore"] = score }
    };

    public static AuditEvent RiskEscalated(int auditResultId, double escalatedScore) => new()
    {
        Type = AuditEventType.RiskEscalated, EntityId = auditResultId, EntityType = "AuditResult",
        Data = new() { ["EscalatedScore"] = escalatedScore }
    };
}
