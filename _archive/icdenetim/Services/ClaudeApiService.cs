using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace BkmArgus.Services;

/// <summary>
/// Claude API servisi - HttpClient ile dogrudan API cagrisi.
/// </summary>
public class ClaudeApiService : IClaudeApiService
{
    private readonly IConfiguration _config;
    private readonly ILogger<ClaudeApiService> _logger;
    private readonly HttpClient _httpClient;
    private const string ApiUrl = "https://api.anthropic.com/v1/messages";
    private const string DefaultModel = "claude-sonnet-4-20250514";

    public ClaudeApiService(IConfiguration config, ILogger<ClaudeApiService> logger)
    {
        _config = config;
        _logger = logger;
        _httpClient = new HttpClient();
    }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_config["Claude__ApiKey"]);

    public async Task<string> AnalyzeAsync(string systemPrompt, string userMessage)
    {
        if (!IsConfigured)
        {
            _logger.LogWarning("Claude API anahtari yapilandirilmamis. Claude__ApiKey ortam degiskenini kontrol edin.");
            return "[AI yapilandirilmamis] Claude__ApiKey tanimlanmalidir.";
        }

        try
        {
            var requestBody = new
            {
                model = DefaultModel,
                max_tokens = 2048,
                system = systemPrompt,
                messages = new[] { new { role = "user", content = userMessage } }
            };

            var json = JsonSerializer.Serialize(requestBody);
            var request = new HttpRequestMessage(HttpMethod.Post, ApiUrl)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
            request.Headers.Add("x-api-key", _config["Claude__ApiKey"]);
            request.Headers.Add("anthropic-version", "2023-06-01");

            var response = await _httpClient.SendAsync(request);

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                _logger.LogError("Claude API hatasi: {Status} - {Body}", response.StatusCode, errorBody);
                return $"[AI hatasi] {response.StatusCode}";
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(responseJson);
            var content = doc.RootElement.GetProperty("content");
            if (content.GetArrayLength() > 0)
            {
                return content[0].GetProperty("text").GetString() ?? "[AI bos yanit]";
            }

            return "[AI bos yanit]";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Claude API cagrisi basarisiz.");
            return $"[AI hatasi] {ex.Message}";
        }
    }

    public async Task<string> AnalyzeWithVisionAsync(string systemPrompt, string userMessage, byte[] imageData)
    {
        if (!IsConfigured)
        {
            _logger.LogWarning("Claude API anahtari yapilandirilmamis.");
            return "[AI yapilandirilmamis] Claude__ApiKey tanimlanmalidir.";
        }

        try
        {
            var base64Image = Convert.ToBase64String(imageData);
            var requestBody = new
            {
                model = DefaultModel,
                max_tokens = 2048,
                system = systemPrompt,
                messages = new[]
                {
                    new
                    {
                        role = "user",
                        content = new object[]
                        {
                            new
                            {
                                type = "image",
                                source = new
                                {
                                    type = "base64",
                                    media_type = "image/jpeg",
                                    data = base64Image
                                }
                            },
                            new { type = "text", text = userMessage }
                        }
                    }
                }
            };

            var json = JsonSerializer.Serialize(requestBody);
            var request = new HttpRequestMessage(HttpMethod.Post, ApiUrl)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
            request.Headers.Add("x-api-key", _config["Claude__ApiKey"]);
            request.Headers.Add("anthropic-version", "2023-06-01");

            var response = await _httpClient.SendAsync(request);

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                _logger.LogError("Claude Vision API hatasi: {Status} - {Body}", response.StatusCode, errorBody);
                return $"[AI hatasi] {response.StatusCode}";
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(responseJson);
            var content = doc.RootElement.GetProperty("content");
            if (content.GetArrayLength() > 0)
            {
                return content[0].GetProperty("text").GetString() ?? "[AI bos yanit]";
            }

            return "[AI bos yanit]";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Claude Vision API cagrisi basarisiz.");
            return $"[AI hatasi] {ex.Message}";
        }
    }

    public async Task<Stream> StreamAnalyzeAsync(string systemPrompt, string userMessage)
    {
        if (!IsConfigured)
        {
            _logger.LogWarning("Claude API anahtari yapilandirilmamis.");
            return new MemoryStream(Encoding.UTF8.GetBytes("[AI yapilandirilmamis] Claude__ApiKey tanimlanmalidir."));
        }

        try
        {
            var requestBody = new
            {
                model = DefaultModel,
                max_tokens = 4096,
                stream = true,
                system = systemPrompt,
                messages = new[] { new { role = "user", content = userMessage } }
            };

            var json = JsonSerializer.Serialize(requestBody);
            var request = new HttpRequestMessage(HttpMethod.Post, ApiUrl)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
            request.Headers.Add("x-api-key", _config["Claude__ApiKey"]);
            request.Headers.Add("anthropic-version", "2023-06-01");

            var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadAsStreamAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Claude Streaming API cagrisi basarisiz.");
            return new MemoryStream(Encoding.UTF8.GetBytes($"[AI hatasi] {ex.Message}"));
        }
    }
}
