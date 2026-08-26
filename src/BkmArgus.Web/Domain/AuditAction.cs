namespace BkmArgus.Web.Domain;

/// <summary>
/// Denetim izi eylem kodları (`audit.AuditLog.Operation`).
///
/// Magic string yasağı (`architecture.md §9`): kod çıplak string yazılırsa
/// yazım hatası derleme hatası vermez, iz "başka bir eylem" adıyla düşer ve
/// filtreleme sessizce eksik sonuç verir.
///
/// Mevcut kodlar (canlı DB'de ölçüldü, 2026-08-26): `OGRENME_CEVAP`,
/// `OGRENME_YOKSAY`, `OGRENME_TARAMA` — bunlar SP içinden yazılıyor
/// (sql/74, sql/76), o yüzden burada da adları korunuyor ki tek sözlük olsun.
/// </summary>
public static class AuditAction
{
    // ── Denetim (audit) ──────────────────────────────────────────────────
    public const string DenetimSilme = "DENETIM_SILME";
    public const string DenetimKesinlestirme = "DENETIM_KESINLESTIRME";

    // ── DÖF ─────────────────────────────────────────────────────────────
    public const string DofGecis = "DOF_GECIS";

    // ── Rapor / veri çıkışı ─────────────────────────────────────────────
    /// <summary>Excel dışa aktarım — veri kurumsal sınırın dışına çıkıyor.</summary>
    public const string DisaAktarim = "DISA_AKTARIM";

    // ── AI (maliyet izi) ────────────────────────────────────────────────
    public const string AiSkillCalistirma = "AI_SKILL_CALISTIRMA";

    // ── SP içinden yazılanlar (yalnız sözlük tamlığı için) ──────────────
    public const string OgrenmeCevap = "OGRENME_CEVAP";
    public const string OgrenmeYoksay = "OGRENME_YOKSAY";
    public const string OgrenmeTarama = "OGRENME_TARAMA";
}
