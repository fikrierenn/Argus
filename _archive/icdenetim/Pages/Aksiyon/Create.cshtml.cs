using System.ComponentModel.DataAnnotations;
using BkmArgus.Models;
using BkmArgus.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Aksiyon;

public class CreateModel : PageModel
{
    private readonly ICorrectiveActionRepository _repo;
    public CreateModel(ICorrectiveActionRepository repo) => _repo = repo;

    [BindProperty] public InputModel Input { get; set; } = new();
    [BindProperty(SupportsGet = true)] public int? AuditId { get; set; }
    [BindProperty(SupportsGet = true)] public int? AuditResultId { get; set; }

    public class InputModel
    {
        [Required(ErrorMessage = "Baslik zorunludur.")]
        public string Title { get; set; } = "";
        [Required(ErrorMessage = "Aciklama zorunludur.")]
        public string Description { get; set; } = "";
        public string? RootCause { get; set; }
        public string Type { get; set; } = "Corrective";
        public string Priority { get; set; } = "Medium";
        public string? Department { get; set; }
        [Required(ErrorMessage = "Bitis tarihi zorunludur.")]
        public DateTime DueDate { get; set; } = DateTime.Today.AddDays(30);
    }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var action = new CorrectiveAction
        {
            AuditResultId = AuditResultId ?? 0,
            AuditId = AuditId ?? 0,
            Title = Input.Title,
            Description = Input.Description,
            RootCause = Input.RootCause,
            Type = Input.Type,
            Priority = Input.Priority,
            Department = Input.Department,
            DueDate = Input.DueDate,
            Status = "Open"
        };

        var id = await _repo.CreateAsync(action);
        return RedirectToPage("Detail", new { id });
    }
}
