namespace BkmArgus.Models;

/// <summary>
/// Denetim yetkinliği tanımı (Mağaza Denetimi, Depo Denetimi vb.).
/// Her skill'in birden fazla versiyonu olabilir.
/// </summary>
public class Skill
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string Department { get; set; } = "";
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// Skill versiyonu - risk kuralları ve AI prompt context'i tutar.
/// Geçerlilik tarihleri ile hangi versiyonun aktif olduğu belirlenir.
/// </summary>
public class SkillVersion
{
    public int Id { get; set; }
    public int SkillId { get; set; }
    public int VersionNo { get; set; }
    public DateTime EffectiveFrom { get; set; }
    public DateTime? EffectiveTo { get; set; }
    public string? RiskRules { get; set; }
    public string? AiPromptContext { get; set; }
    public int? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
