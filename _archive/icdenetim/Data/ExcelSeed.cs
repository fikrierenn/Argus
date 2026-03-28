using Dapper;
using ExcelDataReader;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Data;

/// <summary>
/// Excel dosyasından denetim maddelerini AuditItems tablosuna seed eder.
/// denetim.xlsx - DENETİM MADDELERİ sayfası okunur.
/// ExcelDataReader kullanır - ClosedXML'e göre farklı Excel yapılarına daha toleranslıdır.
/// </summary>
public static class ExcelSeed
{
    /// <summary>
    /// Excel'den maddeleri okur ve AuditItems'a ekler.
    /// </summary>
    public static async Task<int> SeedAuditItemsFromExcelAsync(IConfiguration config)
    {
        var excelPath = FindExcelPath();
        if (!File.Exists(excelPath))
            throw new FileNotFoundException("denetim.xlsx bulunamadı.", excelPath);

        System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);

        var items = new List<(string AuditGroup, string Area, string RiskType, string ItemText, int SortOrder, string? FindingType, int Probability, int Impact)>();

        using (var stream = File.Open(excelPath, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var reader = ExcelReaderFactory.CreateReader(stream))
        {
            // DENETİM MADDELERİ sayfasını bul
            do
            {
                if (!reader.Name.Contains("MADDELER", StringComparison.OrdinalIgnoreCase))
                    continue;

                var rowIndex = 0;
                while (reader.Read())
                {
                    rowIndex++;
                    if (rowIndex == 1) continue; // Header atla

                    var grup = GetCellString(reader, 0);   // A: GRUP
                    var alan = GetCellString(reader, 1);   // B: Alan
                    var riskTuru = GetCellString(reader, 2); // C: Risk Türü
                    var maddeMetni = GetCellString(reader, 3); // D: Madde metni

                    if (string.IsNullOrWhiteSpace(grup) && string.IsNullOrWhiteSpace(maddeMetni))
                        continue;
                    if (string.IsNullOrWhiteSpace(maddeMetni))
                        continue;

                    var tespitTipi = GetCellString(reader, 5); // F: Tespit tipi (H/E)
                    var olasilik = GetCellInt(reader, 13) ?? GetCellInt(reader, 7) ?? 1; // N veya H
                    var etki = GetCellInt(reader, 14) ?? GetCellInt(reader, 8) ?? 1;     // O veya I

                    items.Add((grup ?? "", alan ?? "", riskTuru ?? "", maddeMetni, rowIndex, tespitTipi, olasilik, etki));
                }
                break;
            } while (reader.NextResult());
        }

        if (items.Count == 0)
            return 0;

        using var conn = new SqlConnection(config.GetConnectionString("DefaultConnection"));
        await conn.OpenAsync();

        foreach (var item in items)
        {
            await conn.ExecuteAsync(
                @"INSERT INTO AuditItems (LocationType, AuditGroup, Area, RiskType, ItemText, SortOrder, FindingType, Probability, Impact, CreatedAt)
                  VALUES (N'Mağaza', @AuditGroup, @Area, @RiskType, @ItemText, @SortOrder, @FindingType, @Probability, @Impact, GETDATE())",
                new
                {
                    item.AuditGroup,
                    item.Area,
                    item.RiskType,
                    item.ItemText,
                    item.SortOrder,
                    item.FindingType,
                    item.Probability,
                    item.Impact
                });
        }

        return items.Count;
    }

    private static string? GetCellString(IExcelDataReader reader, int col)
    {
        try
        {
            var v = reader.GetValue(col);
            return v?.ToString()?.Trim();
        }
        catch { return null; }
    }

    private static int? GetCellInt(IExcelDataReader reader, int col)
    {
        try
        {
            var v = reader.GetValue(col);
            if (v == null) return null;
            if (v is int i) return i;
            if (v is double d) return (int)d;
            if (int.TryParse(v.ToString(), out var parsed)) return parsed;
            if (double.TryParse(v.ToString(), out var d2)) return (int)d2;
            return null;
        }
        catch { return null; }
    }

    private static string FindExcelPath()
    {
        var candidates = new[]
        {
            Path.Combine(Directory.GetCurrentDirectory(), "denetim.xlsx"),
            Path.Combine(Directory.GetCurrentDirectory(), "..", "denetim.xlsx"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "denetim.xlsx")
        };
        return candidates.FirstOrDefault(File.Exists) ?? candidates[0];
    }
}
