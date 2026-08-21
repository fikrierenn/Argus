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
    private async Task<List<ScoredMatch>> ScoreAllAsync(string text, CancellationToken token)
    {
        if (!_options.SemanticMemoryEnabled)
        {
            return [];
        }

        var vector = await embedding.TryEmbedQueryAsync(text, token);
        if (vector is null || vector.Length == 0)
        {
            return [];
        }

        await using var connection = db.CreateConnection();
        var rows = await connection.QueryAsync<SemanticVectorRow>(
            new CommandDefinition(
                "ai.sp_SemanticVector_ListWeighted",
                new { ModelAdi = embedding.ModelName, Top = _options.SemanticTop },
                commandType: CommandType.StoredProcedure,
                cancellationToken: token));

        var scored = new List<ScoredMatch>();

        foreach (var row in rows)
        {
            var other = TryParseVector(row);
            if (other is null)
            {
                continue;
            }

            // Boyut uyusmazligi = farkli model. Sessizce yanlis skor uretmektense atla.
            if (other.Length != vector.Length)
            {
                logger.LogWarning(
                    "Vektor boyutu uyusmuyor (kayit {Boyut}, sorgu {Beklenen}). SourceId={SourceId} atlandi.",
                    other.Length, vector.Length, row.SourceId);
                continue;
            }

            var raw = CosineSimilarity(vector, other);

            scored.Add(new ScoredMatch(
                RawSimilarity: raw,
                WeightedScore: raw * row.Weight,
                Match: new SemanticMatch
                {
                    SourceId = row.SourceId,
                    DofId = row.DofId,
                    Title = string.IsNullOrWhiteSpace(row.Title) ? "Gecmis kayit" : row.Title,
                    Similarity = raw,
                    IsCritical = row.IsCritical
                }));
        }

        // Siralama agirlikli skora gore: dogrulanmis vaka one cikar.
        // Kabul karari ise ham benzerlige bakar (yukaridaki iki kapi).
        scored.Sort((a, b) => b.WeightedScore.CompareTo(a.WeightedScore));
        return scored;
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

    private readonly record struct ScoredMatch(double RawSimilarity, double WeightedScore, SemanticMatch Match);
}
