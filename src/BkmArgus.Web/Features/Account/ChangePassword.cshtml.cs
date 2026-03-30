using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Services;

namespace BkmArgus.Web.Features.Account;

[Authorize]
public class ChangePasswordModel : PageModel
{
    private readonly AuthService _auth;
    public ChangePasswordModel(AuthService auth) => _auth = auth;

    [BindProperty] public string CurrentPassword { get; set; } = "";
    [BindProperty] public string NewPassword { get; set; } = "";
    [BindProperty] public string ConfirmPassword { get; set; } = "";
    [BindProperty(SupportsGet = true)] public bool First { get; set; }
    public string? Error { get; private set; }
    public string? Success { get; private set; }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        if (string.IsNullOrWhiteSpace(CurrentPassword) || string.IsNullOrWhiteSpace(NewPassword))
        {
            Error = "Tum alanlar zorunludur.";
            return Page();
        }

        if (NewPassword.Length < 6)
        {
            Error = "Yeni sifre en az 6 karakter olmalidir.";
            return Page();
        }

        if (NewPassword != ConfirmPassword)
        {
            Error = "Yeni sifreler eslesmiyor.";
            return Page();
        }

        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(userIdStr, out var userId))
        {
            Error = "Oturum hatasi.";
            return Page();
        }

        var ok = await _auth.ChangePasswordAsync(userId, CurrentPassword, NewPassword);
        if (!ok)
        {
            Error = "Mevcut sifre hatali.";
            return Page();
        }

        if (First)
            return RedirectToPage("/Index");

        Success = "Sifre basariyla degistirildi.";
        return Page();
    }
}
