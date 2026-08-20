namespace BkmArgus.Web.Security;

/// <summary>
/// audit.Users.RoleCode degerleri. DB varsayilani: DENETCI (bkz. sql/35_migration_auth.sql).
/// </summary>
public static class Roles
{
    public const string Admin = "ADMIN";
    public const string Yonetici = "YONETICI";
    public const string Denetci = "DENETCI";
}

/// <summary>
/// Yetki politikalari. Sayfalarda: @attribute [Authorize(Policy = Policies.AdminOnly)]
/// </summary>
public static class Policies
{
    /// <summary>Sadece ADMIN — referans tanimlari, kullanici yonetimi, sistem ayarlari.</summary>
    public const string AdminOnly = "AdminOnly";

    /// <summary>ADMIN veya YONETICI — AI calistirma, korelasyon, maliyetli/kapsamli islemler.</summary>
    public const string YonetimVeUstu = "YonetimVeUstu";
}
