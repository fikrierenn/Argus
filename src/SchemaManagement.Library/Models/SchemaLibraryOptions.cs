namespace SchemaManagement.Library.Models;

public class SchemaLibraryOptions
{
    public string MigrationHistoryTable { get; set; } = "__MigrationHistory";
    public bool CreateMigrationHistoryIfNotExists { get; set; } = true;
    public int CommandTimeout { get; set; } = 30;
    public bool ValidateBeforeDeployment { get; set; } = true;
    public bool BackupBeforeDeployment { get; set; }
    public string? BackupDirectory { get; set; }
}
