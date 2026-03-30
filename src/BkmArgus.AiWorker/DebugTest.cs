using System.Data;
using Dapper;

namespace BkmArgus.AiWorker;

public static class DebugTest
{
    public static async Task TestRiskOzetGetir(Db db)
    {
        await using var connection = db.CreateConnection();
        
        // Test with a simple query first to see what data is actually returned
        var testQuery = @"
            SELECT TOP 1
                r.KesimTarihi,
                r.DonemKodu,
                r.MekanId,
                MekanAd = COALESCE(m.MekanAd, CONCAT('Mekan-', r.MekanId)),
                r.StokId,
                UrunKod = COALESCE(u.UrunKod, CONCAT('BK-', r.StokId)),
                UrunAd = COALESCE(u.UrunAd, CONCAT('Urun-', r.StokId)),
                r.RiskSkor,
                r.RiskYorum,
                r.FlagVeriKalite,
                r.FlagGirissizSatis,
                r.FlagOluStok,
                r.FlagNetBirikim,
                r.FlagIadeYuksek,
                r.FlagBozukIadeYuksek,
                r.FlagSayimDuzeltmeYuk,
                r.FlagSirketIciYuksek,
                r.FlagHizliDevir,
                r.FlagSatisYaslanma
            FROM rpt.RiskUrunOzet_Gunluk r
            LEFT JOIN src.vw_Mekan m ON m.MekanId = r.MekanId
            LEFT JOIN src.vw_Urun u ON u.StokId = r.StokId
            ORDER BY r.KesimTarihi DESC";

        try
        {
            // First try to get as dynamic to see the actual data
            var dynamicResult = await connection.QueryFirstOrDefaultAsync(testQuery);
            if (dynamicResult != null)
            {
                Console.WriteLine("Dynamic query successful:");
                foreach (var prop in ((IDictionary<string, object>)dynamicResult).Keys)
                {
                    var value = ((IDictionary<string, object>)dynamicResult)[prop];
                    Console.WriteLine($"  {prop}: {value} (Type: {value?.GetType().Name ?? "null"})");
                }
            }

            // Now try with the strongly typed model
            var typedResult = await connection.QuerySingleOrDefaultAsync<RiskSummaryRow>(testQuery);
            Console.WriteLine($"Typed query successful: {typedResult != null}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
        }
    }
}
