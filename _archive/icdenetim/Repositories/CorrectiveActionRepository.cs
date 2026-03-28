using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;

namespace BkmArgus.Repositories;

/// <summary>
/// Düzeltici/Önleyici Faaliyet (DOF) repository - Dapper ile SQL Server erişimi.
/// </summary>
public class CorrectiveActionRepository : ICorrectiveActionRepository
{
    private readonly IConfiguration _config;

    public CorrectiveActionRepository(IConfiguration config)
    {
        _config = config;
    }

    public async Task<IEnumerable<CorrectiveAction>> GetByAuditIdAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QueryAsync<CorrectiveAction>(
            "SELECT * FROM CorrectiveActions WHERE AuditId = @AuditId ORDER BY CreatedAt DESC",
            new { AuditId = auditId });
    }

    public async Task<CorrectiveAction?> GetByIdAsync(int id)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QuerySingleOrDefaultAsync<CorrectiveAction>(
            "SELECT * FROM CorrectiveActions WHERE Id = @Id",
            new { Id = id });
    }

    public async Task<IEnumerable<CorrectiveAction>> GetOpenAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QueryAsync<CorrectiveAction>(
            "SELECT * FROM CorrectiveActions WHERE Status NOT IN ('Closed', 'Rejected') ORDER BY DueDate ASC");
    }

    public async Task<IEnumerable<CorrectiveAction>> GetOverdueAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QueryAsync<CorrectiveAction>(
            @"SELECT * FROM CorrectiveActions
              WHERE DueDate < CAST(GETDATE() AS DATE)
                AND Status NOT IN ('Closed', 'Rejected')
              ORDER BY DueDate ASC");
    }

    public async Task<int> CreateAsync(CorrectiveAction action)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QuerySingleAsync<int>(
            @"INSERT INTO CorrectiveActions
                (AuditResultId, AuditId, Title, Description, RootCause, Type,
                 AssignedToUserId, Department, DueDate, Priority, Status,
                 AiGenerated, AiConfidence)
              VALUES
                (@AuditResultId, @AuditId, @Title, @Description, @RootCause, @Type,
                 @AssignedToUserId, @Department, @DueDate, @Priority, @Status,
                 @AiGenerated, @AiConfidence);
              SELECT CAST(SCOPE_IDENTITY() AS INT);",
            action);
    }

    public async Task UpdateStatusAsync(int id, string status, string? note)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            @"UPDATE CorrectiveActions
              SET Status = @Status, ClosureNote = COALESCE(@Note, ClosureNote)
              WHERE Id = @Id",
            new { Id = id, Status = status, Note = note });
    }

    public async Task CloseAsync(int id, int closedBy, string closureNote)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            @"UPDATE CorrectiveActions
              SET Status = 'Closed', ClosedAt = GETDATE(), ClosedBy = @ClosedBy, ClosureNote = @ClosureNote
              WHERE Id = @Id",
            new { Id = id, ClosedBy = closedBy, ClosureNote = closureNote });
    }

    public async Task<Dictionary<string, int>> GetCountByStatusAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var rows = await conn.QueryAsync<(string Status, int Count)>(
            "SELECT Status, COUNT(*) AS [Count] FROM CorrectiveActions GROUP BY Status");
        return rows.ToDictionary(r => r.Status, r => r.Count);
    }

    public async Task<List<CorrectiveAction>> GetClosedByItemAndLocationAsync(int auditItemId, string locationName)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<CorrectiveAction>(
            @"SELECT ca.* FROM CorrectiveActions ca
              INNER JOIN AuditResults ar ON ar.Id = ca.AuditResultId
              INNER JOIN Audits a ON a.Id = ca.AuditId
              WHERE ar.AuditItemId = @AuditItemId
                AND a.LocationName = @LocationName
                AND ca.Status = 'Closed'
              ORDER BY ca.ClosedAt DESC",
            new { AuditItemId = auditItemId, LocationName = locationName })).ToList();
    }

    public async Task MarkIneffectiveAsync(int id, decimal effectivenessScore, string note)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            @"UPDATE CorrectiveActions
              SET IsEffective = 0, EffectivenessScore = @Score, EffectivenessNote = @Note
              WHERE Id = @Id",
            new { Id = id, Score = effectivenessScore, Note = note });
    }
}
