using BkmArgus.Web.Data;
using BkmArgus.Web.Domain;
using BkmArgus.Web.Security;
using BkmArgus.Web.Services;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using Serilog;

namespace BkmArgus.Web.Endpoints;

/// <summary>
/// `/api/*` uç noktaları. `Program.cs`'ten buraya taşındı.
///
/// NEDEN (kod-uyum denetimi 2026-08-27): `Program.cs` 372 satıra çıkmıştı
/// (yumuşak sınır 300) ve `/api/dof/transition` lambda'sı 83 satırdı
/// (sınır 80). Uç nokta tanımları uzantı metotlarına ayrıldı; SP mesajı
/// eşlemesi `SpMesaj`'a çıktı.
/// </summary>
public static class ApiEndpoints
{
    /// <summary>Bildirim uç noktaları.</summary>
    public static void MapBildirimApi(this WebApplication app)
    {
        // Okundu işaretle — tek bildirim.
        app.MapPost("/api/notifications/mark-read",
            async (HttpContext ctx, NotificationService svc, IAntiforgery af, ILoggerFactory lf) =>
        {
            // CSRF kapısı — tek yerden (ApiGuard).
            var red = await ApiGuard.TokenDogrulaAsync(ctx, af, lf.CreateLogger("Api.Notifications"));
            if (red is not null) return red;

            // Parametre sorgu dizesinden GÖVDEYE taşındı: sorgu dizesi tarayıcı
            // geçmişine, erişim loguna ve Referer başlığına yazılır.
            var govde = await ApiGuard.GovdeOkuAsync<NotifIdRequest>(ctx);
            if (govde is null || govde.Id <= 0)
                return Results.BadRequest(new { success = false, error = "Gecersiz bildirim kimligi." });

            var userId = ctx.KullaniciId();
            if (userId is null) return Results.Unauthorized();

            // Etkilenen satır 0 ise bildirim bu kullanıcıya ait DEĞİL (ya da yok).
            // Eskiden her durumda Ok() dönüyordu ve istemci de yanıta bakmıyordu:
            // uçtan uca sıfır doğrulama. -1 = SET NOCOUNT ON, yani "bilinmiyor" —
            // 0 ile aynı şey değil, o yüzden ayrı ele alınır.
            var etkilenen = await svc.MarkReadAsync(govde.Id, userId.Value);
            if (etkilenen == 0)
            {
                Log.Warning("Bildirim okundu isaretlenemedi: kayit yok veya kullaniciya ait degil. " +
                            "BildirimId={BildirimId} KullaniciId={KullaniciId}", govde.Id, userId);
                return Results.NotFound();
            }

            return Results.Ok();
        }).RequireAuthorization();

        // Tümünü okundu işaretle.
        app.MapPost("/api/notifications/mark-all-read",
            async (HttpContext ctx, NotificationService svc, IAntiforgery af, ILoggerFactory lf) =>
        {
            var red = await ApiGuard.TokenDogrulaAsync(ctx, af, lf.CreateLogger("Api.Notifications"));
            if (red is not null) return red;

            var userId = ctx.KullaniciId();
            if (userId is null) return Results.Unauthorized();

            await svc.MarkAllReadAsync(userId.Value);
            return Results.Ok();
        }).RequireAuthorization();
    }

    /// <summary>DÖF pano geçişi (sürükle-bırak ve klavye).</summary>
    public static void MapDofApi(this WebApplication app)
    {
        app.MapPost("/api/dof/transition",
            async (HttpContext ctx, SqlDb db, AuditTrail iz, IAntiforgery af, ILoggerFactory lf) =>
        {
            var red = await ApiGuard.TokenDogrulaAsync(ctx, af, lf.CreateLogger("Api.Dof"));
            if (red is not null) return red;

            var userId = ctx.KullaniciId();
            if (userId is null) return Results.Unauthorized();

            // Rol sabitten geliyor (magic string yasağı, architecture.md §9).
            var role = ctx.User.FindFirstValue(ClaimTypes.Role) ?? Roles.Denetci;

            var govde = await ApiGuard.GovdeOkuAsync<DofTransitionRequest>(ctx);
            if (govde is null || govde.DofId <= 0)
                return Results.BadRequest(new { success = false, error = "Gecersiz dofId." });

            var newStatus = govde.NewStatus ?? "";
            if (string.IsNullOrWhiteSpace(newStatus))
                return Results.BadRequest(new { success = false, error = "newStatus zorunlu." });

            try
            {
                await db.ExecuteAsync("dof.sp_Finding_Transition", new
                {
                    DofId = govde.DofId,
                    NewStatus = newStatus,
                    UserId = userId.Value,
                    UserRole = role,
                    Reason = "Kanban surukle-birak ile degistirildi"
                });

                // Denetim izi: durum değiştiren işlem (security-principles.md).
                // Geçiş SP içinde StatusHistory'ye de yazılıyor ama o SÜREÇ izi;
                // bu KULLANICI EYLEMİ izi ve tek yerden okunabilir olmalı.
                await iz.YazAsync(AuditAction.DofGecis, "dof.Findings",
                    userId, (int)govde.DofId, yeniDeger: $"Yeni durum: {newStatus} (pano)");

                return Results.Ok(new { success = true });
            }
            catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
            {
                // İş kuralı hatası — SP'nin gerçek nedeni jenerikle EZİLMEZ.
                Log.Warning("DOF gecis is kurali reddi. DofId={DofId} NewStatus={NewStatus} SpMesaj={SpMesaj}",
                    govde.DofId, newStatus, sqlEx.Message);
                return Results.BadRequest(new { success = false, error = SpMesaj.Cevir(sqlEx.Message) });
            }
            catch (Exception ex)
            {
                // İç hata detayı kullanıcıya sızmaz; log'a yazılır.
                Log.Error(ex, "DOF gecis hatasi. DofId={DofId} NewStatus={NewStatus}", govde.DofId, newStatus);
                return Results.BadRequest(new { success = false, error = "Durum degistirilemedi." });
            }
        }).RequireAuthorization();
    }

    /// <summary>AI skill çalıştırma, durum sorgulama ve geri bildirim.</summary>
    public static void MapAiApi(this WebApplication app)
    {
        // Skill çalıştır — LLM maliyeti üretir.
        app.MapPost("/api/ai/skill/execute",
            async (HttpContext ctx, SqlDb db, AuditTrail iz, IAntiforgery af, ILoggerFactory lf) =>
        {
            var red = await ApiGuard.TokenDogrulaAsync(ctx, af, lf.CreateLogger("Api.Ai"));
            if (red is not null) return red;

            var form = await ApiGuard.GovdeOkuAsync<SkillExecuteRequest>(ctx);
            if (form is null) return Results.BadRequest();

            var userId = ctx.KullaniciId();
            if (userId is null) return Results.Unauthorized();

            var result = await db.QuerySingleAsync<ExecutionIdResult>(
                "ai.sp_SkillExecution_Insert",
                new { SkillId = form.SkillId, KullaniciId = userId.Value,
                      VarlikTipi = form.EntityType, VarlikId = form.EntityId,
                      GirdiJson = form.InputJson });

            // Denetim izi: AI skill çalıştırmak MALİYET üretir (ai-layer.md).
            await iz.YazAsync(AuditAction.AiSkillCalistirma, "ai.SkillExecutions",
                userId, result?.Id ?? 0,
                yeniDeger: $"Skill: {form.SkillId} · Varlik: {form.EntityType}/{form.EntityId}");

            return Results.Ok(new { executionId = result?.Id ?? 0 });
        }).RequireAuthorization(Policies.YonetimVeUstu);

        // Skill durumu.
        //
        // IDOR KAPANDI (güvenlik denetimi 2026-08-27, confidence 90): burada
        // yalnız `RequireAuthorization()` vardı ve `ai.sp_SkillExecution_Get`
        // kapsam filtresi uygulamıyor (`WHERE ExecutionId = @ExecutionId`,
        // ölçüldü). Yani DENETCI `?id=1..N` ile yönetim-yetkili skill
        // çalıştırmalarının LLM GİRDİ/ÇIKTILARINI okuyabiliyordu.
        // Çalıştırma tarafı zaten YonetimVeUstu; okuma da aynı kapıya bağlandı
        // (yalnız o rol skill çalıştırabildiği için kimse kendi kaydını
        // kaybetmiyor).
        app.MapGet("/api/ai/skill/status/{id:int}", async (int id, SqlDb db) =>
        {
            var result = await db.QuerySingleAsync<SkillStatusResult>(
                "ai.sp_SkillExecution_Get", new { ExecutionId = id });
            return result is null ? Results.NotFound() : Results.Ok(result);
        }).RequireAuthorization(Policies.YonetimVeUstu);

        // Geri bildirim (onay/red + yorum).
        //
        // YETKİ: yorum metni `ai.fn_LearningContext` üzerinden her skill'in
        // SİSTEM prompt'una giriyor — buraya yazan kişi modelin talimatını
        // yazıyor. O yüzden YonetimVeUstu.
        //
        // CSRF KAPISI EKLENDİ (2026-08-27): dört uç nokta kapatılırken bu
        // atlanmıştı. Aynı sınıfta olduğu hâlde dışarıda kalması, kapının
        // kendisini güvenilmez yapar. Ayrıca gövde okuma da tek yola
        // (`GovdeOkuAsync`) bağlandı: eskiden çıplak `ReadFromJsonAsync`
        // form-encoded istekte yakalanmayan bir istisna atıp temiz 400
        // yerine 500 üretiyordu.
        app.MapPost("/api/ai/feedback",
            async (HttpContext ctx, SqlDb db, IAntiforgery af, ILoggerFactory lf) =>
        {
            var red = await ApiGuard.TokenDogrulaAsync(ctx, af, lf.CreateLogger("Api.Ai"));
            if (red is not null) return red;

            var form = await ApiGuard.GovdeOkuAsync<FeedbackRequest>(ctx);
            if (form is null) return Results.BadRequest();

            // Prompt'a girecek metin sınırlı olmalı; uzun metin hem bütçeyi yer
            // hem enjeksiyon yüzeyini büyütür.
            if (form.Comment is { Length: > 1000 })
                return Results.BadRequest("Yorum en fazla 1000 karakter olabilir.");

            var userId = ctx.KullaniciId();
            if (userId is null) return Results.Unauthorized();

            try
            {
                await db.ExecuteAsync("ai.sp_Feedback_Upsert",
                    new { form.RequestId, form.SkillExecutionId, Onay = form.IsApproved,
                          Puan = form.Rating, Yorum = form.Comment, KullaniciId = userId.Value });

                return Results.Ok();
            }
            catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
            {
                // İş kuralı hatası — SP Türkçe yazdı, kullanıcıya gösterilebilir.
                return Results.BadRequest(new { success = false, error = sqlEx.Message });
            }
            catch (SqlException sqlEx)
            {
                Log.Error(sqlEx, "AI geri bildirim SQL hatasi. KullaniciId={KullaniciId}", userId);
                return Results.BadRequest(new { success = false, error = "Geri bildirim kaydedilemedi." });
            }
        }).RequireAuthorization(Policies.YonetimVeUstu);
    }
}

/// <summary>
/// SP'nin ürettiği iş kuralı mesajını kullanıcıya gösterilecek Türkçe metne
/// çevirir. `Program.cs` içindeki 41 satırlık blok buraya taşındı.
/// </summary>
public static class SpMesaj
{
    /// <summary>
    /// ÖLÇÜLDÜ 2026-08-26 — CANLI SP ile `sql/38` AYRIŞMIŞ:
    ///   canlı : 'Zaten bu durumda: %s' · 'Gecersiz gecis: X -> Y (rol: Z)'
    ///   sql/38: 'Finding is already in status %s' · 'Invalid transition: ...'
    /// Yani dosya İngilizce, veritabanı Türkçe. İlk yazdığım eşleme (yalnız
    /// İngilizce kalıplar) canlıda HİÇ tutmadı ve gerçek sebep jeneriğe
    /// düşüyordu — ölçüm olmasaydı "düzelttim" diyecektim.
    ///
    /// Tanınmayan mesaj HAM hâliyle geçer: 50000-59999 aralığı sözleşme
    /// gereği kullanıcıya gösterilebilir (`error-handling.md`) ve bu metin
    /// kendi SP'mizin iş kuralı açıklaması, iç hata detayı değil.
    /// </summary>
    public static string Cevir(string? spMesaji)
    {
        var ham = (spMesaji ?? "").Trim();

        return ham switch
        {
            var m when m.Contains("Zaten bu durumda", StringComparison.OrdinalIgnoreCase)
                    || m.Contains("already in status", StringComparison.OrdinalIgnoreCase)
                => "Bu bulgu zaten bu durumda. Sayfayı yenileyin.",

            var m when m.Contains("Gecersiz gecis", StringComparison.OrdinalIgnoreCase)
                    || m.Contains("Invalid transition", StringComparison.OrdinalIgnoreCase)
                => "Bu geçişe bu rolle izin verilmiyor — yönetici onayı gerekiyor.",

            var m when m.Contains("bulunamadi", StringComparison.OrdinalIgnoreCase)
                    || m.Contains("not found", StringComparison.OrdinalIgnoreCase)
                => "Bulgu bulunamadı.",

            "" => "Geçişe izin verilmedi.",
            _ => ham
        };
    }
}

/// <summary>
/// Oturumdaki kullanıcı kimliğini okuyan tek yol.
///
/// NEDEN (kod-uyum denetimi): `int.TryParse(...NameIdentifier...)` deseni
/// repo genelinde 24 yerde, yalnız `Program.cs`'te beş kez tekrarlıyordu.
/// </summary>
public static class HttpContextExtensions
{
    /// <summary>Kimlik yoksa <c>null</c> — çağıran fail-closed davranmalı.</summary>
    public static int? KullaniciId(this HttpContext ctx) =>
        int.TryParse(ctx.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
}

// --- Minimal API gövde sözleşmeleri ---
// Parametreler sorgu dizesinden GÖVDEYE taşındı (plan 06 Faz 4): sorgu dizesi
// tarayıcı geçmişine, erişim loguna ve Referer başlığına yazılır.
public record NotifIdRequest(int Id);
public record DofTransitionRequest(long DofId, string? NewStatus);
public record SkillExecuteRequest(string SkillId, string EntityType, int EntityId, string? InputJson);
public record FeedbackRequest(int? RequestId, int? SkillExecutionId, bool IsApproved, int? Rating, string? Comment);
public record ExecutionIdResult(int Id);
public record SkillStatusResult(int ExecutionId, string SkillId, int? RequestedByUserId, string? EntityType,
    int? EntityId, string Status, string? InputJson, string? OutputJson, string? ModelName,
    decimal? ConfidenceScore, string? ErrorMessage, DateTime CreatedAt, DateTime? CompletedAt,
    string? RequestedByUserName);
