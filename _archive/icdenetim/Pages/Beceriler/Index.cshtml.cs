using BkmArgus.Models;
using BkmArgus.Repositories;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Beceriler;

public class IndexModel : PageModel
{
    private readonly ISkillRepository _repo;
    public IndexModel(ISkillRepository repo) => _repo = repo;

    public List<Skill> Skills { get; set; } = [];

    public async Task OnGetAsync()
    {
        Skills = (await _repo.GetAllAsync()).ToList();
    }
}
