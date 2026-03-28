using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Spectre.Console;
using System.Data;

namespace BkmArgus.Installer.Services;

public class DatabaseService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<DatabaseService> _logger;
    private string _connectionString;

    public DatabaseService(IConfiguration configuration, ILogger<DatabaseService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _connectionString = _configuration.GetConnectionString("BkmDenetim") ?? "";
    }

    public async Task<bool> TestConnectionAsync()
    {
        try
        {
            _logger.LogInformation($"🔗 Bağlantı string'i test ediliyor: {_connectionString.Substring(0, Math.Min(50, _connectionString.Length))}...");
            
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            
            _logger.LogInformation("✅ Veritabanı bağlantısı başarılı");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"❌ Veritabanı bağlantı testi başarısız. Connection string: {_connectionString}");
            return false;
        }
    }

    public async Task<List<string>> GetExistingSchemasAsync()
    {
        var schemas = new List<string>();
        try
        {
            _logger.LogInformation("📋 Şema kontrolü başlatılıyor...");
            
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            
            var command = new SqlCommand("SELECT name FROM sys.schemas WHERE name IN ('src','ref','rpt','dof','ai','log','etl')", connection);
            using var reader = await command.ExecuteReaderAsync();
            
            while (await reader.ReadAsync())
            {
                var schemaName = reader.GetString(0);
                schemas.Add(schemaName);
                _logger.LogInformation($"  ✅ Şema bulundu: {schemaName}");
            }
            
            _logger.LogInformation($"📋 Toplam {schemas.Count} şema bulundu");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Şema kontrolü başarısız");
        }
        
        return schemas;
    }

    public async Task<Dictionary<string, int>> GetStoredProcedureCountsAsync()
    {
        var counts = new Dictionary<string, int>();
        try
        {
            _logger.LogInformation("⚙️ Stored procedure sayımı başlatılıyor...");
            
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            
            var query = @"
                SELECT 
                    SCHEMA_NAME(schema_id) as SchemaName,
                    COUNT(*) as ProcCount
                FROM sys.procedures 
                WHERE SCHEMA_NAME(schema_id) IN ('ai', 'etl', 'log', 'rpt')
                GROUP BY SCHEMA_NAME(schema_id)";
            
            var command = new SqlCommand(query, connection);
            using var reader = await command.ExecuteReaderAsync();
            
            while (await reader.ReadAsync())
            {
                var schemaName = reader.GetString(0);
                var procCount = reader.GetInt32(1);
                counts[schemaName] = procCount;
                _logger.LogInformation($"  ⚙️ {schemaName}: {procCount} stored procedure");
            }
            
            _logger.LogInformation($"⚙️ Toplam {counts.Values.Sum()} stored procedure bulundu");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Stored procedure sayımı başarısız");
        }
        
        return counts;
    }

    public async Task<bool> ExecuteSqlFileAsync(string filePath, IProgress<string>? progress = null)
    {
        try
        {
            if (!File.Exists(filePath))
            {
                progress?.Report($"❌ Dosya bulunamadı: {filePath}");
                return false;
            }

            var sql = await File.ReadAllTextAsync(filePath);
            
            // GO statement'larını daha doğru şekilde parse et
            var batches = System.Text.RegularExpressions.Regex.Split(sql, 
                @"^\s*GO\s*$", 
                System.Text.RegularExpressions.RegexOptions.Multiline | System.Text.RegularExpressions.RegexOptions.IgnoreCase)
                .Where(batch => !string.IsNullOrWhiteSpace(batch))
                .ToArray();

            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            progress?.Report($"📁 Çalıştırılıyor: {Path.GetFileName(filePath)}");

            for (int i = 0; i < batches.Length; i++)
            {
                var batch = batches[i].Trim();
                if (string.IsNullOrEmpty(batch)) continue;

                try
                {
                    using var command = new SqlCommand(batch, connection);
                    command.CommandTimeout = 300; // 5 dakika
                    await command.ExecuteNonQueryAsync();
                    
                    progress?.Report($"  ✅ Batch {i + 1}/{batches.Length} tamamlandı");
                }
                catch (Exception ex)
                {
                    progress?.Report($"  ❌ Batch {i + 1} hatası: {ex.Message}");
                    _logger.LogError(ex, "SQL batch execution failed");
                    // Devam et, bazı hatalar normal olabilir (örn: zaten var olan objeler)
                }
            }

            progress?.Report($"✅ {Path.GetFileName(filePath)} tamamlandı");
            return true;
        }
        catch (Exception ex)
        {
            progress?.Report($"❌ Dosya çalıştırma hatası: {ex.Message}");
            _logger.LogError(ex, "SQL file execution failed");
            return false;
        }
    }

    public async Task CheckSystemStatusAsync()
    {
        AnsiConsole.MarkupLine("[bold blue]🔍 Sistem Durumu Kontrolü[/]");
        AnsiConsole.WriteLine();

        // Bağlantı testi
        AnsiConsole.Status()
            .Start("Veritabanı bağlantısı test ediliyor...", async ctx =>
            {
                var connected = await TestConnectionAsync();
                if (connected)
                {
                    AnsiConsole.MarkupLine("✅ [green]Veritabanı bağlantısı başarılı[/]");
                }
                else
                {
                    AnsiConsole.MarkupLine("❌ [red]Veritabanı bağlantısı başarısız[/]");
                    return;
                }

                // Şema kontrolü
                ctx.Status("Şemalar kontrol ediliyor...");
                var schemas = await GetExistingSchemasAsync();
                var requiredSchemas = new[] { "src", "ref", "rpt", "dof", "ai", "log", "etl" };
                
                AnsiConsole.MarkupLine("\n[bold]📋 Şema Durumu:[/]");
                foreach (var schema in requiredSchemas)
                {
                    if (schemas.Contains(schema))
                    {
                        AnsiConsole.MarkupLine($"  ✅ [green]{schema}[/]");
                    }
                    else
                    {
                        AnsiConsole.MarkupLine($"  ❌ [red]{schema}[/]");
                    }
                }

                // Stored procedure kontrolü
                ctx.Status("Stored procedure'lar kontrol ediliyor...");
                var procCounts = await GetStoredProcedureCountsAsync();
                
                AnsiConsole.MarkupLine("\n[bold]⚙️ Stored Procedure Durumu:[/]");
                AnsiConsole.MarkupLine($"  🤖 AI Procedures: [yellow]{procCounts.GetValueOrDefault("ai", 0)}[/]");
                AnsiConsole.MarkupLine($"  📊 ETL Procedures: [yellow]{procCounts.GetValueOrDefault("etl", 0)}[/]");
                AnsiConsole.MarkupLine($"  📝 Log Procedures: [yellow]{procCounts.GetValueOrDefault("log", 0)}[/]");
                AnsiConsole.MarkupLine($"  📈 Report Procedures: [yellow]{procCounts.GetValueOrDefault("rpt", 0)}[/]");
            });
    }
}