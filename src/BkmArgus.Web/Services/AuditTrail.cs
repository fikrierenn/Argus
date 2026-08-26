using BkmArgus.Web.Data;
using Microsoft.Data.SqlClient;

namespace BkmArgus.Web.Services;

/// <summary>
/// Denetim izi (`audit.AuditLog`) yazan tek servis.
///
/// NEDEN VAR: `security-principles.md §Audit Log Kapsamı` on bir eylemi
/// zorunlu kılıyor ama ölçüldü (2026-08-26) — web katmanında tabloya yazan
/// hiçbir yer yoktu; tablodaki 3 satırın tamamı AI öğrenme döngüsünün
/// SP içi INSERT'lerinden geliyordu. Denetim yazılımının kendi eylemlerini
/// kaydetmemesi, dışarıdan bakan bir denetçinin ilk bulacağı şeydir.
///
/// HATA DAVRANIŞI (bilinçli): iz yazımı başarısız olursa kullanıcının işi
/// DÜŞMEZ ama sessiz de kalmaz — `LogError` ile uygulama loguna yazılır.
/// Denetim izi bir gözlemdir; gözlem alınamadı diye yapılan iş geri alınmaz.
/// Sessiz `catch` yasağı (`error-handling.md`) log ile karşılanıyor.
/// </summary>
public sealed class AuditTrail(SqlDb db, ILogger<AuditTrail> logger)
{
    /// <summary>
    /// İz yazar. İstisna FIRLATMAZ — çağıran akışı kesmemeli.
    /// </summary>
    /// <param name="eylem">`AuditAction` sabitlerinden biri.</param>
    /// <param name="tabloAdi">Etkilenen tablo, şema dahil (`audit.Audits`).</param>
    /// <param name="kullaniciId">Eylemi yapan; sistem eylemi için null.</param>
    /// <param name="kayitId">Etkilenen kayıt; tek kayda bağlı değilse 0.</param>
    /// <param name="eskiDeger">Değişiklik öncesi özet (opsiyonel).</param>
    /// <param name="yeniDeger">Değişiklik sonrası özet / bağlam.</param>
    public async Task YazAsync(
        string eylem,
        string tabloAdi,
        int? kullaniciId,
        int kayitId = 0,
        string? eskiDeger = null,
        string? yeniDeger = null,
        CancellationToken ct = default)
    {
        try
        {
            await db.ExecuteAsync("audit.sp_AuditLog_Write", new
            {
                Eylem = eylem,
                TabloAdi = tabloAdi,
                KullaniciId = kullaniciId,
                KayitId = kayitId,
                EskiDeger = eskiDeger,
                YeniDeger = yeniDeger
            });
        }
        catch (SqlException sqlEx)
        {
            // İz yazılamadı — iş devam eder ama bu SESSİZ kalmaz.
            logger.LogError(sqlEx,
                "Denetim izi yazilamadi. Eylem={Eylem} Tablo={Tablo} KayitId={KayitId} KullaniciId={KullaniciId}",
                eylem, tabloAdi, kayitId, kullaniciId);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Denetim izi yazilamadi (beklenmedik). Eylem={Eylem} Tablo={Tablo}", eylem, tabloAdi);
        }
    }
}
