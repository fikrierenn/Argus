using Dapper;
using BkmArgus.Data;

namespace BkmArgus.Services;

/// <summary>
/// Denetim sonuçları için veri zekası motoru.
/// Tekrar eden bulgular, sistemik sorunlar ve risk eskalasyonu tespit eder.
/// Dapper ile doğrudan SQL sorguları çalıştırır.
/// </summary>
public class DataIntelligenceService : IDataIntelligenceService
{
    private readonly IConfiguration _config;

    public DataIntelligenceService(IConfiguration config) => _config = config;

    /// <inheritdoc />
    public async Task AnalyzeAuditAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        // Kesinleşen denetimdeki tüm başarısız sonuçları al
        var failedResults = await conn.QueryAsync<FailedResultDto>(
            @"SELECT ar.Id AS AuditResultId, ar.AuditItemId, ar.RiskScore,
                     a.LocationName, a.AuditDate
              FROM AuditResults ar
              INNER JOIN Audits a ON a.Id = ar.AuditId
              WHERE ar.AuditId = @AuditId AND ar.IsPassed = 0",
            new { AuditId = auditId });

        var resultList = failedResults.ToList();
        if (resultList.Count == 0) return;

        // Her başarısız sonuç için tekrar tespiti yap
        foreach (var result in resultList)
        {
            await DetectAndUpdateRepeatAsync(conn, result.AuditResultId, result.AuditItemId,
                result.LocationName, result.AuditDate);
        }

        // Benzersiz AuditItemId'ler için sistemik tespit yap
        var distinctItemIds = resultList.Select(r => r.AuditItemId).Distinct();
        foreach (var itemId in distinctItemIds)
        {
            await DetectAndUpdateSystemicAsync(conn, itemId);
        }

        // DOF etkinlik kontrolu: basarisiz sonuclarda kapanmis DOF var mi?
        foreach (var result in resultList)
        {
            await CheckDofEffectivenessAsync(conn, result.AuditResultId, result.AuditItemId,
                result.LocationName, result.AuditDate);
        }
    }

    /// <inheritdoc />
    public async Task<RepeatInfo> DetectRepeatAsync(int auditResultId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        // Sonucun madde ve lokasyon bilgilerini al
        var context = await conn.QuerySingleOrDefaultAsync<FailedResultDto>(
            @"SELECT ar.Id AS AuditResultId, ar.AuditItemId, ar.RiskScore,
                     a.LocationName, a.AuditDate
              FROM AuditResults ar
              INNER JOIN Audits a ON a.Id = ar.AuditId
              WHERE ar.Id = @AuditResultId",
            new { AuditResultId = auditResultId });

        if (context == null)
            return new RepeatInfo { AuditResultId = auditResultId };

        return await CalculateRepeatInfoAsync(conn, auditResultId, context.AuditItemId,
            context.LocationName, context.AuditDate);
    }

    /// <inheritdoc />
    public async Task<SystemicInfo> DetectSystemicAsync(int auditItemId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();
        return await CalculateSystemicInfoAsync(conn, auditItemId);
    }

    /// <inheritdoc />
    public async Task<RiskEscalation> CalculateRiskEscalationAsync(int auditResultId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        var result = await conn.QuerySingleOrDefaultAsync<dynamic>(
            @"SELECT ar.RiskScore, ar.RepeatCount, ar.IsSystemic
              FROM AuditResults ar
              WHERE ar.Id = @AuditResultId",
            new { AuditResultId = auditResultId });

        if (result == null)
            return new RiskEscalation { AuditResultId = auditResultId };

        int riskScore = (int)result.RiskScore;
        int repeatCount = (int)result.RepeatCount;
        bool isSystemic = (bool)result.IsSystemic;

        return CalculateEscalation(auditResultId, riskScore, repeatCount, isSystemic);
    }

    // ─── Dahili yardımcı metotlar ──────────────────────────────────────

    /// <summary>
    /// Tekrar bilgisini hesaplar ve AuditResults satırını günceller.
    /// </summary>
    private async Task DetectAndUpdateRepeatAsync(
        Microsoft.Data.SqlClient.SqlConnection conn,
        int auditResultId, int auditItemId, string locationName, DateTime auditDate)
    {
        var repeatInfo = await CalculateRepeatInfoAsync(conn, auditResultId, auditItemId,
            locationName, auditDate);

        await conn.ExecuteAsync(
            @"UPDATE AuditResults
              SET RepeatCount = @RepeatCount,
                  FirstSeenAt = @FirstSeenAt,
                  LastSeenAt  = @LastSeenAt
              WHERE Id = @AuditResultId",
            new
            {
                repeatInfo.AuditResultId,
                repeatInfo.RepeatCount,
                repeatInfo.FirstSeenAt,
                repeatInfo.LastSeenAt
            });
    }

    /// <summary>
    /// Aynı madde + aynı lokasyonda önceki başarısızlıkları sorgular.
    /// </summary>
    private static async Task<RepeatInfo> CalculateRepeatInfoAsync(
        Microsoft.Data.SqlClient.SqlConnection conn,
        int auditResultId, int auditItemId, string locationName, DateTime auditDate)
    {
        // Aynı madde + aynı lokasyon + daha önceki tarihlerde başarısız olanlar
        var previousFailures = await conn.QueryAsync<DateTime>(
            @"SELECT a.AuditDate
              FROM AuditResults ar
              INNER JOIN Audits a ON a.Id = ar.AuditId
              WHERE ar.AuditItemId = @AuditItemId
                AND a.LocationName = @LocationName
                AND ar.IsPassed = 0
                AND a.AuditDate < @AuditDate
                AND a.IsFinalized = 1
              ORDER BY a.AuditDate",
            new { AuditItemId = auditItemId, LocationName = locationName, AuditDate = auditDate });

        var dates = previousFailures.ToList();

        return new RepeatInfo
        {
            AuditResultId = auditResultId,
            RepeatCount = dates.Count,
            FirstSeenAt = dates.Count > 0 ? dates.First() : null,
            LastSeenAt = dates.Count > 0 ? dates.Last() : null
        };
    }

    /// <summary>
    /// Sistemik sorun tespiti yapar ve ilgili tüm sonuçları günceller.
    /// Son 12 ayda 3+ farklı lokasyonda başarısız -> sistemik.
    /// </summary>
    private async Task DetectAndUpdateSystemicAsync(
        Microsoft.Data.SqlClient.SqlConnection conn, int auditItemId)
    {
        var info = await CalculateSystemicInfoAsync(conn, auditItemId);

        if (info.IsSystemic)
        {
            // Son 12 aydaki tüm başarısız sonuçları sistemik olarak işaretle
            await conn.ExecuteAsync(
                @"UPDATE ar
                  SET ar.IsSystemic = 1
                  FROM AuditResults ar
                  INNER JOIN Audits a ON a.Id = ar.AuditId
                  WHERE ar.AuditItemId = @AuditItemId
                    AND ar.IsPassed = 0
                    AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())",
                new { AuditItemId = auditItemId });
        }
    }

    /// <summary>
    /// Sistemik bilgiyi hesaplar (son 12 ayda kaç farklı lokasyonda başarısız).
    /// </summary>
    private static async Task<SystemicInfo> CalculateSystemicInfoAsync(
        Microsoft.Data.SqlClient.SqlConnection conn, int auditItemId)
    {
        var locations = (await conn.QueryAsync<string>(
            @"SELECT DISTINCT a.LocationName
              FROM AuditResults ar
              INNER JOIN Audits a ON a.Id = ar.AuditId
              WHERE ar.AuditItemId = @AuditItemId
                AND ar.IsPassed = 0
                AND a.AuditDate >= DATEADD(MONTH, -12, GETDATE())
                AND a.IsFinalized = 1",
            new { AuditItemId = auditItemId })).ToList();

        return new SystemicInfo
        {
            AuditItemId = auditItemId,
            IsSystemic = locations.Count >= 3,
            AffectedLocationCount = locations.Count,
            AffectedLocations = locations
        };
    }

    /// <summary>
    /// Risk eskalasyonu hesabı:
    /// BaseRisk * (1 + RepeatCount * 0.15) * (IsSystemic ? 1.3 : 1.0)
    /// </summary>
    private static RiskEscalation CalculateEscalation(
        int auditResultId, int riskScore, int repeatCount, bool isSystemic)
    {
        double escalated = riskScore;
        var factors = new List<string>();

        // Tekrar faktörü: her tekrar %15 artış
        if (repeatCount > 0)
        {
            var repeatMultiplier = 1.0 + repeatCount * 0.15;
            escalated *= repeatMultiplier;
            factors.Add($"Tekrar ({repeatCount}x): x{repeatMultiplier:F2}");
        }

        // Sistemik faktör: %30 artış
        if (isSystemic)
        {
            escalated *= 1.3;
            factors.Add("Sistemik sorun: x1.30");
        }

        var reason = factors.Count == 0
            ? "Eskalasyon yok"
            : string.Join(" + ", factors);

        return new RiskEscalation
        {
            AuditResultId = auditResultId,
            OriginalRisk = riskScore,
            EscalatedRisk = Math.Round(escalated, 2),
            EscalationReason = reason,
            Factors = factors
        };
    }

    /// <summary>
    /// Basarisiz bir sonuc icin daha once kapanmis DOF var mi kontrol eder.
    /// Varsa, DOF'u etkisiz olarak isaretler.
    /// </summary>
    private static async Task CheckDofEffectivenessAsync(
        Microsoft.Data.SqlClient.SqlConnection conn,
        int auditResultId, int auditItemId, string locationName, DateTime auditDate)
    {
        // Ayni madde + ayni lokasyonda, bu denetimden ONCE kapanmis DOF'lari bul
        var closedDofs = await conn.QueryAsync<(int Id, DateTime? ClosedAt)>(
            @"SELECT ca.Id, ca.ClosedAt
              FROM CorrectiveActions ca
              INNER JOIN AuditResults ar ON ar.Id = ca.AuditResultId
              INNER JOIN Audits a ON a.Id = ca.AuditId
              WHERE ar.AuditItemId = @AuditItemId
                AND a.LocationName = @LocationName
                AND ca.Status = 'Closed'
                AND ca.ClosedAt < @AuditDate",
            new { AuditItemId = auditItemId, LocationName = locationName, AuditDate = auditDate });

        var dofList = closedDofs.ToList();
        if (dofList.Count == 0) return;

        // Tekrar sayisina gore etkinlik skoru hesapla
        // Her tekrarda -0.25, minimum 0.0
        var repeatCount = dofList.Count;
        var effectivenessScore = Math.Max(0.0m, 1.0m - repeatCount * 0.25m);

        foreach (var dof in dofList)
        {
            await conn.ExecuteAsync(
                @"UPDATE CorrectiveActions
                  SET IsEffective = 0,
                      EffectivenessScore = @Score,
                      EffectivenessNote = @Note
                  WHERE Id = @Id AND (IsEffective IS NULL OR IsEffective = 1)",
                new
                {
                    Id = dof.Id,
                    Score = effectivenessScore,
                    Note = $"Ayni sorun {auditDate:dd.MM.yyyy} tarihinde tekrarladi. Tekrar sayisi: {repeatCount}"
                });
        }
    }

    // ─── Dahili DTO ────────────────────────────────────────────────────

    private class FailedResultDto
    {
        public int AuditResultId { get; set; }
        public int AuditItemId { get; set; }
        public int RiskScore { get; set; }
        public string LocationName { get; set; } = string.Empty;
        public DateTime AuditDate { get; set; }
    }
}
