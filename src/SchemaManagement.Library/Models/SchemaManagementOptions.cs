namespace SchemaManagement.Library.Models;

public class SchemaManagementOptions
{
    public string MigrationHistoryTable { get; set; } = "SchemaVersions";
    public bool CreateDatabaseIfNotExists { get; set; }
    public int CommandTimeout { get; set; } = 30;
    public bool EnableLogging { get; set; } = true;
    public string LogLevel { get; set; } = "Information";
}
