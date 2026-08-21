using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using Tokenizers.DotNet;

namespace BkmArgus.AiWorker;

/// <summary>
/// Cross-encoder yeniden siralayici. Sorgu ve belgeyi BIRLIKTE gorur, tek bir
/// alaka skoru uretir — bu yuzden iki ayri vektorun kosinusundan daha
/// isabetlidir, ama her aday icin bir model cagrisi gerektirir.
///
/// OLCUM (ai.RetrievalEvalSet, iki bagimsiz sorgu seti):
///
///                        ELLE(30)      LLM(20)      TUMU(50)
///   yapilandirma        H@1   H@3    H@1   H@3    H@1   H@3    ms
///   hibrit rrf15       0,767 1,000  0,700 0,850  0,740 0,940    35
///   + seroe-mmarco-tr  0,967 1,000  0,650 0,750  0,840 0,900  1679
///   + ytu-modernbert   0,933 1,000  0,600 0,900  0,800 0,960  2453
///
/// Iki set bilincli olarak farkli: ELLE sorgulari denetci dilinde yazildi ve
/// kayitlarla kelime paylasiyor; LLM sorgulari saf parafraz, ortusme yok.
/// Siralama setler arasinda TERSINE DONUYOR — reranker kelime paylasan
/// sorgularda cok iyi, saf parafrazda hibritten kotu. Gercek kullanim karisik.
///
/// KARAR: varsayilan KAPALI. Reranker top-1 kesinligi gereken yerde kazandirir
/// (0,740 -> 0,840); LLM'e ilk N kanit secilirken ise H@3 onemlidir ve orada
/// hibrit zaten 0,940 ile onde, ustelik 48 kat hizli. Acmadan once kendi
/// kullanim sekliniz icin ai.RetrievalEvalRuns'a bakin.
///
/// Aday penceresi 10'dan 25'e cikarmak OLCULDU: kazanc yok, sure iki kati.
/// </summary>
public sealed class CrossEncoderReranker : IDisposable
{
    private readonly AiWorkerOptions _options;
    private readonly ILogger<CrossEncoderReranker> _logger;
    private readonly SemaphoreSlim _gate = new(1, 1);   // InferenceSession thread-safe degil

    private InferenceSession? _session;
    private Tokenizer? _tokenizer;
    private bool _initAttempted;

    public CrossEncoderReranker(IOptions<AiWorkerOptions> options, ILogger<CrossEncoderReranker> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public bool IsEnabled => _options.RerankerEnabled;

    /// <summary>
    /// Adaylari yeniden siralar. Model yuklenemezse GIRDI SIRASI korunur —
    /// reranker bir iyilestirmedir, olmadiginda arama calismaya devam eder.
    /// </summary>
    public async Task<IReadOnlyList<T>> RerankAsync<T>(
        string query,
        IReadOnlyList<T> candidates,
        Func<T, string> textSelector,
        CancellationToken token = default)
    {
        if (!_options.RerankerEnabled || candidates.Count <= 1 || string.IsNullOrWhiteSpace(query))
        {
            return candidates;
        }

        await _gate.WaitAsync(token);
        try
        {
            if (!EnsureLoaded())
            {
                return candidates;
            }

            // Yalniz ilk N aday yeniden siralanir; gerisi sirasini korur.
            // Tum listeyi skorlamak gecikmeyi lineer buyutur, kazanci buyutmez.
            var window = Math.Min(_options.RerankerTopN, candidates.Count);
            var scored = new List<(T Item, float Score)>(window);

            for (var i = 0; i < window; i++)
            {
                token.ThrowIfCancellationRequested();
                scored.Add((candidates[i], Score(query, textSelector(candidates[i]))));
            }

            scored.Sort((a, b) => b.Score.CompareTo(a.Score));

            var result = new List<T>(candidates.Count);
            result.AddRange(scored.Select(s => s.Item));
            result.AddRange(candidates.Skip(window));
            return result;
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Yeniden siralama basarisiz; hibrit sirasi korunuyor.");
            return candidates;
        }
        finally
        {
            _gate.Release();
        }
    }

    private bool EnsureLoaded()
    {
        if (_session is not null && _tokenizer is not null)
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
            var dir = _options.RerankerModelPath;

            if (string.IsNullOrWhiteSpace(dir) || !Directory.Exists(dir))
            {
                _logger.LogWarning("Reranker modeli bulunamadi: {Dizin}. Yeniden siralama atlanacak.", dir);
                return false;
            }

            var modelPath = Path.Combine(dir, "model.onnx");
            var tokenizerPath = Path.Combine(dir, "tokenizer.json");

            if (!File.Exists(modelPath) || !File.Exists(tokenizerPath))
            {
                _logger.LogWarning("Reranker dosyalari eksik: {Dizin}", dir);
                return false;
            }

            _tokenizer = new Tokenizer(vocabPath: tokenizerPath);
            _session = new InferenceSession(modelPath, new SessionOptions
            {
                IntraOpNumThreads = Math.Max(1, Math.Min(4, Environment.ProcessorCount / 2))
            });

            _logger.LogInformation("Reranker hazir: {Model}", _options.RerankerModel);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Reranker yuklenemedi; yeniden siralama devre disi.");
            _session = null;
            _tokenizer = null;
            return false;
        }
    }

    private float Score(string query, string document)
    {
        // Ozel token sozlesmesi model ailesine gore degisir. Yanlis sozlesme
        // hata vermez, SESSIZCE bozuk skor uretir — bu yuzden yapilandirmadan
        // okunuyor, tahmin edilmiyor.
        var q = _tokenizer!.Encode(query).Select(i => (long)i).ToList();
        var d = _tokenizer.Encode(document).Select(i => (long)i).ToList();

        List<long> ids;

        if (string.Equals(_options.RerankerTokenStyle, "bert", StringComparison.OrdinalIgnoreCase))
        {
            // [CLS] sorgu [SEP] belge [SEP]
            if (q.Count > 0 && q[^1] == 3) q.RemoveAt(q.Count - 1);
            if (d.Count > 0 && d[0] == 2) d.RemoveAt(0);
            if (d.Count > 0 && d[^1] == 3) d.RemoveAt(d.Count - 1);
            ids = q.Concat(d).Append(3L).ToList();
        }
        else
        {
            // XLM-R: <s> sorgu </s> belge </s>
            if (q.Count > 0 && q[^1] == 2) q.RemoveAt(q.Count - 1);
            if (d.Count > 0 && d[0] == 0) d.RemoveAt(0);
            ids = q.Concat([2L]).Concat(d).ToList();
        }

        if (ids.Count > _options.RerankerMaxTokens)
        {
            ids = ids.Take(_options.RerankerMaxTokens).ToList();
        }

        var n = ids.Count;

        using var result = _session!.Run(
        [
            NamedOnnxValue.CreateFromTensor("input_ids", new DenseTensor<long>(ids.ToArray(), [1, n])),
            NamedOnnxValue.CreateFromTensor("attention_mask",
                new DenseTensor<long>(Enumerable.Repeat(1L, n).ToArray(), [1, n]))
        ]);

        // Tek etiketli alaka skoru. Mutlak deger kalibre DEGIL — bu modeller
        // dogru cevaba da negatif logit verebilir. Yalniz SIRALAMA anlamlidir,
        // bu yuzden skor bir esikle karsilastirilmaz.
        return result.First().AsTensor<float>()[0, 0];
    }

    public void Dispose()
    {
        _session?.Dispose();
        _gate.Dispose();
    }
}
