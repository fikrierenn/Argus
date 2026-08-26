using Microsoft.AspNetCore.Authentication.Cookies;
using BkmArgus.Web.Services;
using BkmArgus.Web.Security;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.AspNetCore", Serilog.Events.LogEventLevel.Warning)
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File("logs/bkmargus-.log",
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 30,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();

// Sirlar kaynak kodda tutulmaz: appsettings.Local.json (gitignore) veya ortam degiskeni.
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);
builder.Configuration.AddEnvironmentVariables();

// Add services to the container.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/AccessDenied";
        options.ExpireTimeSpan = TimeSpan.FromDays(7);
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        // Prod'da daima HTTPS; dev'de http://localhost uzerinde cerez set edilebilsin diye gevsetilir.
        options.Cookie.SecurePolicy = builder.Environment.IsDevelopment()
            ? CookieSecurePolicy.SameAsRequest
            : CookieSecurePolicy.Always;
        options.Cookie.Name = "BkmArgus.Auth";
    });

builder.Services.AddAuthorization(options =>
{
    // Kimligi dogrulanmis olmak varsayilan; ustune rol politikalari.
    options.AddPolicy(Policies.AdminOnly, policy =>
        policy.RequireAuthenticatedUser().RequireRole(Roles.Admin));

    options.AddPolicy(Policies.YonetimVeUstu, policy =>
        policy.RequireAuthenticatedUser().RequireRole(Roles.Admin, Roles.Yonetici));
});

builder.Services.AddRazorPages(options =>
{
    options.RootDirectory = "/Features";
});
builder.Services.AddSingleton<BkmArgus.Web.Data.SqlDb>();

// --- Solum ortak katmani (plan: 04) ---
// Solum.Web'in kendi DI uzantisi (AddSolumWeb) henuz yok; kayitlar elle.
// Kabuk her sayfada oldugu icin eksik kayit tum uygulamayi calisma aninda
// dusurur — bu blok eksiksiz kalmali.
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<Solum.Abstractions.ICurrentUser, ArgusCurrentUser>();
builder.Services.AddScoped<Solum.Abstractions.ICurrentCompany, ArgusCurrentCompany>();
builder.Services.AddSingleton<Solum.Abstractions.IClock, ArgusClock>();
builder.Services.AddScoped<Solum.Core.Permissions.IPermissionChecker, ArgusPermissionChecker>();
builder.Services.AddScoped<Solum.Web.Menu.IMenuBuilder, Solum.Web.Menu.MenuBuilder>();
builder.Services.AddSingleton<Solum.Web.Menu.IMenuContributor, BkmArgus.Web.Features.ArgusMenu>();
builder.Services.AddSingleton<Solum.Web.Components.ITableRenderer, Solum.Web.Components.HtmlTableRenderer>();
builder.Services.AddSingleton<Solum.Web.Components.IKpiRenderer, Solum.Web.Components.HtmlKpiRenderer>();
// <solum-field> tag helper'i ureticiyi DI'dan alir; kayit yoksa ILK RENDER patlar
// (Solum denetci bulgusu D8). AddSolumWeb() gelene kadar elle.
builder.Services.AddScoped<Solum.Web.Components.IFieldRenderer, Solum.Web.Components.HtmlFieldRenderer>();

builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<NotificationService>();
// Denetim izi — audit.AuditLog'a yazan TEK servis (plan 06 Faz 1).
builder.Services.AddScoped<AuditTrail>();
builder.Services.AddSingleton<ExcelExportService>();

// Sir sifreleme ana anahtari yoksa uret ve appsettings.Local.json'a yaz.
// Kurulumda elle adim birakmamak icin. Anahtar VERITABANINA yazilmaz:
// sifreli API anahtarlariyla ayni yerde durursa sifrelemenin anlami kalmaz.
var secretsPath = BkmArgus.Infrastructure.SecretProtector.ResolveSecretsFilePath();
builder.Configuration.AddJsonFile(secretsPath, optional: true, reloadOnChange: true);

if (BkmArgus.Infrastructure.SecretProtector.EnsureMasterKey(builder.Configuration, secretsPath, out var secretKeyError))
{
    Log.Information("BKM_SECRET_KEY uretildi ve {Dosya} icine yazildi.", secretsPath);
}
else if (secretKeyError is not null)
{
    Log.Warning("BKM_SECRET_KEY uretilemedi: {Hata}. Sir sifreleme devre disi.", secretKeyError);
}

var app = builder.Build();

app.UseSerilogRequestLogging(options =>
{
    options.MessageTemplate = "{RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.000} ms";
});

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// Dev'de yalniz HTTP portu (5169) dinlenebiliyor; yonlendirme prod'a ozel.
if (!app.Environment.IsDevelopment())
    app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthentication();

// ⚠ GELISTIRME ORTAMI OTURUM ATLAMA (kullanici talebi 2026-08-25).
// Iki kapi: ortam Development OLMALI + Auth:DevBypassRole DOLU olmali.
// Bayrak takipli appsettings'e YAZILMAZ; appsettings.Local.json (gitignore)
// ya da ortam degiskeninden gelir. Uretimde ayarliysa asagidaki dogrulama
// uygulamayi ACILISTA dusurur — sessizce acik kalmaz.
DevAuthBypassMiddleware.UretimdeKapaliOldugunuDogrula(app.Configuration, app.Environment);

if (app.Environment.IsDevelopment())
{
    var devRol = app.Configuration["Auth:DevBypassRole"];
    if (!string.IsNullOrWhiteSpace(devRol))
    {
        var devAyar = new DevAuthBypassOptions
        {
            Role = devRol,
            UserId = app.Configuration.GetValue("Auth:DevBypassUserId", 1),
            UserName = app.Configuration["Auth:DevBypassName"] ?? "Gelistirici (DEV)"
        };

        // Acik oldugu HER acilista gorunur olsun — sessiz bir kimlik atlama
        // en tehlikeli halidir.
        Log.Warning("*** DEV OTURUM ATLAMA AKTIF *** Rol={Rol} KullaniciId={Id}. " +
                    "Bu yalniz Development ortaminda calisir; uretimde uygulama baslamaz.",
                    devAyar.Role, devAyar.UserId);

        app.UseMiddleware<DevAuthBypassMiddleware>(devAyar);
    }
}

app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

// --- Notification API endpoints ---
app.MapPost("/api/notifications/mark-read", async (HttpContext ctx, NotificationService svc) =>
{
    if (!int.TryParse(ctx.Request.Query["id"], out var notifId)) return Results.BadRequest();
    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();

    // Etkilenen satir 0 ise bildirim bu kullaniciya ait DEGIL (ya da yok).
    // Eskiden her durumda Ok() donuyordu ve istemci de yanita bakmiyordu:
    // uctan uca sifir dogrulama (denetim bulgusu 4.1). -1 = SET NOCOUNT ON,
    // yani "bilinmiyor" — 0 ile ayni sey degil, o yuzden ayri ele alinir.
    var etkilenen = await svc.MarkReadAsync(notifId, userId);
    if (etkilenen == 0)
    {
        Log.Warning("Bildirim okundu isaretlenemedi: kayit yok veya kullaniciya ait degil. " +
                    "BildirimId={BildirimId} KullaniciId={KullaniciId}", notifId, userId);
        return Results.NotFound();
    }

    return Results.Ok();
}).RequireAuthorization();

app.MapPost("/api/notifications/mark-all-read", async (HttpContext ctx, NotificationService svc) =>
{
    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();
    await svc.MarkAllReadAsync(userId);
    return Results.Ok();
}).RequireAuthorization();

// DOF drag & drop transition API
app.MapPost("/api/dof/transition", async (HttpContext ctx, BkmArgus.Web.Data.SqlDb db, AuditTrail iz) =>
{
    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    var role = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value ?? "DENETCI";
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();

    if (!long.TryParse(ctx.Request.Query["dofId"].ToString(), out var dofId))
        return Results.BadRequest(new { success = false, error = "Gecersiz dofId." });

    var newStatus = ctx.Request.Query["newStatus"].ToString();
    if (string.IsNullOrWhiteSpace(newStatus))
        return Results.BadRequest(new { success = false, error = "newStatus zorunlu." });

    try
    {
        await db.ExecuteAsync("dof.sp_Finding_Transition", new
        {
            DofId = dofId,
            NewStatus = newStatus,
            UserId = userId,
            UserRole = role,
            Reason = "Kanban surukle-birak ile degistirildi"
        });
        // Denetim izi: durum degistiren islem (security-principles.md).
        // Gecis SP icinde StatusHistory'ye de yaziliyor ama o SUREC izi;
        // bu KULLANICI EYLEMI izi ve tek yerden okunabilir olmali.
        await iz.YazAsync(BkmArgus.Web.Domain.AuditAction.DofGecis, "dof.Findings",
            userId, (int)dofId, yeniDeger: $"Yeni durum: {newStatus} (pano)");

        return Results.Ok(new { success = true });
    }
    catch (Microsoft.Data.SqlClient.SqlException sqlEx)
        when (sqlEx.Number is >= 50000 and < 60000)
    {
        // IS KURALI HATASI. Eskiden tek `catch (Exception)` vardi ve SP'nin
        // urettigi GERCEK neden jenerikle eziliyordu (denetim bulgusu 2.5):
        // DENETCI karti "Kapandi"ya tasiyor, ekran yalniz "Durum
        // degistirilemedi." diyor, kullanici defalarca deneyip IT'ye ticket
        // aciyordu. Dogru mesaj tek adimda cozerdi.
        //
        // 50000-59999 araligi SOZLESME GEREGI kullaniciya gosterilebilir
        // (`error-handling.md`), o yuzden SP mesaji ONCE oldugu gibi gecer.
        //
        // OLCULDU 2026-08-26 — CANLI SP ILE sql/38 AYRISMIS:
        //   canli : 'Zaten bu durumda: %s' · 'Gecersiz gecis: X -> Y (rol: Z)'
        //   sql/38: 'Finding is already in status %s' · 'Invalid transition: ...'
        // Yani dosya Ingilizce, veritabani Turkce. Ilk yazdigim eslesme
        // (yalniz Ingilizce kaliplar) canlida HIC tutmadi ve mesaj jenerige
        // dusuyordu — olcum olmasaydi "duzelttim" diyecektim. Simdi iki dil
        // de tanınıyor, taninmayan mesaj ham haliyle gosteriliyor (kendi
        // SP'mizin is kurali metni, sizinti degil) ve daima loglaniyor.
        // Ayrisma plan 06'ya kaydedildi (fresh-DB kapisi tam bunun icin var).
        var ham = (sqlEx.Message ?? "").Trim();
        var mesaj = ham switch
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

        Log.Warning("DOF gecis is kurali reddi. DofId={DofId} NewStatus={NewStatus} SpMesaj={SpMesaj}",
            dofId, newStatus, ham);
        return Results.BadRequest(new { success = false, error = mesaj });
    }
    catch (Exception ex)
    {
        // Ic hata detayi kullaniciya sizmaz; log'a yazilir.
        Log.Error(ex, "DOF gecis hatasi. DofId={DofId} NewStatus={NewStatus}", dofId, newStatus);
        return Results.BadRequest(new { success = false, error = "Durum degistirilemedi." });
    }
}).RequireAuthorization();

// --- AI Skill Execution API ---
app.MapPost("/api/ai/skill/execute", async (HttpContext ctx, BkmArgus.Web.Data.SqlDb db, AuditTrail iz) =>
{
    var form = await ctx.Request.ReadFromJsonAsync<SkillExecuteRequest>();
    if (form is null) return Results.BadRequest();

    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();

    var result = await db.QuerySingleAsync<ExecutionIdResult>(
        "ai.sp_SkillExecution_Insert",
        new { SkillId = form.SkillId, KullaniciId = userId,
              VarlikTipi = form.EntityType, VarlikId = form.EntityId,
              GirdiJson = form.InputJson });

    // Denetim izi: AI skill calistirmak MALIYET uretir (ai-layer.md) —
    // kimin neyi tetikledigi izlenebilir olmali.
    await iz.YazAsync(BkmArgus.Web.Domain.AuditAction.AiSkillCalistirma, "ai.SkillExecutions",
        userId, result?.Id ?? 0,
        yeniDeger: $"Skill: {form.SkillId} · Varlik: {form.EntityType}/{form.EntityId}");

    return Results.Ok(new { executionId = result?.Id ?? 0 });
}).RequireAuthorization(Policies.YonetimVeUstu);

app.MapGet("/api/ai/skill/status/{id:int}", async (int id, BkmArgus.Web.Data.SqlDb db) =>
{
    var result = await db.QuerySingleAsync<SkillStatusResult>(
        "ai.sp_SkillExecution_Get", new { ExecutionId = id });
    return result is null ? Results.NotFound() : Results.Ok(result);
}).RequireAuthorization();

// --- AI Feedback API ---
// YETKI: Yorum metni ai.fn_LearningContext uzerinden her skill'in SISTEM
// prompt'una giriyor. Yani buraya yazan kisi modelin talimatini yaziyor.
// RequireAuthorization() yetmez — en dusuk rol (DENETCI) tum AI ciktisini
// yonlendirebilirdi. Maliyetli/etkili endpoint kurali: YonetimVeUstu.
app.MapPost("/api/ai/feedback", async (HttpContext ctx, BkmArgus.Web.Data.SqlDb db) =>
{
    var form = await ctx.Request.ReadFromJsonAsync<FeedbackRequest>();
    if (form is null) return Results.BadRequest();

    // Prompt'a girecek metin sinirli olmali; uzun metin hem butceyi yer
    // hem enjeksiyon yuzeyini buyutur.
    if (form.Comment is { Length: > 1000 })
        return Results.BadRequest("Yorum en fazla 1000 karakter olabilir.");

    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();

    await db.ExecuteAsync("ai.sp_Feedback_Upsert",
        new { form.RequestId, form.SkillExecutionId, Onay = form.IsApproved,
              Puan = form.Rating, Yorum = form.Comment, KullaniciId = userId });

    return Results.Ok();
}).RequireAuthorization(BkmArgus.Web.Security.Policies.YonetimVeUstu);

app.Run();

// --- DTO Records for Minimal API ---
record SkillExecuteRequest(string SkillId, string EntityType, int EntityId, string? InputJson);
record FeedbackRequest(int? RequestId, int? SkillExecutionId, bool IsApproved, int? Rating, string? Comment);
record ExecutionIdResult(int Id);
record SkillStatusResult(int ExecutionId, string SkillId, string Status, string? OutputJson,
    string? ModelName, int? ConfidenceScore, string? ErrorMessage, DateTime CreatedAt, DateTime? CompletedAt);
