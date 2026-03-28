using DbUp;
using DbUp.Engine;
using DbUp.Engine.Output;
using DbUp.Helpers;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using SchemaManagement.Library.Interfaces;
using SchemaManagement.Library.Models;

namespace SchemaManagement.Library.Services;

public sealed class DbUpService : IDbUpService
{
    private readonly string _connectionString;
    private readonly SchemaManagementOptions _options;
    private readonly ILogger<DbUpService>? _logger;

    public DbUpService(string connectionString, SchemaManagementOptions options, ILogger<DbUpService>? logger = null)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new ArgumentException("Connection string is required.", nameof(connectionString));
        }

        _connectionString = connectionString;
        _options = options;
        _logger = logger;
    }

    public Task CreateDatabaseIfNotExistsAsync()
    {
        EnsureDatabase.For.SqlDatabase(_connectionString);
        return Task.CompletedTask;
    }

    public Task<DatabaseUpgradeResult> PerformUpgradeAsync(string scriptsPath)
    {
        if (string.IsNullOrWhiteSpace(scriptsPath))
        {
            throw new ArgumentException("Scripts path is required.", nameof(scriptsPath));
        }

        var upgrader = BuildUpgrader(scriptsPath, useLogging: _options.EnableLogging);
        var result = upgrader.PerformUpgrade();
        return Task.FromResult(result);
    }

    public Task<bool> IsUpgradeRequiredAsync(string scriptsPath)
    {
        if (string.IsNullOrWhiteSpace(scriptsPath))
        {
            throw new ArgumentException("Scripts path is required.", nameof(scriptsPath));
        }

        var upgrader = BuildUpgrader(scriptsPath, useLogging: false);
        var required = upgrader.IsUpgradeRequired();
        return Task.FromResult(required);
    }

    public async Task<List<string>> GetExecutedScriptsAsync()
    {
        var (schema, table) = ResolveJournalTable();
        var sql = $"SELECT ScriptName FROM [{schema}].[{table}] ORDER BY Applied";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        try
        {
            var scripts = await connection.QueryAsync<string>(sql);
            return scripts.ToList();
        }
        catch
        {
            return new List<string>();
        }
    }

    private UpgradeEngine BuildUpgrader(string scriptsPath, bool useLogging)
    {
        var (schema, table) = ResolveJournalTable();
        var builder = DeployChanges.To
            .SqlDatabase(_connectionString)
            .WithScriptsFromFileSystem(scriptsPath)
            .JournalToSqlTable(schema, table);

        if (!useLogging)
        {
            builder = builder.LogToNowhere();
        }
        else if (_logger is not null)
        {
            builder = builder.LogTo(new LoggerUpgradeLog(_logger));
        }
        else
        {
            builder = builder.LogToConsole();
        }

        return builder.Build();
    }

    private (string Schema, string Table) ResolveJournalTable()
    {
        var name = string.IsNullOrWhiteSpace(_options.MigrationHistoryTable)
            ? "SchemaVersions"
            : _options.MigrationHistoryTable;

        var parts = name.Split('.', 2, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 2)
        {
            return (parts[0], parts[1]);
        }

        return ("dbo", parts[0]);
    }

    private sealed class LoggerUpgradeLog : IUpgradeLog
    {
        private readonly ILogger _logger;

        public LoggerUpgradeLog(ILogger logger)
        {
            _logger = logger;
        }

        public void WriteInformation(string format, params object[] args)
        {
            _logger.LogInformation(format, args);
        }

        public void WriteError(string format, params object[] args)
        {
            _logger.LogError(format, args);
        }

        public void WriteWarning(string format, params object[] args)
        {
            _logger.LogWarning(format, args);
        }
    }
}
