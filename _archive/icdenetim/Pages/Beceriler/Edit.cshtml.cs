using System.ComponentModel.DataAnnotations;
using BkmArgus.Models;
using BkmArgus.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Beceriler;

public class EditModel : PageModel
{
    private readonly ISkillRepository _repo;
    public EditModel(ISkillRepository repo) => _repo = repo;

    [BindProperty(SupportsGet = true)]
    public int Id { get; set; }

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

    public async Task<IActionResult> OnGetAsync()
    {
        var skill = await _repo.GetByIdAsync(Id);
        if (skill == null) return NotFound();

        Input = new InputModel
        {
            Code = skill.Code,
            Name = skill.Name,
            Department = skill.Department,
            Description = skill.Description,
            IsActive = skill.IsActive
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var skill = await _repo.GetByIdAsync(Id);
        if (skill == null) return NotFound();

        skill.Code = Input.Code.ToUpperInvariant();
        skill.Name = Input.Name;
        skill.Department = Input.Department;
        skill.Description = Input.Description;
        skill.IsActive = Input.IsActive;

        await _repo.UpdateAsync(skill);
        return RedirectToPage("Index");
    }
}
