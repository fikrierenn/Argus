using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace BkmArgus.AiWorker;

/// <summary>
/// OpenAI uyumlu saglayicilar icin TEK cagri yolu.
/// GLM (Z.AI), DeepSeek, Groq, OpenRouter, Together, Mistral, vLLM ve benzerleri
/// ayni sozlesmeyi konusur; yeni birini eklemek icin bu dosya DEGISMEZ —
/// ai.LlmProviders tablosuna Kind = 'openai' kaydi eklemek yeter.
/// LlmService buyudugu icin saglayici basina ayri dosyaya bolunmustur
/// (csharp-conventions.md dosya boyutu disiplini).
/// </summary>
public sealed partial class LlmService
{
    private async Task<LlmCallResult> CallOpenAiCompatibleWithRetryAsync(LlmProviderConfig provider, string model, string prompt, CancellationToken token)
    {
        const int maxRetries = 2;

        for (var attempt = 1; attempt <= maxRetries; attempt++)
        {
            try
            {
                var result = await CallOpenAiCompatibleAsync(provider, model, prompt, token);
                if (result.Success)
                {
                    return result;
                }

                if (attempt < maxRetries)
                {
                    var delay = TimeSpan.FromSeconds(2 * attempt);
                    _logger.LogWarning("{Saglayici} {Attempt}. deneme basarisiz. {Delay}s sonra tekrar. Hata: {Error}",
                        provider.Name, attempt, delay.TotalSeconds, result.Error);
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
                _logger.LogError(ex, "{Saglayici} {Attempt}. denemesi istisna ile basarisiz", provider.Name, attempt);
                if (attempt == maxRetries)
                {
                    return new LlmCallResult { Error = $"{provider.Name} {maxRetries} denemede basarisiz: {ex.Message}" };
                }
            }
        }

        return new LlmCallResult { Error = $"{provider.Name} {maxRetries} denemede basarisiz." };
    }

    private async Task<LlmCallResult> CallOpenAiCompatibleAsync(LlmProviderConfig provider, string model, string prompt, CancellationToken token)
    {
        var baseUrl = provider.BaseUrl;

        // Anahtar yoksa saglayici KAPALI sayilir — exception degil, hata sonucu (ai-layer.md §2)
        if (string.IsNullOrWhiteSpace(provider.ApiKey))
        {
            return new LlmCallResult
            {
                Error = BuildError(provider.Name, model, "API anahtari bos.", null, null, prompt.Length, baseUrl)
            };
        }

        if (string.IsNullOrWhiteSpace(model))
        {
            return new LlmCallResult
            {
                Error = BuildError(provider.Name, "-", "Model adi bos.", null, null, prompt.Length, baseUrl)
            };
        }

        using var cts = CancellationTokenSource.CreateLinkedTokenSource(token);
        cts.CancelAfter(TimeSpan.FromSeconds(_options.LlmTimeoutSeconds));

        try
        {
            // Prompt icindeki <|system|> blogu ayrilir; GLM sistem mesajini
            // ayri bir mesaj olarak bekler (OpenAI sozlesmesi).
            var (systemPrompt, userPrompt) = ExtractClaudeSystemPrompt(prompt);

            var payload = new OpenAiChatRequest
            {
                Model = model,
                Temperature = _options.Temperature,
                // Saglayici kendi sinirini bildirmisse o gecerli: muhakeme modeli
                // 8-16K isterken kucuk bir model 2K ile yetinir.
                MaxTokens = provider.MaxOutputTokens is > 0
                    ? provider.MaxOutputTokens.Value
                    : (_options.MaxTokens > 0 ? _options.MaxTokens : 4096)
            };

            if (!string.IsNullOrWhiteSpace(systemPrompt))
            {
                payload.Messages.Add(new OpenAiMessage { Role = "system", Content = systemPrompt });
            }

            payload.Messages.Add(new OpenAiMessage { Role = "user", Content = userPrompt });

            var requestJson = MergeExtraBody(
                JsonSerializer.Serialize(payload, JsonOptions),
                provider.ExtraBodyJson,
                provider.Name);

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                $"{provider.BaseUrl.TrimEnd('/')}/{provider.Path.TrimStart('/')}");
            request.Headers.Add("Authorization", $"Bearer {provider.ApiKey}");
            request.Content = new StringContent(requestJson, Encoding.UTF8, "application/json");

            using var response = await _openAi.SendAsync(request, cts.Token);
            var body = await response.Content.ReadAsStringAsync(cts.Token);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("{Saglayici} HTTP istegi basarisiz. Model={Model} Status={Status}", provider.Name, model, response.StatusCode);
                var detail = $"Status={(int)response.StatusCode} {response.ReasonPhrase}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(provider.Name, model, "HTTP istegi basarisiz.", detail, body, prompt.Length, baseUrl)
                };
            }

            if (string.IsNullOrWhiteSpace(body))
            {
                return new LlmCallResult
                {
                    Error = BuildError(provider.Name, model, "HTTP yaniti bos.", "BodyLen=0", null, prompt.Length, baseUrl)
                };
            }

            OpenAiChatResponse? data;
            try
            {
                data = JsonSerializer.Deserialize<OpenAiChatResponse>(body, JsonOptions);
            }
            catch (JsonException ex)
            {
                var detail = $"ParseError={ex.GetType().Name}: {ex.Message}; BodyLen={body.Length}";
                return new LlmCallResult
                {
                    Error = BuildError(provider.Name, model, "Yanit parse edilemedi.", detail, body, prompt.Length, baseUrl)
                };
            }

            var choice = data?.Choices?.FirstOrDefault();
            var raw = choice?.Message?.Content;

            if (string.IsNullOrWhiteSpace(raw))
            {
                var detail = $"BodyLen={body.Length}; FinishReason={choice?.FinishReason ?? "-"}";

                if (!string.IsNullOrWhiteSpace(data?.Error?.Message))
                {
                    detail = $"{detail}; ApiError={data.Error.Message}";
                }

                // Muhakeme modeli token butcesini dusunmeye harcadiysa bunu acikca
                // soyle — "yanit bos" demek gercek sebebi gizliyordu.
                var reasoningLen = choice?.Message?.ReasoningContent?.Length ?? 0;
                var message = choice?.FinishReason == "length" && reasoningLen > 0
                    ? $"Token butcesi muhakemeye harcandi, cevap alani bos kaldi "
                      + $"(reasoning {reasoningLen} karakter, MaxTokens={_options.MaxTokens}). "
                      + "MaxTokens artirin veya modelin dusunme modunu kapatin."
                    : "Yanit bos.";

                return new LlmCallResult
                {
                    Error = BuildError(provider.Name, model, message, detail, body, prompt.Length, baseUrl)
                };
            }

            var json = ExtractAndValidateJson(raw);
            if (string.IsNullOrWhiteSpace(json))
            {
                _logger.LogWarning("{Saglayici} icin gecerli JSON cikarilamadi. Raw={Raw}", provider.Name, raw[..Math.Min(200, raw.Length)]);
                return new LlmCallResult
                {
                    Error = BuildError(provider.Name, model, "Gecerli JSON bulunamadi.",
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
                Error = BuildError(provider.Name, model, $"Zaman asimi ({_options.LlmTimeoutSeconds}s).",
                    null, null, prompt.Length, baseUrl)
            };
        }
        catch (HttpRequestException ex)
        {
            return new LlmCallResult
            {
                Error = BuildError(provider.Name, model, "Baglanti hatasi.", ex.Message, null, prompt.Length, baseUrl)
            };
        }
    }

    /// <summary>
    /// Saglayiciya ozel parametreleri istek govdesine birlestirir. Ayni ada sahip
    /// alan varsa saglayici ayari kazanir. Bozuk JSON istegi durdurmaz — uyarilir
    /// ve yok sayilir; kayit anindaki ISJSON kisiti zaten ilk savunma hattidir.
    /// </summary>
    private string MergeExtraBody(string baseJson, string? extraBodyJson, string providerName)
    {
        if (string.IsNullOrWhiteSpace(extraBodyJson))
        {
            return baseJson;
        }

        try
        {
            var merged = JsonNode.Parse(baseJson)!.AsObject();
            var extra = JsonNode.Parse(extraBodyJson)?.AsObject();

            if (extra is null)
            {
                return baseJson;
            }

            foreach (var (key, value) in extra.ToList())
            {
                merged[key] = value?.DeepClone();
            }

            return merged.ToJsonString();
        }
        catch (JsonException ex)
        {
            _logger.LogWarning("{Saglayici} ek govde parametreleri okunamadi, yok sayiliyor: {Mesaj}",
                providerName, ex.Message);
            return baseJson;
        }
    }

    // ── OpenAI sohbet-tamamlama sozlesmesi ─────────────────────────────────

    private sealed class OpenAiChatRequest
    {
        [JsonPropertyName("model")]
        public string Model { get; set; } = string.Empty;

        [JsonPropertyName("messages")]
        public List<OpenAiMessage> Messages { get; } = [];

        [JsonPropertyName("temperature")]
        public double Temperature { get; set; }

        [JsonPropertyName("max_tokens")]
        public int MaxTokens { get; set; }
    }

    private sealed class OpenAiMessage
    {
        [JsonPropertyName("role")]
        public string Role { get; set; } = string.Empty;

        [JsonPropertyName("content")]
        public string Content { get; set; } = string.Empty;

        /// <summary>
        /// Muhakeme modellerinde (GLM-4.6, DeepSeek-R1 vb.) dusunme adimlari buraya
        /// gelir ve token butcesinden dusulur. Cevap alaninin bos kalmasinin en
        /// yaygin sebebi budur; teshis icin okunur, icerik olarak kullanilmaz.
        /// </summary>
        [JsonPropertyName("reasoning_content")]
        public string? ReasoningContent { get; set; }
    }

    private sealed class OpenAiChatResponse
    {
        [JsonPropertyName("choices")]
        public List<OpenAiChoice>? Choices { get; set; }

        [JsonPropertyName("error")]
        public OpenAiError? Error { get; set; }
    }

    private sealed class OpenAiChoice
    {
        [JsonPropertyName("message")]
        public OpenAiMessage? Message { get; set; }

        /// <summary>"stop" | "length" | "content_filter" — bos yanitin sebebini ayirt eder.</summary>
        [JsonPropertyName("finish_reason")]
        public string? FinishReason { get; set; }
    }

    private sealed class OpenAiError
    {
        [JsonPropertyName("message")]
        public string? Message { get; set; }
    }
}
