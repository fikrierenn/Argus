using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Services;

namespace BkmArgus.Web.Features.Account;

public class LogoutModel : PageModel
{
    private readonly AuthService _auth;
    public LogoutModel(AuthService auth) => _auth = auth;

    public async Task<IActionResult> OnGetAsync()
    {
        await _auth.LogoutAsync(HttpContext);
        return RedirectToPage("/Account/Login");
    }
}
