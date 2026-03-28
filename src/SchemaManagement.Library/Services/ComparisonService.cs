using SchemaManagement.Library.Interfaces;
using SchemaManagement.Library.Models;

namespace SchemaManagement.Library.Services;

public sealed class ComparisonService : IComparisonService
{
    public Task<ComparisonResult> CompareSchemaWithFilesAsync(DatabaseSchema currentSchema, string filesPath)
    {
        return Task.FromResult(new ComparisonResult
        {
            Success = false,
            ComparisonDate = DateTime.UtcNow
        });
    }

    public Task<List<SchemaDifference>> IdentifyDifferencesAsync(DatabaseSchema current, DatabaseSchema fromFiles)
    {
        return Task.FromResult(new List<SchemaDifference>());
    }
}
