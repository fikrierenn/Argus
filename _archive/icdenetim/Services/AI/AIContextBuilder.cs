using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using BkmArgus.Repositories;
using System.Text.Json;

namespace BkmArgus.Services.AI;

/// <summary>
/// AI icin zengin context olusturur.
/// Finding + Skill + Historical data + DOF effectiveness -> structured prompt.
/// </summary>
public class AIContextBuilder
{
    private readonly IConfiguration _config;
    private readonly IFindingsService _findings;
    private readonly ISkillRepository _skills;

    public AIContextBuilder(IConfiguration config, IFindingsService findings, ISkillRepository skills)
    {
        _config = config;
        _findings = findings;
        _skills = skills;
    }

    /// <summary>Bir denetim icin tam AI context olusturur.</summary>
    public async Task<AuditAIContext> BuildForAuditAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);

        var audit = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "SELECT Id, LocationName, AuditDate, ReportNo, Manager, Directorate FROM Audits WHERE Id = @Id",
            new { Id = auditId });

        if (audit == null) return new AuditAIContext { AuditId = auditId };

        var findings = await _findings.GetFailedByAuditIdAsync(auditId);
        var allFindings = await _findings.GetByAuditIdAsync(auditId);

        // Lokasyon gecmisi
        var locationHistory = await conn.QueryAsync<dynamic>(
            @"SELECT a.Id, a.AuditDate,
                     SUM(CASE WHEN ar.IsPassed = 1 THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100 AS Score
              FROM Audits a
              INNER JOIN AuditResults ar ON ar.AuditId = a.Id
              WHERE a.LocationName = @Location AND a.IsFinalized = 1
              GROUP BY a.Id, a.AuditDate
              ORDER BY a.AuditDate DESC",
            new { Location = (string)audit.LocationName });

        // Skill context
        string? skillContext = null;
        string? riskRulesJson = null;
        var firstFinding = findings.FirstOrDefault();
        if (firstFinding?.SkillId != null)
        {
            var version = await _skills.GetActiveVersionAsync(firstFinding.SkillId.Value);
            if (version != null)
            {
                skillContext = version.AiPromptContext;
                riskRulesJson = version.RiskRules;
            }
        }

        return new AuditAIContext
        {
            AuditId = auditId,
            LocationName = (string)audit.LocationName,
            AuditDate = (DateTime)audit.AuditDate,
            Manager = (string?)audit.Manager,
            Directorate = (string?)audit.Directorate,
            TotalItems = allFindings.Count,
            PassedItems = allFindings.Count(f => f.IsPassed),
            FailedItems = findings.Count,
            PassRate = allFindings.Count > 0 ? (double)allFindings.Count(f => f.IsPassed) / allFindings.Count * 100 : 0,
            FailedFindings = findings,
            RepeatCount = findings.Sum(f => f.RepeatCount),
            SystemicCount = findings.Count(f => f.IsSystemic),
            IneffectiveDofCount = findings.Count(f => f.HasIneffectiveDof),
            HighRiskCount = findings.Count(f => f.EscalatedRiskScore > 15),
            LocationHistoryCount = locationHistory.Count(),
            SkillContext = skillContext,
            RiskRulesJson = riskRulesJson
        };
    }

    /// <summary>Context'i Claude API icin prompt'a donusturur.</summary>
    public string BuildPrompt(AuditAIContext ctx)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"## Denetim Analizi: {ctx.LocationName}");
        sb.AppendLine($"Tarih: {ctx.AuditDate:dd.MM.yyyy} | Yonetici: {ctx.Manager} | Direktorluk: {ctx.Directorate}");
        sb.AppendLine($"Sonuc: {ctx.TotalItems} madde, {ctx.PassedItems} gecti, {ctx.FailedItems} kaldi (Basari: %{ctx.PassRate:F1})");
        sb.AppendLine();

        if (ctx.FailedFindings.Count > 0)
        {
            sb.AppendLine("## Basarisiz Bulgular:");
            foreach (var f in ctx.FailedFindings.OrderByDescending(x => x.EscalatedRiskScore))
            {
                sb.Append($"- [{f.Area}] {f.ItemText} (Risk: {f.RiskScore}");
                if (f.RepeatCount > 0) sb.Append($", Tekrar: {f.RepeatCount}x");
                if (f.IsSystemic) sb.Append(", SISTEMIK");
                if (f.HasIneffectiveDof) sb.Append(", DOF_ETKISIZ");
                sb.AppendLine(")");
            }
        }

        if (ctx.RepeatCount > 0) sb.AppendLine($"\nToplam tekrarlayan bulgu: {ctx.RepeatCount}");
        if (ctx.SystemicCount > 0) sb.AppendLine($"Sistemik sorun sayisi: {ctx.SystemicCount}");
        if (ctx.IneffectiveDofCount > 0) sb.AppendLine($"Etkisiz DOF sayisi: {ctx.IneffectiveDofCount}");
        sb.AppendLine($"Lokasyon gecmis denetim sayisi: {ctx.LocationHistoryCount}");

        return sb.ToString();
    }
}

/// <summary>Denetim AI context verisi.</summary>
public class AuditAIContext
{
    public int AuditId { get; set; }
    public string LocationName { get; set; } = "";
    public DateTime AuditDate { get; set; }
    public string? Manager { get; set; }
    public string? Directorate { get; set; }
    public int TotalItems { get; set; }
    public int PassedItems { get; set; }
    public int FailedItems { get; set; }
    public double PassRate { get; set; }
    public List<Finding> FailedFindings { get; set; } = [];
    public int RepeatCount { get; set; }
    public int SystemicCount { get; set; }
    public int IneffectiveDofCount { get; set; }
    public int HighRiskCount { get; set; }
    public int LocationHistoryCount { get; set; }
    public string? SkillContext { get; set; }
    public string? RiskRulesJson { get; set; }
}
