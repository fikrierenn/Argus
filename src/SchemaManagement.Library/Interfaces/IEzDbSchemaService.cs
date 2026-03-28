using SchemaManagement.Library.Models;

namespace SchemaManagement.Library.Interfaces;

public interface IEzDbSchemaService
{
    Task<DatabaseSchema> ExtractSchemaAsync();
    Task<string> GenerateCreateScriptAsync(string schema, string objectName, string objectType);
    Task<List<TableInfo>> GetTablesAsync();
    Task<List<ViewInfo>> GetViewsAsync();
    Task<List<ProcedureInfo>> GetProceduresAsync();
}
