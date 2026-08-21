using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using Tokenizers.DotNet;

namespace BkmArgus.AiWorker;

/// <summary>
/// Yerel embedding — ONNX Runtime ile surec icinde calisir, ayri servis yok.
///
/// Neden yerel: metinler mekan, personel ve urun adi tasiyor. Bulut embedding
/// bunlari yurt disina aktarirdi (KVKK). Yerel model ayrica ucretsiz ve
/// aglik gecikmesi yok — 189 kayitlik arsivi tek seferde vektorlemek gerekiyor.
///
/// Model: multilingual-e5-base (ONNX int8, 768 boyut). Turkce denetim metniyle
/// olculdu: 7 kayitlik arsivde 6 sorgudan 5'i dogru ilk sonucu getirdi.
///
/// Onemli: e5 sikisik bir benzerlik araliginda calisir (0.75-0.90). Mutlak
/// esikle karar vermek yaniltir; SemanticMemoryService siralama ve marj
/// kullanir.
/// </summary>
public sealed class LocalEmbeddingService : IDisposable
{
    private const string QueryPrefix = "query: ";
    private const string PassagePrefix = "passage: ";

    private readonly AiWorkerOptions _options;
    private readonly ILogger<LocalEmbeddingService> _logger;
    private readonly SemaphoreSlim _gate = new(1, 1);   // InferenceSession thread-safe degil

    private InferenceSession? _session;
    private Tokenizer? _tokenizer;
    private bool _initAttempted;

    public LocalEmbeddingService(IOptions<AiWorkerOptions> options, ILogger<LocalEmbeddingService> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>Vektorlerin hangi modelle uretildigi DB'ye yazilir.</summary>
    public string ModelName => _options.EmbeddingModel;

    public int Dimensions { get; private set; }

    public bool IsReady => _session is not null && _tokenizer is not null;

    /// <summary>
    /// Modeli diskten yukler. Basarisiz olursa servis kapali kalir ve worker
    /// calismaya devam eder — semantik hafiza atlanir, is durmaz.
    /// </summary>
    private bool EnsureLoaded()
    {
        if (IsReady)
        {
            return true;
        }

        if (_initAttempted)
        {
            return false;
        }

        _initAttempted = true;

        try
        {
            var dir = _options.EmbeddingModelPath;

            if (string.IsNullOrWhiteSpace(dir) || !Directory.Exists(dir))
            {
                _logger.LogWarning("Embedding modeli bulunamadi: {Dizin}. Semantik hafiza devre disi.", dir);
                return false;
            }

            var modelPath = Path.Combine(dir, "model.onnx");
            var tokenizerPath = Path.Combine(dir, "tokenizer.json");

            if (!File.Exists(modelPath) || !File.Exists(tokenizerPath))
            {
                _logger.LogWarning("model.onnx veya tokenizer.json eksik: {Dizin}", dir);
                return false;
            }

            _tokenizer = new Tokenizer(vocabPath: tokenizerPath);

            var sessionOptions = new SessionOptions
            {
                // 16 GB makinede diger islere yer birakmak icin sinirli paralellik
                IntraOpNumThreads = Math.Max(1, Math.Min(4, Environment.ProcessorCount / 2))
            };
            _session = new InferenceSession(modelPath, sessionOptions);

            // Boyutu modelin kendisinden ogren — sabit varsaymak, model
            // degisince sessizce yanlis vektor uretmeye yol acar
            Dimensions = Embed("boyut olcumu", isQuery: false)?.Length ?? 0;

            _logger.LogInformation(
                "Yerel embedding hazir: {Model}, {Boyut} boyut, {Dizin}",
                _options.EmbeddingModel, Dimensions, dir);

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Embedding modeli yuklenemedi. Semantik hafiza devre disi.");
            _session = null;
            _tokenizer = null;
            return false;
        }
    }

    /// <summary>Aranan metni gomer (e5 "query:" oneki).</summary>
    public Task<float[]?> TryEmbedQueryAsync(string text, CancellationToken token = default)
        => TryEmbedAsync(text, isQuery: true, token);

    /// <summary>Arsivlenen metni gomer (e5 "passage:" oneki).</summary>
    public Task<float[]?> TryEmbedPassageAsync(string text, CancellationToken token = default)
        => TryEmbedAsync(text, isQuery: false, token);

    private async Task<float[]?> TryEmbedAsync(string text, bool isQuery, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }

        await _gate.WaitAsync(token);
        try
        {
            return !EnsureLoaded() ? null : Embed(text, isQuery);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Embedding uretilemedi.");
            return null;
        }
        finally
        {
            _gate.Release();
        }
    }

    private float[]? Embed(string text, bool isQuery)
    {
        if (_tokenizer is null || _session is null)
        {
            return null;
        }

        // e5 asimetriktir: sorgu ve belge farkli oneklerle gomulur.
        // Oneki atlamak kaliteyi belirgin dusurur.
        var prefixed = (isQuery ? QueryPrefix : PassagePrefix) + text;

        var ids = _tokenizer.Encode(prefixed).Select(i => (long)i).ToArray();

        // Model penceresi asilirsa kirp — uzun DOF aciklamalari icin gerekli
        if (ids.Length > _options.EmbeddingMaxTokens)
        {
            ids = ids.Take(_options.EmbeddingMaxTokens).ToArray();
        }

        var n = ids.Length;

        using var result = _session.Run(
        [
            NamedOnnxValue.CreateFromTensor("input_ids", new DenseTensor<long>(ids, [1, n])),
            NamedOnnxValue.CreateFromTensor("attention_mask",
                new DenseTensor<long>(Enumerable.Repeat(1L, n).ToArray(), [1, n]))
        ]);

        var last = result.First().AsTensor<float>();      // [1, n, hidden]
        var hidden = last.Dimensions[2];

        // Ortalama havuzlama + L2 normalizasyon — e5'in sozlesmesi.
        // Normalizasyon sayesinde kosinus benzerligi basit nokta carpimina duser.
        var vector = new float[hidden];
        for (var t = 0; t < n; t++)
        {
            for (var h = 0; h < hidden; h++)
            {
                vector[h] += last[0, t, h];
            }
        }

        var norm = 0f;
        for (var h = 0; h < hidden; h++)
        {
            vector[h] /= n;
            norm += vector[h] * vector[h];
        }

        norm = MathF.Sqrt(norm);
        if (norm <= float.Epsilon)
        {
            return null;
        }

        for (var h = 0; h < hidden; h++)
        {
            vector[h] /= norm;
        }

        return vector;
    }

    public void Dispose()
    {
        _session?.Dispose();
        _gate.Dispose();
    }
}
