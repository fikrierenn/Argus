using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dapper;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public sealed class AiWorkerService : BackgroundService
{
    private const int MaxErrorLength = 2000;
    private readonly Db _db;
    private readonly EmbeddingService _embedding;
    private readonly SemanticMemoryService _semantic;
    private readonly LlmService _llm;
    private readonly LmRules _rules;
    private readonly AiWorkerOptions _options;
    private readonly ILogger<AiWorkerService> _logger;
    private DateTime _lastVectorSyncUtc = DateTime.MinValue;

    public AiWorkerService(
        Db db,
        EmbeddingService embedding,
        SemanticMemoryService semantic,
        LlmService llm,
        LmRules rules,
        IOptions<AiWorkerOptions> options,
        ILogger<AiWorkerService> logger)
    {
        _db = db;
        _embedding = embedding;
        _semantic = semantic;
        _llm = llm;
        _rules = rules;
        _options = options.Value;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await SyncVectorsIfNeededAsync(stoppingToken);
            await ProcessQueueAsync(stoppingToken);
            await ProcessLlmQueueAsync(stoppingToken);
            _logger.LogInformation("AI Worker cycle completed.");
            await Task.Delay(TimeSpan.FromSeconds(_options.PollSeconds), stoppingToken);
        }
    }

    private async Task ProcessQueueAsync(CancellationToken token)
    {
        await using var connection = _db.CreateConnection();

        const string sql = @"
;WITH cte AS (
    SELECT TOP (@Top) *
    FROM ai.AnalysisQueue WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE Status IN ('NEW', 'BEKLEMEDE')
    ORDER BY Priority DESC, CreatedAt
)
UPDATE cte
SET Status = 'LM_RUNNING',
    RetryCount = RetryCount + 1,
    LastRetryAt = SYSDATETIME(),
    UpdatedAt = SYSDATETIME()
OUTPUT
    inserted.RequestId,
    inserted.SnapshotDate,
    inserted.PeriodCode,
    inserted.LocationId,
    inserted.ProductId,
    inserted.SourceType,
    inserted.SourceKey,
    inserted.Priority,
    inserted.Status,
    inserted.CreatedAt;";

        var requests = (await connection.QueryAsync<AnalysisQueueRow>(sql, new { Top = _options.BatchSize })).ToList();

        if (requests.Count == 0)
        {
            _logger.LogInformation("No new AI requests to process.");
            return;
        }

        foreach (var row in requests)
        {
            try
            {
                var risk = await connection.QuerySingleOrDefaultAsync<RiskSummaryRow>(
                    "ai.sp_RiskSummary_Get",
                    new
                    {
                        KesimTarihi = row.SnapshotDate ?? (object)DBNull.Value,
                        DonemKodu = row.PeriodCode,
                        MekanId = row.LocationId,
                        StokId = row.ProductId
                    },
                    commandType: CommandType.StoredProcedure);

                if (risk is null)
                {
                    await MarkErrorAsync(connection, row.RequestId ?? 0, "Risk record not found.");
                    continue;
                }

                var decision = _rules.Decide(risk);
                var riskText = BuildRiskText(risk);
                var match = await _semantic.FindBestMatchAsync(riskText, token);
                if (match is not null && match.IsCritical)
                {
                    var percent = Math.Round(match.Similarity * 100);
                    var note = $"Bu risk, geçmişteki ID:{match.SourceId} nolu '{match.Title}' olayına %{percent} benziyor.";
                    decision = decision with
                    {
                        PriorityScore = 100,
                        LlmRequired = true,
                        SemanticNote = note
                    };
                }

                await UpsertRuleResultAsync(connection, row.RequestId ?? 0, decision);

                var newStatus = decision.LlmRequired ? "LLM_QUEUED" : "LM_DONE";
                await connection.ExecuteAsync(
                    "UPDATE ai.AnalysisQueue SET Status = @Status, EvidencePlan = @EvidencePlan, RuleNote = @RuleNote, UpdatedAt = SYSDATETIME() WHERE RequestId = @RequestId",
                    new
                    {
                        RequestId = row.RequestId ?? 0,
                        Status = newStatus,
                        EvidencePlan = decision.EvidencePlan,
                        RuleNote = decision.SemanticNote
                    });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "AI request processing failed. RequestId={RequestId}", row.RequestId);
                await MarkErrorAsync(connection, row.RequestId ?? 0, FormatException("LM request processing failed", ex));
            }
        }
    }

    private async Task SyncVectorsIfNeededAsync(CancellationToken token)
    {
        if (!_embedding.IsReady)
        {
            return;
        }

        var now = DateTime.UtcNow;
        if ((now - _lastVectorSyncUtc).TotalMinutes < _options.VectorSyncMinutes)
        {
            return;
        }

        _lastVectorSyncUtc = now;
        await using var connection = _db.CreateConnection();
        var sources = await connection.QueryAsync<DofRecordRow>(
            "ai.sp_SemanticVector_SourceList",
            new { Top = 200 },
            commandType: CommandType.StoredProcedure);

        foreach (var source in sources)
        {
            if (token.IsCancellationRequested)
            {
                break;
            }

            var text = BuildDofText(source);
            var vector = await _embedding.TryEmbedAsync(text, token);
            if (vector is null || vector.Length == 0)
            {
                continue;
            }

            var critical = source.RiskSeviyesi >= 3;
            var summary = string.IsNullOrWhiteSpace(source.Aciklama) ? source.Baslik : $"{source.Baslik}. {source.Aciklama}";
            if (summary.Length > 500)
            {
                summary = summary[..500];
            }

            await connection.ExecuteAsync(
                "ai.sp_SemanticVector_Upsert",
                new
                {
                    RiskId = source.DofId,
                    DofId = source.DofId,
                    Baslik = source.Baslik,
                    OzetMetin = summary,
                    KritikMi = critical,
                    VektorJson = JsonSerializer.Serialize(vector)
                },
                commandType: CommandType.StoredProcedure);
        }

        await SyncDocVectorsAsync(connection, token);
    }

    private static string BuildRiskText(RiskSummaryRow risk)
    {
        return $"Mekan:{risk.MekanAd}; Ürün:{risk.UrunAd}; Skor:{risk.RiskScore}; Yorum:{risk.RiskComment}";
    }

    private static string BuildDofText(DofRecordRow dof)
    {
        return $"DÖF:{dof.Baslik}; Açıklama:{dof.Aciklama}; Kaynak:{dof.KaynakAnahtar}";
    }

    private async Task SyncDocVectorsAsync(IDbConnection connection, CancellationToken token)
    {
        if (!_options.DocsEnabled)
        {
            return;
        }

        var docsRoot = ResolveDocsRoot();
        if (string.IsNullOrWhiteSpace(docsRoot))
        {
            return;
        }

        foreach (var file in Directory.EnumerateFiles(docsRoot, "*.md", SearchOption.AllDirectories))
        {
            if (token.IsCancellationRequested)
            {
                break;
            }

            string content;
            try
            {
                content = await File.ReadAllTextAsync(file, token);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Document could not be read. File={File}", file);
                continue;
            }

            if (string.IsNullOrWhiteSpace(content))
            {
                continue;
            }

            var clean = NormalizeDocText(content, _options.DocsMaxChars);
            var vector = await _embedding.TryEmbedAsync(clean, token);
            if (vector is null || vector.Length == 0)
            {
                continue;
            }

            var riskId = ComputeDocRiskId(docsRoot, file);
            var title = $"DOC:{Path.GetFileName(file)}";
            var snippet = TrimTo(clean, _options.DocsSnippetChars);

            await connection.ExecuteAsync(
                "ai.sp_SemanticVector_Upsert",
                new
                {
                    RiskId = riskId,
                    DofId = (long?)null,
                    Baslik = title,
                    OzetMetin = snippet,
                    KritikMi = false,
                    VektorJson = JsonSerializer.Serialize(vector)
                },
                commandType: CommandType.StoredProcedure);
        }
    }

    private string? ResolveDocsRoot()
    {
        if (string.IsNullOrWhiteSpace(_options.DocsPath))
        {
            return FindDocsRoot();
        }

        var path = Path.IsPathRooted(_options.DocsPath)
            ? _options.DocsPath
            : Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), _options.DocsPath));

        return Directory.Exists(path) ? path : FindDocsRoot();
    }

    private static string? FindDocsRoot()
    {
        var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "docs");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        return null;
    }

    private static long ComputeDocRiskId(string docsRoot, string file)
    {
        var relative = Path.GetRelativePath(docsRoot, file).Replace('\\', '/').ToLowerInvariant();
        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(relative));
        var value = BitConverter.ToInt64(hash, 0);
        if (value == 0)
        {
            value = 1;
        }

        return value > 0 ? -value : value;
    }

    private static string NormalizeDocText(string content, int maxChars)
    {
        var text = content.Replace("\r", " ").Replace("\n", " ").Trim();
        if (maxChars > 0 && text.Length > maxChars)
        {
            text = text[..maxChars];
        }

        return text;
    }

    private static string TrimTo(string text, int maxChars)
    {
        if (maxChars <= 0)
        {
            return string.Empty;
        }

        return text.Length <= maxChars ? text : text[..maxChars];
    }

    private async Task ProcessLlmQueueAsync(CancellationToken token)
    {
        if (!_options.LlmEnabled)
        {
            return;
        }

        const string sql = @"
;WITH cte AS (
    SELECT TOP (@Top) *
    FROM ai.AnalysisQueue WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE Status = 'LLM_QUEUED'
    ORDER BY Priority DESC, CreatedAt
)
UPDATE cte
SET Status = 'LLM_RUNNING',
    UpdatedAt = SYSDATETIME()
OUTPUT
    inserted.RequestId,
    inserted.SnapshotDate,
    inserted.PeriodCode,
    inserted.LocationId,
    inserted.ProductId,
    inserted.EvidencePlan,
    inserted.EvidenceJson,
    inserted.RuleNote;";

        await using var connection = _db.CreateConnection();
        var requests = await connection.QueryAsync<AnalysisQueueLlmRow>(sql, new { Top = _options.BatchSize });

        foreach (var row in requests)
        {
            try
            {
                var risk = await connection.QuerySingleOrDefaultAsync<RiskSummaryRow>(
                    "ai.sp_RiskSummary_Get",
                    new
                    {
                        KesimTarihi = row.SnapshotDate ?? (object)DBNull.Value,
                        DonemKodu = row.PeriodCode,
                        MekanId = row.LocationId,
                        StokId = row.ProductId
                    },
                    commandType: CommandType.StoredProcedure);

                if (risk is null)
                {
                    await MarkErrorAsync(connection, row.RequestId, "Risk record not found (LLM).");
                    continue;
                }

                var riskText = BuildRiskText(risk);
                var evidenceMatches = await _semantic.FindTopEvidenceAsync(riskText, 3, token);
                var evidenceNote = FormatEvidenceMatches(evidenceMatches);
                var prompt = BuildAdvancedLlmPrompt(risk, row, evidenceNote);
                var call = await _llm.GenerateAsync(prompt, token);
                if (!call.Success || call.Result is null)
                {
                    var error = string.IsNullOrWhiteSpace(call.Error) ? "LLM response could not be obtained." : call.Error;
                    await MarkErrorAsync(connection, row.RequestId, error);
                    continue;
                }

                await UpsertLlmResultAsync(connection, row.RequestId, call.Result);

                await connection.ExecuteAsync(
                    "UPDATE ai.AnalysisQueue SET Status = @Status, UpdatedAt = SYSDATETIME() WHERE RequestId = @RequestId",
                    new { RequestId = row.RequestId, Status = "LLM_DONE" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "LLM request processing failed. RequestId={RequestId}", row.RequestId);
                await MarkErrorAsync(connection, row.RequestId, FormatException("LLM request processing failed", ex));
            }
        }
    }

    private static string BuildAdvancedLlmPrompt(RiskSummaryRow risk, AnalysisQueueLlmRow row, string evidenceNote)
    {
        var flags = $"VeriKalite={risk.FlagDataQuality}; GirişsizSatış={risk.FlagSalesWithoutEntry}; ÖlüStok={risk.FlagDeadStock}; " +
                    $"NetBirikim={risk.FlagNetAccumulation}; İadeYüksek={risk.FlagHighReturn}; BozukİadeYüksek={risk.FlagHighDamagedReturn}; " +
                    $"SayımDüzeltme={risk.FlagHighCountAdjustment}; ŞirketİçiYüksek={risk.FlagHighInternalUse}; HızlıDevir={risk.FlagFastTurnover}; " +
                    $"SatışYaşlanma={risk.FlagSalesAging}";

        var ruleNote = string.IsNullOrWhiteSpace(row.RuleNote) ? "-" : row.RuleNote;
        var evidence = string.IsNullOrWhiteSpace(row.EvidenceJson) ? "-" : row.EvidenceJson;

        var sb = new StringBuilder();

        // System prompt
        sb.AppendLine("<|system|>");
        sb.AppendLine("Sen BKM (Bankalararası Kart Merkezi) denetim uzmanısın.");
        sb.AppendLine("15+ yıllık denetim tecrüben var ve özellikle stok manipülasyonu, sahtekarlık ve iç kontrol zafiyetleri konusunda uzmansın.");
        sb.AppendLine("Riskleri analiz ederken aşağıdaki prensiplere uymalısın:");
        sb.AppendLine("1. Her hipotez için en az 2 kanıt gerekçesi sun");
        sb.AppendLine("2. SQL sorguları pratik ve executable olsun");
        sb.AppendLine("3. Aksiyonlar maliyet-fayda analizi dikkate alsın");
        sb.AppendLine("4. Confidence score 0-100 arası olsun ve gerçekçi olsun");
        sb.AppendLine("5. Türkçe olarak yanıt ver ama teknik terimleri koru");
        sb.AppendLine("<|/system|>");
        sb.AppendLine();

        // Examples - Few-shot learning
        sb.AppendLine("<|examples|>");
        sb.AppendLine("Example 1:");
        sb.AppendLine("Input: Mekan:İstanbul Merkez; Ürün:POS Terminali; Skor:95; FlagNetBirikim=true");
        sb.AppendLine("Output:");
        sb.AppendLine(@"{
  ""rootCauseHypotheses"": [""Stok manipülasyonu - muhtemel sahte giriş""],
  ""validationSteps"": [{""title"":""Giriş fişlerini kontrol et"",""sql_or_action"":""SELECT * FROM src.vw_StokHareket WHERE MekanId=1 AND TipId IN (1,2) AND Tarih BETWEEN '2024-01-01' AND '2024-01-31'"",""expectedFinding"": ""Anormal giriş paterni""}],
  ""confidence"": 85
}");
        sb.AppendLine("<|/examples|>");
        sb.AppendLine();

        // Current Task
        sb.AppendLine("<|task|>");
        sb.AppendLine("Aşağıdaki risk durumunu analiz et:");
        sb.AppendLine($"Risk Context: {BuildDetailedRiskContext(risk)}");
        sb.AppendLine($"Evidence: {evidenceNote}");
        sb.AppendLine($"Historical Similarities: {ruleNote}");
        sb.AppendLine();
        sb.AppendLine("Output format (SADECE JSON):");
        sb.AppendLine(GetJsonSchema());
        sb.AppendLine("<|/task|>");

        return sb.ToString();
    }

    private static string BuildDetailedRiskContext(RiskSummaryRow risk)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"Tarih: {risk.SnapshotDate?.ToString("yyyy-MM-dd") ?? "Belirsiz"}");
        sb.AppendLine($"Dönem: {risk.PeriodCode}");
        sb.AppendLine($"Mekan: {risk.MekanAd} (ID: {risk.LocationId})");
        sb.AppendLine($"Ürün: {risk.UrunAd} ({risk.UrunKod}) - ID: {risk.ProductId}");
        sb.AppendLine($"Risk Skoru: {risk.RiskScore}/100");
        sb.AppendLine($"Yorum: {risk.RiskComment ?? "Yok"}");
        sb.AppendLine($"Veri Kalite Sorunu: {(risk.FlagDataQuality ? "Evet" : "Hayır")}");
        sb.AppendLine($"Girişsiz Satış: {(risk.FlagSalesWithoutEntry ? "Evet" : "Hayır")}");
        sb.AppendLine($"Ölü Stok: {(risk.FlagDeadStock ? "Evet" : "Hayır")}");
        sb.AppendLine($"Net Birikim: {(risk.FlagNetAccumulation ? "Evet" : "Hayır")}");
        sb.AppendLine($"Yüksek İade: {(risk.FlagHighReturn ? "Evet" : "Hayır")}");
        sb.AppendLine($"Bozuk İade: {(risk.FlagHighDamagedReturn ? "Evet" : "Hayır")}");
        sb.AppendLine($"Sayım Düzeltme: {(risk.FlagHighCountAdjustment ? "Evet" : "Hayır")}");
        sb.AppendLine($"Şirket İçi Kullanım: {(risk.FlagHighInternalUse ? "Evet" : "Hayır")}");
        sb.AppendLine($"Hızlı Devir: {(risk.FlagFastTurnover ? "Evet" : "Hayır")}");
        sb.AppendLine($"Satış Yaşlanma: {(risk.FlagSalesAging ? "Evet" : "Hayır")}");
        return sb.ToString();
    }

    private static string GetJsonSchema()
    {
        return @"{
  ""rootCauseHypotheses"": [""Hipotez 1"", ""Hipotez 2""],
  ""validationSteps"": [
    {
      ""title"": ""Doğrulama adımı başlığı"",
      ""sql_or_action"": ""SQL sorgusu veya eylem"",
      ""expectedFinding"": ""Beklenen bulgu""
    }
  ],
  ""recommendedActions"": [""Aksiyon 1"", ""Aksiyon 2""],
  ""dofDraft"": {
    ""Baslik"": ""DÖF başlığı"",
    ""Ozet"": ""Özet açıklama"",
    ""KokNedenSinifi"": ""Stok_Sahtekarligi"",
    ""Aksiyonlar"": [""Aksiyon 1""],
    ""KanitOzet"": [""Kanıt 1""]
  },
  ""executiveSummary"": [""Özet madde 1"", ""Özet madde 2"", ""Özet madde 3""],
  ""confidence"": 75
}";
    }

    private static string FormatEvidenceMatches(IReadOnlyList<SemanticMatch> matches)
    {
        if (matches.Count == 0)
        {
            return "-";
        }

        return string.Join("; ", matches.Select(m =>
        {
            var percent = Math.Round(m.Similarity * 100);
            return $"{m.Title} (%{percent})";
        }));
    }

    private static Task UpsertLlmResultAsync(IDbConnection connection, long requestId, LlmResultRow result)
    {
        const string sql = @"
MERGE ai.LlmResults AS t
USING (SELECT @RequestId AS RequestId) AS s
ON t.RequestId = s.RequestId
WHEN MATCHED THEN
    UPDATE SET
        ModelName = @ModelName,
        PromptVersion = @PromptVersion,
        RootCauseHypotheses = @RootCauseHypotheses,
        VerificationSteps = @VerificationSteps,
        RecommendedActions = @RecommendedActions,
        DofDraftJson = @DofDraftJson,
        ExecutiveSummary = @ExecutiveSummary,
        ConfidenceScore = @ConfidenceScore,
        CreatedAt = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (RequestId, ModelName, PromptVersion, RootCauseHypotheses, VerificationSteps, RecommendedActions, DofDraftJson, ExecutiveSummary, ConfidenceScore, CreatedAt)
    VALUES (@RequestId, @ModelName, @PromptVersion, @RootCauseHypotheses, @VerificationSteps, @RecommendedActions, @DofDraftJson, @ExecutiveSummary, @ConfidenceScore, SYSDATETIME());";

        return connection.ExecuteAsync(sql, new
        {
            RequestId = requestId,
            result.ModelName,
            result.PromptVersion,
            result.RootCauseHypotheses,
            result.VerificationSteps,
            result.RecommendedActions,
            result.DofDraftJson,
            ExecutiveSummary = result.ExecutiveSummary ?? result.RawJson,
            result.ConfidenceScore
        });
    }

    private static Task UpsertRuleResultAsync(IDbConnection connection, long requestId, RuleDecision decision)
    {
        const string sql = @"
MERGE ai.RuleResults AS t
USING (SELECT @RequestId AS RequestId) AS s
ON t.RequestId = s.RequestId
WHEN MATCHED THEN
    UPDATE SET
        RootCauseClass = @RootCauseClass,
        EvidencePlan = @EvidencePlan,
        LlmRequired = @LlmRequired,
        PriorityScore = @PriorityScore,
        BriefSummary = @BriefSummary,
        FeatureJson = @FeatureJson,
        RuleSetVersion = @RuleSetVersion,
        CreatedAt = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (RequestId, RootCauseClass, EvidencePlan, LlmRequired, PriorityScore, BriefSummary, FeatureJson, RuleSetVersion, CreatedAt)
    VALUES (@RequestId, @RootCauseClass, @EvidencePlan, @LlmRequired, @PriorityScore, @BriefSummary, @FeatureJson, @RuleSetVersion, SYSDATETIME());";

        return connection.ExecuteAsync(sql, new
        {
            RequestId = requestId,
            decision.RootCauseClass,
            decision.EvidencePlan,
            decision.LlmRequired,
            decision.PriorityScore,
            decision.BriefSummary,
            decision.FeatureJson,
            RuleSetVersion = "v1"
        });
    }

    private static Task MarkErrorAsync(IDbConnection connection, long requestId, string error)
    {
        var safe = TrimError(error);
        return connection.ExecuteAsync(
            "UPDATE ai.AnalysisQueue SET Status = @Status, ErrorMessage = @ErrorMessage, UpdatedAt = SYSDATETIME() WHERE RequestId = @RequestId",
            new { RequestId = requestId, Status = "ERROR", ErrorMessage = safe });
    }

    private static string TrimError(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return "Unknown error.";
        }

        var clean = message.Replace("\r", " ").Replace("\n", " ").Trim();
        return clean.Length <= MaxErrorLength ? clean : clean[..MaxErrorLength];
    }

    private static string FormatException(string context, Exception ex)
    {
        var detail = $"{ex.GetType().Name}: {ex.Message}";
        return string.IsNullOrWhiteSpace(context) ? detail : $"{context}. {detail}";
    }
}
