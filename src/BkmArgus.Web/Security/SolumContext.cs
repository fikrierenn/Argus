using System.Security.Claims;
using Solum.Abstractions;

namespace BkmArgus.Web.Security;

/// <summary>
/// Solum'un "bu islemi kim yapti" sorusunu BkmArgus cerez kimliginden cevaplar.
/// Solum.Identity ALINMADIGI icin bu adaptor zorunlu (plan: 04).
/// </summary>
public sealed class ArgusCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    /// <inheritdoc />
    public string? UserId => accessor.HttpContext?.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

    /// <inheritdoc />
    public string? UserName => accessor.HttpContext?.User.Identity?.Name;

    /// <inheritdoc />
    public bool IsAuthenticated => accessor.HttpContext?.User.Identity?.IsAuthenticated == true;
}

/// <summary>
/// Zaman kaynagi. BkmArgus YEREL saat kullanir (DB tarafinda SYSDATETIME()),
/// bu yuzden UtcNow degil Now (csharp-conventions.md).
/// </summary>
public sealed class ArgusClock : IClock
{
    /// <summary>
    /// Su an — offset TASIYAN tek sekil (Solum 2026-09 sozlesmesi).
    ///
    /// Solum `IClock.Now`'u `DateTime`'dan `DateTimeOffset`'e cevirdi: iki ayri
    /// sekil (Now + OffsetNow) tuketiciye "hangisi dogru" sorusunu biraktigi
    /// icin tek sekle indirildi. BkmArgus YEREL saat kullanir (DB tarafinda
    /// SYSDATETIME()), o yuzden kaynak `DateTimeOffset.Now`; yerel gereken
    /// yerde `.LocalDateTime` okunur.
    /// </summary>
    public DateTimeOffset Now => DateTimeOffset.Now;
}

/// <summary>
/// BkmArgus tek tuzel kisilik icin calisir — sirket boyutu YOK.
///
/// Is kurali: uydurma bir kimlik (ornegin 1) dondurmek yanlis olurdu; Solum
/// tarafinda "sirket secili" gorunur ve satir suzmesi anlamli sanilirdi.
/// Null = "sirket kavrami yok" durustur ve sirket secici partial'i (secenek
/// listesi verilmedigi icin) hic gorunmez.
/// </summary>
public sealed class ArgusCurrentCompany : ICurrentCompany
{
    /// <inheritdoc />
    public int? CompanyId => null;

    /// <inheritdoc />
    public bool IsCrossCompany => false;
}
