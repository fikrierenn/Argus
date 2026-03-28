using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.FileProviders;
using Spectre.Console;
using System.Text.Json;

namespace BkmArgus.Installer.Services;

public class WebInstaller
{
    private readonly InstallationService _installationService;
    private readonly DatabaseService _databaseService;
    private readonly ILogger<WebInstaller> _logger;

    public WebInstaller(
        InstallationService installationService,
        DatabaseService databaseService,
        ILogger<WebInstaller> logger)
    {
        _installationService = installationService;
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task RunAsync()
    {
        AnsiConsole.MarkupLine("[bold blue]🌐 Web Interface Installer[/]");
        AnsiConsole.WriteLine();

        var builder = WebApplication.CreateBuilder();
        
        // Console loglama ekle
        builder.Logging.ClearProviders();
        builder.Logging.AddConsole();
        builder.Logging.SetMinimumLevel(LogLevel.Information);
        
        builder.Services.AddSingleton(_installationService);
        builder.Services.AddSingleton(_databaseService);
        
        var app = builder.Build();
        
        // Static files - wwwroot klasörünü doğru şekilde ayarla
        var wwwrootPath = Path.Combine(AppContext.BaseDirectory, "wwwroot");
        if (Directory.Exists(wwwrootPath))
        {
            app.UseStaticFiles(new StaticFileOptions
            {
                FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(wwwrootPath),
                RequestPath = ""
            });
        }
        
        // API endpoints
        app.MapGet("/", async context =>
        {
            var htmlPath = Path.Combine(AppContext.BaseDirectory, "wwwroot", "index.html");
            if (File.Exists(htmlPath))
            {
                var html = await File.ReadAllTextAsync(htmlPath);
                context.Response.ContentType = "text/html";
                await context.Response.WriteAsync(html);
            }
            else
            {
                context.Response.StatusCode = 404;
                await context.Response.WriteAsync("index.html not found");
            }
        });

        app.MapGet("/api/status", async (HttpContext context) =>
        {
            var dbService = context.RequestServices.GetRequiredService<DatabaseService>();
            var logger = context.RequestServices.GetRequiredService<ILogger<WebInstaller>>();
            
            try
            {
                logger.LogInformation("🔍 API /status çağrıldı");
                
                logger.LogInformation("📡 Veritabanı bağlantısı test ediliyor...");
                var connected = await dbService.TestConnectionAsync();
                logger.LogInformation($"📡 Bağlantı durumu: {connected}");
                
                logger.LogInformation("📋 Şemalar kontrol ediliyor...");
                var schemas = await dbService.GetExistingSchemasAsync();
                logger.LogInformation($"📋 Bulunan şemalar: {string.Join(", ", schemas)}");
                
                logger.LogInformation("⚙️ Stored procedure'lar kontrol ediliyor...");
                var procCounts = await dbService.GetStoredProcedureCountsAsync();
                logger.LogInformation($"⚙️ SP sayıları: {string.Join(", ", procCounts.Select(x => $"{x.Key}={x.Value}"))}");
                
                var result = new
                {
                    Connected = connected,
                    Schemas = schemas,
                    StoredProcedureCounts = procCounts,
                    Timestamp = DateTime.Now
                };
                
                logger.LogInformation($"✅ API yanıtı hazırlandı: Connected={connected}, Schemas={schemas.Count}, SP={procCounts.Count}");
                
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsync(System.Text.Json.JsonSerializer.Serialize(result));
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "❌ API /status hatası");
                
                var errorResult = new
                {
                    Connected = false,
                    Schemas = new List<string>(),
                    StoredProcedureCounts = new Dictionary<string, int>(),
                    Timestamp = DateTime.Now,
                    Error = ex.Message
                };
                
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsync(System.Text.Json.JsonSerializer.Serialize(errorResult));
            }
        });

        app.MapPost("/api/install", async (HttpContext context, InstallationService installService) =>
        {
            var body = await context.Request.ReadFromJsonAsync<InstallRequest>();
            
            var progress = new Progress<string>(message =>
            {
                // Bu gerçek uygulamada SignalR ile client'a gönderilir
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {message}");
            });

            bool success;
            if (body?.InstallationType == "full")
            {
                success = await installService.RunFullInstallationAsync(progress);
            }
            else
            {
                success = await installService.RunSelectiveInstallationAsync(body?.Components ?? new List<string>(), progress);
            }

            return new { Success = success, Message = success ? "Kurulum başarılı" : "Kurulum hatası" };
        });

        app.MapPost("/api/verify", async (InstallationService installService) =>
        {
            var progress = new Progress<string>(message =>
            {
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {message}");
            });

            var success = await installService.VerifyInstallationAsync(progress);
            return new { Success = success, Message = success ? "Doğrulama başarılı" : "Doğrulama hatası" };
        });

        // Boş port bul
        var port = FindAvailablePort(5555);
        var url = $"http://localhost:{port}";
        
        AnsiConsole.MarkupLine($"🌐 Web installer başlatılıyor: [link]{url}[/]");
        AnsiConsole.MarkupLine("[dim]Tarayıcınızda otomatik olarak açılacak...[/]");
        
        // Tarayıcıyı aç
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            });
        }
        catch
        {
            AnsiConsole.MarkupLine($"[yellow]Tarayıcı otomatik açılamadı. Manuel olarak şu adresi ziyaret edin: {url}[/]");
        }

        AnsiConsole.MarkupLine("\n[dim]Web installer'ı kapatmak için Ctrl+C tuşlarına basın...[/]");
        
        try
        {
            await app.RunAsync(url);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Web installer başlatma hatası");
            AnsiConsole.MarkupLine($"[red]❌ Web installer başlatılamadı: {ex.Message}[/]");
        }
    }

    private class InstallRequest
    {
        public string InstallationType { get; set; } = "";
        public List<string> Components { get; set; } = new();
    }

    private static int FindAvailablePort(int startPort)
    {
        for (int port = startPort; port < startPort + 100; port++)
        {
            try
            {
                using var listener = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, port);
                listener.Start();
                listener.Stop();
                return port;
            }
            catch
            {
                // Port kullanımda, bir sonrakini dene
            }
        }
        
        // Hiç boş port bulunamadı, varsayılanı döndür
        return startPort;
    }
}