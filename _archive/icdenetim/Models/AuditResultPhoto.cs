namespace BkmArgus.Models;

/// <summary>
/// Denetim madde sonucuna eklenen fotoğraf.
/// </summary>
public class AuditResultPhoto
{
    public int Id { get; set; }
    public int AuditResultId { get; set; }
    public string FilePath { get; set; } = string.Empty;
    public string? Remark { get; set; }
    public DateTime CreatedAt { get; set; }
}
