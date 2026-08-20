using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public sealed class EmbeddingService
{
    private readonly HttpClient _http;
    private readonly AiWorkerOptions _options;
    private readonly ILogger<EmbeddingService> _logger;

    // Devre kesici: Ollama kapaliyken her kayit icin yeniden baglanmaya calismak
    // worker'i surunduruyordu (her deneme tam bir baglanti zaman asimi). Ust uste
    // birkac hatadan sonra servis bir sure "hazir degil" sayilir.
    private const int FailureThreshold = 3;
    private static readonly TimeSpan CooldownPeriod = TimeSpan.FromMinutes(5);

    private int _consecutiveFailures;
    private DateTime _unavailableUntilUtc = DateTime.MinValue;

    public bool IsReady =>
        !string.IsNullOrWhiteSpace(_options.EmbeddingModel)
        && DateTime.UtcNow >= _unavailableUntilUtc;

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
                RegisterFailure();
                return null;
            }

            var result = await response.Content.ReadFromJsonAsync<EmbeddingResponse>(cancellationToken: cts.Token);
            _consecutiveFailures = 0;
            return result?.Embedding;
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
            // Temiz kapanis — devre kesiciye hata olarak yazilmaz
            throw;
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Embedding istegi zaman asimina ugradi.");
            RegisterFailure();
            return null;
        }
        catch (HttpRequestException ex)
        {
            // Baglanti hatasi — yigin izi basmaya gerek yok, tekrarlayan bir durum
            _logger.LogWarning("Embedding servisine ulasilamadi: {Mesaj}", ex.Message);
            RegisterFailure();
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Embedding istegi hatasi.");
            RegisterFailure();
            return null;
        }
    }

    // Ust uste hata sayisi esigi asinca servisi gecici olarak devre disi birakir.
    // Sessiz basarisizlik degil: devre acildiginda bir kez uyari loglanir.
    private void RegisterFailure()
    {
        _consecutiveFailures++;

        if (_consecutiveFailures < FailureThreshold || DateTime.UtcNow < _unavailableUntilUtc)
        {
            return;
        }

        _unavailableUntilUtc = DateTime.UtcNow.Add(CooldownPeriod);
        _logger.LogWarning(
            "Embedding servisi {Adet} ust uste hatadan sonra {Dakika} dakika devre disi birakildi. " +
            "Semantik hafiza bu surede atlanir.",
            _consecutiveFailures, CooldownPeriod.TotalMinutes);
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
