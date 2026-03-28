using BkmArgus.Models;

namespace BkmArgus.Repositories;

/// <summary>
/// Düzeltici/Önleyici Faaliyet (DOF) repository arayüzü.
/// </summary>
public interface ICorrectiveActionRepository
{
    Task<IEnumerable<CorrectiveAction>> GetByAuditIdAsync(int auditId);
    Task<CorrectiveAction?> GetByIdAsync(int id);
    Task<IEnumerable<CorrectiveAction>> GetOpenAsync();
    Task<IEnumerable<CorrectiveAction>> GetOverdueAsync();
    Task<int> CreateAsync(CorrectiveAction action);
    Task UpdateStatusAsync(int id, string status, string? note);
    Task CloseAsync(int id, int closedBy, string closureNote);
    Task<Dictionary<string, int>> GetCountByStatusAsync();
    /// <summary>Belirli bir madde + lokasyon icin kapanmis DOF'lari getirir.</summary>
    Task<List<CorrectiveAction>> GetClosedByItemAndLocationAsync(int auditItemId, string locationName);
    /// <summary>DOF'u etkisiz olarak isaretler.</summary>
    Task MarkIneffectiveAsync(int id, decimal effectivenessScore, string note);
}
