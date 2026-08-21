using BkmArgus.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Xunit;
using Xunit.Abstractions;

namespace BkmArgus.Tests;

/// <summary>
/// Geri getirme yapilandirmalarini ayni sorgu setleriyle karsilastirir ve
/// sonuclari ai.RetrievalEvalRuns'a yazar.
///
/// UC AYRI SET olculur: elle yazilan sorgular, LLM'in yazdiklari, ve ikisi
/// birlikte. Sebep: sorgulari kayitlara bakarak yazan kisi farkinda olmadan
/// eslesecek kelimeler secebilir ve aramayi oldugundan iyi gosterir. Ikinci
/// bir yazar bu yanliligi tasimaz. Iki set AYNI siralamayi veriyorsa karar
/// saglam; ayrisiyorsa hangisinin yaniltigi arastirilmali.
///
/// Bir "gecti/kaldi" testi degil, bir OLCUM kosumu. Tek sert kapi: hibrit
/// arama tek basina vektorden kotu OLMAMALI.
///
/// Veritabani ve yerel modeller gerekir; yoksa test atlanir.
/// </summary>
public sealed class RetrievalEvalTests(ITestOutputHelper output)
{
    private static readonly string ModelRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
        "BkmArgus", "models");

    private static string EmbeddingDir => Path.Combine(ModelRoot, "multilingual-e5-base");
    private static string SeroeRerankerDir => Path.Combine(ModelRoot, "turkish-reranker");
    private static string YtuRerankerDir => Path.Combine(ModelRoot, "ytu-modernbert-tr-reranker");

    private static readonly (string Name, RetrievalMode Mode, int RrfK)[] BaseConfigurations =
    [
        ("vector", RetrievalMode.Vector, 15),
        ("bm25", RetrievalMode.Bm25, 15),
        ("hybrid-rrf15", RetrievalMode.Hybrid, 15),
        ("hybrid-rrf60", RetrievalMode.Hybrid, 60)
    ];

    [Fact]
    public async Task Yapilandirmalari_karsilastir_ve_kaydet()
    {
        var connectionString = ResolveConnectionString();

        if (connectionString is null || !Directory.Exists(EmbeddingDir))
        {
            output.WriteLine("Veritabani veya embedding modeli yok — olcum atlandi.");
            return;
        }

        using var baseline = new RetrievalEvaluator(connectionString, EmbeddingDir);
        await baseline.LoadArchiveAsync();

        var sets = new List<(string Label, List<RetrievalEvaluator.EvalQuery> Queries)>
        {
            ("ELLE", await baseline.LoadQueriesAsync("MANUEL")),
            ("LLM", await baseline.LoadQueriesAsync("LLM")),
            ("TUMU", await baseline.LoadQueriesAsync())
        };

        if (sets[^1].Queries.Count == 0)
        {
            output.WriteLine("Olcum seti bos — sql/64_retrieval_eval_seed.sql uygulanmali.");
            return;
        }

        output.WriteLine($"Setler: ELLE {sets[0].Queries.Count} | LLM {sets[1].Queries.Count} | TUMU {sets[2].Queries.Count}");
        output.WriteLine("");

        RetrievalEvaluator.EvalResult? vectorAll = null;
        RetrievalEvaluator.EvalResult? hybridAll = null;

        var rerankers = new List<(string Label, string Dir, RerankerStyle Style)>
        {
            ("hybrid+seroe-mmarco-tr", SeroeRerankerDir, RerankerStyle.XlmRoberta),
            ("hybrid+ytu-modernbert-tr", YtuRerankerDir, RerankerStyle.Bert)
        };

        foreach (var (setLabel, setQueries) in sets)
        {
            if (setQueries.Count == 0)
            {
                continue;
            }

            output.WriteLine($"--- {setLabel} ({setQueries.Count} sorgu) ---");
            output.WriteLine($"{"Yapilandirma",-26} {"H@1",6} {"H@3",6} {"MRR",6} {"ms",6}");

            foreach (var (name, mode, rrfK) in BaseConfigurations)
            {
                var result = baseline.Evaluate(setQueries, mode, rrfK);

                output.WriteLine(
                    $"{name,-26} {result.HitRate1,6:F3} {result.HitRate3,6:F3} {result.Mrr10,6:F3} {result.AvgLatencyMs,6}");

                await SaveRunAsync(connectionString, $"{name} [{setLabel}]", null, rrfK, result);

                if (setLabel != "TUMU")
                {
                    continue;
                }

                if (mode == RetrievalMode.Vector)
                {
                    vectorAll = result;
                }
                else if (mode == RetrievalMode.Hybrid && (hybridAll is null || result.HitRate1 > hybridAll.HitRate1))
                {
                    hybridAll = result;
                }
            }

            foreach (var (label, dir, style) in rerankers)
            {
                if (!Directory.Exists(dir))
                {
                    continue;
                }

                using var withReranker = new RetrievalEvaluator(connectionString, EmbeddingDir, dir, style);
                await withReranker.LoadArchiveAsync();

                // Aday penceresi taranir: dogru cevap hibritin ilk N'ine
                // girmiyorsa reranker onu kurtaramaz. Parafraz sorgularda
                // pencerenin dar olmasi supheli — olcerek bakiyoruz.
                foreach (var window in new[] { 10, 25 })
                {
                    withReranker.RerankCandidates = window;
                    var result = withReranker.Evaluate(setQueries, RetrievalMode.HybridRerank, 60);
                    var name = $"{label}@{window}";

                    output.WriteLine(
                        $"{name,-26} {result.HitRate1,6:F3} {result.HitRate3,6:F3} {result.Mrr10,6:F3} {result.AvgLatencyMs,6}");

                    await SaveRunAsync(connectionString, $"{name} [{setLabel}]", label, 60, result);
                }
            }

            output.WriteLine("");
        }

        output.WriteLine("Not: setler kucuk. Birkac puanlik fark gurultu olabilir;");
        output.WriteLine("iki setin AYNI siralamayi vermesi tek basina yuksek skordan degerlidir.");

        // Tek sert kapi: hibrit, tek basina vektorden kotu olmamali.
        if (vectorAll is not null && hybridAll is not null)
        {
            Assert.True(
                hybridAll.HitRate1 >= vectorAll.HitRate1,
                $"Hibrit ({hybridAll.HitRate1:F3}) tek basina vektorden ({vectorAll.HitRate1:F3}) kotu.");
        }
    }

    private static async Task SaveRunAsync(
        string connectionString, string name, string? rerankerModel, int rrfK,
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
        cmd.Parameters.AddWithValue("@RerankModeli", (object?)rerankerModel ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RrfK", rrfK);
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
    /// Baglanti dizesi: ortam degiskeni, sonra Local.json. Test sabit sir tasimaz.
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
