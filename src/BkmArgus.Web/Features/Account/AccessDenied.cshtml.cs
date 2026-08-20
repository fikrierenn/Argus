using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features.Account;

public class AccessDeniedModel : PageModel
{
    public string RoleCode { get; private set; } = "-";

    public void OnGet()
    {
        RoleCode = User.FindFirstValue(ClaimTypes.Role) ?? "-";
    }
}
