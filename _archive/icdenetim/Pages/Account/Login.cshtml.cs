using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Dapper;
using BkmArgus.Data;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Pages.Account;

/// <summary>
/// Giriş sayfası - Cookie auth ile session başlatır.
/// </summary>
public class LoginModel : PageModel
{
    private readonly IConfiguration _config;

    public LoginModel(IConfiguration config) => _config = config;

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required(ErrorMessage = "E-posta gerekli")]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Şifre gerekli")]
        [DataType(DataType.Password)]
        public string Password { get; set; } = string.Empty;
    }

    public IActionResult OnGet()
    {
        // Zaten giriş yapmışsa ana sayfaya yönlendir
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToPage("/Denetimler/Index");
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        try
        {
            // Kullanıcıyı DB'den kontrol et (bcrypt ile şifre karşılaştırma)
            using var conn = DbConnectionFactory.Create(_config);
            var user = await conn.QuerySingleOrDefaultAsync<UserDto>(
            "SELECT Id, Email, PasswordHash, FullName FROM Users WHERE Email = @Email",
            new { Input.Email });

        if (user == null || !BCrypt.Net.BCrypt.Verify(Input.Password, user.PasswordHash))
        {
            ModelState.AddModelError(string.Empty, "Geçersiz e-posta veya şifre.");
            return Page();
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Name, user.FullName)
        };

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        var principal = new ClaimsPrincipal(identity);
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);

            return RedirectToPage("/Denetimler/Index");
        }
        catch (SqlException ex) when (ex.Number == 208)
        {
            // Users tablosu yok - veritabanı kurulmamış, Setup sayfasına yönlendir
            return RedirectToPage("/Account/Setup");
        }
    }

    private record UserDto(int Id, string Email, string PasswordHash, string FullName);
}
