namespace BkmArgus.Models;

/// <summary>
/// Kullanıcı modeli - giriş ve yetkilendirme için.
/// Şimdilik tüm kullanıcılar admin.
/// </summary>
public class User
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
