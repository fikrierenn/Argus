using Microsoft.Extensions.Logging;
using Spectre.Console;

namespace BkmArgus.Installer.Services;

public class ConsoleInstaller
{
    private readonly InstallationService _installationService;
    private readonly DatabaseService _databaseService;
    private readonly ILogger<ConsoleInstaller> _logger;

    public ConsoleInstaller(
        InstallationService installationService, 
        DatabaseService databaseService,
        ILogger<ConsoleInstaller> logger)
    {
        _installationService = installationService;
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task RunAsync()
    {
        AnsiConsole.MarkupLine("[bold blue]🚀 Console Installer[/]");
        AnsiConsole.WriteLine();

        // Bağlantı testi
        AnsiConsole.Status()
            .Start("Veritabanı bağlantısı test ediliyor...", async ctx =>
            {
                var connected = await _databaseService.TestConnectionAsync();
                if (!connected)
                {
                    AnsiConsole.MarkupLine("❌ [red]Veritabanı bağlantısı başarısız! Lütfen bağlantı ayarlarını kontrol edin.[/]");
                    return;
                }
                AnsiConsole.MarkupLine("✅ [green]Veritabanı bağlantısı başarılı[/]");
            });

        // Kurulum tipi seçimi
        var installationType = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("[green]Kurulum tipini seçin:[/]")
                .AddChoices(new[] {
                    "Tam Kurulum (Önerilen)",
                    "Seçmeli Kurulum",
                    "Sadece Durum Kontrolü"
                }));

        switch (installationType)
        {
            case "Tam Kurulum (Önerilen)":
                await RunFullInstallation();
                break;
                
            case "Seçmeli Kurulum":
                await RunSelectiveInstallation();
                break;
                
            case "Sadece Durum Kontrolü":
                await _databaseService.CheckSystemStatusAsync();
                break;
        }
    }

    private async Task RunFullInstallation()
    {
        AnsiConsole.MarkupLine("[bold yellow]⚡ Tam Kurulum Başlatılıyor[/]");
        AnsiConsole.WriteLine();

        var confirm = AnsiConsole.Confirm("Tam kurulum yapılsın mı? Bu işlem mevcut verileri etkileyebilir.");
        if (!confirm)
        {
            AnsiConsole.MarkupLine("[yellow]Kurulum iptal edildi.[/]");
            return;
        }

        var progress = new Progress<string>(message =>
        {
            AnsiConsole.MarkupLine($"[dim]{DateTime.Now:HH:mm:ss}[/] {message}");
        });

        await AnsiConsole.Progress()
            .StartAsync(async ctx =>
            {
                var task = ctx.AddTask("[green]Kurulum İlerliyor...[/]");
                task.MaxValue = 100;

                var success = await _installationService.RunFullInstallationAsync(progress);
                
                task.Value = 100;
                
                if (success)
                {
                    AnsiConsole.MarkupLine("\n[bold green]🎉 Kurulum başarıyla tamamlandı![/]");
                    
                    // Doğrulama
                    AnsiConsole.MarkupLine("\n[bold blue]🔍 Kurulum doğrulanıyor...[/]");
                    await _installationService.VerifyInstallationAsync(progress);
                }
                else
                {
                    AnsiConsole.MarkupLine("\n[bold red]❌ Kurulum sırasında hatalar oluştu![/]");
                }
            });
    }

    private async Task RunSelectiveInstallation()
    {
        AnsiConsole.MarkupLine("[bold yellow]🔧 Seçmeli Kurulum[/]");
        AnsiConsole.WriteLine();

        var components = AnsiConsole.Prompt(
            new MultiSelectionPrompt<string>()
                .Title("[green]Kurulacak bileşenleri seçin:[/]")
                .NotRequired()
                .PageSize(10)
                .MoreChoicesText("[grey](Daha fazla seçenek için yukarı/aşağı ok tuşlarını kullanın)[/]")
                .InstructionsText("[grey](Seçmek için [blue]<space>[/], onaylamak için [green]<enter>[/])[/]")
                .AddChoices(new[] {
                    "Şemalar",
                    "Tablolar", 
                    "ETL System",
                    "AI V2 System"
                }));

        if (!components.Any())
        {
            AnsiConsole.MarkupLine("[yellow]Hiçbir bileşen seçilmedi.[/]");
            return;
        }

        AnsiConsole.MarkupLine($"[bold]Seçilen bileşenler:[/] {string.Join(", ", components)}");
        
        var confirm = AnsiConsole.Confirm("Seçili bileşenler kurulsun mu?");
        if (!confirm)
        {
            AnsiConsole.MarkupLine("[yellow]Kurulum iptal edildi.[/]");
            return;
        }

        var progress = new Progress<string>(message =>
        {
            AnsiConsole.MarkupLine($"[dim]{DateTime.Now:HH:mm:ss}[/] {message}");
        });

        await AnsiConsole.Progress()
            .StartAsync(async ctx =>
            {
                var task = ctx.AddTask("[green]Seçili Bileşenler Kuruluyor...[/]");
                task.MaxValue = components.Count;

                var success = await _installationService.RunSelectiveInstallationAsync(components, progress);
                
                task.Value = components.Count;
                
                if (success)
                {
                    AnsiConsole.MarkupLine("\n[bold green]🎉 Seçili bileşenler başarıyla kuruldu![/]");
                }
                else
                {
                    AnsiConsole.MarkupLine("\n[bold red]❌ Kurulum sırasında hatalar oluştu![/]");
                }
            });
    }
}