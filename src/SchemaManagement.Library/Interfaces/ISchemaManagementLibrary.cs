using SchemaManagement.Library.Models;

namespace SchemaManagement.Library.Interfaces;

public interface ISchemaManagementLibrary
{
    Task InitializeAsync(string connectionString, SchemaManagementOptions options);

    Task<DatabaseSchema> GetDatabaseSchemaAsync();
    Task<TableSchema> GetTableSchemaAsync(string schema, string tableName);
    Task<ViewSchema> GetViewSchemaAsync(string schema, string viewName);
    Task<ProcedureSchema> GetProcedureSchemaAsync(string schema, string procedureName);

    Task<ExportResult> ExportAllSchemaAsync(string outputPath);
    Task<ExportResult> ExportSelectedObjectsAsync(List<DatabaseObject> objects, string outputPath);
    Task<byte[]> ExportSchemaAsZipAsync();

    Task<MigrationResult> ApplyMigrationsAsync(string migrationsPath);
    Task<List<AppliedMigration>> GetAppliedMigrationsAsync();
    Task<List<string>> GetPendingMigrationsAsync(string migrationsPath);

    Task<ComparisonResult> CompareWithFilesAsync(string sqlFilesPath);
    Task<List<SchemaDifference>> GetSchemaDifferencesAsync(string sqlFilesPath);
}
