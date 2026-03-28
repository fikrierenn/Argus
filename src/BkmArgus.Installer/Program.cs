using BkmArgus.Installer.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Spectre.Console;

namespace BkmArgus.Installer;

class Program
{
    static async Task Main(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);
        
        // Services
        builder.Services.AddScoped<DatabaseService>();
        builder.Services.AddScoped<InstallationService>();
        builder.Services.AddScoped<ConsoleInstaller>();
        builder.Services.AddScoped<WebInstaller>();
        
        var host = builder.Build();
        
        // Logo ve başlık
        AnsiConsole.Write(
            new FigletText("BKM Denetim")
                .LeftJustified()
                .Color(Color.Blue));
        
        AnsiConsole.MarkupLine("[bold yellow]AI V2 Enhancement System Installer[/]");
        AnsiConsole.MarkupLine("[dim]Version 2.0 - 2025[/]");
        AnsiConsole.WriteLine();
        
        // Kurulum modu seçimi
        var mode = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("[green]Kurulum modunu seçin:[/]")
                .AddChoices(new[] {
                    "Console (Hızlı Kurulum)",
                    "Web Interface (Detaylı Kurulum)",
                    "Sistem Durumu Kontrolü",
                    "Çıkış"
                }));
        
        try
        {
            switch (mode)
            {
                case "Console (Hızlı Kurulum)":
                    var consoleInstaller = host.Services.GetRequiredService<ConsoleInstaller>();
                    await consoleInstaller.RunAsync();
                    break;
                    
                case "Web Interface (Detaylı Kurulum)":
                    var webInstaller = host.Services.GetRequiredService<WebInstaller>();
                    await webInstaller.RunAsync();
                    break;
                    
                case "Sistem Durumu Kontrolü":
                    var dbService = host.Services.GetRequiredService<DatabaseService>();
                    await dbService.CheckSystemStatusAsync();
                    break;
                    
                case "Çıkış":
                    AnsiConsole.MarkupLine("[yellow]Kurulum iptal edildi.[/]");
                    return;
            }
        }
        catch (Exception ex)
        {
            AnsiConsole.WriteException(ex);
            AnsiConsole.MarkupLine("[red]Kurulum sırasında hata oluştu![/]");
        }
        
        AnsiConsole.MarkupLine("\n[green]Devam etmek için bir tuşa basın...[/]");
        Console.ReadKey();
    }
}