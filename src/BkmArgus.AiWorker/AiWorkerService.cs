using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BkmArgus.AiWorker.Skills;
using Dapper;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public sealed class AiWorkerService : BackgroundService
{
    private const int MaxErrorLength = 2000;
    private readonly Db _db;
    private readonly LocalEmbeddingService _embedding;
    private readonly SemanticMemoryService _semantic;
    private readonly LlmService _llm;
    private readonly LmRules _rules;
    private readonly AiWorkerOptions _options;
    private readonly ILogger<AiWorkerService> _logger;
    private readonly IServiceProvider _serviceProvider;
    // LM kural setinin surumu — kural mantigi degisince artirilir,
    // boylece eski ciktinin hangi kural setiyle uretildigi izlenebilir kalir.
    private const string RuleSetVersion = "v1";

    private DateTime _lastVectorSyncUtc = DateTime.UtcNow;

    public AiWorkerService(
        Db db,
        LocalEmbeddingService embedding,
        SemanticMemoryService semantic,
        LlmService llm,
        LmRules rules,
        IOptions<AiWorkerOptions> options,
        ILogger<AiWorkerService> logger,
        IServiceProvider serviceProvider)
    {
        _db = db;
        _embedding = embedding;
        _semantic = semantic;
        _llm = llm;
        _rules = rules;
        _options = options.Value;
        _logger = logger;
        _serviceProvider = serviceProvider;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await TriggerPostRiskEtlAsync(stoppingToken);
            }
            catch (Exception ex) { _logger.LogWarning(ex, "PostRiskEtl tetigi basarisiz, atlaniyor"); }

            try
            {
                await SyncVectorsIfNeededAsync(stoppingToken);
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Vektor senkronu basarisiz, atlaniyor"); }

            try
            {
                await ProcessQueueAsync(stoppingToken);
            }
            catch (Exception ex) { _logger.LogWarning(ex, "LM kuyrugu islenemedi, atlaniyor"); }

            try
            {
                await ProcessLlmQueueAsync(stoppingToken);
            }
            catch (Exception ex) { _logger.LogWarning(ex, "LLM kuyrugu islenemedi, atlaniyor"); }

            try
            {
                await ProcessSkillQueueAsync(stoppingToken);
            }
            catch (Exception ex) { _logger.LogError(ex, "Skill kuyrugu islenemedi"); }

            _logger.LogInformation("AI Worker dongusu tamamlandi.");
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

                // Kural sonucuna gore kuyruk durumu: LLM gerekiyorsa siraya, gerekmiyorsa kapat
                var newStatus = decision.LlmRequired ? "LLM_QUEUED" : "LM_DONE";
                await connection.ExecuteAsync(
                    "ai.sp_AnalysisQueue_SetRuleOutcome",
                    new
                    {
                        IstekId    = row.RequestId ?? 0,
                        Durum      = newStatus,
                        KanitPlani = decision.EvidencePlan,
                        KuralNotu  = decision.SemanticNote
                    },
                    commandType: CommandType.StoredProcedure);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "AI request processing failed. RequestId={RequestId}", row.RequestId);
                await MarkErrorAsync(connection, row.RequestId ?? 0, FormatException("LM request processing failed", ex));
            }
        }
    }

    // Gunluk risk ETL'i sonrasi, esigi asan urunleri AI analiz kuyruguna alir.
    // SP idempotent (mekan+urun+gun+periyot bazinda NOT EXISTS korumasi), bu yuzden
    // her poll dongusunde guvenle cagrilabilir; ETL'in devasa SP'sine dokunmaya gerek yok.
    private async Task TriggerPostRiskEtlAsync(CancellationToken token)
    {
        if (!_options.PostRiskEtlTriggerEnabled)
        {
            return;
        }

        using var connection = _db.CreateConnection();
        var queued = await connection.ExecuteScalarAsync<int?>(
            new CommandDefinition(
                "ai.sp_Trigger_PostRiskEtl",
                new { RiskEsik = _options.PostRiskEtlRiskEsik },
                commandType: CommandType.StoredProcedure,
                cancellationToken: token));

        // Sifir da bir sonuctur — sessiz gecme (etl-discipline.md)
        if (queued is > 0)
        {
            _logger.LogInformation("PostRiskEtl: {Adet} yeni analiz istegi kuyruklandi.", queued);
        }
    }

    private async Task SyncVectorsIfNeededAsync(CancellationToken token)
    {
        if (!_options.SemanticMemoryEnabled)
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

        // Kaynak yalniz kapanmis DOF degil: acik bulgular, saha denetim sonuclari
        // ve gecmis AI analizleri de hafizaya girer. Her biri kendi agirligiyla
        // gelir (SP hesaplar) — dogrulanmis vaka ile ham gozlem esit sayilmaz.
        var sources = await connection.QueryAsync<VectorSourceRow>(
            new CommandDefinition(
                "ai.sp_SemanticVector_SourceList",
                new { Top = _options.VectorSyncBatchSize, ModelAdi = _embedding.ModelName },
                commandType: CommandType.StoredProcedure,
                cancellationToken: token));

        var written = 0;
        var skipped = 0;

        foreach (var source in sources)
        {
            if (token.IsCancellationRequested)
            {
                break;
            }

            var text = string.IsNullOrWhiteSpace(source.SummaryText) ? source.Title : source.SummaryText;

            // Arsivlenen metin "passage:" onekiyle gomulur; arama tarafi "query:" kullanir
            var vector = await _embedding.TryEmbedPassageAsync(text, token);
            if (vector is null || vector.Length == 0)
            {
                skipped++;
                continue;
            }

            await connection.ExecuteAsync(
                "ai.sp_SemanticVector_Upsert",
                new
                {
                    KaynakTipi = source.Source,
                    KaynakId   = source.SourceId,
                    DofId      = source.DofId,
                    Baslik     = Truncate(source.Title, 500),
                    OzetMetin  = Truncate(text, 4000),
                    Kritik     = source.IsCritical,
                    VektorJson = JsonSerializer.Serialize(vector),
                    Agirlik    = source.Weight,
                    ModelAdi   = _embedding.ModelName,
                    Boyut      = vector.Length
                },
                commandType: CommandType.StoredProcedure);

            written++;
        }

        // Sessiz senkron yasak — sifir da bir sonuctur
        if (written > 0 || skipped > 0)
        {
            _logger.LogInformation(
                "Semantik hafiza: {Yazilan} vektor yazildi, {Atlanan} atlandi ({Model}).",
                written, skipped, _embedding.ModelName);
        }

        await SyncGoldenVectorsAsync(connection, token);
    }

    private static string Truncate(string? value, int max)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        return value.Length <= max ? value : value[..max];
    }

    private async Task SyncGoldenVectorsAsync(IDbConnection connection, CancellationToken token)
    {
        if (!_embedding.IsReady)
        {
            return;
        }

        var approved = await connection.QueryAsync<ApprovedExample>(
            "ai.sp_Feedback_TopApproved",
            new { Top = 20 },
            commandType: CommandType.StoredProcedure);

        foreach (var item in approved)
        {
            if (token.IsCancellationRequested)
            {
                break;
            }

            if (string.IsNullOrWhiteSpace(item.ApprovedOutput))
            {
                continue;
            }

            var vector = await _embedding.TryEmbedPassageAsync(item.ApprovedOutput, token);
            if (vector is null || vector.Length == 0)
            {
                continue;
            }

            var title = $"GOLDEN:{item.SkillId}:{item.FeedbackId}";
            var summary = item.ApprovedOutput.Length > 500
                ? item.ApprovedOutput[..500]
                : item.ApprovedOutput;

            await connection.ExecuteAsync(
                "ai.sp_SemanticVector_UpsertGolden",
                new
                {
                    KaynakId   = (long)item.FeedbackId,
                    Baslik     = Truncate(title, 500),
                    OzetMetin  = Truncate(summary, 4000),
                    VektorJson = JsonSerializer.Serialize(vector),
                    ModelAdi   = _embedding.ModelName,
                    Boyut      = vector.Length,
                    Kritik     = false
                },
                commandType: CommandType.StoredProcedure);
        }
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
            var vector = await _embedding.TryEmbedPassageAsync(clean, token);
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

                // Few-shot: inject approved golden examples
                var approvedExamples = await connection.QueryAsync<ApprovedExample>(
                    "ai.sp_Feedback_TopApproved",
                    new { Top = 2 },
                    commandType: CommandType.StoredProcedure);
                var promptBuilder = new StringBuilder(prompt);
                foreach (var ex in approvedExamples)
                {
                    if (!string.IsNullOrWhiteSpace(ex.ApprovedOutput))
                    {
                        promptBuilder.AppendLine($"\n--- Onaylanmis Ornek ---\n{ex.ApprovedOutput}\n");
                    }
                }
                prompt = promptBuilder.ToString();

                var sw = System.Diagnostics.Stopwatch.StartNew();
                var call = await _llm.GenerateAsync(prompt, token);
                sw.Stop();

                if (!call.Success || call.Result is null)
                {
                    var error = string.IsNullOrWhiteSpace(call.Error) ? "LLM response could not be obtained." : call.Error;
                    await MarkErrorAsync(connection, row.RequestId, error);
                    continue;
                }

                await UpsertLlmResultAsync(connection, row.RequestId, call.Result, prompt, (int)sw.ElapsedMilliseconds);

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

    // LLM ciktisini kalici hale getirir. Inline MERGE yerine SP (SP-first).
    // Sayisal degerler LLM'den DEGIL deterministik katmandan gelir; burada
    // yalniz LLM'in urettigi anlati ve modelin kendi guven skoru saklanir.
    private static Task UpsertLlmResultAsync(
        IDbConnection connection, long requestId, LlmResultRow result, string prompt, int durationMs)
        => connection.ExecuteAsync(
            "ai.sp_LlmResult_Upsert",
            new
            {
                IstekId            = requestId,
                ModelAdi           = result.ModelName,
                SaglayiciAdi       = result.ProviderName,
                PromptSurumu       = result.PromptVersion,
                // Denetim izi: hangi prompt, hangi ham yanit, ne kadar surdu (TODO G1)
                PromptMetni        = prompt,
                SonucMetni         = result.RawJson,
                KokNedenHipotez    = result.RootCauseHypotheses,
                DogrulamaAdimlari  = result.VerificationSteps,
                OnerilenAksiyon    = result.RecommendedActions,
                DofTaslakJson      = result.DofDraftJson,
                YoneticiOzeti      = result.ExecutiveSummary ?? result.RawJson,
                GuvenSkoru         = result.ConfidenceScore,
                SureMs             = durationMs,
                BitisSebebi        = result.FinishReason
            },
            commandType: CommandType.StoredProcedure);

    private static Task UpsertRuleResultAsync(IDbConnection connection, long requestId, RuleDecision decision)
        => connection.ExecuteAsync(
            "ai.sp_RuleResult_Upsert",
            new
            {
                IstekId         = requestId,
                KokNedenSinifi  = decision.RootCauseClass,
                KanitPlani      = decision.EvidencePlan,
                LlmGerekli      = decision.LlmRequired,
                OncelikSkoru    = decision.PriorityScore,
                KisaOzet        = decision.BriefSummary,
                OzellikJson     = decision.FeatureJson,
                KuralSetiSurumu = RuleSetVersion
            },
            commandType: CommandType.StoredProcedure);

    private async Task ProcessSkillQueueAsync(CancellationToken token)
    {
        await using var connection = _db.CreateConnection();

        var pending = (await connection.QueryAsync<SkillExecutionQueueRow>(
            "ai.sp_SkillExecution_Pending",
            new { Top = _options.BatchSize },
            commandType: CommandType.StoredProcedure)).ToList();

        if (pending.Count == 0) return;
        _logger.LogInformation("Processing {Count} skill executions", pending.Count);

        using var scope = _serviceProvider.CreateScope();
        var skillExecutor = scope.ServiceProvider.GetRequiredService<SkillExecutor>();

        foreach (var item in pending)
        {
            try
            {
                var variables = await BuildSkillVariablesAsync(connection, item);
                var result = await skillExecutor.ExecuteAsync(item.SkillId, variables, token);

                await connection.ExecuteAsync(
                    "ai.sp_SkillExecution_Update",
                    new
                    {
                        item.ExecutionId,
                        Durum = result.Success ? "DONE" : "ERROR",
                        CiktiJson = result.Output,
                        ModelAdi = result.ModelName,
                        GuvenSkoru = result.ConfidenceScore,
                        HataMesaji = result.Error,
                        SurumNo = result.SkillVersionNo
                    },
                    commandType: CommandType.StoredProcedure);

                await connection.ExecuteAsync(@"
                    INSERT INTO log.Notifications (UserId, Type, Title, Message, Link, IsRead, CreatedAt)
                    VALUES (@UserId, @Type, @Title, @Message, @Link, 0, SYSDATETIME())",
                    new
                    {
                        UserId = item.RequestedByUserId,
                        Type = result.Success ? "AI_SKILL_DONE" : "AI_SKILL_ERROR",
                        Title = result.Success ? "AI Analiz Tamamlandi" : "AI Analiz Hatasi",
                        Message = result.Success
                            ? $"{item.SkillId} basariyla tamamlandi"
                            : $"{item.SkillId} hata: {result.Error}",
                        Link = $"/Ai/SkillResult?id={item.ExecutionId}"
                    });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Skill execution failed: {ExecutionId}", item.ExecutionId);
                await connection.ExecuteAsync(
                    "ai.sp_SkillExecution_Update",
                    new
                    {
                        item.ExecutionId,
                        Durum = "ERROR",
                        CiktiJson = (string?)null,
                        ModelAdi = (string?)null,
                        GuvenSkoru = (int?)null,
                        HataMesaji = TrimError(ex.Message)
                    },
                    commandType: CommandType.StoredProcedure);
            }
        }
    }

    /// <summary>
    /// sem.* katmanindan konuya uygun sema baglamini yukler ve
    /// {{SemantikBaglam}} degiskenine yazar.
    ///
    /// Konu, skill kimligi ve varlik tipinden turetilir; sem.sp_Context_Build
    /// coklu result set dondurur (ipuclari, varliklar, kopruler, metrikler,
    /// golden sorgular). Hepsi tek metne cevrilir cunku prompt template'i
    /// tek degisken bekler.
    ///
    /// Basarisiz olursa degisken BOS kalir ve skill yine calisir — semantik
    /// baglam bir iyilestirmedir, zorunluluk degil.
    /// </summary>
    /// <summary>
    /// Skill prompt degiskenlerini ai.sp_SkillContext_Build'den yukler.
    ///
    /// SP (Ad, Deger) satirlari dondurur; her satir bir prompt degiskenidir.
    /// Degisken adlarinin TEK tanim yeri o SP'dir — burada isim gecmez, boylece
    /// C# ile prompt sozlugu bir daha ayrisamaz.
    ///
    /// Basarisiz olursa eski yukleyicilerin doldurdugu kismi baglamla devam
    /// edilir; skill calismaya devam eder.
    /// </summary>
    private async Task AddSkillContextAsync(
        IDbConnection connection, SkillExecutionQueueRow item, Dictionary<string, string> variables)
    {
        try
        {
            var rows = await connection.QueryAsync<SkillContextRow>(
                "ai.sp_SkillContext_Build",
                new { SkillId = item.SkillId, VarlikTipi = item.EntityType, VarlikId = item.EntityId },
                commandType: CommandType.StoredProcedure);

            var sayac = 0;

            foreach (var row in rows)
            {
                if (string.IsNullOrWhiteSpace(row.Ad))
                {
                    continue;
                }

                variables[row.Ad] = row.Deger ?? string.Empty;
                sayac++;
            }

            _logger.LogInformation(
                "Skill baglami yuklendi: {Adet} degisken ({Skill}/{VarlikTipi}#{VarlikId}).",
                sayac, item.SkillId, item.EntityType, item.EntityId);
        }
        catch (Exception ex)
        {
            // Baglam eksik kalirsa skill yine calisir; sessiz gecmiyoruz
            _logger.LogWarning(ex, "Skill baglami yuklenemedi ({Skill}).", item.SkillId);
        }
    }

    /// <summary>ai.sp_SkillContext_Build satiri: bir prompt degiskeni.</summary>
    private sealed class SkillContextRow
    {
        public string Ad { get; init; } = string.Empty;
        public string? Deger { get; init; }
    }

    private async Task AddSemanticContextAsync(
        IDbConnection connection, SkillExecutionQueueRow item, Dictionary<string, string> variables)
    {
        try
        {
            var topic = string.Join(" ", new[]
            {
                item.SkillId,
                item.EntityType,
                variables.GetValueOrDefault("UrunAdi"),
                variables.GetValueOrDefault("MekanAdi"),
                variables.GetValueOrDefault("Baslik")
            }.Where(s => !string.IsNullOrWhiteSpace(s)));

            if (string.IsNullOrWhiteSpace(topic))
            {
                return;
            }

            using var grid = await connection.QueryMultipleAsync(
                "sem.sp_Context_Build",
                new { Konu = topic, MinGuven = 0.70m, TopHer = _options.SemanticContextTopPerSection },
                commandType: CommandType.StoredProcedure);

            var sections = new List<string>();

            while (!grid.IsConsumed)
            {
                var rows = (await grid.ReadAsync()).ToList();
                if (rows.Count == 0)
                {
                    continue;
                }

                foreach (var row in rows)
                {
                    // Result set sekilleri farkli; dinamik satiri ad: deger
                    // ciftlerine cevirip tek satira indiriyoruz.
                    var fields = ((IDictionary<string, object>)row)
                        .Where(kv => kv.Value is not null && !string.IsNullOrWhiteSpace(kv.Value.ToString()))
                        .Select(kv => $"{kv.Key}={kv.Value}");

                    sections.Add("- " + string.Join(" | ", fields));
                }
            }

            if (sections.Count == 0)
            {
                return;
            }

            var context = string.Join("\n", sections);

            // Prompt butcesini korumak icin ust sinir; kesilirse acikca belirt
            if (context.Length > _options.SemanticContextMaxChars)
            {
                context = context[.._options.SemanticContextMaxChars]
                          + "\n- (baglam kisaltildi)";
            }

            variables["SemantikBaglam"] = context;

            _logger.LogInformation(
                "Semantik baglam eklendi: {Satir} kayit, {Karakter} karakter ({Skill}).",
                sections.Count, context.Length, item.SkillId);
        }
        catch (Exception ex)
        {
            // Baglam yoksa skill yine calisir — sessiz gecmiyoruz ama durdurmuyoruz
            _logger.LogWarning(ex, "Semantik baglam yuklenemedi ({Skill}).", item.SkillId);
        }
    }

    private async Task<Dictionary<string, string>> BuildSkillVariablesAsync(IDbConnection connection, SkillExecutionQueueRow item)
    {
        var variables = new Dictionary<string, string>();

        // Parse InputJson first (can be overridden by DB context)
        if (!string.IsNullOrEmpty(item.InputJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<Dictionary<string, string>>(item.InputJson);
                if (json != null)
                    foreach (var kv in json) variables[kv.Key] = kv.Value;
            }
            catch { /* ignore malformed JSON */ }
        }

        // Load DB context based on EntityType
        try
        {
            switch (item.EntityType?.ToUpperInvariant())
            {
                case "DENETIM":
                    await LoadAuditContextAsync(connection, item.EntityId, variables);
                    break;
                case "DOF":
                    await LoadDofContextAsync(connection, item.EntityId, variables);
                    break;
                case "MEKAN":
                    await LoadLocationRiskContextAsync(connection, item.EntityId, variables);
                    break;
                case "URUN":
                    await LoadProductRiskContextAsync(connection, item.EntityId, variables);
                    break;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Skill baglami yuklenemedi ({VarlikTipi}/{VarlikId}) — kismi baglamla devam ediliyor.",
                item.EntityType, item.EntityId);
        }

        // Skill degisken sozlugu: ai.sp_SkillContext_Build TEK kaynak.
        // Yukaridaki eski yukleyiciler kendi adlandirmalariyla (failedItemsList,
        // productList...) kalir; SP'nin urettikleri onlarin UZERINE yazilir.
        // Sebep: prompt'lar ile yukleyiciler bagimsiz iki sozluk kullaniyordu ve
        // 47 degisken slotundan yalnizca 5'i doluyordu — LLM bos veriye bakip
        // "bulgu yok" diyordu. Artik adlar tek yerde tanimli.
        await AddSkillContextAsync(connection, item, variables);

        // Semantik katman: sema sozlugu ve LLM'in uyduramayacagi tuzaklar.
        // "stkKod barkod DEGIL", "urnTip=0 zorunlu", DMY tarih formati gibi
        // bilgiler yalnizca bilinebilir; modelin tahmin etmesi beklenemez.
        // Bu olmadan LLM makul gorunen ama yanlis sema uydurur.
        await AddSemanticContextAsync(connection, item, variables);

        return variables;
    }

    private static async Task LoadAuditContextAsync(IDbConnection connection, int auditId, Dictionary<string, string> vars)
    {
        var audit = await connection.QuerySingleOrDefaultAsync(
            "audit.sp_Audit_Get",
            new { AuditId = auditId },
            commandType: CommandType.StoredProcedure);

        if (audit == null) return;

        vars["locationName"] = (string)(audit.LocationName ?? "Bilinmiyor");
        vars["auditDate"] = ((DateTime?)audit.AuditDate)?.ToString("dd.MM.yyyy") ?? "-";
        vars["totalItems"] = ((int?)audit.TotalItems ?? 0).ToString();
        vars["failedItems"] = ((int?)audit.FailedItems ?? 0).ToString();

        var results = (await connection.QueryAsync(
            "SELECT AuditGroup, Area, ItemText, RiskLevel, RepeatCount, IsSystemic FROM audit.AuditResults WHERE AuditId=@AuditId AND IsPassed=0 ORDER BY RiskScore DESC",
            new { AuditId = auditId })).ToList();

        vars["failedItemsList"] = results.Count == 0
            ? "Basarisiz bulgu bulunamadi."
            : string.Join("\n", results.Select(r =>
                $"- [{r.AuditGroup}/{r.Area}] {r.ItemText} (Risk: {r.RiskLevel})"));

        var repeats = results.Where(r => (int)(r.RepeatCount ?? 0) > 1).ToList();
        vars["repeatItems"] = repeats.Count == 0
            ? "Tekrar eden madde yok."
            : string.Join("\n", repeats.Select(r =>
                $"- {r.ItemText} ({r.RepeatCount}x tekrar)"));

        vars["semanticContext"] = "";
    }

    private static async Task LoadDofContextAsync(IDbConnection connection, int dofId, Dictionary<string, string> vars)
    {
        var finding = await connection.QuerySingleOrDefaultAsync(
            "SELECT Title, Description, RiskLevel, Status FROM dof.Findings WHERE DofId=@DofId",
            new { DofId = dofId });

        if (finding == null) return;

        vars["findingTitle"] = (string)(finding.Title ?? "");
        vars["riskLevel"] = ((int?)finding.RiskLevel)?.ToString() ?? "3";
        vars["auditGroup"] = "";
        vars["area"] = (string)(finding.Description ?? "");
        vars["pastDofs"] = "";
        vars["similarCases"] = "";
    }

    private static async Task LoadLocationRiskContextAsync(IDbConnection connection, int locationId, Dictionary<string, string> vars)
    {
        var topProducts = (await connection.QueryAsync(
            "rpt.sp_RiskList",
            new { MekanCSV = locationId.ToString(), Top = 10, PageSize = 10, Page = 1, OrderBy = "SKOR", OrderDir = "DESC" },
            commandType: CommandType.StoredProcedure)).ToList();

        if (topProducts.Count == 0) return;

        var first = topProducts[0];
        vars["locationName"] = (string)(first.MekanAd ?? $"Mekan-{locationId}");
        vars["productList"] = string.Join("\n", topProducts.Take(5).Select(p =>
        {
            var flags = new List<string>();
            if ((bool?)p.FlagGirissizSatis == true) flags.Add("GirissizSatis");
            if ((bool?)p.FlagStokYok == true) flags.Add("StokYok");
            if ((bool?)p.FlagNetBirikim == true) flags.Add("NetBirikim");
            if ((bool?)p.FlagIadeYuksek == true) flags.Add("IadeYuksek");
            if ((bool?)p.FlagSayimDuzeltme == true) flags.Add("SayimDuzeltme");
            if ((bool?)p.FlagHizliDevir == true) flags.Add("HizliDevir");
            var flagStr = flags.Count == 0 ? "" : $" [{string.Join(", ", flags)}]";
            return $"- {p.UrunAd} (Risk:{p.RiskSkor}){flagStr}";
        }));
    }

    private static async Task LoadProductRiskContextAsync(IDbConnection connection, int productId, Dictionary<string, string> vars)
    {
        var row = await connection.QuerySingleOrDefaultAsync(
            @"SELECT TOP 1
                m.MekanAd, v.MekanId, u.UrunKod, u.UrunAd, v.DonemKodu, v.RiskSkor,
                v.FlagGirissizSatis, v.FlagStokKaydiYok, v.FlagStokSifir,
                v.FlagNetBirikim, v.FlagIadeYuksek, v.FlagSayimDuzeltmeYuk, v.FlagHizliDevir, v.StokMiktar
              FROM rpt.vw_RiskUrunOzet_Stok v
              LEFT JOIN src.vw_Mekan m ON m.MekanId = v.MekanId
              LEFT JOIN src.vw_Urun u ON u.StokId = v.StokId
              WHERE v.StokId = @StokId AND v.DonemKodu = 'Son30Gun'
              ORDER BY v.RiskSkor DESC",
            new { StokId = productId });

        if (row == null) return;

        vars["productName"] = (string)(row.UrunAd ?? $"Urun-{productId}");
        vars["productCode"] = (string)(row.UrunKod ?? "");
        vars["locationName"] = (string)(row.MekanAd ?? "");
        vars["riskScore"] = ((int?)row.RiskSkor ?? 0).ToString();
        vars["activeFlags"] = BuildProductFlagSummary(row);
        vars["movementSummary"] = $"Stok: {row.StokMiktar}";
        vars["semanticContext"] = "";
    }

    private static string BuildProductFlagSummary(dynamic row)
    {
        var flags = new List<string>();
        if ((bool?)row.FlagGirissizSatis == true) flags.Add("GirissizSatis");
        if ((bool?)row.FlagStokKaydiYok == true || (bool?)row.FlagStokSifir == true) flags.Add("StokYok");
        if ((bool?)row.FlagNetBirikim == true) flags.Add("NetBirikim");
        if ((bool?)row.FlagIadeYuksek == true) flags.Add("IadeYuksek");
        if ((bool?)row.FlagSayimDuzeltmeYuk == true) flags.Add("SayimDuzeltme");
        if ((bool?)row.FlagHizliDevir == true) flags.Add("HizliDevir");
        return flags.Count == 0 ? "Aktif flag yok" : string.Join(", ", flags);
    }

    // Istegi ERROR durumuna dusurur. Sessiz basarisizlik yasak — hata mesaji
    // her zaman kayda gecer (error-handling.md).
    private static Task MarkErrorAsync(IDbConnection connection, long requestId, string error)
        => connection.ExecuteAsync(
            "ai.sp_AnalysisQueue_MarkError",
            new { IstekId = requestId, HataMesaji = TrimError(error) },
            commandType: CommandType.StoredProcedure);

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
