using Microsoft.Data.SqlClient;
using Dapper;
using Microsoft.Extensions.Configuration;

namespace BkmDenetim.AiWorker;

public static class CreateAiRequest
{
    public static async Task RunTest()
    {
        // Connection string'i appsettings'den al
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddJsonFile("src/BkmDenetim.AiWorker/appsettings.json")
            .Build();
            
        var connectionString = configuration.GetConnectionString("BkmDenetim");
        Console.WriteLine($"Connection String: {connectionString}");
        
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        
        Console.WriteLine("\n=== YENİ AI İSTEĞİ OLUŞTURMA ===");
        
        try
        {
            // Yeni AI isteği oluştur
            var newRequestId = await connection.QuerySingleAsync<int>(@"
                INSERT INTO ai.AiAnalizIstegi (
                    IstekTipi, 
                    Durum, 
                    Oncelik, 
                    OlusturmaTarihi, 
                    GuncellemeTarihi,
                    KesimTarihi,
                    MekanId,
                    StokId
                ) VALUES (
                    'RISK_ANALIZ', 
                    'NEW', 
                    1, 
                    SYSDATETIME(), 
                    SYSDATETIME(),
                    CAST(SYSDATETIME() AS date),
                    4478,
                    1691524
                );
                SELECT CAST(SCOPE_IDENTITY() AS int);");
                
            Console.WriteLine($"✅ Yeni AI isteği oluşturuldu, ID: {newRequestId}");
            
            // Mevcut AI isteklerini kontrol et
            var pendingRequests = await connection.QueryAsync(@"
                SELECT IstekId, IstekTipi, Durum, Oncelik, OlusturmaTarihi 
                FROM ai.AiAnalizIstegi 
                WHERE Durum IN ('NEW', 'BEKLEMEDE', 'PROCESSING')
                ORDER BY OlusturmaTarihi DESC");
                
            Console.WriteLine($"\n📋 Bekleyen AI istekleri ({pendingRequests.Count()} adet):");
            foreach (var req in pendingRequests)
            {
                Console.WriteLine($"  ID: {req.IstekId}, Tip: {req.IstekTipi}, Durum: {req.Durum}, Tarih: {req.OlusturmaTarihi}");
            }
            
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ AI isteği oluşturma hatası: {ex.Message}");
        }

        Console.WriteLine("\n=== İŞLEM TAMAMLANDI ===");
    }
}