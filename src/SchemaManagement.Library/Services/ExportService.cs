using SchemaManagement.Library.Interfaces;
using SchemaManagement.Library.Models;
using System.IO.Compression;
using System.Text.Json;

namespace SchemaManagement.Library.Services;

public sealed class ExportService : IExportService
{
    public async Task<ExportResult> ExportToFilesAsync(DatabaseSchema schema, string outputPath)
    {
        if (schema is null)
        {
            throw new ArgumentNullException(nameof(schema));
        }

        if (string.IsNullOrWhiteSpace(outputPath))
        {
            throw new ArgumentException("Output path is required.", nameof(outputPath));
        }

        var start = DateTime.UtcNow;
        Directory.CreateDirectory(outputPath);

        var fileName = string.IsNullOrWhiteSpace(schema.Name) ? "schema.json" : $"{schema.Name}.schema.json";
        var filePath = Path.Combine(outputPath, fileName);
        var json = JsonSerializer.Serialize(schema, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(filePath, json);

        var fileInfo = new FileInfo(filePath);
        return new ExportResult
        {
            Success = true,
            Message = "Schema exported as JSON.",
            ExportedFiles = new List<string> { filePath },
            ExecutionTime = DateTime.UtcNow - start,
            TotalSizeBytes = fileInfo.Exists ? fileInfo.Length : 0
        };
    }

    public Task<byte[]> CreateZipArchiveAsync(Dictionary<string, string> files)
    {
        if (files is null)
        {
            throw new ArgumentNullException(nameof(files));
        }

        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            foreach (var entry in files)
            {
                var zipEntry = archive.CreateEntry(entry.Key, CompressionLevel.Optimal);
                using var entryStream = zipEntry.Open();
                using var writer = new StreamWriter(entryStream);
                writer.Write(entry.Value);
            }
        }

        return Task.FromResult(stream.ToArray());
    }

    public Task<string> OrganizeScriptsByTypeAsync(List<DatabaseObject> objects)
    {
        return Task.FromResult(string.Empty);
    }
}
