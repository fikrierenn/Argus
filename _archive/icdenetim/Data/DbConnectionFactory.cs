using System.Data;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Data;

/// <summary>
/// Dapper icin SqlConnection factory arayuzu.
/// Test ortaminda mock'lanabilir.
/// </summary>
public interface IDbConnectionFactory
{
    /// <summary>
    /// Yeni bir veritabani baglantisi olusturur.
    /// Caller Dispose etmeli (using pattern).
    /// </summary>
    IDbConnection Create();
}

/// <summary>
/// SQL Server baglanti factory implementasyonu.
/// </summary>
public class SqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration config)
    {
        _connectionString = config.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection tanimli degil.");
    }

    public IDbConnection Create() => new SqlConnection(_connectionString);
}

/// <summary>
/// Geriye donuk uyumluluk icin statik factory.
/// Yeni kodda IDbConnectionFactory kullanin.
/// </summary>
public static class DbConnectionFactory
{
    public static SqlConnection Create(IConfiguration config)
    {
        var connStr = config.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection tanimli degil.");
        return new SqlConnection(connStr);
    }
}
