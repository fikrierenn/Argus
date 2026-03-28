using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using BkmArgus.Repositories;
using System.Text.Json;

namespace BkmArgus.Services;

/// <summary>
/// Finding servisi - AuditResult'lari zenginlestirerek sunar.
/// SQL JOIN ile tek sorguda temel veriyi toplar, C# tarafinda zenginlestirir.
/// </summary>
public class FindingsService : IFindingsService
{
    private readonly IConfiguration _config;
    private readonly ISkillRepository _skillRepo;

    // Temel JOIN sorgusu - tum metotlarda kullanilir
    private const string BaseSql = @"
        SELECT ar.Id, ar.AuditId, ar.AuditItemId, ar.AuditGroup, ar.Area, ar.RiskType,
               ar.ItemText, ar.SortOrder, ar.IsPassed, ar.FindingType,
               ar.Probability, ar.Impact, ar.RiskScore, ar.RiskLevel, ar.Remark,
               ar.FirstSeenAt, ar.LastSeenAt, ar.RepeatCount, ar.IsSystemic,
               a.LocationName, a.AuditDate, a.Directorate,
               ai.SkillId, s.Code AS SkillCode
        FROM AuditResults ar
        INNER JOIN Audits a ON a.Id = ar.AuditId
        INNER JOIN AuditItems ai ON ai.Id = ar.AuditItemId
        LEFT JOIN Skills s ON s.Id = ai.SkillId";

    public FindingsService(IConfiguration config, ISkillRepository skillRepo)
    {
        _config = config;
        _skillRepo = skillRepo;
    }

    public async Task<Finding?> GetByIdAsync(int auditResultId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        var finding = await conn.QuerySingleOrDefaultAsync<Finding>(
            $"{BaseSql} WHERE ar.Id = @Id AND a.IsFinalized = 1",
            new { Id = auditResultId });

        if (finding != null)
            await EnrichWithDofsAsync(conn, new List<Finding> { finding });

        return finding;
    }

    public async Task<List<Finding>> GetByAuditIdAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        var findings = (await conn.QueryAsync<Finding>(
            $"{BaseSql} WHERE ar.AuditId = @AuditId AND a.IsFinalized = 1 ORDER BY ar.AuditGroup, ar.SortOrder",
            new { AuditId = auditId })).ToList();

        await EnrichWithDofsAsync(conn, findings);
        return findings;
    }

    public async Task<List<Finding>> GetFailedByAuditIdAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        var findings = (await conn.QueryAsync<Finding>(
            $"{BaseSql} WHERE ar.AuditId = @AuditId AND ar.IsPassed = 0 AND a.IsFinalized = 1 ORDER BY ar.RiskScore DESC",
            new { AuditId = auditId })).ToList();

        await EnrichWithDofsAsync(conn, findings);
        return findings;
    }

    public async Task<List<Finding>> GetRepeatingAsync(int minRepeat = 2)
    {
        using var conn = DbConnectionFactory.Create(_config);
        var findings = (await conn.QueryAsync<Finding>(
            $@"{BaseSql}
            WHERE ar.IsPassed = 0 AND ar.RepeatCount >= @MinRepeat AND a.IsFinalized = 1
              AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
            ORDER BY ar.RepeatCount DESC, ar.RiskScore DESC",
            new { MinRepeat = minRepeat })).ToList();

        await EnrichWithDofsAsync(conn, findings);
        return findings;
    }

    public async Task<List<Finding>> GetSystemicAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var findings = (await conn.QueryAsync<Finding>(
            $@"{BaseSql}
            WHERE ar.IsPassed = 0 AND ar.IsSystemic = 1 AND a.IsFinalized = 1
              AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
            ORDER BY ar.RiskScore DESC",
            new { })).ToList();

        await EnrichWithDofsAsync(conn, findings);
        return findings;
    }

    public async Task<List<Finding>> GetHighRiskAsync(double minEscalatedScore = 15)
    {
        // EscalatedRiskScore C# computed oldugu icin, once tum basarisizlari cek, sonra filtrele
        using var conn = DbConnectionFactory.Create(_config);
        var allFailed = (await conn.QueryAsync<Finding>(
            $@"{BaseSql}
            WHERE ar.IsPassed = 0 AND a.IsFinalized = 1
              AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
            ORDER BY ar.RiskScore DESC",
            new { })).ToList();

        var highRisk = allFailed.Where(f => f.EscalatedRiskScore >= minEscalatedScore).ToList();
        await EnrichWithDofsAsync(conn, highRisk);
        return highRisk;
    }

    public async Task<List<Finding>> GetWithIneffectiveDofAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        // DOF'u olan ve etkisiz isaretli olan sonuclari bul
        var findings = (await conn.QueryAsync<Finding>(
            $@"{BaseSql}
            INNER JOIN CorrectiveActions ca ON ca.AuditResultId = ar.Id
            WHERE ar.IsPassed = 0 AND ca.IsEffective = 0 AND a.IsFinalized = 1
            ORDER BY ar.RiskScore DESC",
            new { })).ToList();

        // Distinct (ayni finding birden fazla DOF varsa tekrar edebilir)
        findings = findings.DistinctBy(f => f.Id).ToList();
        await EnrichWithDofsAsync(conn, findings);
        return findings;
    }

    /// <summary>
    /// Findings listesine iliskili DOF'lari yukler.
    /// Tek sorguda tum DOF'lari ceker, sonra dagitir.
    /// </summary>
    private static async Task EnrichWithDofsAsync(
        Microsoft.Data.SqlClient.SqlConnection conn, List<Finding> findings)
    {
        if (findings.Count == 0) return;

        var resultIds = findings.Select(f => f.Id).Distinct().ToList();
        var dofs = (await conn.QueryAsync<CorrectiveAction>(
            "SELECT * FROM CorrectiveActions WHERE AuditResultId IN @Ids ORDER BY CreatedAt DESC",
            new { Ids = resultIds })).ToList();

        var dofMap = dofs.GroupBy(d => d.AuditResultId).ToDictionary(g => g.Key, g => g.ToList());
        foreach (var finding in findings)
        {
            if (dofMap.TryGetValue(finding.Id, out var relatedDofs))
                finding.RelatedDofs = relatedDofs;
        }
    }
}
