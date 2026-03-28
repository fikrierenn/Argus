using System.Text;
using Dapper;
using BkmArgus.Data;

namespace BkmArgus.Services;

/// <summary>
/// Denetim rapor olusturma servisi.
/// AI yapilandirilmamissa bile gercek denetim verileriyle yapilandirilmis rapor uretir.
/// AI yapilandirilmissa Claude API ile zenginlestirilmis rapor olusturur.
/// </summary>
public class ReportGeneratorService : IReportGeneratorService
{
    private readonly IClaudeApiService _claudeApi;
    private readonly IConfiguration _config;
    private readonly ILogger<ReportGeneratorService> _logger;

    public ReportGeneratorService(
        IClaudeApiService claudeApi,
        IConfiguration config,
        ILogger<ReportGeneratorService> logger)
    {
        _claudeApi = claudeApi;
        _config = config;
        _logger = logger;
    }

    // ─── Public API ─────────────────────────────────────────────────────

    public async Task<string> GenerateNarrativeReportAsync(int auditId)
    {
        _logger.LogInformation("Anlatimsal rapor olusturuluyor. DenetimId: {AuditId}", auditId);

        var data = await FetchAuditDataAsync(auditId);
        if (data == null)
            return $"Denetim #{auditId} bulunamadi.";

        var dataReport = FormatNarrativeReport(data);

        if (!_claudeApi.IsConfigured)
            return dataReport;

        try
        {
            var skillContext = await GetSkillContextAsync(auditId);
            var systemPrompt = BuildNarrativeSystemPrompt(skillContext);
            var userMessage = $"Asagidaki denetim verilerine dayanarak profesyonel bir ic denetim raporu yaz.\n\n{dataReport}";
            var aiReport = await _claudeApi.AnalyzeAsync(systemPrompt, userMessage);
            return aiReport;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "AI rapor olusturma basarisiz, veri raporu donuluyor. DenetimId: {AuditId}", auditId);
            return dataReport;
        }
    }

    public async Task<string> GenerateActionPlanAsync(int auditId)
    {
        _logger.LogInformation("Aksiyon plani olusturuluyor. DenetimId: {AuditId}", auditId);

        var data = await FetchAuditDataAsync(auditId);
        if (data == null)
            return $"Denetim #{auditId} bulunamadi.";

        var failedItems = await FetchFailedItemsAsync(auditId);
        var dataReport = FormatActionPlan(data, failedItems);

        if (!_claudeApi.IsConfigured)
            return dataReport;

        try
        {
            var skillContext = await GetSkillContextAsync(auditId);
            var systemPrompt = "Sen bir ic denetim aksiyon plani uzmanisisn. " +
                "Basarisiz denetim maddelerine dayanarak somut, olculebilir ve sureli duzeltici/onleyici faaliyetler oner. " +
                "Risk skoru yuksek maddeler oncelikli olmali." +
                (skillContext != null ? $"\n\nBeceri baglamı: {skillContext}" : "");
            var userMessage = $"Asagidaki denetim bulgularina dayanarak detayli aksiyon plani olustur.\n\n{dataReport}";
            var aiPlan = await _claudeApi.AnalyzeAsync(systemPrompt, userMessage);
            return aiPlan;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "AI aksiyon plani basarisiz, veri raporu donuluyor. DenetimId: {AuditId}", auditId);
            return dataReport;
        }
    }

    public async Task<string> GenerateExecutiveSummaryAsync(int auditId)
    {
        _logger.LogInformation("Yonetici ozeti olusturuluyor. DenetimId: {AuditId}", auditId);

        var data = await FetchAuditDataAsync(auditId);
        if (data == null)
            return $"Denetim #{auditId} bulunamadi.";

        var dataReport = FormatExecutiveSummary(data);

        if (!_claudeApi.IsConfigured)
            return dataReport;

        try
        {
            var systemPrompt = "Sen bir ust yonetime rapor sunan ic denetim uzmanisisn. " +
                "Kisa, oz ve karar vermeye yardimci bir yonetici ozeti hazirla. " +
                "Kritik bulgulari, riskleri ve onerilen aksiyonlari vurgula.";
            var userMessage = $"Asagidaki denetim verilerine dayanarak yonetici ozeti olustur.\n\n{dataReport}";
            var aiSummary = await _claudeApi.AnalyzeAsync(systemPrompt, userMessage);
            return aiSummary;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "AI yonetici ozeti basarisiz, veri raporu donuluyor. DenetimId: {AuditId}", auditId);
            return dataReport;
        }
    }

    // ─── Data Fetching ──────────────────────────────────────────────────

    private async Task<AuditReportData?> FetchAuditDataAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        var audit = await conn.QuerySingleOrDefaultAsync<AuditReportData>(
            @"SELECT
                a.Id,
                a.LocationName,
                a.LocationType,
                a.AuditDate,
                a.ReportDate,
                a.ReportNo,
                a.Manager,
                a.Directorate,
                a.IsFinalized,
                u.FullName AS AuditorName,
                COUNT(ar.Id) AS TotalItems,
                SUM(CASE WHEN ar.IsPassed = 1 THEN 1 ELSE 0 END) AS PassedCount,
                SUM(CASE WHEN ar.IsPassed = 0 THEN 1 ELSE 0 END) AS FailedCount,
                AVG(CASE WHEN ar.IsPassed = 0 THEN CAST(ar.RiskScore AS FLOAT) ELSE NULL END) AS AvgFailedRiskScore,
                MAX(CASE WHEN ar.IsPassed = 0 THEN ar.RiskScore ELSE 0 END) AS MaxRiskScore,
                SUM(CASE WHEN ar.IsPassed = 0 AND ar.RepeatCount > 0 THEN 1 ELSE 0 END) AS RepeatFindingCount,
                SUM(CASE WHEN ar.IsPassed = 0 AND ar.IsSystemic = 1 THEN 1 ELSE 0 END) AS SystemicFindingCount
              FROM Audits a
              INNER JOIN Users u ON u.Id = a.AuditorId
              LEFT JOIN AuditResults ar ON ar.AuditId = a.Id
              WHERE a.Id = @AuditId
              GROUP BY a.Id, a.LocationName, a.LocationType, a.AuditDate, a.ReportDate,
                       a.ReportNo, a.Manager, a.Directorate, a.IsFinalized, u.FullName",
            new { AuditId = auditId });

        return audit;
    }

    private async Task<List<FailedItemDetail>> FetchFailedItemsAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        var items = await conn.QueryAsync<FailedItemDetail>(
            @"SELECT
                ar.AuditGroup,
                ar.Area,
                ar.RiskType,
                ar.ItemText,
                ar.Probability,
                ar.Impact,
                ar.RiskScore,
                ar.RiskLevel,
                ar.Remark,
                ar.RepeatCount,
                ar.IsSystemic,
                ar.FirstSeenAt
              FROM AuditResults ar
              WHERE ar.AuditId = @AuditId AND ar.IsPassed = 0
              ORDER BY ar.RiskScore DESC, ar.SortOrder",
            new { AuditId = auditId });

        return items.ToList();
    }

    private async Task<string?> GetSkillContextAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        // AuditItems -> Skills -> SkillVersions araciligiyla AI prompt context al
        var context = await conn.QueryFirstOrDefaultAsync<string>(
            @"SELECT TOP 1 sv.AiPromptContext
              FROM AuditResults ar
              INNER JOIN AuditItems ai ON ai.Id = ar.AuditItemId
              INNER JOIN Skills s ON s.Id = ai.SkillId
              INNER JOIN SkillVersions sv ON sv.SkillId = s.Id AND sv.IsActive = 1
              WHERE ar.AuditId = @AuditId AND ai.SkillId IS NOT NULL
              ORDER BY sv.CreatedAt DESC",
            new { AuditId = auditId });

        return context;
    }

    // ─── Formatting ─────────────────────────────────────────────────────

    private static string FormatNarrativeReport(AuditReportData d)
    {
        var sb = new StringBuilder();
        sb.AppendLine("═══════════════════════════════════════════════════");
        sb.AppendLine("              IC DENETIM RAPORU");
        sb.AppendLine("═══════════════════════════════════════════════════");
        sb.AppendLine();

        // Genel bilgiler
        sb.AppendLine($"Rapor No      : {d.ReportNo}");
        sb.AppendLine($"Lokasyon      : {d.LocationName} ({d.LocationType})");
        sb.AppendLine($"Denetim Tarihi: {d.AuditDate:dd.MM.yyyy}");
        sb.AppendLine($"Rapor Tarihi  : {d.ReportDate:dd.MM.yyyy}");
        sb.AppendLine($"Denetci       : {d.AuditorName}");
        if (!string.IsNullOrEmpty(d.Manager))
            sb.AppendLine($"Magaza Muduru  : {d.Manager}");
        if (!string.IsNullOrEmpty(d.Directorate))
            sb.AppendLine($"Mudurluk      : {d.Directorate}");
        sb.AppendLine($"Durum         : {(d.IsFinalized ? "Kesinlesmis" : "Taslak")}");
        sb.AppendLine();

        // Ozet istatistikler
        sb.AppendLine("───────────────────────────────────────────────────");
        sb.AppendLine("  OZET ISTATISTIKLER");
        sb.AppendLine("───────────────────────────────────────────────────");
        sb.AppendLine($"Toplam Madde   : {d.TotalItems}");
        sb.AppendLine($"Uygun (Evet)   : {d.PassedCount}");
        sb.AppendLine($"Uygunsuz (Hayir): {d.FailedCount}");

        var complianceRate = d.TotalItems > 0 ? (double)d.PassedCount / d.TotalItems * 100 : 0;
        sb.AppendLine($"Uyum Orani     : %{complianceRate:F1}");

        if (d.FailedCount > 0)
        {
            sb.AppendLine($"Ort. Risk Skoru: {d.AvgFailedRiskScore:F1} (basarisiz maddeler)");
            sb.AppendLine($"Maks Risk Skoru: {d.MaxRiskScore}");

            if (d.RepeatFindingCount > 0)
                sb.AppendLine($"Tekrar Bulgular: {d.RepeatFindingCount} madde");
            if (d.SystemicFindingCount > 0)
                sb.AppendLine($"Sistemik Sorunlar: {d.SystemicFindingCount} madde");
        }
        sb.AppendLine();

        // Genel degerlendirme
        sb.AppendLine("───────────────────────────────────────────────────");
        sb.AppendLine("  GENEL DEGERLENDIRME");
        sb.AppendLine("───────────────────────────────────────────────────");

        if (d.FailedCount == 0)
        {
            sb.AppendLine("Denetimde herhangi bir uygunsuzluk tespit edilmemistir.");
            sb.AppendLine("Lokasyon tum kontrol maddelerinden basariyla gecmistir.");
        }
        else
        {
            var riskLabel = d.AvgFailedRiskScore switch
            {
                <= 8 => "DUSUK",
                <= 15 => "ORTA",
                _ => "YUKSEK"
            };
            sb.AppendLine($"Denetimde {d.FailedCount} adet uygunsuzluk tespit edilmistir.");
            sb.AppendLine($"Genel risk seviyesi: {riskLabel}");

            if (d.RepeatFindingCount > 0)
                sb.AppendLine($"UYARI: {d.RepeatFindingCount} bulgu daha once de tespit edilmis tekrar bulgulardir.");
            if (d.SystemicFindingCount > 0)
                sb.AppendLine($"KRITIK: {d.SystemicFindingCount} bulgu birden fazla lokasyonda gorulen sistemik sorunlardir.");
        }

        sb.AppendLine();
        return sb.ToString();
    }

    private static string FormatActionPlan(AuditReportData d, List<FailedItemDetail> failedItems)
    {
        var sb = new StringBuilder();
        sb.AppendLine("═══════════════════════════════════════════════════");
        sb.AppendLine("            AKSIYON PLANI");
        sb.AppendLine("═══════════════════════════════════════════════════");
        sb.AppendLine();
        sb.AppendLine($"Lokasyon: {d.LocationName} | Denetim: {d.AuditDate:dd.MM.yyyy} | Rapor No: {d.ReportNo}");
        sb.AppendLine();

        if (failedItems.Count == 0)
        {
            sb.AppendLine("Uygunsuzluk tespit edilmemistir. Aksiyon plani gerektirmez.");
            return sb.ToString();
        }

        // Risk gruplarına gore sirala
        var highRisk = failedItems.Where(f => f.RiskScore > 15).ToList();
        var mediumRisk = failedItems.Where(f => f.RiskScore > 8 && f.RiskScore <= 15).ToList();
        var lowRisk = failedItems.Where(f => f.RiskScore <= 8).ToList();

        if (highRisk.Count > 0)
        {
            sb.AppendLine("───────────────────────────────────────────────────");
            sb.AppendLine($"  YUKSEK RISK ({highRisk.Count} madde) - ACIL AKSIYON GEREKLI");
            sb.AppendLine("───────────────────────────────────────────────────");
            FormatFailedItemGroup(sb, highRisk);
        }

        if (mediumRisk.Count > 0)
        {
            sb.AppendLine("───────────────────────────────────────────────────");
            sb.AppendLine($"  ORTA RISK ({mediumRisk.Count} madde) - PLANLANAN AKSIYON");
            sb.AppendLine("───────────────────────────────────────────────────");
            FormatFailedItemGroup(sb, mediumRisk);
        }

        if (lowRisk.Count > 0)
        {
            sb.AppendLine("───────────────────────────────────────────────────");
            sb.AppendLine($"  DUSUK RISK ({lowRisk.Count} madde) - IZLEME");
            sb.AppendLine("───────────────────────────────────────────────────");
            FormatFailedItemGroup(sb, lowRisk);
        }

        return sb.ToString();
    }

    private static void FormatFailedItemGroup(StringBuilder sb, List<FailedItemDetail> items)
    {
        var idx = 1;
        foreach (var item in items)
        {
            sb.AppendLine();
            sb.AppendLine($"  {idx}. [{item.AuditGroup} / {item.Area}]");
            sb.AppendLine($"     Madde: {item.ItemText}");
            sb.AppendLine($"     Risk: {item.RiskType} | Skor: {item.RiskScore} ({item.RiskLevel}) | O:{item.Probability} x E:{item.Impact}");

            if (item.RepeatCount > 0)
                sb.AppendLine($"     ⚠ TEKRAR: Bu bulgu daha once {item.RepeatCount} kez tespit edilmis (ilk: {item.FirstSeenAt:dd.MM.yyyy})");
            if (item.IsSystemic)
                sb.AppendLine($"     ⚠ SISTEMIK: Birden fazla lokasyonda gorulen sorun");
            if (!string.IsNullOrEmpty(item.Remark))
                sb.AppendLine($"     Not: {item.Remark}");

            idx++;
        }
        sb.AppendLine();
    }

    private static string FormatExecutiveSummary(AuditReportData d)
    {
        var sb = new StringBuilder();
        sb.AppendLine("═══════════════════════════════════════════════════");
        sb.AppendLine("            YONETICI OZETI");
        sb.AppendLine("═══════════════════════════════════════════════════");
        sb.AppendLine();
        sb.AppendLine($"Lokasyon   : {d.LocationName} ({d.LocationType})");
        sb.AppendLine($"Tarih      : {d.AuditDate:dd.MM.yyyy}");
        sb.AppendLine($"Rapor No   : {d.ReportNo}");
        sb.AppendLine($"Denetci    : {d.AuditorName}");
        sb.AppendLine();

        var complianceRate = d.TotalItems > 0 ? (double)d.PassedCount / d.TotalItems * 100 : 0;

        sb.AppendLine($"Uyum Orani : %{complianceRate:F1}");
        sb.AppendLine($"Toplam     : {d.TotalItems} madde | {d.PassedCount} uygun | {d.FailedCount} uygunsuz");
        sb.AppendLine();

        if (d.FailedCount == 0)
        {
            sb.AppendLine("SONUC: Denetim basariyla tamamlanmis, uygunsuzluk tespit edilmemistir.");
        }
        else
        {
            var riskLabel = d.AvgFailedRiskScore switch
            {
                <= 8 => "DUSUK",
                <= 15 => "ORTA",
                _ => "YUKSEK"
            };
            sb.AppendLine($"RISK SEVIYESI: {riskLabel} (Ort: {d.AvgFailedRiskScore:F1}, Maks: {d.MaxRiskScore})");

            if (d.RepeatFindingCount > 0 || d.SystemicFindingCount > 0)
            {
                sb.AppendLine();
                sb.AppendLine("DIKKAT GEREKTIREN KONULAR:");
                if (d.RepeatFindingCount > 0)
                    sb.AppendLine($"  - {d.RepeatFindingCount} tekrar eden bulgu (onceki denetimlerde de tespit edilmis)");
                if (d.SystemicFindingCount > 0)
                    sb.AppendLine($"  - {d.SystemicFindingCount} sistemik sorun (birden fazla lokasyonda goruluyor)");
            }

            sb.AppendLine();
            sb.AppendLine($"ONERI: {d.FailedCount} uygunsuzluk icin duzeltici faaliyet planlanmalidir.");
            if (d.MaxRiskScore > 15)
                sb.AppendLine("ACIL: Yuksek riskli bulgular oncelikli olarak ele alinmalidir.");
        }

        sb.AppendLine();
        return sb.ToString();
    }

    private static string BuildNarrativeSystemPrompt(string? skillContext)
    {
        var prompt = "Sen bir ic denetim raporu yazarisin. " +
            "Profesyonel, resmi ve nesnel bir dil kullan. " +
            "Bulgulari risk seviyesine gore sirala. " +
            "Tekrar eden ve sistemik sorunlari vurgula. " +
            "Somut ve uygulanabilir oneriler sun.";

        if (!string.IsNullOrEmpty(skillContext))
            prompt += $"\n\nBeceri baglami: {skillContext}";

        return prompt;
    }

    // ─── Internal DTOs ──────────────────────────────────────────────────

    private class AuditReportData
    {
        public int Id { get; set; }
        public string LocationName { get; set; } = string.Empty;
        public string LocationType { get; set; } = string.Empty;
        public DateTime AuditDate { get; set; }
        public DateTime ReportDate { get; set; }
        public string ReportNo { get; set; } = string.Empty;
        public string? Manager { get; set; }
        public string? Directorate { get; set; }
        public bool IsFinalized { get; set; }
        public string AuditorName { get; set; } = string.Empty;
        public int TotalItems { get; set; }
        public int PassedCount { get; set; }
        public int FailedCount { get; set; }
        public double AvgFailedRiskScore { get; set; }
        public int MaxRiskScore { get; set; }
        public int RepeatFindingCount { get; set; }
        public int SystemicFindingCount { get; set; }
    }

    private class FailedItemDetail
    {
        public string AuditGroup { get; set; } = string.Empty;
        public string Area { get; set; } = string.Empty;
        public string RiskType { get; set; } = string.Empty;
        public string ItemText { get; set; } = string.Empty;
        public int Probability { get; set; }
        public int Impact { get; set; }
        public int RiskScore { get; set; }
        public string? RiskLevel { get; set; }
        public string? Remark { get; set; }
        public int RepeatCount { get; set; }
        public bool IsSystemic { get; set; }
        public DateTime? FirstSeenAt { get; set; }
    }
}
