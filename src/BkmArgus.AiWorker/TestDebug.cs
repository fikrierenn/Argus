using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BkmArgus.AiWorker;

public class TestDebug
{
    public static async Task Main(string[] args)
    {
        var host = Host.CreateDefaultBuilder(args)
            .ConfigureServices((context, services) =>
            {
                services.Configure<AiWorkerOptions>(context.Configuration.GetSection("AiWorker"));
                services.AddSingleton<Db>();
                services.AddLogging(builder => builder.AddConsole());
            })
            .Build();

        var db = host.Services.GetRequiredService<Db>();
        var logger = host.Services.GetRequiredService<ILogger<TestDebug>>();

        try
        {
            logger.LogInformation("Starting debug test...");
            await DebugTest.TestRiskOzetGetir(db);
            logger.LogInformation("Debug test completed.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Debug test failed.");
        }
    }
}
