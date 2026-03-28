using Dapper;
using Microsoft.Data.SqlClient;
using SchemaManagement.Library.Models;
using System.Data;

namespace SchemaManagement.Library.Services;

internal sealed class SqlServerSchemaReader
{
    private readonly string _connectionString;
    private readonly int _commandTimeout;

    public SqlServerSchemaReader(string connectionString, SchemaManagementOptions options)
    {
        _connectionString = connectionString;
        _commandTimeout = options.CommandTimeout <= 0 ? 30 : options.CommandTimeout;
    }

    public async Task<List<TableInfo>> GetTablesAsync()
    {
        const string query = @"
SELECT 
    s.name as SchemaName,
    t.name as TableName,
    t.create_date as CreatedDate,
    t.modify_date as ModifiedDate
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
ORDER BY s.name, t.name";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
        var results = await connection.QueryAsync<TableInfo>(query, commandTimeout: _commandTimeout);
        return results.ToList();
    }

    public async Task<List<ViewInfo>> GetViewsAsync()
    {
        const string query = @"
SELECT 
    s.name as SchemaName,
    v.name as ViewName,
    v.create_date as CreatedDate,
    v.modify_date as ModifiedDate
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
WHERE v.is_ms_shipped = 0
ORDER BY s.name, v.name";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
        var results = await connection.QueryAsync<ViewInfo>(query, commandTimeout: _commandTimeout);
        return results.ToList();
    }

    public async Task<List<ProcedureInfo>> GetProceduresAsync()
    {
        const string query = @"
SELECT 
    s.name as SchemaName,
    p.name as ProcedureName,
    p.create_date as CreatedDate,
    p.modify_date as ModifiedDate
FROM sys.procedures p
INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE p.is_ms_shipped = 0
ORDER BY s.name, p.name";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
        var results = await connection.QueryAsync<ProcedureInfo>(query, commandTimeout: _commandTimeout);
        return results.ToList();
    }

    public async Task<TableSchema> GetTableSchemaAsync(string schemaName, string tableName)
    {
        const string query = @"
SELECT 
    s.name as SchemaName,
    t.name as TableName,
    t.create_date as CreatedDate,
    t.modify_date as ModifiedDate
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = @SchemaName AND t.name = @TableName";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var table = await connection.QuerySingleOrDefaultAsync<TableSchema>(
            query,
            new { SchemaName = schemaName, TableName = tableName },
            commandTimeout: _commandTimeout);

        if (table is null)
        {
            return new TableSchema
            {
                SchemaName = schemaName,
                TableName = tableName
            };
        }

        table.Columns = await GetTableColumnsAsync(connection, schemaName, tableName);
        table.Indexes = await GetTableIndexesAsync(connection, schemaName, tableName);
        table.Constraints = await GetTableConstraintsAsync(connection, schemaName, tableName);
        table.CreateScript = GenerateCreateTableScript(table);

        return table;
    }

    public async Task<ViewSchema> GetViewSchemaAsync(string schemaName, string viewName)
    {
        const string query = @"
SELECT 
    s.name as SchemaName,
    v.name as ViewName,
    v.create_date as CreatedDate,
    v.modify_date as ModifiedDate,
    m.definition as Definition
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
INNER JOIN sys.sql_modules m ON v.object_id = m.object_id
WHERE s.name = @SchemaName AND v.name = @ViewName";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var view = await connection.QuerySingleOrDefaultAsync<ViewSchema>(
            query,
            new { SchemaName = schemaName, ViewName = viewName },
            commandTimeout: _commandTimeout);

        if (view is null)
        {
            return new ViewSchema
            {
                SchemaName = schemaName,
                ViewName = viewName
            };
        }

        view.CreateScript = GenerateCreateViewScript(view);
        return view;
    }

    public async Task<ProcedureSchema> GetProcedureSchemaAsync(string schemaName, string procedureName)
    {
        const string query = @"
SELECT 
    s.name as SchemaName,
    p.name as ProcedureName,
    p.create_date as CreatedDate,
    p.modify_date as ModifiedDate,
    m.definition as Definition
FROM sys.procedures p
INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
WHERE s.name = @SchemaName AND p.name = @ProcedureName";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var procedure = await connection.QuerySingleOrDefaultAsync<ProcedureSchema>(
            query,
            new { SchemaName = schemaName, ProcedureName = procedureName },
            commandTimeout: _commandTimeout);

        if (procedure is null)
        {
            return new ProcedureSchema
            {
                SchemaName = schemaName,
                ProcedureName = procedureName
            };
        }

        procedure.Parameters = await GetProcedureParametersAsync(connection, schemaName, procedureName);
        procedure.CreateScript = GenerateCreateProcedureScript(procedure);
        return procedure;
    }

    private async Task<List<ColumnSchema>> GetTableColumnsAsync(SqlConnection connection, string schemaName, string tableName)
    {
        const string query = @"
SELECT 
    c.COLUMN_NAME as ColumnName,
    c.DATA_TYPE as DataType,
    c.CHARACTER_MAXIMUM_LENGTH as MaxLength,
    c.NUMERIC_PRECISION as Precision,
    c.NUMERIC_SCALE as Scale,
    CASE WHEN c.IS_NULLABLE = 'YES' THEN 1 ELSE 0 END as IsNullable,
    c.COLUMN_DEFAULT as DefaultValue,
    CASE WHEN ic.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END as IsIdentity,
    CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END as IsPrimaryKey,
    c.ORDINAL_POSITION as OrdinalPosition
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN sys.identity_columns ic ON ic.object_id = OBJECT_ID(c.TABLE_SCHEMA + '.' + c.TABLE_NAME) 
    AND ic.name = c.COLUMN_NAME
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

        var results = await connection.QueryAsync<ColumnSchema>(
            query,
            new { SchemaName = schemaName, TableName = tableName },
            commandTimeout: _commandTimeout);

        return results.ToList();
    }

    private async Task<List<IndexSchema>> GetTableIndexesAsync(SqlConnection connection, string schemaName, string tableName)
    {
        const string query = @"
SELECT 
    i.name as IndexName,
    i.type_desc as IndexType,
    i.is_unique as IsUnique,
    i.is_primary_key as IsPrimaryKey,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) as Columns
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = @SchemaName AND t.name = @TableName
GROUP BY i.name, i.type_desc, i.is_unique, i.is_primary_key
ORDER BY i.name";

        var results = await connection.QueryAsync<dynamic>(
            query,
            new { SchemaName = schemaName, TableName = tableName },
            commandTimeout: _commandTimeout);

        return results.Select(idx => new IndexSchema
        {
            IndexName = idx.IndexName,
            IndexType = idx.IndexType,
            IsUnique = idx.IsUnique,
            IsPrimaryKey = idx.IsPrimaryKey,
            Columns = idx.Columns?.Split(", ", StringSplitOptions.RemoveEmptyEntries).ToList() ?? new List<string>()
        }).ToList();
    }

    private async Task<List<ConstraintSchema>> GetTableConstraintsAsync(SqlConnection connection, string schemaName, string tableName)
    {
        const string query = @"
SELECT 
    tc.CONSTRAINT_NAME as ConstraintName,
    tc.CONSTRAINT_TYPE as ConstraintType,
    cc.CHECK_CLAUSE as Definition,
    STRING_AGG(kcu.COLUMN_NAME, ', ') as Columns
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
LEFT JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
WHERE tc.TABLE_SCHEMA = @SchemaName AND tc.TABLE_NAME = @TableName
GROUP BY tc.CONSTRAINT_NAME, tc.CONSTRAINT_TYPE, cc.CHECK_CLAUSE
ORDER BY tc.CONSTRAINT_NAME";

        var results = await connection.QueryAsync<dynamic>(
            query,
            new { SchemaName = schemaName, TableName = tableName },
            commandTimeout: _commandTimeout);

        return results.Select(c => new ConstraintSchema
        {
            ConstraintName = c.ConstraintName,
            ConstraintType = c.ConstraintType,
            Definition = c.Definition ?? string.Empty,
            Columns = c.Columns?.Split(", ", StringSplitOptions.RemoveEmptyEntries).ToList() ?? new List<string>()
        }).ToList();
    }

    private async Task<List<ParameterSchema>> GetProcedureParametersAsync(SqlConnection connection, string schemaName, string procedureName)
    {
        const string query = @"
SELECT 
    p.name as ParameterName,
    t.name as DataType,
    p.max_length as MaxLength,
    p.is_output as IsOutput,
    p.default_value as DefaultValue,
    p.parameter_id as OrdinalPosition
FROM sys.parameters p
INNER JOIN sys.types t ON p.user_type_id = t.user_type_id
INNER JOIN sys.procedures pr ON p.object_id = pr.object_id
INNER JOIN sys.schemas s ON pr.schema_id = s.schema_id
WHERE s.name = @SchemaName AND pr.name = @ProcedureName
ORDER BY p.parameter_id";

        var results = await connection.QueryAsync<ParameterSchema>(
            query,
            new { SchemaName = schemaName, ProcedureName = procedureName },
            commandTimeout: _commandTimeout);

        return results.ToList();
    }

    private static string GenerateCreateTableScript(TableSchema table)
    {
        var script = new System.Text.StringBuilder();
        script.AppendLine($"-- Table: {table.SchemaName}.{table.TableName}");
        script.AppendLine($"-- Created: {table.CreatedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine($"-- Modified: {table.ModifiedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine();
        script.AppendLine($"CREATE TABLE [{table.SchemaName}].[{table.TableName}] (");

        var columnScripts = new List<string>();
        foreach (var column in table.Columns.OrderBy(c => c.OrdinalPosition))
        {
            var columnScript = new System.Text.StringBuilder();
            columnScript.Append($"    [{column.ColumnName}] {column.DataType}");

            if (column.MaxLength.HasValue && column.MaxLength > 0)
            {
                if (column.DataType.Contains("char", StringComparison.OrdinalIgnoreCase))
                {
                    columnScript.Append($"({(column.MaxLength == -1 ? "MAX" : column.MaxLength.ToString())})");
                }
            }
            else if (column.Precision.HasValue && column.Scale.HasValue)
            {
                columnScript.Append($"({column.Precision},{column.Scale})");
            }

            if (column.IsIdentity)
            {
                columnScript.Append(" IDENTITY(1,1)");
            }

            columnScript.Append(column.IsNullable ? " NULL" : " NOT NULL");

            if (!string.IsNullOrEmpty(column.DefaultValue))
            {
                columnScript.Append($" DEFAULT {column.DefaultValue}");
            }

            columnScripts.Add(columnScript.ToString());
        }

        script.AppendLine(string.Join(",\n", columnScripts));
        script.AppendLine(");");

        return script.ToString();
    }

    private static string GenerateCreateViewScript(ViewSchema view)
    {
        var script = new System.Text.StringBuilder();
        script.AppendLine($"-- View: {view.SchemaName}.{view.ViewName}");
        script.AppendLine($"-- Created: {view.CreatedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine($"-- Modified: {view.ModifiedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine();
        script.AppendLine(view.Definition);
        return script.ToString();
    }

    private static string GenerateCreateProcedureScript(ProcedureSchema procedure)
    {
        var script = new System.Text.StringBuilder();
        script.AppendLine($"-- Procedure: {procedure.SchemaName}.{procedure.ProcedureName}");
        script.AppendLine($"-- Created: {procedure.CreatedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine($"-- Modified: {procedure.ModifiedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine();
        script.AppendLine(procedure.Definition);
        return script.ToString();
    }
}
