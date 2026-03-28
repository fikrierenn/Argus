using SchemaManagement.Library.Models;

namespace SchemaManagement.Library.Interfaces;

public interface IExportService
{
    Task<ExportResult> ExportToFilesAsync(DatabaseSchema schema, string outputPath);
    Task<byte[]> CreateZipArchiveAsync(Dictionary<string, string> files);
    Task<string> OrganizeScriptsByTypeAsync(List<DatabaseObject> objects);
}
