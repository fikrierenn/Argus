using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BkmArgus.AiWorker;

public static class TestEmbedding
{
    public static async Task RunTest()
    {
        var services = new ServiceCollection();
        
        // Configuration
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build();
        
        services.AddSingleton<IConfiguration>(configuration);
        services.Configure<AiWorkerOptions>(configuration.GetSection("AiWorker"));
        services.AddHttpClient("ollama", client =>
        {
            client.BaseAddress = new Uri(configuration["AiWorker:OllamaBaseUrl"] ?? "http://localhost:11434");
        });
        services.AddLogging(builder => builder.AddConsole());
        
        // Services
        services.AddSingleton<EmbeddingService>();
        services.AddSingleton<LlmService>();
        
        var serviceProvider = services.BuildServiceProvider();
        var embedding = serviceProvider.GetRequiredService<EmbeddingService>();
        var logger = serviceProvider.GetRequiredService<ILogger<Program>>();
        
        Console.WriteLine("Embedding test başlatılıyor...");
        
        var testText = "Bu bir test metnidir.";
        var vector = await embedding.TryEmbedAsync(testText, CancellationToken.None);
        
        if (vector != null && vector.Length > 0)
        {
            Console.WriteLine($"✅ Embedding başarılı! Boyut: {vector.Length}");
            Console.WriteLine($"İlk 5 değer: {string.Join(", ", vector.Take(5))}");
        }
        else
        {
            Console.WriteLine("❌ Embedding başarısız!");
        }
    }
}
