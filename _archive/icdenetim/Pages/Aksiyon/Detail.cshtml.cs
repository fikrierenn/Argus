using System.Security.Claims;
using BkmArgus.Models;
using BkmArgus.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Aksiyon;

public class DetailModel : PageModel
{
    private readonly ICorrectiveActionRepository _repo;
    public DetailModel(ICorrectiveActionRepository repo) => _repo = repo;

    [BindProperty(SupportsGet = true)] public int Id { get; set; }
    public CorrectiveAction? Action { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        Action = await _repo.GetByIdAsync(Id);
        return Action == null ? NotFound() : Page();
    }

    public async Task<IActionResult> OnPostStartAsync()
    {
        await _repo.UpdateStatusAsync(Id, "InProgress", null);
        return RedirectToPage("Detail", new { id = Id });
    }

    public async Task<IActionResult> OnPostValidateAsync()
    {
        await _repo.UpdateStatusAsync(Id, "PendingValidation", null);
        return RedirectToPage("Detail", new { id = Id });
    }

    public async Task<IActionResult> OnPostCloseAsync(string? closureNote)
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
        await _repo.CloseAsync(Id, userId, closureNote ?? "");
        return RedirectToPage("Detail", new { id = Id });
    }

    public async Task<IActionResult> OnPostRejectAsync(string? note)
    {
        await _repo.UpdateStatusAsync(Id, "Rejected", note);
        return RedirectToPage("Detail", new { id = Id });
    }
}
