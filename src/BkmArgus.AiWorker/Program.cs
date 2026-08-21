using BkmArgus.AiWorker;
using BkmArgus.AiWorker.Skills;
using BkmArgus.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;

IHost host = Host.CreateDefaultBuilder(args)
    // Sirlar kaynak kodda tutulmaz: appsettings.Local.json (gitignore) veya ortam degiskeni.
    .ConfigureAppConfiguration((context, config) =>
    {
        config.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

        // Web ile ORTAK sir dosyasi — ana sifreleme anahtari buradan gelir.
        // Iki uygulama ayni anahtari gormezse Web sifreler, Worker cozemez.
        config.AddJsonFile(SecretProtector.ResolveSecretsFilePath(), optional: true, reloadOnChange: true);
        config.AddEnvironmentVariables();
    })
    .ConfigureServices(services =>
    {
        services.AddSingleton<Db>();
        services.AddSingleton<LocalEmbeddingService>();
        services.AddSingleton<SemanticMemoryService>();
        services.AddSingleton<LlmService>();
        services.AddSingleton<LmRules>();
        services.AddSingleton<SkillRegistry>();
        services.AddScoped<SkillExecutor>();
        services.AddOptions<AiWorkerOptions>()
            .BindConfiguration("AiWorker")
            .Configure<IConfiguration>((options, config) =>
            {
                options.ConnectionString = BkmDenetimConnection.Resolve(config);
                var claudeKey = config["Claude:ApiKey"];
                if (!string.IsNullOrWhiteSpace(claudeKey))
                {
                    options.ClaudeApiKey = claudeKey;
                }
            });
        services.AddHttpClient("ollama", client =>
        {
            var baseUrl = Environment.GetEnvironmentVariable("OLLAMA_BASE_URL");
            client.BaseAddress = new Uri(!string.IsNullOrWhiteSpace(baseUrl) ? baseUrl : "http://localhost:11434");
            client.Timeout = TimeSpan.FromMinutes(10);
        });
        services.AddHttpClient("gemini", client =>
        {
            client.BaseAddress = new Uri("https://generativelanguage.googleapis.com");
        });
        services.AddHttpClient("claude", client =>
        {
            client.BaseAddress = new Uri("https://api.anthropic.com");
        });
        // OpenAI uyumlu tum saglayicilar tek istemciyi paylasir; adres kayit
        // defterinden gelir, bu yuzden BaseAddress atanmaz.
        services.AddHttpClient("openai-compatible", client =>
        {
            client.Timeout = TimeSpan.FromMinutes(10);
        });
        services.AddSingleton<LlmProviderRegistry>();
        services.AddHostedService<AiWorkerService>();
    })
    .Build();

await host.RunAsync();
