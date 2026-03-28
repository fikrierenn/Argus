using Dapper;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Data;

/// <summary>
/// Uygulama başlangıcında veritabanı seed işlemleri.
/// Users tablosu boşsa admin kullanıcısı oluşturur.
/// </summary>
public static class DbInitializer
{
    /// <summary>
    /// Admin kullanıcisi yoksa olusturur.
    /// Sifre: Seed:AdminPassword ortam degiskeni veya config'den alinir.
    /// Varsayilan sifre sadece ilk kurulumda kullanilir, ilk giriste degistirilmelidir.
    /// </summary>
    public static async Task SeedAsync(IConfiguration config)
    {
        try
        {
            using var conn = DbConnectionFactory.Create(config);
            var count = await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM Users");
            if (count > 0) return;

            var seedPassword = config["Seed:AdminPassword"]
                ?? Environment.GetEnvironmentVariable("ICDENETIM_SEED_PASSWORD")
                ?? throw new InvalidOperationException(
                    "Seed admin sifresi tanimli degil. " +
                    "Seed:AdminPassword config key veya ICDENETIM_SEED_PASSWORD ortam degiskeni ayarlayin.");
            var seedEmail = config["Seed:AdminEmail"] ?? "admin@bkmargus.local";
            var seedName = config["Seed:AdminFullName"] ?? "Admin";

            var hash = BCrypt.Net.BCrypt.HashPassword(seedPassword, workFactor: 11);
            await conn.ExecuteAsync(
                @"INSERT INTO Users (Email, PasswordHash, FullName, CreatedAt)
                  VALUES (@Email, @PasswordHash, @FullName, GETDATE())",
                new { Email = seedEmail, PasswordHash = hash, FullName = seedName });
        }
        catch (SqlException)
        {
            // Bağlantı hatası veya tablo yok - uygulama yine de başlar
            // SQL Server çalışmıyor veya Schema.sql henüz çalıştırılmamış
        }
    }
}
