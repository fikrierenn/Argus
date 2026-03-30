using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Services;

namespace BkmArgus.Web.Features.Account;

public class LoginModel : PageModel
{
    private readonly AuthService _auth;
    public LoginModel(AuthService auth) => _auth = auth;

    [BindProperty] public string Username { get; set; } = "admin";
    [BindProperty] public string Password { get; set; } = "";
    public string? Error { get; private set; }
    [BindProperty(SupportsGet = true)] public string? ReturnUrl { get; set; }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        if (string.IsNullOrWhiteSpace(Username) || string.IsNullOrWhiteSpace(Password))
        {
            Error = "Kullanici adi ve sifre gereklidir.";
            return Page();
        }

        var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
        var ua = Request.Headers.UserAgent.ToString();

        var result = await _auth.LoginAsync(HttpContext, Username.Trim(), Password, ip, ua);
        if (!result.Success)
        {
            Error = result.Error;
            return Page();
        }

        if (result.MustChangePassword)
            return RedirectToPage("/Account/ChangePassword", new { first = true });

        return LocalRedirect(ReturnUrl ?? "/");
    }
}
