using BkmArgus.Models;

namespace BkmArgus.Services;

/// <summary>
/// Finding servisi - AuditResult'lari zenginlestirerek Finding olarak sunar.
/// Mevcut tablolardan JOIN ile veri toplar, yeni tablo gerektirmez.
/// </summary>
public interface IFindingsService
{
    /// <summary>Tek bir bulguyu zenginlestirerek doner.</summary>
    Task<Finding?> GetByIdAsync(int auditResultId);

    /// <summary>Bir denetimin tum bulgularini (gecen+kalan) doner.</summary>
    Task<List<Finding>> GetByAuditIdAsync(int auditId);

    /// <summary>Bir denetimin sadece basarisiz bulgularini doner.</summary>
    Task<List<Finding>> GetFailedByAuditIdAsync(int auditId);

    /// <summary>Tekrarlayan bulgulari doner (tum denetimler genelinde).</summary>
    Task<List<Finding>> GetRepeatingAsync(int minRepeat = 2);

    /// <summary>Sistemik sorunlari doner (3+ lokasyonda tekrar).</summary>
    Task<List<Finding>> GetSystemicAsync();

    /// <summary>Yuksek riskli bulgulari doner (eskalasyon sonrasi).</summary>
    Task<List<Finding>> GetHighRiskAsync(double minEscalatedScore = 15);

    /// <summary>Etkisiz DOF'u olan bulgulari doner.</summary>
    Task<List<Finding>> GetWithIneffectiveDofAsync();
}
