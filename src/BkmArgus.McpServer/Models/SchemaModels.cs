using BkmArgus.McpServer.Services;

namespace BkmArgus.McpServer.Models;

public class TableDefinition
{
    public string SchemaName { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public List<ColumnDefinition> Columns { get; set; } = new();
    public List<IndexDefinition> Indexes { get; set; } = new();
    public List<ConstraintDefinition> Constraints { get; set; } = new();
    public string CreateScript { get; set; } = string.Empty;
    public DateTime CreatedDate { get; set; }
    public DateTime ModifiedDate { get; set; }
}

public class ColumnDefinition
{
    public string ColumnName { get; set; } = string.Empty;
    public string DataType { get; set; } = string.Empty;
    public int? MaxLength { get; set; }
    public int? Precision { get; set; }
    public int? Scale { get; set; }
    public bool IsNullable { get; set; }
    public string? DefaultValue { get; set; }
    public bool IsIdentity { get; set; }
    public bool IsPrimaryKey { get; set; }
    public int OrdinalPosition { get; set; }
}

public class IndexDefinition
{
    public string IndexName { get; set; } = string.Empty;
    public string IndexType { get; set; } = string.Empty;
    public bool IsUnique { get; set; }
    public bool IsPrimaryKey { get; set; }
    public List<string> Columns { get; set; } = new();
}

public class ConstraintDefinition
{
    public string ConstraintName { get; set; } = string.Empty;
    public string ConstraintType { get; set; } = string.Empty;
    public string Definition { get; set; } = string.Empty;
    public List<string> Columns { get; set; } = new();
}

public class ViewDefinition
{
    public string SchemaName { get; set; } = string.Empty;
    public string ViewName { get; set; } = string.Empty;
    public string Definition { get; set; } = string.Empty;
    public string CreateScript { get; set; } = string.Empty;
    public DateTime CreatedDate { get; set; }
    public DateTime ModifiedDate { get; set; }
}

public class ProcedureDefinition
{
    public string SchemaName { get; set; } = string.Empty;
    public string ProcedureName { get; set; } = string.Empty;
    public string Definition { get; set; } = string.Empty;
    public List<ParameterDefinition> Parameters { get; set; } = new();
    public string CreateScript { get; set; } = string.Empty;
    public DateTime CreatedDate { get; set; }
    public DateTime ModifiedDate { get; set; }
}

public class ParameterDefinition
{
    public string ParameterName { get; set; } = string.Empty;
    public string DataType { get; set; } = string.Empty;
    public int? MaxLength { get; set; }
    public bool IsOutput { get; set; }
    public string? DefaultValue { get; set; }
    public int OrdinalPosition { get; set; }
}

public class SchemaComparisonResult
{
    public List<DatabaseObject> NewObjects { get; set; } = new();
    public List<DatabaseObject> ModifiedObjects { get; set; } = new();
    public List<DatabaseObject> DeletedObjects { get; set; } = new();
    public DateTime ComparisonDate { get; set; } = DateTime.Now;
    public string Summary { get; set; } = string.Empty;
}

public class SchemaExtractionResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public int ObjectCount { get; set; }
    public TimeSpan ExecutionTime { get; set; }
    public List<string> Errors { get; set; } = new();
}
