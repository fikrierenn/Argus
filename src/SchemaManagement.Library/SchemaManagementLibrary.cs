using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using SchemaManagement.Library.Interfaces;
using SchemaManagement.Library.Models;
using SchemaManagement.Library.Services;

namespace SchemaManagement.Library;

public sealed class SchemaManagementLibrary : ISchemaManagementLibrary
{
    private readonly ILoggerFactory? _loggerFactory;
    private readonly ILogger<SchemaManagementLibrary>? _logger;

    private string? _connectionString;
    private SchemaManagementOptions? _options;
    private IEzDbSchemaService? _schemaService;
    private IDbUpService? _dbUpService;
    private SqlServerSchemaReader? _schemaReader;
    private IExportService? _exportService;
    private IComparisonService? _comparisonService;

    public SchemaManagementLibrary(ILoggerFactory? loggerFactory = null)
    {
        _loggerFactory = loggerFactory;
        _logger = loggerFactory?.CreateLogger<SchemaManagementLibrary>();
    }

    public Task InitializeAsync(string connectionString, SchemaManagementOptions options)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new ArgumentException("Connection string is required.", nameof(connectionString));
        }

        _connectionString = connectionString;
        _options = options ?? new SchemaManagementOptions();
        _schemaReader = new SqlServerSchemaReader(connectionString, _options);
        _schemaService = new EzDbSchemaService(connectionString, _options);
        _dbUpService = new DbUpService(
            connectionString,
            _options,
            _loggerFactory?.CreateLogger<DbUpService>());

        _exportService = new ExportService();
        _comparisonService = new ComparisonService();

        _logger?.LogInformation("Schema management library initialized.");
        return Task.CompletedTask;
    }

    public async Task<DatabaseSchema> GetDatabaseSchemaAsync()
    {
        EnsureInitialized();
        return await _schemaService!.ExtractSchemaAsync();
    }

    public async Task<TableSchema> GetTableSchemaAsync(string schema, string tableName)
    {
        EnsureInitialized();
        return await _schemaReader!.GetTableSchemaAsync(schema, tableName);
    }

    public async Task<ViewSchema> GetViewSchemaAsync(string schema, string viewName)
    {
        EnsureInitialized();
        return await _schemaReader!.GetViewSchemaAsync(schema, viewName);
    }

    public async Task<ProcedureSchema> GetProcedureSchemaAsync(string schema, string procedureName)
    {
        EnsureInitialized();
        return await _schemaReader!.GetProcedureSchemaAsync(schema, procedureName);
    }

    public async Task<ExportResult> ExportAllSchemaAsync(string outputPath)
    {
        EnsureInitialized();

        if (_exportService is null)
        {
            return new ExportResult { Success = false, Message = "Export service is not configured." };
        }

        var schema = await GetDatabaseSchemaAsync();
        return await _exportService.ExportToFilesAsync(schema, outputPath);
    }

    public Task<ExportResult> ExportSelectedObjectsAsync(List<DatabaseObject> objects, string outputPath)
    {
        return Task.FromResult(new ExportResult
        {
            Success = false,
            Message = "Selective export is not implemented yet."
        });
    }

    public Task<byte[]> ExportSchemaAsZipAsync()
    {
        return Task.FromResult(Array.Empty<byte>());
    }

    public async Task<MigrationResult> ApplyMigrationsAsync(string migrationsPath)
    {
        EnsureInitialized();

        var start = DateTime.UtcNow;
        try
        {
            var upgradeResult = await _dbUpService!.PerformUpgradeAsync(migrationsPath);
            var applied = upgradeResult.Scripts?.Select(s => s.Name).ToList() ?? new List<string>();

            return new MigrationResult
            {
                Success = upgradeResult.Successful,
                Message = upgradeResult.Successful ? "Migrations applied." : upgradeResult.Error?.Message ?? "Migration failed.",
                AppliedScripts = applied,
                Errors = upgradeResult.Error is null ? new List<string>() : new List<string> { upgradeResult.Error.ToString() },
                ExecutionTime = DateTime.UtcNow - start
            };
        }
        catch (Exception ex)
        {
            return new MigrationResult
            {
                Success = false,
                Message = ex.Message,
                Errors = new List<string> { ex.ToString() },
                ExecutionTime = DateTime.UtcNow - start
            };
        }
    }

    public async Task<List<AppliedMigration>> GetAppliedMigrationsAsync()
    {
        EnsureInitialized();
        var (schema, table) = ResolveJournalTable();
        var sql = $"SELECT ScriptName, Applied FROM [{schema}].[{table}] ORDER BY Applied";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        try
        {
            var results = await connection.QueryAsync<AppliedMigration>(sql);
            return results.ToList();
        }
        catch
        {
            return new List<AppliedMigration>();
        }
    }

    public async Task<List<string>> GetPendingMigrationsAsync(string migrationsPath)
    {
        EnsureInitialized();
        if (!Directory.Exists(migrationsPath))
        {
            return new List<string>();
        }

        var executed = await _dbUpService!.GetExecutedScriptsAsync();
        var executedSet = new HashSet<string>(executed, StringComparer.OrdinalIgnoreCase);

        var files = Directory.EnumerateFiles(migrationsPath, "*.sql", SearchOption.AllDirectories)
            .Select(Path.GetFileName)
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .Select(name => name!)
            .ToList();

        return files.Where(file => !executedSet.Contains(file)).ToList();
    }

    public Task<ComparisonResult> CompareWithFilesAsync(string sqlFilesPath)
    {
        return Task.FromResult(new ComparisonResult
        {
            Success = false,
            ComparisonDate = DateTime.UtcNow
        });
    }

    public Task<List<SchemaDifference>> GetSchemaDifferencesAsync(string sqlFilesPath)
    {
        return Task.FromResult(new List<SchemaDifference>());
    }

    private void EnsureInitialized()
    {
        if (_connectionString is null || _options is null || _schemaService is null || _dbUpService is null || _schemaReader is null)
        {
            throw new InvalidOperationException("SchemaManagementLibrary is not initialized. Call InitializeAsync first.");
        }
    }

    private (string Schema, string Table) ResolveJournalTable()
    {
        var name = string.IsNullOrWhiteSpace(_options?.MigrationHistoryTable)
            ? "SchemaVersions"
            : _options.MigrationHistoryTable;

        var parts = name.Split('.', 2, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 2)
        {
            return (parts[0], parts[1]);
        }

        return ("dbo", parts[0]);
    }
}
