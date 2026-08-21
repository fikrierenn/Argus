using BkmArgus.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Xunit;
using Xunit.Abstractions;

namespace BkmArgus.Tests;

/// <summary>
/// Geri getirme yapilandirmalarini ayni sorgu setiyle karsilastirir ve
/// sonuclari ai.RetrievalEvalRuns'a yazar.
///
/// Bir "gecti/kaldi" testi degil, bir OLCUM kosumu. Tek sert kapi var:
/// hibrit arama, tek basina vektorden kotu OLMAMALI. Gerisi rapordur —
/// 30 sorgu ince farklari savunacak guce sahip degil.
///
/// Veritabani ve yerel modeller gerekir; ikisi de yoksa test atlanir.
/// </summary>
public sealed class RetrievalEvalTests(ITestOutputHelper output)
{
    private static readonly string ModelRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
        "BkmArgus", "models");

    private static string EmbeddingDir => Path.Combine(ModelRoot, "multilingual-e5-base");
    private static string RerankerDir => Path.Combine(ModelRoot, "turkish-reranker");

    [Fact]
    public async Task Yapilandirmalari_karsilastir_ve_kaydet()
    {
        var connectionString = ResolveConnectionString();

        if (connectionString is null || !Directory.Exists(EmbeddingDir))
        {
            output.WriteLine("Veritabani veya embedding modeli yok — olcum atlandi.");
            return;
        }

        using var evaluator = new RetrievalEvaluator(
            connectionString,
            EmbeddingDir,
            Directory.Exists(RerankerDir) ? RerankerDir : null);

        await evaluator.LoadArchiveAsync();
        var queries = await evaluator.LoadQueriesAsync();

        if (queries.Count == 0)
        {
            output.WriteLine("Olcum seti bos — sql/64_retrieval_eval_seed.sql uygulanmali.");
            return;
        }

        output.WriteLine($"{queries.Count} sorgu ile olcum\n");
        output.WriteLine($"{"Yapilandirma",-24} {"H@1",6} {"H@3",6} {"H@5",6} {"MRR",6} {"R@10",6} {"ms",6}");
        output.WriteLine(new string('-', 64));

        var configurations = new List<(string Name, RetrievalMode Mode, int RrfK)>
        {
            ("vector", RetrievalMode.Vector, 0),
            ("bm25", RetrievalMode.Bm25, 0),
            ("hybrid-rrf10", RetrievalMode.Hybrid, 10),
            ("hybrid-rrf15", RetrievalMode.Hybrid, 15),
            ("hybrid-rrf60", RetrievalMode.Hybrid, 60)
        };

        if (Directory.Exists(RerankerDir))
        {
            configurations.Add(("hybrid+rerank-tr", RetrievalMode.HybridRerank, 15));
        }

        RetrievalEvaluator.EvalResult? vectorOnly = null;
        RetrievalEvaluator.EvalResult? bestHybrid = null;

        foreach (var (name, mode, rrfK) in configurations)
        {
            var result = evaluator.Evaluate(queries, mode, rrfK == 0 ? 15 : rrfK);

            output.WriteLine(
                $"{name,-24} {result.HitRate1,6:F3} {result.HitRate3,6:F3} {result.HitRate5,6:F3} " +
                $"{result.Mrr10,6:F3} {result.Recall10,6:F3} {result.AvgLatencyMs,6}");

            await SaveRunAsync(connectionString, name, mode, rrfK, result);

            if (mode == RetrievalMode.Vector) vectorOnly = result;
            if (mode is RetrievalMode.Hybrid && (bestHybrid is null || result.HitRate1 > bestHybrid.HitRate1))
            {
                bestHybrid = result;
            }
        }

        output.WriteLine("");
        output.WriteLine("Not: 30 sorgu bir kapidir, benchmark degil.");
        output.WriteLine("Birkac puanlik fark gurultu olabilir; buyuk farklar yorumlanabilir.");

        // Tek sert kapi: hibrit, tek basina vektorden kotu olmamali.
        // Kotuyse fuzyon parametreleri veya BM25 tokenizasyonu bozulmus demektir.
        if (vectorOnly is not null && bestHybrid is not null)
        {
            Assert.True(
                bestHybrid.HitRate1 >= vectorOnly.HitRate1,
                $"Hibrit ({bestHybrid.HitRate1:F3}) tek basina vektorden ({vectorOnly.HitRate1:F3}) kotu. " +
                "Fuzyon veya BM25 tokenizasyonu bozulmus olabilir.");
        }
    }

    private static async Task SaveRunAsync(
        string connectionString, string name, RetrievalMode mode, int rrfK,
        RetrievalEvaluator.EvalResult result)
    {
        await using var db = new SqlConnection(connectionString);
        await db.OpenAsync();

        await using var cmd = new SqlCommand("ai.sp_RetrievalEval_SaveRun", db)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Yapilandirma", name);
        cmd.Parameters.AddWithValue("@GommeModeli", "multilingual-e5-base");
        cmd.Parameters.AddWithValue("@RerankModeli",
            mode == RetrievalMode.HybridRerank
                ? "seroe/mmarco-mMiniLMv2-L12-turkish"
                : (object)DBNull.Value);
        cmd.Parameters.AddWithValue("@RrfK", rrfK == 0 ? DBNull.Value : rrfK);
        cmd.Parameters.AddWithValue("@SorguSayisi", result.QueryCount);
        cmd.Parameters.AddWithValue("@Isabet1", result.HitRate1);
        cmd.Parameters.AddWithValue("@Isabet3", result.HitRate3);
        cmd.Parameters.AddWithValue("@Isabet5", result.HitRate5);
        cmd.Parameters.AddWithValue("@Mrr10", result.Mrr10);
        cmd.Parameters.AddWithValue("@Recall10", result.Recall10);
        cmd.Parameters.AddWithValue("@OrtGecikmeMs", result.AvgLatencyMs);

        await cmd.ExecuteNonQueryAsync();
    }

    /// <summary>
    /// Baglanti dizesi: ortam degiskeni, sonra AiWorker'in Local.json'i.
    /// Test sabit bir sir tasimaz.
    /// </summary>
    private static string? ResolveConnectionString()
    {
        var fromEnv = Environment.GetEnvironmentVariable("BKM_DENETIM_CONN");
        if (!string.IsNullOrWhiteSpace(fromEnv))
        {
            return fromEnv;
        }

        foreach (var candidate in new[]
                 {
                     @"D:\Dev\BkmArgus\src\BkmArgus.AiWorker\appsettings.Local.json",
                     @"D:\Dev\BkmArgus\src\BkmArgus.Web\appsettings.Local.json"
                 })
        {
            if (!File.Exists(candidate))
            {
                continue;
            }

            var config = new ConfigurationBuilder().AddJsonFile(candidate).Build();
            var value = BkmDenetimConnection.TryResolve(config);
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return null;
    }
}
