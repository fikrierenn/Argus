namespace BkmArgus.Models;

/// <summary>
/// Denetim kaydı - lokasyon, tarih, denetçi bilgileri.
/// </summary>
public class Audit
{
    public int Id { get; set; }
    public string LocationName { get; set; } = string.Empty;
    public string LocationType { get; set; } = string.Empty;
    public DateTime AuditDate { get; set; }
    public DateTime ReportDate { get; set; }
    public string ReportNo { get; set; } = string.Empty;
    public int AuditorId { get; set; }
    public string? Manager { get; set; }
    public string? Directorate { get; set; }
    public DateTime CreatedAt { get; set; }
    /// <summary>Denetim kesinleştirildi mi - kesinleşince raporlar otomatik oluşur.</summary>
    public bool IsFinalized { get; set; }
    /// <summary>Kesinleştirme tarihi.</summary>
    public DateTime? FinalizedAt { get; set; }
}
