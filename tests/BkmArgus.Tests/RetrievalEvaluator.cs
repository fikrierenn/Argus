using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;
using Tokenizers.DotNet;

namespace BkmArgus.Tests;

/// <summary>
/// Geri getirme kalitesi olcumu. Yapilandirmalari ayni sorgu setiyle
/// karsilastirir; hangi degisikligin gercekten kazandirdigini sayiyla soyler.
///
/// Bu oturumda arama uzerine dort karar verildi ve dordunde de tahmin yanildi:
/// agirligin carpan olmasi siralamayi eziyordu, sablon oneki benzerligi
/// cokertiyordu, ortalama merkezleme faydali sanildi ama zararliydi,
/// Ingilizce reranker iyilestirir sanildi ama bozdu. Bu sinif o donguyu
/// kapatmak icin var.
///
/// Metrik secimi: sorgu basina TEK dogru cevap var, bu yuzden MRR ve
/// HitRate uygundur. nDCG dereceli alaka icin tasarlandi; ikili alakada
/// MRR ile ayni bilgiyi verir, ek bir sey soylemez.
///
/// Beklenti: 30 sorgu kucuk bir settir. Birkac puanlik fark gurultu
/// olabilir; yalnizca buyuk farklar (or. 0,767 -> 0,967) guvenle yorumlanir.
/// "0,60 -> 0,63 iyilestirdim" bu setle SAVUNULAMAZ.
/// </summary>
public sealed class RetrievalEvaluator : IDisposable
{
    /// <summary>
    /// Yeniden siralanacak aday sayisi. Kucuk pencere hizli ama dogru cevap
    /// hibritin ilk N'ine giremezse reranker onu kurtaramaz — parafraz
    /// sorgularda tam olarak bu oluyor.
    /// </summary>
    public int RerankCandidates { get; set; } = 10;

    private readonly string _connectionString;
    private readonly InferenceSession _embedder;
    private readonly Tokenizer _embedTokenizer;
    private readonly InferenceSession? _reranker;
    private readonly Tokenizer? _rerankTokenizer;
    private readonly RerankerStyle _rerankStyle;

    private List<ArchiveRow> _archive = [];
    private KeywordScorer _keywords = new();

    public RetrievalEvaluator(
        string connectionString, string embeddingDir,
        string? rerankerDir = null, RerankerStyle rerankStyle = RerankerStyle.XlmRoberta)
    {
        _rerankStyle = rerankStyle;
        _connectionString = connectionString;
        _embedTokenizer = new Tokenizer(vocabPath: Path.Combine(embeddingDir, "tokenizer.json"));
        _embedder = new InferenceSession(Path.Combine(embeddingDir, "model.onnx"));

        if (!string.IsNullOrWhiteSpace(rerankerDir) && Directory.Exists(rerankerDir))
        {
            _rerankTokenizer = new Tokenizer(vocabPath: Path.Combine(rerankerDir, "tokenizer.json"));
            _reranker = new InferenceSession(Path.Combine(rerankerDir, "model.onnx"));
        }
    }

    public async Task LoadArchiveAsync()
    {
        _archive = [];

        await using var db = new SqlConnection(_connectionString);
        await db.OpenAsync();

        await using var cmd = new SqlCommand(
            "SELECT Source, SourceId, Title, ISNULL(SummaryText, '') , Weight, VectorJson " +
            "FROM ai.SemanticVectors WHERE VectorJson IS NOT NULL", db);
        await using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var vector = JsonSerializer.Deserialize<float[]>(reader.GetString(5));
            if (vector is not { Length: > 0 })
            {
                continue;
            }

            _archive.Add(new ArchiveRow(
                reader.GetString(0), reader.GetInt64(1), reader.GetString(2),
                reader.GetString(3), reader.GetDouble(4), vector));
        }

        _keywords = new KeywordScorer();
        _keywords.Build(_archive.Select(a => $"{a.Title} {a.Summary}").ToList());
    }

    /// <summary>
    /// Sorgulari yukler. origin verilirse yalniz o kaynaktan (MANUEL / LLM).
    /// Iki seti ayri olcmek, sorgu yazarinin yanliligini gorunur kilar.
    /// </summary>
    public async Task<List<EvalQuery>> LoadQueriesAsync(string? origin = null)
    {
        var queries = new List<EvalQuery>();

        await using var db = new SqlConnection(_connectionString);
        await db.OpenAsync();

        await using var cmd = new SqlCommand(
            "SELECT QueryText, ExpectSource, ExpectId FROM ai.RetrievalEvalSet " +
            "WHERE IsActive = 1 AND (@Origin IS NULL OR Origin = @Origin) ORDER BY EvalId", db);
        cmd.Parameters.AddWithValue("@Origin", (object?)origin ?? DBNull.Value);
        await using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            queries.Add(new EvalQuery(reader.GetString(0), reader.GetString(1), reader.GetInt64(2)));
        }

        return queries;
    }

    public EvalResult Evaluate(IReadOnlyList<EvalQuery> queries, RetrievalMode mode, int rrfK = 15)
    {
        int hit1 = 0, hit3 = 0, hit5 = 0, recall10 = 0;
        double mrrSum = 0;
        long totalMs = 0;

        foreach (var query in queries)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var ranked = Retrieve(query.Text, mode, rrfK);
            sw.Stop();
            totalMs += sw.ElapsedMilliseconds;

            // Ayni kontrol maddesi farkli denetimlerde tekrar ediyor; bu yuzden
            // dogruluk BASLIK esitligiyle olculur. Yoksa ayni metni tasiyan
            // dogru bir kayit yalnizca farkli Id tasidigi icin yanlis sayilirdi.
            var expectedTitle = _archive
                .FirstOrDefault(a => a.Source == query.ExpectSource && a.SourceId == query.ExpectId)?.Title;

            if (expectedTitle is null)
            {
                continue;
            }

            var rank = 0;
            for (var i = 0; i < ranked.Count && i < 10; i++)
            {
                if (!string.Equals(_archive[ranked[i]].Title, expectedTitle, StringComparison.Ordinal))
                {
                    continue;
                }

                rank = i + 1;
                break;
            }

            if (rank == 0)
            {
                continue;
            }

            recall10++;
            mrrSum += 1.0 / rank;
            if (rank <= 5) hit5++;
            if (rank <= 3) hit3++;
            if (rank == 1) hit1++;
        }

        var n = queries.Count;
        return new EvalResult(
            n,
            (decimal)hit1 / n, (decimal)hit3 / n, (decimal)hit5 / n,
            (decimal)(mrrSum / n), (decimal)recall10 / n,
            (int)(totalMs / n));
    }

    private List<int> Retrieve(string query, RetrievalMode mode, int rrfK)
    {
        var semantic = new Dictionary<int, int>();
        var keyword = new Dictionary<int, int>();

        if (mode is RetrievalMode.Vector or RetrievalMode.Hybrid or RetrievalMode.HybridRerank)
        {
            var qv = Embed(query, isQuery: true);
            var ordered = _archive
                .Select((a, i) => (i, s: Cosine(qv, a.Vector)))
                .OrderByDescending(x => x.s)
                .ToArray();

            for (var r = 0; r < ordered.Length; r++)
            {
                semantic[ordered[r].i] = r + 1;
            }
        }

        if (mode is RetrievalMode.Bm25 or RetrievalMode.Hybrid or RetrievalMode.HybridRerank)
        {
            var ordered = _keywords.Score(query).OrderByDescending(kv => kv.Value).ToArray();
            for (var r = 0; r < ordered.Length; r++)
            {
                keyword[ordered[r].Key] = r + 1;
            }
        }

        // Tek yontemliyse dogrudan siralama, degilse RRF
        if (mode == RetrievalMode.Vector)
        {
            return semantic.OrderBy(kv => kv.Value).Select(kv => kv.Key).ToList();
        }

        if (mode == RetrievalMode.Bm25)
        {
            return keyword.OrderBy(kv => kv.Value).Select(kv => kv.Key).ToList();
        }

        var fused = new Dictionary<int, double>();
        foreach (var (i, r) in semantic) fused[i] = fused.GetValueOrDefault(i) + 1.0 / (rrfK + r);
        foreach (var (i, r) in keyword) fused[i] = fused.GetValueOrDefault(i) + 1.0 / (rrfK + r);

        var hybrid = fused.OrderByDescending(kv => kv.Value).Select(kv => kv.Key).ToList();

        if (mode != RetrievalMode.HybridRerank || _reranker is null)
        {
            return hybrid;
        }

        // Reranker yalniz ilk N adayi yeniden sirala; gerisi sirasini korur
        var candidates = hybrid.Take(RerankCandidates).ToList();
        var rescored = candidates
            .Select(i => (i, s: Rerank(query, $"{_archive[i].Title} {_archive[i].Summary}")))
            .OrderByDescending(x => x.s)
            .Select(x => x.i)
            .ToList();

        rescored.AddRange(hybrid.Skip(RerankCandidates));
        return rescored;
    }

    private float[] Embed(string text, bool isQuery)
    {
        var ids = _embedTokenizer.Encode((isQuery ? "query: " : "passage: ") + text)
            .Select(i => (long)i).ToArray();

        if (ids.Length > 512) ids = ids.Take(512).ToArray();
        var n = ids.Length;

        using var result = _embedder.Run(
        [
            NamedOnnxValue.CreateFromTensor("input_ids", new DenseTensor<long>(ids, [1, n])),
            NamedOnnxValue.CreateFromTensor("attention_mask",
                new DenseTensor<long>(Enumerable.Repeat(1L, n).ToArray(), [1, n]))
        ]);

        var last = result.First().AsTensor<float>();
        var hidden = last.Dimensions[2];
        var vector = new float[hidden];

        for (var t = 0; t < n; t++)
            for (var h = 0; h < hidden; h++) vector[h] += last[0, t, h];

        var norm = 0f;
        for (var h = 0; h < hidden; h++) { vector[h] /= n; norm += vector[h] * vector[h]; }
        norm = MathF.Sqrt(norm);
        for (var h = 0; h < hidden; h++) vector[h] /= norm;

        return vector;
    }

    private float Rerank(string query, string document)
    {
        // Cross-encoder sorgu ve belgeyi BIRLIKTE gorur. Ozel token'lar model
        // ailesine gore degisir; yanlis sozlesme sessizce bozuk skor uretir.
        var q = _rerankTokenizer!.Encode(query).Select(i => (long)i).ToList();
        var d = _rerankTokenizer.Encode(document).Select(i => (long)i).ToList();

        List<long> ids;
        int maxLen;

        if (_rerankStyle == RerankerStyle.XlmRoberta)
        {
            // <s> sorgu </s> belge </s>   (<s>=0, </s>=2)
            if (q.Count > 0 && q[^1] == 2) q.RemoveAt(q.Count - 1);
            if (d.Count > 0 && d[0] == 0) d.RemoveAt(0);
            ids = q.Concat([2L]).Concat(d).ToList();
            maxLen = 512;
        }
        else
        {
            // [CLS] sorgu [SEP] belge [SEP]   ([CLS]=2, [SEP]=3)
            if (q.Count > 0 && q[^1] == 3) q.RemoveAt(q.Count - 1);
            if (d.Count > 0 && d[0] == 2) d.RemoveAt(0);
            if (d.Count > 0 && d[^1] == 3) d.RemoveAt(d.Count - 1);
            ids = q.Concat(d).Append(3L).ToList();
            maxLen = 8192;
        }

        if (ids.Count > maxLen) ids = ids.Take(maxLen).ToList();

        var n = ids.Count;
        using var result = _reranker!.Run(
        [
            NamedOnnxValue.CreateFromTensor("input_ids", new DenseTensor<long>(ids.ToArray(), [1, n])),
            NamedOnnxValue.CreateFromTensor("attention_mask",
                new DenseTensor<long>(Enumerable.Repeat(1L, n).ToArray(), [1, n]))
        ]);

        return result.First().AsTensor<float>()[0, 0];
    }

    private static float Cosine(float[] a, float[] b)
    {
        var s = 0f;
        for (var i = 0; i < a.Length; i++) s += a[i] * b[i];
        return s;
    }

    public void Dispose()
    {
        _embedder.Dispose();
        _reranker?.Dispose();
    }

    public sealed record ArchiveRow(string Source, long SourceId, string Title, string Summary, double Weight, float[] Vector);
    public sealed record EvalQuery(string Text, string ExpectSource, long ExpectId);
    public sealed record EvalResult(
        int QueryCount, decimal HitRate1, decimal HitRate3, decimal HitRate5,
        decimal Mrr10, decimal Recall10, int AvgLatencyMs);

    /// <summary>Uretim kodundaki KeywordIndex ile ayni BM25 mantigi.</summary>
    private sealed class KeywordScorer
    {
        private static readonly HashSet<string> Stop = new(StringComparer.Ordinal)
        {
            "ve","ile","icin","bir","bu","mi","mu","da","de","var","yok","olan",
            "ediliyor","dikkat","gore","olarak","kadar","daha","cok","her"
        };

        private readonly Dictionary<string, Dictionary<int, int>> _postings = new(StringComparer.Ordinal);
        private int[] _lengths = [];
        private double _avgLength;
        private int _count;

        public void Build(IReadOnlyList<string> documents)
        {
            _count = documents.Count;
            _lengths = new int[_count];

            for (var i = 0; i < _count; i++)
            {
                var terms = Tokenize(documents[i]);
                _lengths[i] = terms.Count;

                foreach (var term in terms)
                {
                    if (!_postings.TryGetValue(term, out var posting))
                    {
                        _postings[term] = posting = new Dictionary<int, int>();
                    }

                    posting[i] = posting.GetValueOrDefault(i) + 1;
                }
            }

            _avgLength = _count == 0 ? 0 : _lengths.Average();
        }

        public Dictionary<int, double> Score(string query)
        {
            var scores = new Dictionary<int, double>();

            foreach (var term in Tokenize(query).Distinct(StringComparer.Ordinal))
            {
                if (!_postings.TryGetValue(term, out var posting)) continue;

                var idf = Math.Log(1 + (_count - posting.Count + 0.5) / (posting.Count + 0.5));

                foreach (var (doc, tf) in posting)
                {
                    var norm = 1 - 0.75 + 0.75 * (_lengths[doc] / Math.Max(1e-9, _avgLength));
                    scores[doc] = scores.GetValueOrDefault(doc) + idf * (tf * 2.2) / (tf + 1.2 * norm);
                }
            }

            return scores;
        }

        private static List<string> Tokenize(string text)
        {
            var result = new List<string>();
            var buffer = new StringBuilder();

            foreach (var ch in text.ToLower(CultureInfo.GetCultureInfo("tr-TR")))
            {
                if (char.IsLetterOrDigit(ch))
                {
                    buffer.Append(ch switch
                    {
                        'ç' => 'c', 'ğ' => 'g', 'ı' => 'i', 'ö' => 'o', 'ş' => 's', 'ü' => 'u',
                        _ => ch
                    });
                }
                else if (buffer.Length > 0)
                {
                    Emit(buffer.ToString(), result);
                    buffer.Clear();
                }
            }

            if (buffer.Length > 0) Emit(buffer.ToString(), result);
            return result;
        }

        private static void Emit(string token, List<string> result)
        {
            if (token.Length < 2 || Stop.Contains(token)) return;

            result.Add(token);
            if (token.Length > 5) result.Add(token[..5] + "#");
        }
    }
}

/// <summary>
/// Cross-encoder'in ozel token sozlesmesi. XLM-R tabanli modeller (mmarco,
/// bge-m3) ile BERT tabanlilar (ModernBERT-tr) farkli ayirici kullanir.
/// </summary>
public enum RerankerStyle
{
    XlmRoberta,
    Bert
}

public enum RetrievalMode
{
    Vector,
    Bm25,
    Hybrid,
    HybridRerank
}
