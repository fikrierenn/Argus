using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

/// <summary>
/// Semantik hafiza — gecmis DOF, denetim bulgusu ve AI analizleri arasinda
/// anlamca benzer kayitlari bulur.
///
/// Kabul karari MUTLAK ESIKLE verilmez. Onceki surum `hamBenzerlik * Agirlik`
/// carpimini 0.85 ile kiyasliyordu; e5 gibi sikisik araliktaki modellerde ham
/// benzerlik 0.80 civarinda kalir, 0.85 agirlikla carpilinca 0.68 eder ve esik
/// HICBIR ZAMAN gecilmez. Hafiza sessizce hep bos doner.
///
/// Yerine iki kapili bir kural: en iyi eslesme (a) bir tabani gecmeli ve
/// (b) ikinciyi belirgin bir marjla gecmeli. Ikinci kosul kritik — olcumde
/// yanlis sonuc getirdigimiz tek vakada aradaki fark 0.0003'tu; marj kurali
/// orada "emin degilim" diyerek dogru davranirdi.
///
/// Agirlik (Weight) yalniz SIRALAMADA kullanilir: kapanmis ve etkinligi
/// dogrulanmis bir DOF, acik bir bulgudan onceliklidir. Kabul esigini
/// bulandirmamasi icin karsilastirmaya girmez.
/// </summary>
public sealed class SemanticMemoryService(
    Db db,
    LocalEmbeddingService embedding,
    IOptions<AiWorkerOptions> options,
    ILogger<SemanticMemoryService> logger)
{
    private readonly AiWorkerOptions _options = options.Value;
    private readonly KeywordIndex _keywords = new();
    private readonly SemaphoreSlim _cacheGate = new(1, 1);

    private List<SemanticVectorRow> _corpus = [];
    private List<float[]> _corpusVectors = [];
    private DateTime _corpusLoadedUtc = DateTime.MinValue;

    /// <summary>
    /// En iyi tek eslesme. Emin olunamayan durumda null doner — yanlis eslesme
    /// vermektense eslesme vermemek yeglenir (halusinasyon kapisi).
    /// </summary>
    public async Task<SemanticMatch?> FindBestMatchAsync(string text, CancellationToken token)
    {
        var scored = await ScoreAllAsync(text, token);
        if (scored.Count == 0)
        {
            return null;
        }

        var best = scored[0];

        // Taban kontrolu: hicbir sey yeterince benzemiyorsa eslesme yok
        if (best.RawSimilarity < _options.SimilarityFloor)
        {
            return null;
        }

        // Marj kontrolu: ikinciyle arasi acik degilse karar veremiyoruz demektir
        if (scored.Count > 1)
        {
            var runnerUp = scored[1].RawSimilarity;
            if (best.RawSimilarity - runnerUp < _options.SimilarityMargin)
            {
                logger.LogDebug(
                    "Semantik eslesme belirsiz: en iyi {Ilk:F4}, ikinci {Ikinci:F4}, marj yetersiz.",
                    best.RawSimilarity, runnerUp);
                return null;
            }
        }

        return best.Match;
    }

    /// <summary>
    /// LLM'e kanit olarak verilecek en benzer N kayit. Tekil karar
    /// verilmedigi icin marj kurali uygulanmaz, yalniz taban gecerli.
    /// </summary>
    public async Task<IReadOnlyList<SemanticMatch>> FindTopEvidenceAsync(
        string text, int top, CancellationToken token)
    {
        var scored = await ScoreAllAsync(text, token);

        return scored
            .Where(s => s.RawSimilarity >= _options.SimilarityFloor)
            .Take(top)
            .Select(s => s.Match)
            .ToList();
    }

    /// <summary>
    /// Tum arsivi puanlar ve agirlikli skora gore siralar.
    /// Yalniz AYNI modelle uretilmis vektorler karsilastirilir — farkli
    /// modellerin vektorleri ayni uzayda degildir, karistirmak anlamsiz
    /// benzerlik uretir.
    /// </summary>
    /// <summary>
    /// Hibrit arama: anlamsal (vektor) + anahtar kelime (BM25), RRF ile birlestirilir.
    ///
    /// Neden ikisi birden — 30 sorgulu kendi olcumumuz (ai.RetrievalEvalRuns):
    ///   yalniz vektor 0,533 | yalniz BM25 0,700 | hibrit 0,767 (HitRate@1)
    /// Vektor "sayim farki" ile "stok tutarsizligi"ni eslestirir ama tanimlayici
    /// terimleri kacirir; BM25 tam tersi. Ikisinin hatalari ortusmuyor.
    ///
    /// Neden RRF, neden agirlikli toplam degil: iki skor ayni olcekte degil
    /// (kosinus bu korpusta 0,75-0,90 arasinda sikisik — olculdu, ciftler arasi
    /// ortalama 0,8803; BM25 sinirsiz). Normalize etmek korpus degistikce kayar.
    /// RRF yalniz SIRA kullanir, olcek sorunu ortadan kalkar.
    /// </summary>
    private async Task<List<ScoredMatch>> ScoreAllAsync(string text, CancellationToken token)
    {
        if (!_options.SemanticMemoryEnabled)
        {
            return [];
        }

        await EnsureCorpusAsync(token);

        if (_corpus.Count == 0)
        {
            return [];
        }

        var vector = await embedding.TryEmbedQueryAsync(text, token);

        // Anlamsal siralama
        var semanticRank = new Dictionary<int, int>();
        var rawScores = new double[_corpus.Count];

        if (vector is { Length: > 0 })
        {
            var ordered = new List<(int Index, double Score)>(_corpus.Count);

            for (var i = 0; i < _corpus.Count; i++)
            {
                var candidate = _corpusVectors[i];

                // Boyut uyusmazligi = farkli model; sessizce yanlis skor uretme
                if (candidate.Length != vector.Length)
                {
                    continue;
                }

                rawScores[i] = CosineSimilarity(vector, candidate);
                ordered.Add((i, rawScores[i]));
            }

            ordered.Sort((a, b) => b.Score.CompareTo(a.Score));
            for (var r = 0; r < ordered.Count; r++)
            {
                semanticRank[ordered[r].Index] = r + 1;
            }
        }

        // Anahtar kelime siralamasi
        var keywordRank = new Dictionary<int, int>();
        var keywordOrdered = _keywords.Score(text).OrderByDescending(kv => kv.Value).ToArray();

        for (var r = 0; r < keywordOrdered.Length; r++)
        {
            keywordRank[keywordOrdered[r].Key] = r + 1;
        }

        // RRF birlestirme. k varsayilani olcumle secilmeli: bu korpusta
        // k=10 ve k=15 esit (HitRate@1 0,767), k=60 ise biraz daha iyi (0,800).
        // "Kucuk k daha ayristirici" beklentisi burada DOGRULANMADI.
        var k = _options.RrfK;
        var fused = new Dictionary<int, double>();

        foreach (var (index, rank) in semanticRank)
        {
            fused[index] = fused.GetValueOrDefault(index) + 1.0 / (k + rank);
        }

        foreach (var (index, rank) in keywordRank)
        {
            fused[index] = fused.GetValueOrDefault(index) + 1.0 / (k + rank);
        }

        var scored = fused
            .Select(kv =>
            {
                var row = _corpus[kv.Key];
                return new ScoredMatch(
                    RawSimilarity: rawScores[kv.Key],
                    WeightedScore: kv.Value * row.Weight,
                    FusionScore: kv.Value,
                    Match: new SemanticMatch
                    {
                        SourceId = row.SourceId,
                        DofId = row.DofId,
                        Title = string.IsNullOrWhiteSpace(row.Title) ? "Gecmis kayit" : row.Title,
                        Similarity = rawScores[kv.Key],
                        IsCritical = row.IsCritical
                    });
            })
            .ToList();

        // Fuzyon skoruna gore sirala. Agirlik yalnizca birbirine cok yakin
        // adaylar arasinda esitligi bozar; carpan yapilirsa benzerlikten daha
        // belirleyici hale gelir — olculdu, IsSystemic kaydi her sorguda
        // birinci geliyordu.
        scored.Sort((a, b) =>
        {
            var diff = b.FusionScore - a.FusionScore;
            if (Math.Abs(diff) > 1e-9)
            {
                return diff > 0 ? 1 : -1;
            }

            return b.WeightedScore.CompareTo(a.WeightedScore);
        });

        return scored;
    }

    /// <summary>
    /// Arsivi bellege alir ve anahtar kelime indeksini kurar.
    /// 189 kayit x 768 float = 581 KB; ayri bir vektor veritabani gerekmiyor.
    /// Olculen tarama maliyeti: 30 sorguda ortalama 28 ms (vektor tarafi).
    /// </summary>
    private async Task EnsureCorpusAsync(CancellationToken token)
    {
        var ttl = TimeSpan.FromMinutes(_options.CorpusCacheMinutes);

        if (_corpus.Count > 0 && DateTime.UtcNow - _corpusLoadedUtc < ttl)
        {
            return;
        }

        await _cacheGate.WaitAsync(token);
        try
        {
            if (_corpus.Count > 0 && DateTime.UtcNow - _corpusLoadedUtc < ttl)
            {
                return;
            }

            await using var connection = db.CreateConnection();
            var rows = (await connection.QueryAsync<SemanticVectorRow>(
                new CommandDefinition(
                    "ai.sp_SemanticVector_ListWeighted",
                    new { ModelAdi = embedding.ModelName, Top = _options.SemanticTop },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: token))).ToList();

            var corpus = new List<SemanticVectorRow>(rows.Count);
            var vectors = new List<float[]>(rows.Count);

            foreach (var row in rows)
            {
                var parsed = TryParseVector(row);
                if (parsed is null)
                {
                    continue;
                }

                corpus.Add(row);
                vectors.Add(parsed);
            }

            _corpus = corpus;
            _corpusVectors = vectors;
            _keywords.Build(corpus.Select(c => $"{c.Title} {c.SummaryText}").ToList());
            _corpusLoadedUtc = DateTime.UtcNow;

            logger.LogInformation("Semantik arsiv bellege alindi: {Adet} kayit ({Model}).",
                corpus.Count, embedding.ModelName);
        }
        finally
        {
            _cacheGate.Release();
        }
    }

    private float[]? TryParseVector(SemanticVectorRow row)
    {
        if (string.IsNullOrWhiteSpace(row.VectorJson))
        {
            return null;
        }

        try
        {
            var parsed = JsonSerializer.Deserialize<float[]>(row.VectorJson);
            return parsed is { Length: > 0 } ? parsed : null;
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "Vektor json parse edilemedi. SourceId={SourceId}", row.SourceId);
            return null;
        }
    }

    /// <summary>
    /// Kosinus benzerligi. Vektorler L2-normalize uretildigi icin nokta carpimi
    /// yeterli olurdu; yine de normalize edilmemis bir kayit gelirse dogru
    /// calissin diye tam formul kullaniliyor.
    /// </summary>
    private static double CosineSimilarity(float[] a, float[] b)
    {
        double dot = 0, na = 0, nb = 0;

        for (var i = 0; i < a.Length; i++)
        {
            dot += a[i] * b[i];
            na += a[i] * a[i];
            nb += b[i] * b[i];
        }

        if (na <= double.Epsilon || nb <= double.Epsilon)
        {
            return 0;
        }

        return dot / (Math.Sqrt(na) * Math.Sqrt(nb));
    }

    private readonly record struct ScoredMatch(
        double RawSimilarity, double WeightedScore, double FusionScore, SemanticMatch Match);
}
