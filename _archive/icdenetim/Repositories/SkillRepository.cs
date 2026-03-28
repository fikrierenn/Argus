using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;

namespace BkmArgus.Repositories;

/// <summary>
/// Skills ve SkillVersions tabloları için Dapper repository.
/// </summary>
public class SkillRepository : ISkillRepository
{
    private readonly IConfiguration _config;

    public SkillRepository(IConfiguration config)
    {
        _config = config;
    }

    public async Task<IEnumerable<Skill>> GetAllAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QueryAsync<Skill>(
            "SELECT * FROM Skills ORDER BY Name");
    }

    public async Task<Skill?> GetByIdAsync(int id)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QuerySingleOrDefaultAsync<Skill>(
            "SELECT * FROM Skills WHERE Id = @Id", new { Id = id });
    }

    public async Task<IEnumerable<Skill>> GetActiveAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QueryAsync<Skill>(
            "SELECT * FROM Skills WHERE IsActive = 1 ORDER BY Name");
    }

    public async Task<int> CreateAsync(Skill skill)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QuerySingleAsync<int>(
            @"INSERT INTO Skills (Code, Name, Department, Description, IsActive)
              VALUES (@Code, @Name, @Department, @Description, @IsActive);
              SELECT CAST(SCOPE_IDENTITY() AS INT);", skill);
    }

    public async Task UpdateAsync(Skill skill)
    {
        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            @"UPDATE Skills
              SET Code = @Code, Name = @Name, Department = @Department,
                  Description = @Description, IsActive = @IsActive
              WHERE Id = @Id", skill);
    }

    public async Task<IEnumerable<SkillVersion>> GetVersionsAsync(int skillId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QueryAsync<SkillVersion>(
            "SELECT * FROM SkillVersions WHERE SkillId = @SkillId ORDER BY VersionNo DESC",
            new { SkillId = skillId });
    }

    public async Task<SkillVersion?> GetActiveVersionAsync(int skillId)
    {
        using var conn = DbConnectionFactory.Create(_config);
        return await conn.QuerySingleOrDefaultAsync<SkillVersion>(
            @"SELECT TOP 1 * FROM SkillVersions
              WHERE SkillId = @SkillId
                AND EffectiveFrom <= GETDATE()
                AND (EffectiveTo IS NULL OR EffectiveTo > GETDATE())
              ORDER BY VersionNo DESC",
            new { SkillId = skillId });
    }
}
