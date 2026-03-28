using SchemaManagement.Library.Models;

namespace SchemaManagement.Library.Interfaces;

public interface IComparisonService
{
    Task<ComparisonResult> CompareSchemaWithFilesAsync(DatabaseSchema currentSchema, string filesPath);
    Task<List<SchemaDifference>> IdentifyDifferencesAsync(DatabaseSchema current, DatabaseSchema fromFiles);
}
