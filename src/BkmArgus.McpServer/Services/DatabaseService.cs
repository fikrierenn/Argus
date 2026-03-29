using BkmArgus.Infrastructure;
using Microsoft.Data.SqlClient;
using Dapper;
using System.Data;
using System.Text.Json;

namespace BkmArgus.McpServer.Services;

public class DatabaseService
{
    private readonly string _connectionString;
    private readonly ILogger<DatabaseService> _logger;

    public DatabaseService(IConfiguration configuration, ILogger<DatabaseService> logger)
    {
        _connectionString = BkmDenetimConnection.Resolve(configuration);
        _logger = logger;
    }

    public async Task<bool> TestConnectionAsync()
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            return connection.State == ConnectionState.Open;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Veritabanı bağlantı testi başarısız");
            return false;
        }
    }

    public async Task<IEnumerable<DatabaseObject>> GetTablesAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = @"
            SELECT 
                s.name as SchemaName,
                t.name as ObjectName,
                'TABLE' as ObjectType,
                ISNULL(CAST(p.rows AS int), 0) as RecordCount,
                t.create_date as CreatedDate,
                t.modify_date as ModifiedDate
            FROM sys.tables t
            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
            LEFT JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
            WHERE t.is_ms_shipped = 0
            ORDER BY s.name, t.name";

        var results = await connection.QueryAsync<DatabaseObject>(query);
        return results;
    }

    public async Task<IEnumerable<DatabaseObject>> GetViewsAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = @"
            SELECT 
                s.name as SchemaName,
                v.name as ObjectName,
                'VIEW' as ObjectType,
                NULL as RecordCount,
                v.create_date as CreatedDate,
                v.modify_date as ModifiedDate
            FROM sys.views v
            INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
            WHERE v.is_ms_shipped = 0
            ORDER BY s.name, v.name";

        var results = await connection.QueryAsync<DatabaseObject>(query);
        return results;
    }

    public async Task<IEnumerable<DatabaseObject>> GetStoredProceduresAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = @"
            SELECT 
                s.name as SchemaName,
                p.name as ObjectName,
                'PROCEDURE' as ObjectType,
                NULL as RecordCount,
                p.create_date as CreatedDate,
                p.modify_date as ModifiedDate
            FROM sys.procedures p
            INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
            WHERE p.is_ms_shipped = 0
            ORDER BY s.name, p.name";

        var results = await connection.QueryAsync<DatabaseObject>(query);
        return results;
    }

    public async Task<QueryResult> ExecuteQueryAsync(string sql, int maxRows = 1000)
    {
        var result = new QueryResult();
        
        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var startTime = DateTime.Now;
            
            using var command = new SqlCommand(sql, connection)
            {
                CommandTimeout = 30
            };

            using var reader = await command.ExecuteReaderAsync();
            
            // Column bilgilerini al
            var columns = new List<string>();
            for (int i = 0; i < reader.FieldCount; i++)
            {
                columns.Add(reader.GetName(i));
            }
            result.Columns = columns;

            // Veri satırlarını al
            var rows = new List<Dictionary<string, object?>>();
            int rowCount = 0;
            
            while (await reader.ReadAsync() && rowCount < maxRows)
            {
                var row = new Dictionary<string, object?>();
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    var value = reader.IsDBNull(i) ? null : reader.GetValue(i);
                    row[columns[i]] = value;
                }
                rows.Add(row);
                rowCount++;
            }
            
            result.Rows = rows;
            result.ExecutionTime = DateTime.Now - startTime;
            result.Success = true;
            result.Message = $"{rowCount} satır döndürüldü";
            
            if (rowCount >= maxRows)
            {
                result.Message += $" (maksimum {maxRows} satır sınırı)";
            }
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Message = ex.Message;
            _logger.LogError(ex, "SQL sorgusu çalıştırılırken hata: {Sql}", sql);
        }

        return result;
    }

    public async Task<QueryResult> ExecuteStoredProcedureAsync(string procedureName, Dictionary<string, object>? parameters = null)
    {
        var result = new QueryResult();
        
        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var startTime = DateTime.Now;
            
            using var command = new SqlCommand(procedureName, connection)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 60
            };

            // Parametreleri ekle
            if (parameters != null)
            {
                foreach (var param in parameters)
                {
                    command.Parameters.AddWithValue($"@{param.Key}", param.Value ?? DBNull.Value);
                }
            }

            using var reader = await command.ExecuteReaderAsync();
            
            // Column bilgilerini al
            var columns = new List<string>();
            for (int i = 0; i < reader.FieldCount; i++)
            {
                columns.Add(reader.GetName(i));
            }
            result.Columns = columns;

            // Veri satırlarını al
            var rows = new List<Dictionary<string, object?>>();
            int rowCount = 0;
            
            while (await reader.ReadAsync() && rowCount < 1000)
            {
                var row = new Dictionary<string, object?>();
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    var value = reader.IsDBNull(i) ? null : reader.GetValue(i);
                    row[columns[i]] = value;
                }
                rows.Add(row);
                rowCount++;
            }
            
            result.Rows = rows;
            result.ExecutionTime = DateTime.Now - startTime;
            result.Success = true;
            result.Message = $"Stored procedure başarıyla çalıştırıldı. {rowCount} satır döndürüldü";
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Message = ex.Message;
            _logger.LogError(ex, "Stored procedure çalıştırılırken hata: {ProcedureName}", procedureName);
        }

        return result;
    }

    public async Task<IEnumerable<ColumnInfo>> GetTableColumnsAsync(string schemaName, string tableName)
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = @"
            SELECT 
                c.COLUMN_NAME as ColumnName,
                c.DATA_TYPE as DataType,
                c.IS_NULLABLE as IsNullable,
                c.CHARACTER_MAXIMUM_LENGTH as MaxLength,
                c.COLUMN_DEFAULT as DefaultValue,
                CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END as IsPrimaryKey
            FROM INFORMATION_SCHEMA.COLUMNS c
            LEFT JOIN (
                SELECT ku.TABLE_CATALOG, ku.TABLE_SCHEMA, ku.TABLE_NAME, ku.COLUMN_NAME
                FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
                INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS ku
                    ON tc.CONSTRAINT_TYPE = 'PRIMARY KEY' 
                    AND tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
            ) pk ON c.TABLE_CATALOG = pk.TABLE_CATALOG
                AND c.TABLE_SCHEMA = pk.TABLE_SCHEMA
                AND c.TABLE_NAME = pk.TABLE_NAME
                AND c.COLUMN_NAME = pk.COLUMN_NAME
            WHERE c.TABLE_SCHEMA = @SchemaName AND c.TABLE_NAME = @TableName
            ORDER BY c.ORDINAL_POSITION";

        var results = await connection.QueryAsync<ColumnInfo>(query, new { SchemaName = schemaName, TableName = tableName });
        return results;
    }
}

public class DatabaseObject
{
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string ObjectType { get; set; } = string.Empty;
    public int? RecordCount { get; set; }
    public DateTime CreatedDate { get; set; }
    public DateTime ModifiedDate { get; set; }
}

public class QueryResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public List<string> Columns { get; set; } = new();
    public List<Dictionary<string, object?>> Rows { get; set; } = new();
    public TimeSpan ExecutionTime { get; set; }
}

public class ColumnInfo
{
    public string ColumnName { get; set; } = string.Empty;
    public string DataType { get; set; } = string.Empty;
    public string IsNullable { get; set; } = string.Empty;
    public int? MaxLength { get; set; }
    public string? DefaultValue { get; set; }
    public bool IsPrimaryKey { get; set; }
}