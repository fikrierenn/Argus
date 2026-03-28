namespace BkmArgus.Models;

/// <summary>
/// Düzeltici/Önleyici Faaliyet (DOF) kaydı.
/// Denetim bulgularına karşı açılan aksiyonları takip eder.
/// </summary>
public class CorrectiveAction
{
    public int Id { get; set; }
    public int AuditResultId { get; set; }
    public int AuditId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? RootCause { get; set; }
    public string Type { get; set; } = "Corrective";           // Corrective, Preventive
    public int? AssignedToUserId { get; set; }
    public string? Department { get; set; }
    public DateTime DueDate { get; set; }
    public string Priority { get; set; } = "Medium";           // Low, Medium, High, Critical
    public string Status { get; set; } = "Open";               // Open, InProgress, PendingValidation, Closed, Rejected
    public DateTime? ClosedAt { get; set; }
    public int? ClosedBy { get; set; }
    public string? ClosureNote { get; set; }
    public bool AiGenerated { get; set; }
    public decimal? AiConfidence { get; set; }
    public DateTime CreatedAt { get; set; }

    // DOF Etkinlik alanlari
    /// <summary>DOF etkili oldu mu? null=henuz degerlendirilmedi, true=etkili, false=etkisiz (sorun tekrarladi).</summary>
    public bool? IsEffective { get; set; }
    /// <summary>Etkinlik skoru: 1.0=tam etkili, 0.0=tamamen etkisiz. Her tekrarda -0.25.</summary>
    public decimal? EffectivenessScore { get; set; }
    /// <summary>Etkinlik degerlendirme notu.</summary>
    public string? EffectivenessNote { get; set; }

    /// <summary>Vadesi geçmiş ve henüz kapatılmamış mı?</summary>
    public bool IsOverdue => DueDate.Date < DateTime.Today
                             && Status != "Closed"
                             && Status != "Rejected";
}
