using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages;

/// <summary>
/// Ana sayfa - giriş yapmışsa Denetimler'e, değilse Login'e yönlendirir.
/// </summary>
public class IndexModel : PageModel
{
    public IActionResult OnGet()
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToPage("/Dashboard/Index");
        return RedirectToPage("/Account/Login");
    }
}
