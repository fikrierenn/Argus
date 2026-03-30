using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Services;

public class AuthService
{
    private readonly SqlDb _db;

    public AuthService(SqlDb db) => _db = db;

    public async Task<AuthResult> LoginAsync(HttpContext httpContext, string username, string password, string? ipAddress, string? userAgent)
    {
        var user = await _db.QuerySingleAsync<UserRow>("audit.sp_Auth_Login", new { Username = username, IpAddress = ipAddress, UserAgent = userAgent });

        if (user is null)
            return AuthResult.Fail("Kullanici bulunamadi.");

        if (user.IsLocked)
            return AuthResult.Fail("Hesap kilitlendi. Yonetici ile iletisime gecin.");

        if (!BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
        {
            await _db.ExecuteAsync("audit.sp_Auth_LoginFail", new { UserId = user.Id, IpAddress = ipAddress, UserAgent = userAgent, Reason = "Yanlis sifre" });
            return AuthResult.Fail("Sifre hatali.");
        }

        // Success
        await _db.ExecuteAsync("audit.sp_Auth_LoginSuccess", new { UserId = user.Id, IpAddress = ipAddress, UserAgent = userAgent });

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Username ?? ""),
            new("FullName", user.FullName ?? ""),
            new(ClaimTypes.Email, user.Email ?? ""),
            new(ClaimTypes.Role, user.RoleCode ?? "DENETCI")
        };

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        var principal = new ClaimsPrincipal(identity);

        await httpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, new AuthenticationProperties
        {
            IsPersistent = true,
            ExpiresUtc = DateTimeOffset.UtcNow.AddDays(7)
        });

        return AuthResult.Ok(user);
    }

    public async Task LogoutAsync(HttpContext httpContext)
    {
        await httpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    }

    public async Task<bool> ChangePasswordAsync(int userId, string currentPassword, string newPassword)
    {
        var user = await _db.QuerySingleAsync<UserRow>("audit.sp_Auth_GetUser", new { UserId = userId });
        if (user is null || !BCrypt.Net.BCrypt.Verify(currentPassword, user.PasswordHash))
            return false;

        var hash = BCrypt.Net.BCrypt.HashPassword(newPassword, 11);
        await _db.ExecuteAsync("audit.sp_Auth_ChangePassword", new { UserId = userId, NewPasswordHash = hash });
        return true;
    }

    public sealed record UserRow
    {
        public int Id { get; init; }
        public string? Username { get; init; }
        public string? FullName { get; init; }
        public string? Email { get; init; }
        public string? PasswordHash { get; init; }
        public string? RoleCode { get; init; }
        public bool IsLocked { get; init; }
        public int FailedLoginCount { get; init; }
        public bool MustChangePassword { get; init; }
    }

    public record AuthResult(bool Success, string? Error, UserRow? User, bool MustChangePassword = false)
    {
        public static AuthResult Ok(UserRow user) => new(true, null, user, user.MustChangePassword);
        public static AuthResult Fail(string error) => new(false, error, null);
    }
}
