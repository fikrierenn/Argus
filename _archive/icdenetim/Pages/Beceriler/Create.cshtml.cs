using System.ComponentModel.DataAnnotations;
using BkmArgus.Models;
using BkmArgus.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Beceriler;

public class CreateModel : PageModel
{
    private readonly ISkillRepository _repo;
    public CreateModel(ISkillRepository repo) => _repo = repo;

    [BindProperty] public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required(ErrorMessage = "Kod zorunludur.")]
        public string Code { get; set; } = "";

        [Required(ErrorMessage = "Ad zorunludur.")]
        public string Name { get; set; } = "";

        [Required(ErrorMessage = "Departman zorunludur.")]
        public string Department { get; set; } = "";

        public string? Description { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var skill = new Skill
        {
            Code = Input.Code.ToUpperInvariant(),
            Name = Input.Name,
            Department = Input.Department,
            Description = Input.Description,
            IsActive = Input.IsActive
        };

        await _repo.CreateAsync(skill);
        return RedirectToPage("Index");
    }
}
