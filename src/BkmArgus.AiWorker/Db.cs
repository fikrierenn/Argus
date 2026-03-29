using BkmArgus.Infrastructure;
using Microsoft.Data.SqlClient;
using Dapper;
using System.Data;

namespace BkmArgus.AiWorker;

public sealed class Db
{
    private readonly string _connectionString;

    public Db(IConfiguration configuration)
    {
        _connectionString = BkmDenetimConnection.Resolve(configuration);
    }

    public SqlConnection CreateConnection() => new SqlConnection(_connectionString);

    public async Task<Dictionary<string, object>> ExecuteStoredProcedureAsync(string procedureName, object? parameters = null)
    {
        using var connection = CreateConnection();
        await connection.OpenAsync();
        
        try
        {
            var result = await connection.QueryAsync(procedureName, parameters, commandType: CommandType.StoredProcedure);
            return new Dictionary<string, object>
            {
                ["Success"] = true,
                ["Data"] = result,
                ["RecordsAffected"] = result.Count()
            };
        }
        catch (Exception ex)
        {
            return new Dictionary<string, object>
            {
                ["Success"] = false,
                ["Error"] = ex.Message,
                ["Exception"] = ex
            };
        }
    }
}
