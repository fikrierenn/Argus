using Microsoft.Data.SqlClient;
using Dapper;
using System.Data;

namespace BkmArgus.AiWorker;

public sealed class Db
{
    private readonly string _connectionString;

    public Db(IConfiguration configuration)
    {
        var envConn = configuration["BKM_DENETIM_CONN"];
        var appConn = configuration.GetConnectionString("BkmDenetim");
        if (!string.IsNullOrWhiteSpace(envConn))
        {
            _connectionString = envConn;
            return;
        }

        if (!string.IsNullOrWhiteSpace(appConn))
        {
            _connectionString = appConn;
            return;
        }

        throw new InvalidOperationException("BKM_DENETIM_CONN veya ConnectionStrings:BkmDenetim tanimli degil.");
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
