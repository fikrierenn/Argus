using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace BkmArgus.AiWorker;

/// <summary>
/// GLM (Z.AI) saglayicisi. OpenAI uyumlu /chat/completions ucu kullanir.
/// LlmService buyudugu icin saglayici basina ayri dosyaya bolunmustur
/// (csharp-conventions.md dosya boyutu disiplini).
/// </summary>
public sealed partial class LlmService
{
    private async Task<LlmCallResult> CallGlmWithRetryAsync(string model, string prompt, CancellationToken token)
    {
        const int maxRetries = 2;

        for (var attempt = 1; attempt <= maxRetries; attempt++)
        {
            try
            {
                var result = await CallGlmAsync(model, prompt, token);
                if (result.Success)
                {
                    return result;
                }

                if (attempt < maxRetries)
                {
                    var delay = TimeSpan.FromSeconds(2 * attempt);
                    _logger.LogWarning("GLM {Attempt}. deneme basarisiz. {Delay}s sonra tekrar. Hata: {Error}",
                        attempt, delay.TotalSeconds, result.Error);
                    await Task.Delay(delay, token);
                }
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                // Temiz kapanis — yutma, yukari birak
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GLM {Attempt}. denemesi istisna ile basarisiz", attempt);
                if (attempt == maxRetries)
                {
                    return new LlmCallResult { Error = $"GLM {maxRetries} denemede basarisiz: {ex.Message}" };
                }
            }
        }

        return new LlmCallResult { Error = $"GLM {maxRetries} denemede basarisiz." };
    }

    private async Task<LlmCallResult> CallGlmAsync(string model, string prompt, CancellationToken token)
    {
        var baseUrl = ResolveBaseUrl(ProviderGlm);

        // Anahtar yoksa saglayici KAPALI sayilir — exception degil, hata sonucu (ai-layer.md §2)
        if (string.IsNullOrWhiteSpace(_options.GlmApiKey))
        {
            return new LlmCallResult
            {
                Error = BuildError(ProviderGlm, model, "GLM API anahtari bos.", null, null, prompt.Length, baseUrl)
            };
        }

        if (string.IsNullOrWhiteSpace(model))
        {
            return new LlmCallResult
            {
                Error = BuildError(ProviderGlm, "-", "GLM model adi bos.", null, null, prompt.Length, baseUrl)
            };
        }

        using var cts = CancellationTokenSource.CreateLinkedTokenSource(token);
        cts.CancelAfter(TimeSpan.FromSeconds(_options.LlmTimeoutSeconds));

        try
        {
            // Prompt icindeki <|system|> blogu ayrilir; GLM sistem mesajini
            // ayri bir mesaj olarak bekler (OpenAI sozlesmesi).
            var (systemPrompt, userPrompt) = ExtractClaudeSystemPrompt(prompt);

            var payload = new GlmChatRequest
            {
                Model = model,
                Temperature = _options.Temperature,
                MaxTokens = _options.MaxTokens > 0 ? _options.MaxTokens : 4096
            };

            if (!string.IsNullOrWhiteSpace(systemPrompt))
            {
                payload.Messages.Add(new GlmMessage { Role = "system", Content = systemPrompt });
            }

            payload.Messages.Add(new GlmMessage { Role = "user", Content = userPrompt });

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                $"{_options.GlmBaseUrl.TrimEnd('/')}/api/paas/v4/chat/completions");
            request.Headers.Add("Authorization", $"Bearer {_options.GlmApiKey}");
            request.Content = new StringContent(
                JsonSerializer.Serialize(payload, JsonOptions),
                Encoding.UTF8,
                "application/json");

            using var response = await _glm.SendAsync(request, cts.Token);
            var body = await response.Content.ReadAsStringAsync(cts.Token);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("GLM HTTP istegi basarisiz. Model={Model} Status={Status}", model, response.StatusCode);
                var detail = $"Status={(int)response.StatusCode} {response.ReasonPhrase}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGlm, model, "HTTP istegi basarisiz.", detail, body, prompt.Length, baseUrl)
                };
            }

            if (string.IsNullOrWhiteSpace(body))
            {
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGlm, model, "HTTP yaniti bos.", "BodyLen=0", null, prompt.Length, baseUrl)
                };
            }

            GlmChatResponse? data;
            try
            {
                data = JsonSerializer.Deserialize<GlmChatResponse>(body, JsonOptions);
            }
            catch (JsonException ex)
            {
                var detail = $"ParseError={ex.GetType().Name}: {ex.Message}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGlm, model, "GLM yaniti parse edilemedi.", detail, body, prompt.Length, baseUrl)
                };
            }

            var raw = data?.Choices?.FirstOrDefault()?.Message?.Content;
            if (string.IsNullOrWhiteSpace(raw))
            {
                var detail = $"BodyLen={body.Length}";
                if (!string.IsNullOrWhiteSpace(data?.Error?.Message))
                {
                    detail = $"{detail}; ApiError={data.Error.Message}";
                }

                return new LlmCallResult
                {
                    Error = BuildError(ProviderGlm, model, "GLM yaniti bos.", detail, body, prompt.Length, baseUrl)
                };
            }

            var json = ExtractAndValidateJson(raw);
            if (string.IsNullOrWhiteSpace(json))
            {
                _logger.LogWarning("GLM icin gecerli JSON cikarilamadi. Raw={Raw}", raw[..Math.Min(200, raw.Length)]);
                return new LlmCallResult
                {
                    Error = BuildError(ProviderGlm, model, "Gecerli JSON bulunamadi.",
                        $"RawLen={raw.Length}", raw[..Math.Min(500, raw.Length)], prompt.Length, baseUrl)
                };
            }

            return new LlmCallResult { Result = ParseAndValidateResult(json, model) };
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            // Zaman asimi — cagiran iptal etmedi, sure doldu
            return new LlmCallResult
            {
                Error = BuildError(ProviderGlm, model, $"Zaman asimi ({_options.LlmTimeoutSeconds}s).",
                    null, null, prompt.Length, baseUrl)
            };
        }
        catch (HttpRequestException ex)
        {
            return new LlmCallResult
            {
                Error = BuildError(ProviderGlm, model, "Baglanti hatasi.", ex.Message, null, prompt.Length, baseUrl)
            };
        }
    }

    // ── GLM istek/yanit sozlesmesi (OpenAI uyumlu) ─────────────────────────

    private sealed class GlmChatRequest
    {
        [JsonPropertyName("model")]
        public string Model { get; set; } = string.Empty;

        [JsonPropertyName("messages")]
        public List<GlmMessage> Messages { get; } = [];

        [JsonPropertyName("temperature")]
        public double Temperature { get; set; }

        [JsonPropertyName("max_tokens")]
        public int MaxTokens { get; set; }
    }

    private sealed class GlmMessage
    {
        [JsonPropertyName("role")]
        public string Role { get; set; } = string.Empty;

        [JsonPropertyName("content")]
        public string Content { get; set; } = string.Empty;
    }

    private sealed class GlmChatResponse
    {
        [JsonPropertyName("choices")]
        public List<GlmChoice>? Choices { get; set; }

        [JsonPropertyName("error")]
        public GlmError? Error { get; set; }
    }

    private sealed class GlmChoice
    {
        [JsonPropertyName("message")]
        public GlmMessage? Message { get; set; }
    }

    private sealed class GlmError
    {
        [JsonPropertyName("message")]
        public string? Message { get; set; }
    }
}
