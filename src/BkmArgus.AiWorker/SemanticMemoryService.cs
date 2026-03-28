using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public sealed class SemanticMemoryService
{
    private readonly Db _db;
    private readonly EmbeddingService _embedding;
    private readonly AiWorkerOptions _options;
    private readonly ILogger<SemanticMemoryService> _logger;

    public SemanticMemoryService(
        Db db,
        EmbeddingService embedding,
        IOptions<AiWorkerOptions> options,
        ILogger<SemanticMemoryService> logger)
    {
        _db = db;
        _embedding = embedding;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<SemanticMatch?> FindBestMatchAsync(string text, CancellationToken token)
    {
        if (!_embedding.IsReady)
        {
            return null;
        }

        var vector = await _embedding.TryEmbedAsync(text, token);
        if (vector is null || vector.Length == 0)
        {
            return null;
        }

        await using var connection = _db.CreateConnection();
        var rows = await connection.QueryAsync<VectorRow>(
            "ai.sp_Ai_GecmisVektor_Liste",
            new { Top = _options.SemanticTop, KritikMi = true },
            commandType: CommandType.StoredProcedure);

        double best = 0;
        VectorRow? bestRow = null;

        foreach (var row in rows)
        {
            if (string.IsNullOrWhiteSpace(row.VektorJson))
            {
                continue;
            }

            float[]? other;
            try
            {
                other = JsonSerializer.Deserialize<float[]>(row.VektorJson);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Vektor json parse edilemedi. RiskId={RiskId}", row.RiskId);
                continue;
            }

            if (other is null || other.Length == 0)
            {
                continue;
            }

            var sim = CosineSimilarity(vector, other);
            if (sim > best)
            {
                best = sim;
                bestRow = row;
            }
        }

        if (bestRow is null || best < _options.SimilarityThreshold)
        {
            return null;
        }

        return new SemanticMatch
        {
            RiskId = bestRow.RiskId,
            DofId = bestRow.DofId,
            Baslik = string.IsNullOrWhiteSpace(bestRow.Baslik) ? "Gecmis kayit" : bestRow.Baslik,
            Similarity = best,
            KritikMi = bestRow.KritikMi
        };
    }

    public async Task<IReadOnlyList<SemanticMatch>> FindTopEvidenceAsync(string text, int top, CancellationToken token)
    {
        if (!_embedding.IsReady)
        {
            return Array.Empty<SemanticMatch>();
        }

        var vector = await _embedding.TryEmbedAsync(text, token);
        if (vector is null || vector.Length == 0)
        {
            return Array.Empty<SemanticMatch>();
        }

        await using var connection = _db.CreateConnection();
        var rows = await connection.QueryAsync<VectorRow>(
            "ai.sp_Ai_GecmisVektor_Liste",
            new { Top = _options.SemanticTop, KritikMi = (bool?)null },
            commandType: CommandType.StoredProcedure);

        var matches = new List<SemanticMatch>();

        foreach (var row in rows)
        {
            if (string.IsNullOrWhiteSpace(row.VektorJson))
            {
                continue;
            }

            float[]? other;
            try
            {
                other = JsonSerializer.Deserialize<float[]>(row.VektorJson);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Vektor json parse edilemedi. RiskId={RiskId}", row.RiskId);
                continue;
            }

            if (other is null || other.Length == 0)
            {
                continue;
            }

            var sim = CosineSimilarity(vector, other);
            if (sim <= 0)
            {
                continue;
            }

            matches.Add(new SemanticMatch
            {
                RiskId = row.RiskId,
                DofId = row.DofId,
                Baslik = string.IsNullOrWhiteSpace(row.Baslik) ? "Gecmis kayit" : row.Baslik,
                Similarity = sim,
                KritikMi = row.KritikMi
            });
        }

        return matches
            .OrderByDescending(x => x.Similarity)
            .Take(top)
            .ToList();
    }

    private static double CosineSimilarity(float[] a, float[] b)
    {
        var len = Math.Min(a.Length, b.Length);
        if (len == 0)
        {
            return 0;
        }

        double dot = 0;
        double normA = 0;
        double normB = 0;

        for (var i = 0; i < len; i++)
        {
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }

        if (normA == 0 || normB == 0)
        {
            return 0;
        }

        return dot / (Math.Sqrt(normA) * Math.Sqrt(normB));
    }
}
