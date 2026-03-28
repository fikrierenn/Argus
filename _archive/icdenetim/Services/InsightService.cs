using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using System.Text.Json;

namespace BkmArgus.Services;

/// <summary>
/// Insight motoru - kural-tabanli ve AI destekli uyari/oneri uretimi.
/// FindingsService uzerinden zenginlestirilmis bulgu verisi kullanir.
/// </summary>
public class InsightService : IInsightService
{
    private readonly IConfiguration _config;
    private readonly IClaudeApiService _claudeApi;
    private readonly IFindingsService _findings;
    private readonly ILogger<InsightService> _logger;

    public InsightService(IConfiguration config, IClaudeApiService claudeApi, IFindingsService findings, ILogger<InsightService> logger)
    {
        _config = config;
        _claudeApi = claudeApi;
        _findings = findings;
        _logger = logger;
    }

    public async Task GenerateInsightsForAuditAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.OpenAsync();

        // Denetim bilgilerini al
        var audit = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "SELECT Id, LocationName, AuditDate FROM Audits WHERE Id = @Id AND IsFinalized = 1",
            new { Id = auditId });
        if (audit == null) return;

        // FindingsService uzerinden zenginlestirilmis bulgulari al
        var failedFindings = await _findings.GetFailedByAuditIdAsync(auditId);
        if (failedFindings.Count == 0) return;

        var insights = new List<AiAnalysis>();

        // === KURAL TABANLI INSIGHT'LAR ===

        foreach (var finding in failedFindings)
        {
            // Kritik tekrar uyarisi (3+ kez tekrar)
            if (finding.RepeatCount >= 3)
            {
                insights.Add(new AiAnalysis
                {
                    EntityType = "AuditResult",
                    EntityId = finding.Id,
                    AnalysisType = "RepeatAlert",
                    InputData = JsonSerializer.Serialize(new { finding.AuditItemId, finding.ItemText, finding.RepeatCount, finding.LocationName }),
                    Result = $"{finding.ItemText} maddesi {finding.LocationName} lokasyonunda {finding.RepeatCount} kez tekrarladi.",
                    Summary = $"Kritik Tekrar: {finding.ItemText} ({finding.RepeatCount}x)",
                    Confidence = 1.0m,
                    Severity = finding.RepeatCount >= 5 ? "Critical" : "High",
                    IsActionable = true,
                    ActionTaken = false
                });
            }

            // Sistemik sorun uyarisi
            if (finding.IsSystemic)
            {
                insights.Add(new AiAnalysis
                {
                    EntityType = "AuditResult",
                    EntityId = finding.Id,
                    AnalysisType = "SystemicAlert",
                    InputData = JsonSerializer.Serialize(new { finding.AuditItemId, finding.ItemText }),
                    Result = $"{finding.ItemText} maddesi 3+ farkli lokasyonda basarisiz - sistemik sorun.",
                    Summary = $"Sistemik Sorun: {finding.ItemText}",
                    Confidence = 1.0m,
                    Severity = "Critical",
                    IsActionable = true,
                    ActionTaken = false
                });
            }

            // Yuksek risk eskalasyonu (Finding.EscalatedRiskScore computed property kullaniliyor)
            if (finding.EscalatedRiskScore > 20)
            {
                insights.Add(new AiAnalysis
                {
                    EntityType = "AuditResult",
                    EntityId = finding.Id,
                    AnalysisType = "RiskEscalation",
                    InputData = JsonSerializer.Serialize(new { finding.AuditItemId, finding.RiskScore, finding.EscalatedRiskScore, finding.RepeatCount, finding.IsSystemic }),
                    Result = $"{finding.ItemText}: Orijinal risk {finding.RiskScore}, eskalasyon sonrasi {finding.EscalatedRiskScore:F1}. Acil mudahale gerekli.",
                    Summary = $"Risk Eskalasyonu: {finding.ItemText} ({finding.RiskScore} -> {finding.EscalatedRiskScore:F1})",
                    Confidence = 1.0m,
                    Severity = "Critical",
                    IsActionable = true,
                    ActionTaken = false
                });
            }

            // Etkisiz DOF uyarisi (Finding.HasIneffectiveDof computed property)
            if (finding.HasIneffectiveDof)
            {
                foreach (var dof in finding.RelatedDofs.Where(d => d.IsEffective == false))
                {
                    insights.Add(new AiAnalysis
                    {
                        EntityType = "CorrectiveAction",
                        EntityId = dof.Id,
                        AnalysisType = "IneffectiveDofAlert",
                        InputData = JsonSerializer.Serialize(new { DofId = dof.Id, dof.Title, finding.ItemText }),
                        Result = $"DOF '{dof.Title}' etkisiz: ilgili sorun ({finding.ItemText}) tekrarladi.",
                        Summary = $"Etkisiz DOF: {dof.Title}",
                        Confidence = 1.0m,
                        Severity = "High",
                        IsActionable = true,
                        ActionTaken = false
                    });
                }
            }
        }

        // === AI DESTEKLI INSIGHT (Claude API aktifse) ===
        if (_claudeApi.IsConfigured && failedFindings.Count > 0)
        {
            try
            {
                var aiInsight = await GenerateAiPatternAnalysisAsync(audit, failedFindings);
                if (aiInsight != null)
                    insights.Add(aiInsight);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "AI pattern analizi basarisiz. Kural-tabanli insight'lar yeterli.");
            }
        }

        // Tum insight'lari kaydet
        if (insights.Count > 0)
        {
            // Ayni denetim icin daha once uretilmis insight'lari temizle (re-run durumu)
            await conn.ExecuteAsync(
                @"DELETE FROM AiAnalyses
                  WHERE EntityId IN (SELECT Id FROM AuditResults WHERE AuditId = @AuditId)
                    AND EntityType IN ('AuditResult', 'CorrectiveAction')
                    AND AnalysisType IN ('RepeatAlert', 'SystemicAlert', 'RiskEscalation', 'IneffectiveDofAlert', 'PatternAnalysis')",
                new { AuditId = auditId });
            // Audit-level insights da temizle
            await conn.ExecuteAsync(
                @"DELETE FROM AiAnalyses WHERE EntityType = 'Audit' AND EntityId = @AuditId AND AnalysisType = 'PatternAnalysis'",
                new { AuditId = auditId });

            foreach (var insight in insights)
            {
                await conn.ExecuteAsync(
                    @"INSERT INTO AiAnalyses (EntityType, EntityId, AnalysisType, InputData, Result, Summary, Confidence, Severity, IsActionable, ActionTaken)
                      VALUES (@EntityType, @EntityId, @AnalysisType, @InputData, @Result, @Summary, @Confidence, @Severity, @IsActionable, @ActionTaken)",
                    insight);
            }

            _logger.LogInformation("Denetim #{AuditId} icin {Count} insight uretildi.", auditId, insights.Count);
        }
    }

    public async Task<List<AiAnalysis>> GetRecentInsightsAsync(int count = 20)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<AiAnalysis>(
            "SELECT TOP (@Count) * FROM AiAnalyses ORDER BY CreatedAt DESC",
            new { Count = count })).ToList();
    }

    public async Task<List<AiAnalysis>> GetActionableInsightsAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        return (await conn.QueryAsync<AiAnalysis>(
            "SELECT * FROM AiAnalyses WHERE IsActionable = 1 AND ActionTaken = 0 ORDER BY CreatedAt DESC"
        )).ToList();
    }

    public async Task MarkActionTakenAsync(int insightId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            "UPDATE AiAnalyses SET ActionTaken = 1 WHERE Id = @Id",
            new { Id = insightId });
    }

    /// <summary>
    /// Claude API ile pattern analizi yapar.
    /// FindingsService'ten gelen zenginlestirilmis bulgulari kullanir.
    /// </summary>
    private async Task<AiAnalysis?> GenerateAiPatternAnalysisAsync(dynamic audit, List<Finding> findings)
    {
        // Skill context'i al (varsa)
        var skillContext = await GetSkillContextAsync((int)audit.Id);

        var systemPrompt = skillContext ?? @"Sen BKMKitap iç denetim AI asistanısın.
Görevin: Denetim bulgularını analiz etmek, pattern'leri tespit etmek ve aksiyon önerileri sunmak.
Kısa ve öz yanıt ver. Türkçe yanıt ver.";

        var findingsSummary = string.Join("\n", findings.Select(f =>
            $"- [{f.Area}/{f.AuditGroup}] {f.ItemText} (Risk: {f.RiskScore}, Eskalasyon: {f.EscalatedRiskScore:F1}, Tekrar: {f.RepeatCount}x, Sistemik: {f.IsSystemic}, DOF: {f.RelatedDofs.Count} adet{(f.HasIneffectiveDof ? " [ETKISIZ]" : "")})"));

        var userMessage = $@"Lokasyon: {audit.LocationName}
Denetim Tarihi: {((DateTime)audit.AuditDate):dd.MM.yyyy}
Toplam Basarisiz Bulgu: {findings.Count}

Bulgular:
{findingsSummary}

Analiz et:
1. En kritik 3 sorunu belirle
2. Ortak kok nedenleri tespit et
3. Her sorun icin somut aksiyon oner
4. Genel risk degerlendirmesi yap";

        var aiResult = await _claudeApi.AnalyzeAsync(systemPrompt, userMessage);

        if (string.IsNullOrEmpty(aiResult) || aiResult.StartsWith("[AI"))
            return null;

        return new AiAnalysis
        {
            EntityType = "Audit",
            EntityId = (int)audit.Id,
            AnalysisType = "PatternAnalysis",
            InputData = JsonSerializer.Serialize(new { Location = (string)audit.LocationName, FailedCount = findings.Count }),
            Result = aiResult,
            Summary = $"AI Pattern Analizi: {audit.LocationName} - {findings.Count} bulgu",
            Confidence = 0.85m,
            Severity = findings.Count >= 5 ? "High" : "Medium",
            IsActionable = true,
            ActionTaken = false
        };
    }

    /// <summary>Denetimin skill'ine ait AiPromptContext'i getirir.</summary>
    private async Task<string?> GetSkillContextAsync(int auditId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QuerySingleOrDefaultAsync<string?>(
            @"SELECT TOP 1 sv.AiPromptContext
              FROM AuditResults ar
              INNER JOIN AuditItems ai ON ai.Id = ar.AuditItemId
              INNER JOIN SkillVersions sv ON sv.SkillId = ai.SkillId
              WHERE ar.AuditId = @AuditId
                AND sv.EffectiveFrom <= GETDATE()
                AND (sv.EffectiveTo IS NULL OR sv.EffectiveTo > GETDATE())
                AND sv.AiPromptContext IS NOT NULL
              ORDER BY sv.VersionNo DESC",
            new { AuditId = auditId });
    }
}
