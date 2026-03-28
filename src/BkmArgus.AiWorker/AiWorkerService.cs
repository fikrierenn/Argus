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
            _logger.LogInformation("AI Worker döngü tamamlandı.");
            await Task.Delay(TimeSpan.FromSeconds(_options.PollSeconds), stoppingToken);
        }
    }

    private async Task ProcessQueueAsync(CancellationToken token)
    {
        await using var connection = _db.CreateConnection();
        
        const string sql = @"
;WITH cte AS (
    SELECT TOP (@Top) *
    FROM ai.AiAnalizIstegi WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE Durum IN ('NEW', 'BEKLEMEDE')
    ORDER BY Oncelik DESC, OlusturmaTarihi
)
UPDATE cte
SET Durum = 'LM_RUNNING',
    DenemeSayisi = DenemeSayisi + 1,
    SonDenemeTarihi = SYSDATETIME(),
    GuncellemeTarihi = SYSDATETIME()
OUTPUT
    inserted.IstekId,
    inserted.KesimTarihi,
    inserted.DonemKodu,
    inserted.MekanId,
    inserted.StokId,
    inserted.KaynakTip,
    inserted.KaynakAnahtar,
    inserted.Oncelik,
    inserted.Durum,
    inserted.OlusturmaTarihi;";

        var istekler = (await connection.QueryAsync<AiIstekRow>(sql, new { Top = _options.BatchSize })).ToList();
        
        if (istekler.Count == 0)
        {
            _logger.LogInformation("İşlenecek yeni AI isteği bulunamadı.");
            return;
        }

        foreach (var istek in istekler)
        {
            try
            {
                var risk = await connection.QuerySingleOrDefaultAsync<RiskOzetRow>(
                    "ai.sp_Ai_RiskOzet_Getir",
                    new
                    {
                        KesimTarihi = istek.KesimTarihi ?? (object)DBNull.Value,
                        DonemKodu = istek.DonemKodu,
                        MekanId = istek.MekanId,
                        StokId = istek.StokId
                    },
                    commandType: CommandType.StoredProcedure);

                if (risk is null)
                {
                    await MarkErrorAsync(connection, istek.IstekId ?? 0, "Risk kaydı bulunamadı.");
                    continue;
                }

                var decision = _rules.Decide(risk);
                var riskText = BuildRiskText(risk);
                var match = await _semantic.FindBestMatchAsync(riskText, token);
                if (match is not null && match.KritikMi)
                {
                    var percent = Math.Round(match.Similarity * 100);
                    var note = $"Bu risk, geçmişteki ID:{match.RiskId} nolu '{match.Baslik}' olayına %{percent} benziyor.";
                    decision = decision with
                    {
                        OncelikPuan = 100,
                        LlmGerekliMi = true,
                        SemanticNot = note
                    };
                }

                await UpsertLmSonucAsync(connection, istek.IstekId ?? 0, decision);

                var yeniDurum = decision.LlmGerekliMi ? "LLM_QUEUED" : "LM_DONE";
                await connection.ExecuteAsync(
                    "UPDATE ai.AiAnalizIstegi SET Durum = @Durum, EvidencePlan = @EvidencePlan, LmNot = @LmNot, GuncellemeTarihi = GETDATE() WHERE IstekId = @IstekId",
                    new
                    {
                        IstekId = istek.IstekId ?? 0,
                        Durum = yeniDurum,
                        EvidencePlan = decision.EvidencePlan,
                        LmNot = decision.SemanticNot
                    });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "AI istek işlenemedi. IstekId={IstekId}", istek.IstekId);
                await MarkErrorAsync(connection, istek.IstekId ?? 0, FormatException("LM istek işlenemedi", ex));
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
        var kaynaklar = await connection.QueryAsync<DofKayitRow>(
            "ai.sp_Ai_GecmisVektor_KaynakListe",
            new { Top = 200 },
            commandType: CommandType.StoredProcedure);

        foreach (var kaynak in kaynaklar)
        {
            if (token.IsCancellationRequested)
            {
                break;
            }

            var text = BuildDofText(kaynak);
            var vector = await _embedding.TryEmbedAsync(text, token);
            if (vector is null || vector.Length == 0)
            {
                continue;
            }

            var kritik = kaynak.RiskSeviyesi >= 3;
            var ozet = string.IsNullOrWhiteSpace(kaynak.Aciklama) ? kaynak.Baslik : $"{kaynak.Baslik}. {kaynak.Aciklama}";
            if (ozet.Length > 500)
            {
                ozet = ozet[..500];
            }

            await connection.ExecuteAsync(
                "ai.sp_Ai_GecmisVektor_Upsert",
                new
                {
                    RiskId = kaynak.DofId,
                    DofId = kaynak.DofId,
                    Baslik = kaynak.Baslik,
                    OzetMetin = ozet,
                    KritikMi = kritik,
                    VektorJson = JsonSerializer.Serialize(vector)
                },
                commandType: CommandType.StoredProcedure);
        }

        await SyncDocVectorsAsync(connection, token);
    }

    private static string BuildRiskText(RiskOzetRow risk)
    {
        return $"Mekan:{risk.MekanAd}; Ürün:{risk.UrunAd}; Skor:{risk.RiskSkor}; Yorum:{risk.RiskYorum}";
    }

    private static string BuildDofText(DofKayitRow dof)
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
                _logger.LogWarning(ex, "Doküman okunamadı. Dosya={File}", file);
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
            var baslik = $"DOC:{Path.GetFileName(file)}";
            var ozet = TrimTo(clean, _options.DocsSnippetChars);

            await connection.ExecuteAsync(
                "ai.sp_Ai_GecmisVektor_Upsert",
                new
                {
                    RiskId = riskId,
                    DofId = (long?)null,
                    Baslik = baslik,
                    OzetMetin = ozet,
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
    FROM ai.AiAnalizIstegi WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE Durum = 'LLM_QUEUED'
    ORDER BY Oncelik DESC, OlusturmaTarihi
)
UPDATE cte
SET Durum = 'LLM_RUNNING',
    GuncellemeTarihi = SYSDATETIME()
OUTPUT
    inserted.IstekId,
    inserted.KesimTarihi,
    inserted.DonemKodu,
    inserted.MekanId,
    inserted.StokId,
    inserted.EvidencePlan,
    inserted.EvidenceJson,
    inserted.LmNot;";

        await using var connection = _db.CreateConnection();
        var istekler = await connection.QueryAsync<AiLlmIstekRow>(sql, new { Top = _options.BatchSize });

        foreach (var istek in istekler)
        {
            try
            {
                var risk = await connection.QuerySingleOrDefaultAsync<RiskOzetRow>(
                    "ai.sp_Ai_RiskOzet_Getir",
                    new
                    {
                        KesimTarihi = istek.KesimTarihi ?? (object)DBNull.Value,
                        DonemKodu = istek.DonemKodu,
                        MekanId = istek.MekanId,
                        StokId = istek.StokId
                    },
                    commandType: CommandType.StoredProcedure);

                if (risk is null)
                {
                    await MarkErrorAsync(connection, istek.IstekId, "Risk kaydı bulunamadı (LLM).");
                    continue;
                }

                var riskText = BuildRiskText(risk);
                var evidenceMatches = await _semantic.FindTopEvidenceAsync(riskText, 3, token);
                var evidenceNote = FormatEvidenceMatches(evidenceMatches);
                var prompt = BuildAdvancedLlmPrompt(risk, istek, evidenceNote);
                var call = await _llm.GenerateAsync(prompt, token);
                if (!call.Success || call.Result is null)
                {
                    var error = string.IsNullOrWhiteSpace(call.Error) ? "LLM yanıtı alınamadı." : call.Error;
                    await MarkErrorAsync(connection, istek.IstekId, error);
                    continue;
                }

                await UpsertLlmSonucAsync(connection, istek.IstekId, call.Result);

                await connection.ExecuteAsync(
                    "UPDATE ai.AiAnalizIstegi SET Durum = @Durum, GuncellemeTarihi = GETDATE() WHERE IstekId = @IstekId",
                    new { IstekId = istek.IstekId, Durum = "LLM_DONE" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "LLM istek işlenemedi. IstekId={IstekId}", istek.IstekId);
                await MarkErrorAsync(connection, istek.IstekId, FormatException("LLM istek işlenemedi", ex));
            }
        }
    }

    private static string BuildAdvancedLlmPrompt(RiskOzetRow risk, AiLlmIstekRow istek, string evidenceNote)
    {
        var flags = $"VeriKalite={risk.FlagVeriKalite}; GirişsizSatış={risk.FlagGirissizSatis}; ÖlüStok={risk.FlagOluStok}; " +
                    $"NetBirikim={risk.FlagNetBirikim}; İadeYüksek={risk.FlagIadeYuksek}; BozukİadeYüksek={risk.FlagBozukIadeYuksek}; " +
                    $"SayımDüzeltme={risk.FlagSayimDuzeltmeYuk}; ŞirketİçiYüksek={risk.FlagSirketIciYuksek}; HızlıDevir={risk.FlagHizliDevir}; " +
                    $"SatışYaşlanma={risk.FlagSatisYaslanma}";

        var lmNot = string.IsNullOrWhiteSpace(istek.LmNot) ? "-" : istek.LmNot;
        var evidence = string.IsNullOrWhiteSpace(istek.EvidenceJson) ? "-" : istek.EvidenceJson;

        var sb = new StringBuilder();
        
        // System prompt - çok daha detaylı
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
        sb.AppendLine($"Historical Similarities: {lmNot}");
        sb.AppendLine();
        sb.AppendLine("Output format (SADECE JSON):");
        sb.AppendLine(GetJsonSchema());
        sb.AppendLine("<|/task|>");
        
        return sb.ToString();
    }

    private static string BuildDetailedRiskContext(RiskOzetRow risk)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"Tarih: {risk.KesimTarihi?.ToString("yyyy-MM-dd") ?? "Belirsiz"}");
        sb.AppendLine($"Dönem: {risk.DonemKodu}");
        sb.AppendLine($"Mekan: {risk.MekanAd} (ID: {risk.MekanId})");
        sb.AppendLine($"Ürün: {risk.UrunAd} ({risk.UrunKod}) - ID: {risk.StokId}");
        sb.AppendLine($"Risk Skoru: {risk.RiskSkor}/100");
        sb.AppendLine($"Yorum: {risk.RiskYorum ?? "Yok"}");
        sb.AppendLine($"Veri Kalite Sorunu: {(risk.FlagVeriKalite ? "Evet" : "Hayır")}");
        sb.AppendLine($"Girişsiz Satış: {(risk.FlagGirissizSatis ? "Evet" : "Hayır")}");
        sb.AppendLine($"Ölü Stok: {(risk.FlagOluStok ? "Evet" : "Hayır")}");
        sb.AppendLine($"Net Birikim: {(risk.FlagNetBirikim ? "Evet" : "Hayır")}");
        sb.AppendLine($"Yüksek İade: {(risk.FlagIadeYuksek ? "Evet" : "Hayır")}");
        sb.AppendLine($"Bozuk İade: {(risk.FlagBozukIadeYuksek ? "Evet" : "Hayır")}");
        sb.AppendLine($"Sayım Düzeltme: {(risk.FlagSayimDuzeltmeYuk ? "Evet" : "Hayır")}");
        sb.AppendLine($"Şirket İçi Kullanım: {(risk.FlagSirketIciYuksek ? "Evet" : "Hayır")}");
        sb.AppendLine($"Hızlı Devir: {(risk.FlagHizliDevir ? "Evet" : "Hayır")}");
        sb.AppendLine($"Satış Yaşlanma: {(risk.FlagSatisYaslanma ? "Evet" : "Hayır")}");
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
            return $"{m.Baslik} (%{percent})";
        }));
    }

    private static Task UpsertLlmSonucAsync(IDbConnection connection, long istekId, LlmResult result)
    {
        const string sql = @"
MERGE ai.AiLlmSonuc AS t
USING (SELECT @IstekId AS IstekId) AS s
ON t.IstekId = s.IstekId
WHEN MATCHED THEN
    UPDATE SET
        Model = @Model,
        PromptVersiyon = @PromptVersiyon,
        KokNedenHipotezleri = @KokNedenHipotezleri,
        DogrulamaAdimlari = @DogrulamaAdimlari,
        OnerilenAksiyonlar = @OnerilenAksiyonlar,
        DofTaslakJson = @DofTaslakJson,
        YoneticiOzeti = @YoneticiOzeti,
        GuvenSkoru = @GuvenSkoru,
        OlusturmaTarihi = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (IstekId, Model, PromptVersiyon, KokNedenHipotezleri, DogrulamaAdimlari, OnerilenAksiyonlar, DofTaslakJson, YoneticiOzeti, GuvenSkoru, OlusturmaTarihi)
    VALUES (@IstekId, @Model, @PromptVersiyon, @KokNedenHipotezleri, @DogrulamaAdimlari, @OnerilenAksiyonlar, @DofTaslakJson, @YoneticiOzeti, @GuvenSkoru, SYSDATETIME());";

        return connection.ExecuteAsync(sql, new
        {
            IstekId = istekId,
            result.Model,
            result.PromptVersiyon,
            result.KokNedenHipotezleri,
            result.DogrulamaAdimlari,
            result.OnerilenAksiyonlar,
            result.DofTaslakJson,
            YoneticiOzeti = result.YoneticiOzeti ?? result.RawJson,
            result.GuvenSkoru
        });
    }

    private static Task UpsertLmSonucAsync(IDbConnection connection, long istekId, LmDecision decision)
    {
        const string sql = @"
MERGE ai.AiLmSonuc AS t
USING (SELECT @IstekId AS IstekId) AS s
ON t.IstekId = s.IstekId
WHEN MATCHED THEN
    UPDATE SET
        RootCauseClass = @RootCauseClass,
        EvidencePlan = @EvidencePlan,
        LlmGerekliMi = @LlmGerekliMi,
        OncelikPuan = @OncelikPuan,
        KisaOzet = @KisaOzet,
        OzellikJson = @OzellikJson,
        RuleSetVersiyon = @RuleSetVersiyon,
        OlusturmaTarihi = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (IstekId, RootCauseClass, EvidencePlan, LlmGerekliMi, OncelikPuan, KisaOzet, OzellikJson, RuleSetVersiyon, OlusturmaTarihi)
    VALUES (@IstekId, @RootCauseClass, @EvidencePlan, @LlmGerekliMi, @OncelikPuan, @KisaOzet, @OzellikJson, @RuleSetVersiyon, SYSDATETIME());";

        return connection.ExecuteAsync(sql, new
        {
            IstekId = istekId,
            decision.RootCauseClass,
            decision.EvidencePlan,
            decision.LlmGerekliMi,
            decision.OncelikPuan,
            decision.KisaOzet,
            decision.OzellikJson,
            RuleSetVersiyon = "v1"
        });
    }

    private static Task MarkErrorAsync(IDbConnection connection, long istekId, string hata)
    {
        var safe = TrimError(hata);
        return connection.ExecuteAsync(
            "UPDATE ai.AiAnalizIstegi SET Durum = @Durum, HataMesaji = @HataMesaji, GuncellemeTarihi = GETDATE() WHERE IstekId = @IstekId",
            new { IstekId = istekId, Durum = "ERROR", HataMesaji = safe });
    }

    private static string TrimError(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return "Bilinmeyen hata.";
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
