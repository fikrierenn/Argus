using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public sealed class LlmService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private const string ProviderOllama = "ollama";
    private const string ProviderGemini = "gemini";
    private readonly HttpClient _ollama;
    private readonly HttpClient _gemini;
    private readonly AiWorkerOptions _options;
    private readonly ILogger<LlmService> _logger;

    public LlmService(
        IHttpClientFactory httpFactory,
        IOptions<AiWorkerOptions> options,
        ILogger<LlmService> logger)
    {
        _ollama = httpFactory.CreateClient("ollama");
        _gemini = httpFactory.CreateClient("gemini");
        _options = options.Value;
        _logger = logger;
    }

    public async Task<LlmCallResult> GenerateAsync(string prompt, CancellationToken token)
    {
        var provider = NormalizeProvider(_options.LlmProvider);
        if (string.IsNullOrWhiteSpace(prompt))
        {
            var model = provider == ProviderGemini ? _options.GeminiModel : _options.LlmModel;
            return new LlmCallResult
            {
                Error = BuildError(provider, model, "Prompt bos.", null, null, 0, ResolveBaseUrl(provider))
            };
        }

        var providers = GetProviderChain(provider);
        var errors = new List<string>();

        foreach (var (currentProvider, model) in providers)
        {
            var result = currentProvider switch
            {
                ProviderGemini => await CallGeminiWithRetryAsync(model, prompt, token),
                ProviderOllama => await CallOllamaWithRetryAsync(model, prompt, token),
                _ => new LlmCallResult { Error = $"Unknown provider: {currentProvider}" }
            };

            if (result.Success)
            {
                // Quality validation
                var validation = ValidateResult(result.Result);
                if (!validation.IsValid)
                {
                    _logger.LogWarning("LLM result quality validation failed. Issues={Issues}", string.Join("; ", validation.Issues));
                    errors.Add($"{currentProvider}: {string.Join(", ", validation.Issues)}");
                    continue;
                }
                return result;
            }

            errors.Add($"{currentProvider}: {result.Error}");
        }

        return new LlmCallResult
        {
            Error = $"All providers failed. Errors: {string.Join(" | ", errors)}"
        };
    }

    private IEnumerable<(string provider, string model)> GetProviderChain(string primaryProvider)
    {
        if (primaryProvider == ProviderOllama)
        {
            yield return (ProviderOllama, _options.LlmModel);
            if (!string.IsNullOrWhiteSpace(_options.LlmModelLowRam) && 
                !string.Equals(_options.LlmModelLowRam, _options.LlmModel, StringComparison.OrdinalIgnoreCase))
            {
                yield return (ProviderOllama, _options.LlmModelLowRam!);
            }
            if (!string.IsNullOrWhiteSpace(_options.GeminiApiKey))
            {
                yield return (ProviderGemini, _options.GeminiModel);
            }
        }
        else if (primaryProvider == ProviderGemini)
        {
            yield return (ProviderGemini, _options.GeminiModel);
            if (!string.IsNullOrWhiteSpace(_options.GeminiModelFallback) &&
                !string.Equals(_options.GeminiModelFallback, _options.GeminiModel, StringComparison.OrdinalIgnoreCase))
            {
                yield return (ProviderGemini, _options.GeminiModelFallback!);
            }
            yield return (ProviderOllama, _options.LlmModel);
        }
    }

    private async Task<LlmCallResult> CallOllamaWithRetryAsync(string model, string prompt, CancellationToken token)
    {
        const int maxRetries = 3;
        for (int attempt = 1; attempt <= maxRetries; attempt++)
        {
            try
            {
                var result = await CallOllamaAsync(model, prompt, token);
                if (result.Success)
                {
                    return result;
                }

                if (attempt < maxRetries)
                {
                    var delay = TimeSpan.FromSeconds(Math.Pow(2, attempt)); // Exponential backoff
                    _logger.LogWarning("Ollama attempt {Attempt} failed. Retrying in {Delay}s. Error: {Error}", 
                        attempt, delay.TotalSeconds, result.Error);
                    await Task.Delay(delay, token);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ollama attempt {Attempt} failed with exception", attempt);
                if (attempt == maxRetries)
                {
                    return new LlmCallResult { Error = $"Ollama failed after {maxRetries} attempts: {ex.Message}" };
                }
            }
        }

        return new LlmCallResult { Error = $"Ollama failed after {maxRetries} attempts" };
    }

    private async Task<LlmCallResult> CallOllamaAsync(string model, string prompt, CancellationToken token)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(token);
        cts.CancelAfter(TimeSpan.FromSeconds(_options.LlmTimeoutSeconds));

        try
        {
            var payload = new GenerateRequest
            {
                Model = model,
                Prompt = prompt,
                Stream = false,
                Format = "json",
                Options = new OllamaOptions
                {
                    Temperature = _options.Temperature,
                    TopP = _options.TopP,
                    RepeatPenalty = _options.RepeatPenalty,
                    NumPredict = _options.MaxTokens,
                    Seed = _options.Seed,
                    Stop = _options.StopTokens
                }
            };

            using var response = await _ollama.PostAsJsonAsync("api/generate", payload, cts.Token);
            var body = await response.Content.ReadAsStringAsync(cts.Token);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Ollama HTTP isteği başarısız. Model={Model} Status={Status}", model, response.StatusCode);
                var detail = $"Status={(int)response.StatusCode} {response.ReasonPhrase}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(ProviderOllama, model, "HTTP isteği başarısız.", detail, body, prompt.Length, ResolveBaseUrl(ProviderOllama))
                };
            }

            if (string.IsNullOrWhiteSpace(body))
            {
                return new LlmCallResult
                {
                    Error = BuildError(ProviderOllama, model, "HTTP yanıtı boş.", $"BodyLen={body.Length}", null, prompt.Length, ResolveBaseUrl(ProviderOllama))
                };
            }

            GenerateResponse? data;
            try
            {
                data = JsonSerializer.Deserialize<GenerateResponse>(body, JsonOptions);
            }
            catch (Exception ex)
            {
                var detail = $"ParseError={ex.GetType().Name}: {ex.Message}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(ProviderOllama, model, "LLM response parse edilemedi.", detail, body, prompt.Length, ResolveBaseUrl(ProviderOllama))
                };
            }

            var raw = data?.Response?.Trim();
            if (string.IsNullOrWhiteSpace(raw))
            {
                _logger.LogWarning("LLM yanıtı boş. Model={Model}", model);
                return new LlmCallResult
                {
                    Error = BuildError(ProviderOllama, model, "LLM response alanı boş.", $"BodyLen={body.Length}", body, prompt.Length, ResolveBaseUrl(ProviderOllama))
                };
            }

            var json = ExtractAndValidateJson(raw);
            if (string.IsNullOrWhiteSpace(json))
            {
                _logger.LogWarning("Geçerli JSON çıkarılamadı. Raw={Raw}", raw[..200]);
                return new LlmCallResult
                {
                    Error = BuildError(ProviderOllama, model, "Geçerli JSON bulunamadı.", $"RawLen={raw.Length}", raw[..500], prompt.Length, ResolveBaseUrl(ProviderOllama))
                };
            }

            return new LlmCallResult
            {
                Result = ParseAndValidateResult(json, model)
            };
        }
        catch (OperationCanceledException)
        {
            var reason = token.IsCancellationRequested
                ? "İstek iptal edildi."
                : $"Zaman aşımı ({_options.LlmTimeoutSeconds}s).";
            _logger.LogWarning("Ollama isteği zaman aşımına uğradı. Model={Model}", model);
            return new LlmCallResult
            {
                Error = BuildError(ProviderOllama, model, reason, null, null, prompt.Length, ResolveBaseUrl(ProviderOllama))
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ollama isteği hatası. Model={Model}", model);
            var detail = $"{ex.GetType().Name}: {ex.Message}";
            return new LlmCallResult
            {
                Error = BuildError(ProviderOllama, model, "Ollama isteği hatası.", detail, null, prompt.Length, ResolveBaseUrl(ProviderOllama))
            };
        }
    }

    private async Task<LlmCallResult> CallGeminiWithRetryAsync(string model, string prompt, CancellationToken token)
    {
        const int maxRetries = 2; // Gemini daha reliable, daha az retry
        for (int attempt = 1; attempt <= maxRetries; attempt++)
        {
            try
            {
                var result = await CallGeminiAsync(model, prompt, token);
                if (result.Success)
                {
                    return result;
                }

                if (attempt < maxRetries)
                {
                    var delay = TimeSpan.FromSeconds(2 * attempt);
                    _logger.LogWarning("Gemini attempt {Attempt} failed. Retrying in {Delay}s. Error: {Error}", 
                        attempt, delay.TotalSeconds, result.Error);
                    await Task.Delay(delay, token);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gemini attempt {Attempt} failed with exception", attempt);
                if (attempt == maxRetries)
                {
                    return new LlmCallResult { Error = $"Gemini failed after {maxRetries} attempts: {ex.Message}" };
                }
            }
        }

        return new LlmCallResult { Error = $"Gemini failed after {maxRetries} attempts" };
    }

    private async Task<LlmCallResult> CallGeminiAsync(string model, string prompt, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(_options.GeminiApiKey))
        {
            return new LlmCallResult
            {
                Error = BuildError(ProviderGemini, model, "Gemini API key boş.", null, null, prompt.Length, ResolveBaseUrl(ProviderGemini))
            };
        }

        if (string.IsNullOrWhiteSpace(model))
        {
            return new LlmCallResult
            {
                Error = BuildError(ProviderGemini, "-", "Gemini model boş.", null, null, prompt.Length, ResolveBaseUrl(ProviderGemini))
            };
        }

        using var cts = CancellationTokenSource.CreateLinkedTokenSource(token);
        cts.CancelAfter(TimeSpan.FromSeconds(_options.LlmTimeoutSeconds));

        try
        {
            var payload = new GeminiGenerateRequest
            {
                Contents =
                {
                    new GeminiContent
                    {
                        Role = "user",
                        Parts = { new GeminiPart { Text = prompt } }
                    }
                },
                GenerationConfig = new GeminiGenerationConfig 
                { 
                    ResponseMimeType = "application/json",
                    Temperature = _options.Temperature,
                    MaxOutputTokens = _options.MaxTokens,
                    StopSequences = _options.StopTokens
                }
            };

            var apiKey = Uri.EscapeDataString(_options.GeminiApiKey);
            var path = $"v1beta/models/{model}:generateContent?key={apiKey}";
            using var response = await _gemini.PostAsJsonAsync(path, payload, cts.Token);
            var body = await response.Content.ReadAsStringAsync(cts.Token);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Gemini HTTP isteği başarısız. Model={Model} Status={Status}", model, response.StatusCode);
                var detail = $"Status={(int)response.StatusCode} {response.ReasonPhrase}; BodyLen={body.Length}";
                var apiError = ExtractGeminiError(body);
                if (!string.IsNullOrWhiteSpace(apiError))
                {
                    detail = $"{detail}; ApiError={apiError}";
                }

                return new LlmCallResult
                {
                    Error = BuildError(ProviderGemini, model, "HTTP isteği başarısız.", detail, body, prompt.Length, ResolveBaseUrl(ProviderGemini))
                };
            }

            if (string.IsNullOrWhiteSpace(body))
            {
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGemini, model, "HTTP yanıtı boş.", $"BodyLen={body.Length}", null, prompt.Length, ResolveBaseUrl(ProviderGemini))
                };
            }

            GeminiGenerateResponse? data;
            try
            {
                data = JsonSerializer.Deserialize<GeminiGenerateResponse>(body, JsonOptions);
            }
            catch (Exception ex)
            {
                var detail = $"ParseError={ex.GetType().Name}: {ex.Message}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGemini, model, "Gemini response parse edilemedi.", detail, body, prompt.Length, ResolveBaseUrl(ProviderGemini))
                };
            }

            var raw = ExtractGeminiText(data);
            if (string.IsNullOrWhiteSpace(raw))
            {
                var detail = $"BodyLen={body.Length}";
                if (data?.Error is not null && !string.IsNullOrWhiteSpace(data.Error.Message))
                {
                    detail = $"{detail}; ApiError={data.Error.Message}";
                }

                return new LlmCallResult
                {
                    Error = BuildError(ProviderGemini, model, "Gemini response boş.", detail, body, prompt.Length, ResolveBaseUrl(ProviderGemini))
                };
            }

            var json = ExtractAndValidateJson(raw);
            if (string.IsNullOrWhiteSpace(json))
            {
                _logger.LogWarning("Gemini için geçerli JSON çıkarılamadı. Raw={Raw}", raw[..200]);
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGemini, model, "Geçerli JSON bulunamadı.", $"RawLen={raw.Length}", raw[..500], prompt.Length, ResolveBaseUrl(ProviderGemini))
                };
            }

            return new LlmCallResult
            {
                Result = ParseAndValidateResult(json, model)
            };
        }
        catch (OperationCanceledException)
        {
            var reason = token.IsCancellationRequested
                ? "İstek iptal edildi."
                : $"Zaman aşımı ({_options.LlmTimeoutSeconds}s).";
            _logger.LogWarning("Gemini isteği zaman aşımına uğradı. Model={Model}", model);
            return new LlmCallResult
            {
                Error = BuildError(ProviderGemini, model, reason, null, null, prompt.Length, ResolveBaseUrl(ProviderGemini))
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Gemini isteği hatası. Model={Model}", model);
            var detail = $"{ex.GetType().Name}: {ex.Message}";
            return new LlmCallResult
            {
                Error = BuildError(ProviderGemini, model, "Gemini isteği hatası.", detail, null, prompt.Length, ResolveBaseUrl(ProviderGemini))
            };
        }
    }

    private static LlmResult ParseAndValidateResult(string raw, string model)
    {
        try
        {
            using var doc = JsonDocument.Parse(raw);
            var root = doc.RootElement;

            var rootCause = GetRaw(root, "rootCauseHypotheses");
            var validation = GetRaw(root, "validationSteps");
            var actions = GetRaw(root, "recommendedActions");
            var dof = GetRaw(root, "dofDraft");
            var exec = GetRaw(root, "executiveSummary");
            int? conf = null;
            if (root.TryGetProperty("confidence", out var c) && c.TryGetInt32(out var value))
            {
                conf = Math.Clamp(value, 0, 100); // Clamp to valid range
            }

            return new LlmResult
            {
                Model = model,
                KokNedenHipotezleri = rootCause,
                DogrulamaAdimlari = validation,
                OnerilenAksiyonlar = actions,
                DofTaslakJson = dof,
                YoneticiOzeti = exec,
                GuvenSkoru = conf,
                RawJson = raw
            };
        }
        catch (Exception ex)
        {
            return new LlmResult { Model = model, RawJson = raw, ParseError = ex.Message };
        }
    }

    private static ValidationResult ValidateResult(LlmResult? result)
    {
        if (result is null)
        {
            return new ValidationResult { IsValid = false, Issues = new List<string> { "Result is null" }, QualityScore = 0 };
        }

        var issues = new List<string>();
        var score = 0;

        // Check confidence score
        if (result.GuvenSkoru.HasValue)
        {
            if (result.GuvenSkoru.Value >= 70) score += 20;
            else if (result.GuvenSkoru.Value < 50) issues.Add("Low confidence score");
        }
        else
        {
            issues.Add("Missing confidence score");
        }

        // Check root causes
        if (!string.IsNullOrWhiteSpace(result.KokNedenHipotezleri))
        {
            score += 25;
        }
        else
        {
            issues.Add("Missing root cause hypotheses");
        }

        // Check validation steps
        if (!string.IsNullOrWhiteSpace(result.DogrulamaAdimlari))
        {
            score += 25;
        }
        else
        {
            issues.Add("Missing validation steps");
        }

        // Check actions
        if (!string.IsNullOrWhiteSpace(result.OnerilenAksiyonlar))
        {
            score += 30;
        }
        else
        {
            issues.Add("Missing recommended actions");
        }

        return new ValidationResult
        {
            IsValid = !issues.Any(),
            Issues = issues,
            QualityScore = score
        };
    }

    private static string ExtractAndValidateJson(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return string.Empty;
        }

        var jsonPatterns = new[]
        {
            @"\{[\s\S]*\}",                                   // Full JSON object
            @"```json\s*(\{[\s\S]*?\})\s*```",                // Code block with json
            @"```(\{[\s\S]*?\})```",                          // Code block without lang
        };

        foreach (var pattern in jsonPatterns)
        {
            var match = Regex.Match(raw, pattern, RegexOptions.Multiline);
            if (match.Success)
            {
                var candidate = match.Groups[1].Success ? match.Groups[1].Value : match.Value;
                
                // Validate JSON structure
                if (IsValidJson(candidate))
                {
                    return candidate;
                }
            }
        }

        return string.Empty;
    }

    private static bool IsValidJson(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.ValueKind == JsonValueKind.Object;
        }
        catch
        {
            return false;
        }
    }

    private static string NormalizeProvider(string? provider)
    {
        if (string.IsNullOrWhiteSpace(provider))
        {
            return ProviderOllama;
        }

        return provider.Trim().ToLowerInvariant();
    }

    private string ResolveBaseUrl(string provider)
    {
        if (string.Equals(provider, ProviderGemini, StringComparison.OrdinalIgnoreCase))
        {
            return _gemini.BaseAddress?.ToString() ?? _options.GeminiBaseUrl;
        }

        return _ollama.BaseAddress?.ToString() ?? _options.OllamaBaseUrl;
    }

    private static string? ExtractGeminiText(GeminiGenerateResponse? data)
    {
        return data?.Candidates?.FirstOrDefault()
            ?.Content?.Parts?.FirstOrDefault()
            ?.Text?.Trim();
    }

    private static string? ExtractGeminiError(string body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return null;
        }

        try
        {
            using var doc = JsonDocument.Parse(body);
            if (!doc.RootElement.TryGetProperty("error", out var error))
            {
                return null;
            }

            var parts = new List<string>();
            if (error.TryGetProperty("status", out var status))
            {
                var statusValue = status.GetString();
                if (!string.IsNullOrWhiteSpace(statusValue))
                {
                    parts.Add(statusValue);
                }
            }

            if (error.TryGetProperty("code", out var code) && code.TryGetInt32(out var codeValue))
            {
                parts.Add(codeValue.ToString());
            }

            if (error.TryGetProperty("message", out var message))
            {
                var messageValue = message.GetString();
                if (!string.IsNullOrWhiteSpace(messageValue))
                {
                    parts.Add(messageValue);
                }
            }

            return parts.Count > 0 ? string.Join(" ", parts) : null;
        }
        catch
        {
            return null;
        }
    }

    private static string BuildError(
        string provider,
        string model,
        string reason,
        string? detail,
        string? body,
        int? promptLen,
        string? baseUrl)
    {
        var sb = new StringBuilder();
        sb.Append("LLM hatası. Provider=").Append(provider).Append(". Model=").Append(model);
        if (!string.IsNullOrWhiteSpace(baseUrl))
        {
            sb.Append(". BaseUrl=").Append(baseUrl.TrimEnd('/'));
        }

        if (promptLen.HasValue)
        {
            sb.Append(". PromptLen=").Append(promptLen.Value);
        }

        sb.Append(". ").Append(reason);
        if (!string.IsNullOrWhiteSpace(detail))
        {
            sb.Append(" | ").Append(detail);
        }

        if (!string.IsNullOrWhiteSpace(body))
        {
            sb.Append(" | Body=").Append(TrimBody(body, 800));
        }

        return sb.ToString();
    }

    private static string TrimBody(string body, int maxChars)
    {
        var clean = body.Replace("\r", " ").Replace("\n", " ").Trim();
        if (clean.Length <= maxChars)
        {
            return clean;
        }

        return clean[..maxChars];
    }

    private static string? GetRaw(JsonElement root, string property)
    {
        return root.TryGetProperty(property, out var element) ? element.GetRawText() : null;
    }

    private sealed class GenerateRequest
    {
        [JsonPropertyName("model")]
        public string Model { get; set; } = string.Empty;
        [JsonPropertyName("prompt")]
        public string Prompt { get; set; } = string.Empty;
        [JsonPropertyName("stream")]
        public bool Stream { get; set; }
        [JsonPropertyName("format")]
        public string? Format { get; set; }
        [JsonPropertyName("options")]
        public OllamaOptions? Options { get; set; }
    }

    private sealed class OllamaOptions
    {
        [JsonPropertyName("temperature")]
        public double Temperature { get; set; } = 0.1;
        [JsonPropertyName("top_p")]
        public double TopP { get; set; } = 0.9;
        [JsonPropertyName("repeat_penalty")]
        public double RepeatPenalty { get; set; } = 1.1;
        [JsonPropertyName("num_predict")]
        public int NumPredict { get; set; } = 2048;
        [JsonPropertyName("seed")]
        public int Seed { get; set; } = 42;
        [JsonPropertyName("stop")]
        public string[]? Stop { get; set; }
    }

    private sealed class GenerateResponse
    {
        public string? Response { get; set; }
        public string? Model { get; set; }
    }

    private sealed class GeminiGenerateRequest
    {
        [JsonPropertyName("contents")]
        public List<GeminiContent> Contents { get; set; } = new();
        [JsonPropertyName("generationConfig")]
        public GeminiGenerationConfig? GenerationConfig { get; set; }
    }

    private sealed class GeminiGenerationConfig
    {
        [JsonPropertyName("responseMimeType")]
        public string? ResponseMimeType { get; set; }
        [JsonPropertyName("temperature")]
        public double Temperature { get; set; } = 0.1;
        [JsonPropertyName("maxOutputTokens")]
        public int MaxOutputTokens { get; set; } = 2048;
        [JsonPropertyName("stopSequences")]
        public string[]? StopSequences { get; set; }
    }

    private sealed class GeminiGenerateResponse
    {
        [JsonPropertyName("candidates")]
        public List<GeminiCandidate>? Candidates { get; set; }
        [JsonPropertyName("error")]
        public GeminiError? Error { get; set; }
    }

    private sealed class GeminiCandidate
    {
        [JsonPropertyName("content")]
        public GeminiContent? Content { get; set; }
        [JsonPropertyName("finishReason")]
        public string? FinishReason { get; set; }
    }

    private sealed class GeminiContent
    {
        [JsonPropertyName("role")]
        public string? Role { get; set; }
        [JsonPropertyName("parts")]
        public List<GeminiPart> Parts { get; set; } = new();
    }

    private sealed class GeminiPart
    {
        [JsonPropertyName("text")]
        public string Text { get; set; } = string.Empty;
    }

    private sealed class GeminiError
    {
        [JsonPropertyName("message")]
        public string? Message { get; set; }
        [JsonPropertyName("status")]
        public string? Status { get; set; }
        [JsonPropertyName("code")]
        public int? Code { get; set; }
    }

    public sealed class ValidationResult
    {
        public bool IsValid { get; set; }
        public List<string> Issues { get; set; } = new();
        public int QualityScore { get; set; }
    }
}
