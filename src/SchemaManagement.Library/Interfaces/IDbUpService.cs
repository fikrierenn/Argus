using DbUp.Engine;

namespace SchemaManagement.Library.Interfaces;

public interface IDbUpService
{
    Task<DatabaseUpgradeResult> PerformUpgradeAsync(string scriptsPath);
    Task<List<string>> GetExecutedScriptsAsync();
    Task<bool> IsUpgradeRequiredAsync(string scriptsPath);
    Task CreateDatabaseIfNotExistsAsync();
}
