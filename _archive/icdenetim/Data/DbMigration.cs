using Dapper;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Data;

/// <summary>
/// Uygulama başlangıcında veritabanı migration'larını çalıştırır.
/// Eksik sütunları ekler - Setup sayfası çalıştırılmamış olsa bile uyumluluk sağlar.
/// </summary>
public static class DbMigration
{
    /// <summary>
    /// Eksik sütunları ekler. Hata olursa sessizce devam eder (veritabanı henüz yoksa).
    /// </summary>
    public static async Task RunMigrationsAsync(IConfiguration config)
    {
        try
        {
            using var conn = DbConnectionFactory.Create(config);
            await conn.OpenAsync();

            // Audits: IsFinalized, FinalizedAt
            await ExecuteIfColumnMissing(conn, "Audits", "IsFinalized",
                "ALTER TABLE Audits ADD IsFinalized BIT NOT NULL DEFAULT 0");
            await ExecuteIfColumnMissing(conn, "Audits", "FinalizedAt",
                "ALTER TABLE Audits ADD FinalizedAt DATETIME2 NULL");

            // AuditItems: LocationType (sadece Mağaza)
            await ExecuteIfColumnMissing(conn, "AuditItems", "LocationType",
                "ALTER TABLE AuditItems ADD LocationType NVARCHAR(20) NOT NULL DEFAULT N'Mağaza'");

            // Kafe kaldırıldı - tüm maddeleri Mağaza yap
            await conn.ExecuteAsync(
                "UPDATE AuditItems SET LocationType = N'Mağaza' WHERE LocationType IN (N'Kafe', N'Herİkisi')");

            // Skills Engine migration
            await RunSqlFileAsync(conn, "Data/Migration_Skills.sql");

            // CorrectiveActions (DOF) migration
            await RunSqlFileAsync(conn, "Data/Migration_CorrectiveActions.sql");

            // AuditLog migration
            await RunSqlFileAsync(conn, "Data/Migration_AuditLog.sql");

            // AI Altyapisi: AiAnalyses tablosu ve indexleri
            await RunSqlFileAsync(conn, "Data/Migration_AiInfrastructure.sql");

            // DOF Effectiveness: etkinlik takip alanlari
            await RunSqlFileAsync(conn, "Data/Migration_DofEffectiveness.sql");

            // Skill Seed: MAGAZA skill'ine RiskRules ve AiPromptContext
            await RunSqlFileAsync(conn, "Data/Migration_SkillSeed.sql");

            // Compatibility: IcDenetim <-> RiskAnaliz table views
            await RunSqlFileAsync(conn, "Data/Migration_Compatibility.sql");

            // Data Intelligence: tekrar/sistemik tespit alanları
            await ExecuteIfColumnMissing(conn, "AuditResults", "FirstSeenAt",
                "ALTER TABLE AuditResults ADD FirstSeenAt DATETIME2 NULL");
            await ExecuteIfColumnMissing(conn, "AuditResults", "LastSeenAt",
                "ALTER TABLE AuditResults ADD LastSeenAt DATETIME2 NULL");
            await ExecuteIfColumnMissing(conn, "AuditResults", "RepeatCount",
                "ALTER TABLE AuditResults ADD RepeatCount INT NOT NULL DEFAULT 0");
            await ExecuteIfColumnMissing(conn, "AuditResults", "IsSystemic",
                "ALTER TABLE AuditResults ADD IsSystemic BIT NOT NULL DEFAULT 0");
            await ExecuteIfIndexMissing(conn, "IX_AuditResults_ItemLocation",
                "CREATE INDEX IX_AuditResults_ItemLocation ON AuditResults(AuditItemId, IsPassed)");

            // admin@bkmargus.local -> fikri.eren@bkmkitap.com gecisi (bir kerelik)
            var seedPassword = Environment.GetEnvironmentVariable("ARGUS_SEED_PASSWORD");
            if (!string.IsNullOrEmpty(seedPassword))
            {
                var newHash = BCrypt.Net.BCrypt.HashPassword(seedPassword, workFactor: 11);
                await conn.ExecuteAsync(
                    @"UPDATE Users SET Email = N'fikri.eren@bkmkitap.com', PasswordHash = @Hash, FullName = N'Fikri Eren'
                      WHERE Email = N'admin@bkmargus.local'",
                    new { Hash = newHash });
            }
        }
        catch (SqlException)
        {
            // Veritabanı yok veya bağlantı hatası - Setup gerekli
        }
    }

    private static async Task ExecuteIfColumnMissing(SqlConnection conn, string table, string column, string sql)
    {
        var exists = await conn.ExecuteScalarAsync<int>(
            @"SELECT COUNT(1) FROM sys.columns c
              JOIN sys.tables t ON c.object_id = t.object_id
              WHERE t.name = @Table AND c.name = @Column",
            new { Table = table, Column = column });
        if (exists == 0)
            await conn.ExecuteAsync(sql);
    }

    private static async Task ExecuteIfIndexMissing(SqlConnection conn, string indexName, string sql)
    {
        var exists = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(1) FROM sys.indexes WHERE name = @IndexName",
            new { IndexName = indexName });
        if (exists == 0)
            await conn.ExecuteAsync(sql);
    }

    /// <summary>
    /// SQL dosyasını okuyup GO ayracıyla bölerek sırayla çalıştırır.
    /// GO olmayan dosyaları tek parça olarak çalıştırır.
    /// </summary>
    private static async Task RunSqlFileAsync(SqlConnection conn, string relativePath)
    {
        var filePath = Path.Combine(AppContext.BaseDirectory, relativePath);
        if (!File.Exists(filePath))
            return;

        var sql = await File.ReadAllTextAsync(filePath);

        // GO ayracını kaldır - Dapper tek batch çalıştırır, GO desteklemez
        // Her statement'ı ayrı ayrı çalıştır
        var batches = sql.Split(new[] { "\nGO\n", "\nGO\r\n", "\r\nGO\r\n", "\r\nGO\n" },
            StringSplitOptions.RemoveEmptyEntries);

        foreach (var batch in batches)
        {
            var trimmed = batch.Trim();
            if (!string.IsNullOrEmpty(trimmed) && !trimmed.StartsWith("--"))
                await conn.ExecuteAsync(trimmed);
        }
    }
}
