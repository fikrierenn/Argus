using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public sealed class EmbeddingService
{
    private readonly HttpClient _http;
    private readonly AiWorkerOptions _options;
    private readonly ILogger<EmbeddingService> _logger;

    public bool IsReady => !string.IsNullOrWhiteSpace(_options.EmbeddingModel);

    public EmbeddingService(
        IHttpClientFactory httpFactory,
        IOptions<AiWorkerOptions> options,
        ILogger<EmbeddingService> logger)
    {
        _http = httpFactory.CreateClient("ollama");
        _options = options.Value;
        _logger = logger;
    }

    public async Task<float[]?> TryEmbedAsync(string text, CancellationToken token)
    {
        if (!IsReady || string.IsNullOrWhiteSpace(text))
        {
            return null;
        }

        using var cts = CancellationTokenSource.CreateLinkedTokenSource(token);
        cts.CancelAfter(TimeSpan.FromSeconds(_options.EmbeddingTimeoutSeconds));

        try
        {
            var payload = new EmbeddingRequest
            {
                Model = _options.EmbeddingModel,
                Prompt = text
            };

            using var response = await _http.PostAsJsonAsync("api/embeddings", payload, cts.Token);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Embedding istegi basarisiz. Status={Status}", response.StatusCode);
                return null;
            }

            var result = await response.Content.ReadFromJsonAsync<EmbeddingResponse>(cancellationToken: cts.Token);
            return result?.Embedding;
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Embedding istegi zaman asimina ugradi.");
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Embedding istegi hatasi.");
            return null;
        }
    }

    private sealed class EmbeddingRequest
    {
        public string Model { get; set; } = string.Empty;
        public string Prompt { get; set; } = string.Empty;
    }

    private sealed class EmbeddingResponse
    {
        public float[]? Embedding { get; set; }
    }
}
