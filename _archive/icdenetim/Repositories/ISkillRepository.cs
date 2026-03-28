using BkmArgus.Models;

namespace BkmArgus.Repositories;

public interface ISkillRepository
{
    Task<IEnumerable<Skill>> GetAllAsync();
    Task<Skill?> GetByIdAsync(int id);
    Task<IEnumerable<Skill>> GetActiveAsync();
    Task<int> CreateAsync(Skill skill);
    Task UpdateAsync(Skill skill);
    Task<IEnumerable<SkillVersion>> GetVersionsAsync(int skillId);

    /// <summary>Bir skill'in su an gecerli olan versiyonunu doner.</summary>
    Task<SkillVersion?> GetActiveVersionAsync(int skillId);
}
