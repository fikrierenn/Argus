using Microsoft.AspNetCore.Authentication.Cookies;
using BkmArgus.Web.Services;
using BkmArgus.Web.Security;
using BkmArgus.Web.Endpoints;
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

// CSRF: `/api/*` uc noktalari token'i BASLIKTAN okur (plan 06 Faz 4).
// Guvenlik denetimi (IMP-2): uc durum-degistiren uc nokta yalniz
// SameSite=Lax'e guveniyordu; ayni site alt alan adi senaryosu aciktir.
builder.Services.AddAntiforgery(o => o.HeaderName = BkmArgus.Web.Security.ApiGuard.TokenHeader);
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

// --- /api/* uc noktalari ---
// Tanimlar Endpoints/ApiEndpoints.cs'te: Program.cs 372 satira cikmisti
// (yumusak sinir 300) ve dof/transition lambda'si 83 satirdi (sinir 80).
app.MapBildirimApi();
app.MapDofApi();
app.MapAiApi();

app.Run();
