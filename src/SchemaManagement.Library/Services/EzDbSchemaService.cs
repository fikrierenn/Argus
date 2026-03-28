using SchemaManagement.Library.Interfaces;
using SchemaManagement.Library.Models;
using System.Text.Json;
using System.Text.Json.Serialization;
using EzDbSchema.MsSql;

namespace SchemaManagement.Library.Services;

public sealed class EzDbSchemaService : IEzDbSchemaService
{
    private readonly string _connectionString;
    private readonly string _schemaName;
    private readonly SqlServerSchemaReader _reader;

    public EzDbSchemaService(string connectionString, SchemaManagementOptions options)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new ArgumentException("Connection string is required.", nameof(connectionString));
        }

        _connectionString = connectionString;
        _schemaName = ResolveSchemaName(connectionString);
        _reader = new SqlServerSchemaReader(connectionString, options);
    }

    public Task<DatabaseSchema> ExtractSchemaAsync()
    {
        var schema = new Database().Render(_schemaName, _connectionString);
        var json = JsonSerializer.Serialize(schema, new JsonSerializerOptions
        {
            ReferenceHandler = ReferenceHandler.IgnoreCycles
        });

        var model = JsonSerializer.Deserialize<DatabaseSchema>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        return Task.FromResult(model ?? new DatabaseSchema { Name = _schemaName });
    }

    public async Task<string> GenerateCreateScriptAsync(string schema, string objectName, string objectType)
    {
        if (string.Equals(objectType, "TABLE", StringComparison.OrdinalIgnoreCase))
        {
            var table = await _reader.GetTableSchemaAsync(schema, objectName);
            return table.CreateScript;
        }

        if (string.Equals(objectType, "VIEW", StringComparison.OrdinalIgnoreCase))
        {
            var view = await _reader.GetViewSchemaAsync(schema, objectName);
            return view.CreateScript;
        }

        if (string.Equals(objectType, "PROCEDURE", StringComparison.OrdinalIgnoreCase))
        {
            var procedure = await _reader.GetProcedureSchemaAsync(schema, objectName);
            return procedure.CreateScript;
        }

        return string.Empty;
    }

    public Task<List<TableInfo>> GetTablesAsync()
    {
        return _reader.GetTablesAsync();
    }

    public Task<List<ViewInfo>> GetViewsAsync()
    {
        return _reader.GetViewsAsync();
    }

    public Task<List<ProcedureInfo>> GetProceduresAsync()
    {
        return _reader.GetProceduresAsync();
    }

    private static string ResolveSchemaName(string connectionString)
    {
        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(connectionString);
        if (!string.IsNullOrWhiteSpace(builder.InitialCatalog))
        {
            return builder.InitialCatalog;
        }

        return "Database";
    }
}
