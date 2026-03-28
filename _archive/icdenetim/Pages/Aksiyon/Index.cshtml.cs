using BkmArgus.Models;
using BkmArgus.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Aksiyon;

public class IndexModel : PageModel
{
    private readonly ICorrectiveActionRepository _repo;
    public IndexModel(ICorrectiveActionRepository repo) => _repo = repo;

    [BindProperty(SupportsGet = true)]
    public string? Filter { get; set; }

    public List<CorrectiveAction> Actions { get; set; } = [];

    public async Task OnGetAsync()
    {
        Actions = Filter switch
        {
            "overdue" => (await _repo.GetOverdueAsync()).ToList(),
            "all" => (await _repo.GetOpenAsync()).Concat(await _repo.GetOverdueAsync()).ToList(),
            _ => (await _repo.GetOpenAsync()).ToList()
        };
    }
}
