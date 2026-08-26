namespace BkmArgus.Web.Domain;

/// <summary>
/// DÖF durum kodları — `dof.StatusRules` sözleşmesinin C# karşılığı.
///
/// NEDEN VAR: `architecture.md §9` magic string yasağı. Kod-uyum denetimi
/// (2026-08-26) altı durum kodunun `Dof/Index` ve `Dof/Detail` içinde çıplak
/// string olarak 20+ kez tekrarlandığını ölçtü. Yazım hatası derleme
/// hatası vermiyor, sessizce boş kolon üretiyor.
///
/// Türkçe etiket de burada: aynı eşleme üç ayrı switch'te tekrarlıyordu.
/// </summary>
public static class DofStatus
{
    public const string Taslak = "DRAFT";
    public const string Acik = "OPEN";
    public const string DevamEdiyor = "IN_PROGRESS";
    public const string OnayBekliyor = "PENDING_VALIDATION";
    public const string Kapandi = "CLOSED";
    public const string Reddedildi = "REJECTED";

    /// <summary>Kullanıcıya gösterilecek Türkçe etiket (`turkish-ui.md`).</summary>
    public static string Label(string? kod) => kod switch
    {
        Taslak => "Taslak",
        Acik => "Açık",
        DevamEdiyor => "Devam ediyor",
        OnayBekliyor => "Onay bekliyor",
        Kapandi => "Kapandı",
        Reddedildi => "Reddedildi",
        // Bilinmeyen kod UYDURULMAZ: ham kod gosterilir ki fark edilsin.
        _ => string.IsNullOrWhiteSpace(kod) ? "—" : kod
    };

    /// <summary>
    /// Akışın bittiği durumlar. Pano bu ikisini AYNI kolonda gösteriyor;
    /// `REJECTED` "Kapandı" kılığına girmesin diye kart üzerinde ayrı rozet var
    /// (denetim bulgusu 3.5).
    /// </summary>
    public static bool AkisBitti(string? kod) => kod is Kapandi or Reddedildi;
}
