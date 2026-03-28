using BkmArgus.AiWorker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;

if (args.Length > 0)
{
    if (args[0] == "test-embedding")
    {
        await TestEmbedding.RunTest();
        return;
    }
    if (args[0] == "test-db")
    {
        await DbTest.RunTest();
        return;
    }
}

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.AddSingleton<Db>();
        services.AddSingleton<EmbeddingService>();
        services.AddSingleton<SemanticMemoryService>();
        services.AddSingleton<LlmService>();
        services.AddSingleton<LmRules>();
        services.AddOptions<AiWorkerOptions>()
            .BindConfiguration("AiWorker")
            .Configure<IConfiguration>((options, config) =>
            {
                var envConn = config["BKM_DENETIM_CONN"];
                var appConn = config.GetConnectionString("BkmDenetim");
                
                if (!string.IsNullOrWhiteSpace(envConn))
                {
                    options.ConnectionString = envConn;
                }
                else if (!string.IsNullOrWhiteSpace(appConn))
                {
                    options.ConnectionString = appConn;
                }
                else
                {
                    throw new InvalidOperationException("BKM_DENETIM_CONN veya ConnectionStrings:BkmDenetim tanımlı değil.");
                }
            });
        services.AddHttpClient("ollama", client =>
        {
            var baseUrl = Environment.GetEnvironmentVariable("OLLAMA_BASE_URL");
            client.BaseAddress = new Uri(!string.IsNullOrWhiteSpace(baseUrl) ? baseUrl : "http://localhost:11434");
        });
        services.AddHttpClient("gemini");
        services.AddHostedService<AiWorkerService>();
    })
    .Build();

await host.RunAsync();
