using Microsoft.Data.SqlClient;

namespace BkmArgus.Data;

/// <summary>
/// Veritabanı kurulumu - Schema.sql çalıştırır, tabloları oluşturur.
/// </summary>
public static class DbSetup
{
    /// <summary>
    /// Schema.sql dosyasını okuyup çalıştırır. GO ile ayrılmış batch'leri sırayla execute eder.
    /// </summary>
    public static async Task RunSchemaAsync(IConfiguration config)
    {
        var connStr = config.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection tanımlı değil.");

        // Önce master'a bağlanıp veritabanını oluştur
        var masterConnStr = connStr
            .Replace("Database=BKMDenetim", "Database=master")
            .Replace("Initial Catalog=BKMDenetim", "Initial Catalog=master");

        using (var conn = new SqlConnection(masterConnStr))
        {
            await conn.OpenAsync();
            await new SqlCommand(@"
                IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'BKMDenetim')
                    CREATE DATABASE BKMDenetim;", conn).ExecuteNonQueryAsync();
        }

        // Schema.sql içeriğini oku - output veya proje dizininden
        var schemaPath = Path.Combine(AppContext.BaseDirectory, "Data", "Schema.sql");
        if (!File.Exists(schemaPath))
            schemaPath = Path.Combine(Directory.GetCurrentDirectory(), "Data", "Schema.sql");
        if (!File.Exists(schemaPath))
            throw new FileNotFoundException("Schema.sql bulunamadı. Data/Schema.sql dosyasının mevcut olduğundan emin olun.", schemaPath);

        var sql = await File.ReadAllTextAsync(schemaPath);

        // GO ile batch'lere böl - her satırda sadece "GO" olan satırlar ayırıcı
        var lines = sql.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
        var batches = new List<string>();
        var current = new List<string>();
        foreach (var line in lines)
        {
            if (line.Trim().Equals("GO", StringComparison.OrdinalIgnoreCase))
            {
                var batch = string.Join("\n", current).Trim();
                if (batch.Length > 0) batches.Add(batch);
                current.Clear();
            }
            else
            {
                current.Add(line);
            }
        }
        var last = string.Join("\n", current).Trim();
        if (last.Length > 0) batches.Add(last);

        using var conn2 = new SqlConnection(connStr);
        await conn2.OpenAsync();

        foreach (var batch in batches)
        {
            // USE master, USE BKMDenetim, CREATE DATABASE gibi komutları atla (zaten yaptık)
            if (batch.Contains("USE master", StringComparison.OrdinalIgnoreCase) ||
                batch.Contains("CREATE DATABASE", StringComparison.OrdinalIgnoreCase))
                continue;

            if (batch.Contains("USE BKMDenetim", StringComparison.OrdinalIgnoreCase))
                continue;

            try
            {
                await new SqlCommand(batch, conn2) { CommandTimeout = 30 }.ExecuteNonQueryAsync();
            }
            catch (SqlException ex) when (ex.Number == 2714 || ex.Number == 2705)
            {
                // Object already exists - devam et
            }
        }
    }
}
