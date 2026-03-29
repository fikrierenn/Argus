using System.Data;
using BkmArgus.Infrastructure;
using Dapper;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Web.Data;

public sealed class SqlDb
{
    private readonly string _connectionString;

    public SqlDb(IConfiguration configuration)
    {
        // BkmDenetimConnection: BKM_DENETIM_CONN > BkmDenetim > BkmArgus (birleşik repo uyumu)
        _connectionString = BkmDenetimConnection.Resolve(configuration);
    }

    public async Task<bool> CanConnectAsync()
    {
        try
        {
            var builder = new SqlConnectionStringBuilder(_connectionString)
            {
                ConnectTimeout = 3
            };

            await using var connection = new SqlConnection(builder.ToString());
            await connection.OpenAsync();
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<DbInfo?> GetDbInfoAsync()
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            return await connection.QuerySingleOrDefaultAsync<DbInfo>(
                "SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DbName;");
        }
        catch
        {
            return null;
        }
    }

    public async Task<List<T>> QueryAsync<T>(string storedProcedure, object? parameters = null)
    {
        await using var connection = new SqlConnection(_connectionString);
        var results = await connection.QueryAsync<T>(
            storedProcedure,
            parameters,
            commandType: CommandType.StoredProcedure);
        return results.AsList();
    }

    public async Task<T?> QuerySingleAsync<T>(string storedProcedure, object? parameters = null)
    {
        await using var connection = new SqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<T>(
            storedProcedure,
            parameters,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> ExecuteAsync(string storedProcedure, object? parameters = null)
    {
        await using var connection = new SqlConnection(_connectionString);
        return await connection.ExecuteAsync(
            storedProcedure,
            parameters,
            commandType: CommandType.StoredProcedure);
    }

    public sealed class DbInfo
    {
        public string? ServerName { get; init; }
        public string? DbName { get; init; }
    }
}
