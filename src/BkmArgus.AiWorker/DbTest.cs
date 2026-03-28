using Microsoft.Data.SqlClient;
using Dapper;
using Microsoft.Extensions.Configuration;

namespace BkmArgus.AiWorker;

public static class DbTest
{
    public static async Task RunTest()
    {
        // Connection string'i appsettings'den al
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build();
            
        var connectionString = configuration.GetConnectionString("BkmDenetim");
        Console.WriteLine($"Connection String: {connectionString}");
        
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        
        Console.WriteLine("\n=== TÜM TABLO LİSTESİ ===");
        
        // Tüm schemaları ve tabloları listele
        try
        {
            var tables = await connection.QueryAsync(@"
                SELECT 
                    s.name as schema_name,
                    t.name as table_name
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE t.is_ms_shipped = 0
                ORDER BY s.name, t.name");
                
            Console.WriteLine("Mevcut Tablolar:");
            foreach (var table in tables)
            {
                Console.WriteLine($"  {table.schema_name}.{table.table_name}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Tablo listesi hatası: {ex.Message}");
        }

        Console.WriteLine("\n=== RİSK TABLO KONTROL ===");
        
        // rpt.RiskUrunOzet_Gunluk tablosunu kontrol et
        try
        {
            var count = await connection.QuerySingleAsync<int>(
                "SELECT COUNT(*) FROM rpt.RiskUrunOzet_Gunluk");
            Console.WriteLine($"rpt.RiskUrunOzet_Gunluk kayıt sayısı: {count}");
            
            if (count > 0)
            {
                var samples = await connection.QueryAsync(
                    "SELECT TOP 5 KesimTarihi, DonemKodu, MekanId, StokId, RiskSkor FROM rpt.RiskUrunOzet_Gunluk ORDER BY KesimTarihi DESC");
                Console.WriteLine("\nSon 5 kayıt:");
                foreach (var row in samples)
                {
                    Console.WriteLine($"  Tarih: {row.KesimTarihi}, Mekan: {row.MekanId}, Stok: {row.StokId}, Skor: {row.RiskSkor}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"rpt.RiskUrunOzet_Gunluk hatası: {ex.Message}");
        }
        
        // ai.AiAnalizIstegi tablosunu kontrol et
        try
        {
            var count = await connection.QuerySingleAsync<int>(
                "SELECT COUNT(*) FROM ai.AiAnalizIstegi");
            Console.WriteLine($"ai.AiAnalizIstegi kayıt sayısı: {count}");
            
            if (count > 0)
            {
                var samples = await connection.QueryAsync(
                    "SELECT TOP 5 IstekId, KesimTarihi, MekanId, StokId, Durum, OlusturmaTarihi FROM ai.AiAnalizIstegi ORDER BY OlusturmaTarihi DESC");
                Console.WriteLine("\nSon 5 AI isteği:");
                foreach (var row in samples)
                {
                    Console.WriteLine($"  ID: {row.IstekId}, Durum: {row.Durum}, Tarih: {row.OlusturmaTarihi}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ai.AiAnalizIstegi hatası: {ex.Message}");
        }
        
        // ai.AiLlmSonuc tablosunu kontrol et
        try
        {
            var count = await connection.QuerySingleAsync<int>(
                "SELECT COUNT(*) FROM ai.AiLlmSonuc");
            Console.WriteLine($"ai.AiLlmSonuc kayıt sayısı: {count}");
            
            if (count > 0)
            {
                var samples = await connection.QueryAsync(
                    "SELECT TOP 5 IstekId, Model, GuvenSkoru, OlusturmaTarihi FROM ai.AiLlmSonuc ORDER BY OlusturmaTarihi DESC");
                Console.WriteLine("\nSon 5 LLM sonucu:");
                foreach (var row in samples)
                {
                    Console.WriteLine($"  Istek: {row.IstekId}, Model: {row.Model}, Skor: {row.GuvenSkoru}, Tarih: {row.OlusturmaTarihi}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ai.AiLlmSonuc hatası: {ex.Message}");
        }
        
        // Yüksek risk skorlu kayıtları kontrol et (50 ve üstü)
        try
        {
            var count = await connection.QuerySingleAsync<int>(
                "SELECT COUNT(*) FROM rpt.RiskUrunOzet_Gunluk WHERE RiskSkor >= 50");
            Console.WriteLine($"RiskSkor >= 50 olan kayıt sayısı: {count}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"RiskSkor sorgusu hatası: {ex.Message}");
        }
        
        // AI isteklerinin hata mesajlarını da kontrol et
        try
        {
            var errorRequests = await connection.QueryAsync(@"
                SELECT IstekId, Durum, HataMesaji, OlusturmaTarihi 
                FROM ai.AiAnalizIstegi 
                WHERE Durum = 'ERROR' AND HataMesaji IS NOT NULL
                ORDER BY OlusturmaTarihi DESC");
                
            if (errorRequests.Any())
            {
                Console.WriteLine($"\n❌ Hatalı AI istekleri ({errorRequests.Count()} adet):");
                foreach (var req in errorRequests.Take(3))
                {
                    Console.WriteLine($"  ID: {req.IstekId}, Hata: {req.HataMesaji}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Hata mesajları kontrol edilemedi: {ex.Message}");
        }

        Console.WriteLine("\n=== TABLO KONTROL BİTTİ ===");
    }
}
