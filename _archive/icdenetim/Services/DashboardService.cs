using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;

namespace BkmArgus.Services;

/// <summary>
/// Dashboard metrikleri - Dapper ile SQL Server sorguları.
/// Tüm sorgular kesinleştirilmiş (IsFinalized=1) denetimleri kullanır.
/// </summary>
public class DashboardService : IDashboardService
{
    private readonly IConfiguration _config;

    public DashboardService(IConfiguration config)
    {
        _config = config;
    }

    public async Task<List<LocationRisk>> GetRiskiestLocationsAsync(int topN = 10)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<LocationRisk>(@"
            SELECT TOP (@TopN)
                a.LocationName,
                COUNT(DISTINCT a.Id) AS AuditCount,
                COUNT(ar.Id) AS TotalFindings,
                SUM(CASE WHEN ar.IsPassed = 0 THEN 1 ELSE 0 END) AS FailedFindings,
                AVG(CASE WHEN ar.IsPassed = 0 THEN CAST(ar.RiskScore AS DECIMAL(10,2)) ELSE NULL END) AS AvgFailedRiskScore,
                CAST(
                    SUM(CASE WHEN ar.IsPassed = 0 THEN 1.0 ELSE 0 END)
                    / NULLIF(COUNT(ar.Id), 0) * 100
                AS DECIMAL(5,2)) AS FailureRate
            FROM Audits a
            INNER JOIN AuditResults ar ON ar.AuditId = a.Id
            WHERE a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
              AND a.IsFinalized = 1
            GROUP BY a.LocationName
            HAVING SUM(CASE WHEN ar.IsPassed = 0 THEN 1 ELSE 0 END) > 0
            ORDER BY AvgFailedRiskScore DESC, FailureRate DESC
        ", new { TopN = topN })).ToList();
    }

    public async Task<List<RepeatedFinding>> GetMostRepeatedFindingsAsync(int topN = 10)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<RepeatedFinding>(@"
            SELECT TOP (@TopN)
                ar.AuditItemId,
                MAX(ar.ItemText) AS ItemText,
                MAX(ar.AuditGroup) AS AuditGroup,
                MAX(ar.Area) AS Area,
                MAX(ar.RiskType) AS RiskType,
                COUNT(*) AS FailCount,
                COUNT(DISTINCT a.LocationName) AS DistinctLocationCount,
                COUNT(DISTINCT a.Id) AS DistinctAuditCount,
                AVG(CAST(ar.RiskScore AS DECIMAL(10,2))) AS AvgRiskScore,
                CASE WHEN COUNT(DISTINCT a.LocationName) >= 3 THEN 1 ELSE 0 END AS IsSystemic
            FROM AuditResults ar
            INNER JOIN Audits a ON a.Id = ar.AuditId
            WHERE ar.IsPassed = 0
              AND a.IsFinalized = 1
              AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
            GROUP BY ar.AuditItemId
            HAVING COUNT(*) >= 2
            ORDER BY FailCount DESC, AvgRiskScore DESC
        ", new { TopN = topN })).ToList();
    }

    public async Task<ActionSummary> GetCorrectiveActionSummaryAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);

        // Tek sorguda tüm durumları çek
        var result = await conn.QuerySingleOrDefaultAsync<ActionSummary>(@"
            SELECT
                SUM(CASE WHEN Status = 'Open' THEN 1 ELSE 0 END) AS [Open],
                SUM(CASE WHEN Status = 'InProgress' THEN 1 ELSE 0 END) AS InProgress,
                SUM(CASE WHEN Status = 'PendingValidation' THEN 1 ELSE 0 END) AS PendingValidation,
                SUM(CASE WHEN Status = 'Closed' THEN 1 ELSE 0 END) AS Closed,
                SUM(CASE WHEN Status = 'Rejected' THEN 1 ELSE 0 END) AS Rejected,
                SUM(CASE WHEN DueDate < CAST(GETDATE() AS DATE)
                          AND Status NOT IN ('Closed', 'Rejected') THEN 1 ELSE 0 END) AS Overdue,
                COUNT(*) AS Total
            FROM CorrectiveActions
        ");

        return result ?? new ActionSummary();
    }

    public async Task<double> GetAverageResolutionTimeAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var result = await conn.ExecuteScalarAsync<double?>(@"
            SELECT AVG(CAST(DATEDIFF(DAY, CreatedAt, ClosedAt) AS FLOAT))
            FROM CorrectiveActions
            WHERE Status = 'Closed'
              AND ClosedAt IS NOT NULL
        ");
        return result ?? 0.0;
    }

    public async Task<List<MonthlyScore>> GetScoreTrendAsync(int months = 12)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<MonthlyScore>(@"
            SELECT
                YEAR(a.AuditDate) AS [Year],
                MONTH(a.AuditDate) AS [Month],
                CAST(
                    SUM(CASE WHEN ar.IsPassed = 1 THEN 1.0 ELSE 0 END)
                    / NULLIF(COUNT(ar.Id), 0) * 100
                AS DECIMAL(5,2)) AS AverageScore,
                COUNT(DISTINCT a.Id) AS AuditCount
            FROM Audits a
            INNER JOIN AuditResults ar ON ar.AuditId = a.Id
            WHERE a.AuditDate >= DATEADD(MONTH, -@Months, GETDATE())
              AND a.IsFinalized = 1
            GROUP BY YEAR(a.AuditDate), MONTH(a.AuditDate)
            ORDER BY [Year], [Month]
        ", new { Months = months })).ToList();
    }

    public async Task<List<DepartmentRisk>> GetDepartmentRisksAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<DepartmentRisk>(@"
            SELECT
                COALESCE(a.Directorate, N'Belirtilmemiş') AS Department,
                COUNT(DISTINCT a.Id) AS AuditCount,
                COUNT(ar.Id) AS TotalFindings,
                SUM(CASE WHEN ar.IsPassed = 0 THEN 1 ELSE 0 END) AS FailedFindings,
                AVG(CASE WHEN ar.IsPassed = 0 THEN CAST(ar.RiskScore AS DECIMAL(10,2)) ELSE NULL END) AS AvgRiskScore,
                CAST(
                    SUM(CASE WHEN ar.IsPassed = 0 THEN 1.0 ELSE 0 END)
                    / NULLIF(COUNT(ar.Id), 0) * 100
                AS DECIMAL(5,2)) AS FailureRate,
                CAST(
                    SUM(CASE WHEN ar.IsPassed = 1 THEN 1.0 ELSE 0 END)
                    / NULLIF(COUNT(ar.Id), 0) * 100
                AS DECIMAL(5,2)) AS AverageScore
            FROM Audits a
            INNER JOIN AuditResults ar ON ar.AuditId = a.Id
            WHERE a.IsFinalized = 1
              AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
            GROUP BY a.Directorate
            ORDER BY AvgRiskScore DESC
        ")).ToList();
    }

    public async Task<List<AiAlert>> GetRecentAiAlertsAsync(int count = 20)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<AiAlert>(@"
            SELECT TOP (@Count)
                Id,
                EntityType,
                EntityId,
                AnalysisType,
                Summary,
                Confidence,
                Severity,
                IsActionable,
                ActionTaken,
                CreatedAt
            FROM AiAnalyses
            ORDER BY CreatedAt DESC
        ", new { Count = count })).ToList();
    }
}
