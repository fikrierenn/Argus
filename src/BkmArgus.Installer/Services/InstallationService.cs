using Microsoft.Extensions.Logging;
using Spectre.Console;

namespace BkmArgus.Installer.Services;

public class InstallationService
{
    private readonly DatabaseService _databaseService;
    private readonly ILogger<InstallationService> _logger;

    public InstallationService(DatabaseService databaseService, ILogger<InstallationService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    public async Task<bool> RunFullInstallationAsync(IProgress<string>? progress = null)
    {
        progress?.Report("🚀 BKM Denetim AI V2 kurulumu başlatılıyor...");
        
        var installationSteps = new[]
        {
            new { File = "sql/01_schemas.sql", Name = "Şemalar", Description = "Veritabanı şemalarını oluşturuyor" },
            new { File = "sql/02_tables.sql", Name = "Tablolar", Description = "AI ve ETL tablolarını oluşturuyor" },
            new { File = "sql/04_sps_etl.sql", Name = "ETL Procedures", Description = "ETL stored procedure'larını oluşturuyor" },
            new { File = "sql/15_ai_enhancement_v2.sql", Name = "AI V2 System", Description = "AI V2 sistemini oluşturuyor" }
        };

        var successCount = 0;
        
        foreach (var step in installationSteps)
        {
            progress?.Report($"📦 {step.Name} - {step.Description}");
            
            var success = await _databaseService.ExecuteSqlFileAsync(step.File, progress);
            if (success)
            {
                successCount++;
                progress?.Report($"✅ {step.Name} başarıyla kuruldu");
            }
            else
            {
                progress?.Report($"❌ {step.Name} kurulumunda hata");
            }
            
            // Kısa bekleme
            await Task.Delay(500);
        }

        var isSuccess = successCount == installationSteps.Length;
        
        if (isSuccess)
        {
            progress?.Report("🎉 Kurulum başarıyla tamamlandı!");
            progress?.Report("ℹ️  AI Worker servisini başlatabilirsiniz.");
        }
        else
        {
            progress?.Report($"⚠️  Kurulum kısmen tamamlandı ({successCount}/{installationSteps.Length})");
        }

        return isSuccess;
    }

    public async Task<bool> RunSelectiveInstallationAsync(List<string> selectedComponents, IProgress<string>? progress = null)
    {
        progress?.Report("🔧 Seçili bileşenler kuruluyor...");
        
        var componentMap = new Dictionary<string, string>
        {
            ["Şemalar"] = "sql/01_schemas.sql",
            ["Tablolar"] = "sql/02_tables.sql", 
            ["ETL System"] = "sql/04_sps_etl.sql",
            ["AI V2 System"] = "sql/15_ai_enhancement_v2.sql"
        };

        var successCount = 0;
        
        foreach (var component in selectedComponents)
        {
            if (componentMap.TryGetValue(component, out var filePath))
            {
                progress?.Report($"📦 {component} kuruluyor...");
                
                var success = await _databaseService.ExecuteSqlFileAsync(filePath, progress);
                if (success)
                {
                    successCount++;
                    progress?.Report($"✅ {component} başarıyla kuruldu");
                }
                else
                {
                    progress?.Report($"❌ {component} kurulumunda hata");
                }
            }
            
            await Task.Delay(300);
        }

        var isSuccess = successCount == selectedComponents.Count;
        
        if (isSuccess)
        {
            progress?.Report("🎉 Seçili bileşenler başarıyla kuruldu!");
        }
        else
        {
            progress?.Report($"⚠️  Kurulum kısmen tamamlandı ({successCount}/{selectedComponents.Count})");
        }

        return isSuccess;
    }

    public async Task<bool> VerifyInstallationAsync(IProgress<string>? progress = null)
    {
        progress?.Report("🔍 Kurulum doğrulanıyor...");
        
        // Bağlantı testi
        var connected = await _databaseService.TestConnectionAsync();
        if (!connected)
        {
            progress?.Report("❌ Veritabanı bağlantısı başarısız");
            return false;
        }
        
        // Şema kontrolü
        var schemas = await _databaseService.GetExistingSchemasAsync();
        var requiredSchemas = new[] { "ai", "etl", "log", "rpt" };
        var missingSchemas = requiredSchemas.Where(s => !schemas.Contains(s)).ToList();
        
        if (missingSchemas.Any())
        {
            progress?.Report($"❌ Eksik şemalar: {string.Join(", ", missingSchemas)}");
            return false;
        }
        
        // Stored procedure kontrolü
        var procCounts = await _databaseService.GetStoredProcedureCountsAsync();
        var aiProcCount = procCounts.GetValueOrDefault("ai", 0);
        var etlProcCount = procCounts.GetValueOrDefault("etl", 0);
        
        if (aiProcCount < 5)
        {
            progress?.Report($"⚠️  AI stored procedure sayısı düşük: {aiProcCount}");
        }
        
        if (etlProcCount < 3)
        {
            progress?.Report($"⚠️  ETL stored procedure sayısı düşük: {etlProcCount}");
        }
        
        progress?.Report("✅ Kurulum doğrulaması tamamlandı");
        return true;
    }
}