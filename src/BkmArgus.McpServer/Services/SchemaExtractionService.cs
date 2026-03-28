using Microsoft.Data.SqlClient;
using Dapper;
using BkmArgus.McpServer.Models;
using System.Text;

namespace BkmArgus.McpServer.Services;

public class SchemaExtractionService
{
    private readonly string _connectionString;
    private readonly ILogger<SchemaExtractionService> _logger;

    public SchemaExtractionService(IConfiguration configuration, ILogger<SchemaExtractionService> logger)
    {
        var envConn = configuration["BKM_DENETIM_CONN"];
        var appConn = configuration.GetConnectionString("BkmDenetim");
        
        if (!string.IsNullOrWhiteSpace(envConn))
        {
            _connectionString = envConn;
        }
        else if (!string.IsNullOrWhiteSpace(appConn))
        {
            _connectionString = appConn;
        }
        else
        {
            throw new InvalidOperationException("BKM_DENETIM_CONN veya ConnectionStrings:BkmDenetim tanımlı değil.");
        }
        
        _logger = logger;
    }

    public async Task<List<TableDefinition>> ExtractTablesAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var tablesQuery = @"
            SELECT 
                s.name as SchemaName,
                t.name as TableName,
                t.create_date as CreatedDate,
                t.modify_date as ModifiedDate
            FROM sys.tables t
            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
            WHERE t.is_ms_shipped = 0
            ORDER BY s.name, t.name";

        var tables = await connection.QueryAsync<TableDefinition>(tablesQuery);
        var tableList = tables.ToList();

        // Her tablo için kolon bilgilerini al
        foreach (var table in tableList)
        {
            table.Columns = await GetTableColumnsAsync(connection, table.SchemaName, table.TableName);
            table.Indexes = await GetTableIndexesAsync(connection, table.SchemaName, table.TableName);
            table.Constraints = await GetTableConstraintsAsync(connection, table.SchemaName, table.TableName);
            table.CreateScript = GenerateCreateTableScript(table);
        }

        return tableList;
    }

    public async Task<List<ViewDefinition>> ExtractViewsAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var viewsQuery = @"
            SELECT 
                s.name as SchemaName,
                v.name as ViewName,
                v.create_date as CreatedDate,
                v.modify_date as ModifiedDate,
                m.definition as Definition
            FROM sys.views v
            INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
            INNER JOIN sys.sql_modules m ON v.object_id = m.object_id
            WHERE v.is_ms_shipped = 0
            ORDER BY s.name, v.name";

        var views = await connection.QueryAsync<ViewDefinition>(viewsQuery);
        var viewList = views.ToList();

        // Her view için CREATE script oluştur
        foreach (var view in viewList)
        {
            view.CreateScript = GenerateCreateViewScript(view);
        }

        return viewList;
    }

    public async Task<List<ProcedureDefinition>> ExtractProceduresAsync()
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var proceduresQuery = @"
            SELECT 
                s.name as SchemaName,
                p.name as ProcedureName,
                p.create_date as CreatedDate,
                p.modify_date as ModifiedDate,
                m.definition as Definition
            FROM sys.procedures p
            INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
            INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
            WHERE p.is_ms_shipped = 0
            ORDER BY s.name, p.name";

        var procedures = await connection.QueryAsync<ProcedureDefinition>(proceduresQuery);
        var procedureList = procedures.ToList();

        // Her procedure için parametre bilgilerini al ve CREATE script oluştur
        foreach (var procedure in procedureList)
        {
            procedure.Parameters = await GetProcedureParametersAsync(connection, procedure.SchemaName, procedure.ProcedureName);
            procedure.CreateScript = GenerateCreateProcedureScript(procedure);
        }

        return procedureList;
    }

    private async Task<List<ColumnDefinition>> GetTableColumnsAsync(SqlConnection connection, string schemaName, string tableName)
    {
        var query = @"
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

        var columns = await connection.QueryAsync<ColumnDefinition>(query, new { SchemaName = schemaName, TableName = tableName });
        return columns.ToList();
    }

    private async Task<List<IndexDefinition>> GetTableIndexesAsync(SqlConnection connection, string schemaName, string tableName)
    {
        var query = @"
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

        var indexes = await connection.QueryAsync<dynamic>(query, new { SchemaName = schemaName, TableName = tableName });
        
        return indexes.Select(idx => new IndexDefinition
        {
            IndexName = idx.IndexName,
            IndexType = idx.IndexType,
            IsUnique = idx.IsUnique,
            IsPrimaryKey = idx.IsPrimaryKey,
            Columns = idx.Columns?.Split(", ", StringSplitOptions.RemoveEmptyEntries).ToList() ?? new List<string>()
        }).ToList();
    }

    private async Task<List<ConstraintDefinition>> GetTableConstraintsAsync(SqlConnection connection, string schemaName, string tableName)
    {
        var query = @"
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

        var constraints = await connection.QueryAsync<dynamic>(query, new { SchemaName = schemaName, TableName = tableName });
        
        return constraints.Select(c => new ConstraintDefinition
        {
            ConstraintName = c.ConstraintName,
            ConstraintType = c.ConstraintType,
            Definition = c.Definition ?? string.Empty,
            Columns = c.Columns?.Split(", ", StringSplitOptions.RemoveEmptyEntries).ToList() ?? new List<string>()
        }).ToList();
    }

    private async Task<List<ParameterDefinition>> GetProcedureParametersAsync(SqlConnection connection, string schemaName, string procedureName)
    {
        var query = @"
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

        var parameters = await connection.QueryAsync<ParameterDefinition>(query, new { SchemaName = schemaName, ProcedureName = procedureName });
        return parameters.ToList();
    }

    private string GenerateCreateTableScript(TableDefinition table)
    {
        var script = new StringBuilder();
        script.AppendLine($"-- Tablo: {table.SchemaName}.{table.TableName}");
        script.AppendLine($"-- Oluşturma Tarihi: {table.CreatedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine($"-- Son Değişiklik: {table.ModifiedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine();
        script.AppendLine($"CREATE TABLE [{table.SchemaName}].[{table.TableName}] (");

        var columnScripts = new List<string>();
        foreach (var column in table.Columns.OrderBy(c => c.OrdinalPosition))
        {
            var columnScript = new StringBuilder();
            columnScript.Append($"    [{column.ColumnName}] {column.DataType}");

            // Veri tipi uzunluğu
            if (column.MaxLength.HasValue && column.MaxLength > 0)
            {
                if (column.DataType.ToLower().Contains("char"))
                {
                    columnScript.Append($"({(column.MaxLength == -1 ? "MAX" : column.MaxLength.ToString())})");
                }
            }
            else if (column.Precision.HasValue && column.Scale.HasValue)
            {
                columnScript.Append($"({column.Precision},{column.Scale})");
            }

            // Identity
            if (column.IsIdentity)
            {
                columnScript.Append(" IDENTITY(1,1)");
            }

            // Null/Not Null
            columnScript.Append(column.IsNullable ? " NULL" : " NOT NULL");

            // Default değer
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

    private string GenerateCreateViewScript(ViewDefinition view)
    {
        var script = new StringBuilder();
        script.AppendLine($"-- View: {view.SchemaName}.{view.ViewName}");
        script.AppendLine($"-- Oluşturma Tarihi: {view.CreatedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine($"-- Son Değişiklik: {view.ModifiedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine();
        script.AppendLine(view.Definition);

        return script.ToString();
    }

    private string GenerateCreateProcedureScript(ProcedureDefinition procedure)
    {
        var script = new StringBuilder();
        script.AppendLine($"-- Stored Procedure: {procedure.SchemaName}.{procedure.ProcedureName}");
        script.AppendLine($"-- Oluşturma Tarihi: {procedure.CreatedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine($"-- Son Değişiklik: {procedure.ModifiedDate:yyyy-MM-dd HH:mm:ss}");
        script.AppendLine();
        script.AppendLine(procedure.Definition);

        return script.ToString();
    }
}
