namespace SchemaManagement.Library.Models;

public class ExportResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public List<string> ExportedFiles { get; set; } = new();
    public List<string> Errors { get; set; } = new();
    public TimeSpan ExecutionTime { get; set; }
    public long TotalSizeBytes { get; set; }
}

public class MigrationResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public List<string> AppliedScripts { get; set; } = new();
    public List<string> Errors { get; set; } = new();
    public TimeSpan ExecutionTime { get; set; }
}

public class ComparisonResult
{
    public bool Success { get; set; }
    public List<SchemaDifference> NewObjects { get; set; } = new();
    public List<SchemaDifference> ModifiedObjects { get; set; } = new();
    public List<SchemaDifference> DeletedObjects { get; set; } = new();
    public int TotalDifferences { get; set; }
    public DateTime ComparisonDate { get; set; }
}

public class SchemaDifference
{
    public string ObjectType { get; set; } = string.Empty;
    public string SchemaName { get; set; } = string.Empty;
    public string ObjectName { get; set; } = string.Empty;
    public string DifferenceType { get; set; } = string.Empty;
    public string? CurrentDefinition { get; set; }
    public string? FileDefinition { get; set; }
}
