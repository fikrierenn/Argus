using System.Data;
using Dapper;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using BkmArgus.Infrastructure;

namespace BkmArgus.AiWorker;

/// <summary>
/// LLM saglayicilarini ai.LlmProviders tablosundan yukler. SkillRegistry ile ayni
/// desen: DB otorite, kod yalniz yedek. DB erisilemezse veya tablo bossa
/// AiWorkerOptions icindeki eski alanlardan zincir uretilir, boylece worker
/// veritabani olmadan da ayakta kalir.
///
/// API anahtari tabloda TUTULMAZ. Tablo anahtarin adini tasir (ApiKeyRef);
/// deger ortam degiskeninden veya yapilandirmadan cozulur.
/// </summary>
public sealed class LlmProviderRegistry(
    Db db,
    IOptions<AiWorkerOptions> options,
    IConfiguration configuration,
    ILogger<LlmProviderRegistry> logger)
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(10);

    private readonly AiWorkerOptions _options = options.Value;
    private readonly SemaphoreSlim _gate = new(1, 1);

    private IReadOnlyList<LlmProviderConfig> _cache = [];
    private DateTime _loadedAtUtc = DateTime.MinValue;

    /// <summary>
    /// Kullanilabilir saglayicilari oncelik sirasinda dondurur.
    /// Kullanilamayan (pasif, modelsiz, anahtari cozulemeyen) kayitlar elenir.
    /// </summary>
    public async Task<IReadOnlyList<LlmProviderConfig>> GetAsync(CancellationToken token = default)
    {
        if (_cache.Count > 0 && DateTime.UtcNow - _loadedAtUtc < CacheTtl)
        {
            return _cache;
        }

        await _gate.WaitAsync(token);
        try
        {
            // Bekleme sirasinda baska bir cagri yenilemis olabilir
            if (_cache.Count > 0 && DateTime.UtcNow - _loadedAtUtc < CacheTtl)
            {
                return _cache;
            }

            var loaded = await LoadFromDatabaseAsync(token);

            if (loaded.Count == 0)
            {
                logger.LogWarning("ai.LlmProviders bos veya okunamadi — yapilandirmadaki eski alanlara donuluyor.");
                loaded = BuildFromLegacyOptions();
            }

            _cache = loaded;
            _loadedAtUtc = DateTime.UtcNow;

            logger.LogInformation("LLM saglayici zinciri yuklendi: {Zincir}",
                loaded.Count > 0 ? string.Join(" -> ", loaded.Select(p => $"{p.Name}/{p.Model}")) : "(bos)");

            return _cache;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>Yonetim ekranindan degisiklik yapildiginda onbellegi dusurur.</summary>
    public void Invalidate() => _loadedAtUtc = DateTime.MinValue;

    private async Task<IReadOnlyList<LlmProviderConfig>> LoadFromDatabaseAsync(CancellationToken token)
    {
        try
        {
            using var connection = db.CreateConnection();
            var rows = await connection.QueryAsync<ProviderRow>(
                new CommandDefinition(
                    "ai.sp_LlmProvider_List",
                    new { SadeceAktif = true },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: token));

            var list = new List<LlmProviderConfig>();

            foreach (var row in rows.OrderBy(r => r.Priority))
            {
                var config = new LlmProviderConfig
                {
                    Name           = row.Name,
                    Kind           = row.Kind,
                    BaseUrl        = row.BaseUrl,
                    Path           = row.RequestPath ?? string.Empty,
                    Model          = row.Model,
                    FallbackModel  = row.FallbackModel,
                    MaxOutputTokens = row.MaxOutputTokens,
                    ExtraBodyJson  = row.ExtraBodyJson,
                    Order          = row.Priority,
                    RequiresApiKey = row.RequiresApiKey,
                    Enabled        = row.IsActive,
                    ApiKey         = ResolveApiKey(row.ApiKeyRef, row.ApiKeyEncrypted)
                };

                // Anahtari cozulemeyen saglayici zincire alinmaz — cagri aninda
                // patlamak yerine bastan elenir (ai-layer.md soft-fail).
                if (!config.IsUsable)
                {
                    logger.LogWarning(
                        "Saglayici {Ad} atlandi: {Sebep}",
                        row.Name,
                        row.RequiresApiKey && string.IsNullOrWhiteSpace(config.ApiKey)
                            ? $"'{row.ApiKeyRef}' anahtari tanimli degil"
                            : "eksik yapilandirma");
                    continue;
                }

                list.Add(config);
            }

            return list;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "ai.LlmProviders okunamadi.");
            return [];
        }
    }

    /// <summary>
    /// Anahtari cozer. Sira: ortam degiskeni / yapilandirma (adiyla), sonra
    /// yonetim ekranindan girilip veritabaninda sifreli saklanan deger.
    /// Ortam degiskeni onceliklidir — uretimde anahtari hic DB'ye koymadan
    /// calistirmak mumkun kalir. Deger hicbir kosulda loglanmaz.
    /// </summary>
    private string ResolveApiKey(string? apiKeyRef, string? apiKeyEncrypted)
    {
        if (!string.IsNullOrWhiteSpace(apiKeyRef))
        {
            var fromEnv = Environment.GetEnvironmentVariable(apiKeyRef);
            if (!string.IsNullOrWhiteSpace(fromEnv))
            {
                return fromEnv;
            }

            // AD ALANI SABIT: ham configuration[apiKeyRef] cagrisi kaldirildi.
            // Onunla "ConnectionStrings:BkmArgus" veya "BKM_SECRET_KEY" gibi bir
            // yol yazip cozulen degeri kendi belirledigi BaseUrl'e Bearer olarak
            // gonderten bir kayit acmak mumkundu — sir sizdirma yolu.
            var fromConfig = configuration[$"AiWorker:{apiKeyRef}"]
                ?? configuration[$"ApiKeys:{apiKeyRef}"];

            if (!string.IsNullOrWhiteSpace(fromConfig))
            {
                return fromConfig;
            }
        }

        // Ekrandan girilmis sifreli anahtar. Cozulemezse bos doner ve saglayici
        // zincire alinmaz — ana anahtar eksikse/degistiyse sessizce kapali kalir.
        return SecretProtector.Unprotect(configuration, apiKeyEncrypted);
    }

    /// <summary>
    /// DB yoksa eski AiWorkerOptions alanlarindan zincir uretir — gecis donemi
    /// yedegi. Kayit defteri seed edildikten sonra bu yol calismaz.
    /// </summary>
    private List<LlmProviderConfig> BuildFromLegacyOptions()
    {
        var list = new List<LlmProviderConfig>
        {
            new()
            {
                Name = "gemini", Kind = LlmProviderKinds.Gemini, BaseUrl = _options.GeminiBaseUrl,
                Model = _options.GeminiModel, FallbackModel = _options.GeminiModelFallback,
                ApiKey = _options.GeminiApiKey, Enabled = _options.GeminiEnabled, Order = 10
            },
            new()
            {
                Name = "claude", Kind = LlmProviderKinds.Claude, BaseUrl = _options.ClaudeBaseUrl,
                Path = "/v1/messages", Model = _options.ClaudeModel, FallbackModel = _options.ClaudeModelFallback,
                ApiKey = _options.ClaudeApiKey, Enabled = _options.ClaudeEnabled, Order = 20
            },
            new()
            {
                Name = "glm", Kind = LlmProviderKinds.OpenAi, BaseUrl = _options.GlmBaseUrl,
                Path = "/api/paas/v4/chat/completions", Model = _options.GlmModel,
                FallbackModel = _options.GlmModelFallback, ApiKey = _options.GlmApiKey,
                Enabled = _options.GlmEnabled, Order = 30
            },
            new()
            {
                Name = "ollama", Kind = LlmProviderKinds.Ollama, BaseUrl = _options.OllamaBaseUrl,
                Path = "/api/generate", Model = _options.LlmModel, FallbackModel = _options.LlmModelLowRam,
                Enabled = _options.OllamaEnabled, RequiresApiKey = false, Order = 90
            }
        };

        // Birincil saglayici zincirin basina alinir
        var primary = (_options.LlmProvider ?? string.Empty).Trim().ToLowerInvariant();
        return list
            .Where(p => p.IsUsable)
            .OrderBy(p => string.Equals(p.Name, primary, StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(p => p.Order)
            .ToList();
    }

    private sealed class ProviderRow
    {
        public string Name { get; init; } = string.Empty;
        public string Kind { get; init; } = string.Empty;
        public string BaseUrl { get; init; } = string.Empty;
        public string? RequestPath { get; init; }
        public string? ApiKeyRef { get; init; }
        public string? ApiKeyEncrypted { get; init; }
        public bool RequiresApiKey { get; init; }
        public string Model { get; init; } = string.Empty;
        public string? FallbackModel { get; init; }
        public int? MaxOutputTokens { get; init; }
        public string? ExtraBodyJson { get; init; }
        public int Priority { get; init; }
        public bool IsActive { get; init; }
    }
}
