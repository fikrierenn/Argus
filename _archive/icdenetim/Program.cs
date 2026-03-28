using BkmArgus.Data;
using BkmArgus.Services;
using Microsoft.AspNetCore.Authentication.Cookies;

// Hash uretmek icin: dotnet run -- hash <password>
if (args.Contains("hash"))
{
    var passwordArg = args.SkipWhile(a => a != "hash").Skip(1).FirstOrDefault();
    if (string.IsNullOrEmpty(passwordArg))
    {
        Console.Error.WriteLine("Kullanim: dotnet run -- hash <password>");
        Environment.Exit(1);
    }
    Console.WriteLine(BCrypt.Net.BCrypt.HashPassword(passwordArg, workFactor: 11));
    Environment.Exit(0);
}

// Pipeline test: dotnet run -- test-pipeline <auditId>
if (args.Contains("test-pipeline"))
{
    var idArg = args.SkipWhile(a => a != "test-pipeline").Skip(1).FirstOrDefault();
    if (!int.TryParse(idArg, out var testAuditId))
    {
        Console.Error.WriteLine("Kullanim: dotnet run -- test-pipeline <auditId>");
        Environment.Exit(1);
    }

    // Minimal DI setup
    var testBuilder = WebApplication.CreateBuilder(Array.Empty<string>());
    var envFile = Path.Combine(testBuilder.Environment.ContentRootPath, ".env");
    if (File.Exists(envFile))
        foreach (var line in File.ReadAllLines(envFile).Where(l => !string.IsNullOrWhiteSpace(l) && !l.TrimStart().StartsWith('#') && l.Contains('=')))
            Environment.SetEnvironmentVariable(line[..line.IndexOf('=')].Trim(), line[(line.IndexOf('=') + 1)..].Trim());
    testBuilder.Configuration.AddEnvironmentVariables();
    testBuilder.Services.AddSingleton<IDbConnectionFactory, SqlConnectionFactory>();
    testBuilder.Services.AddAiServices();
    testBuilder.Services.AddScoped<IDataIntelligenceService, DataIntelligenceService>();
    testBuilder.Services.AddScoped<IInsightService, InsightService>();
    testBuilder.Services.AddScoped<IAuditProcessingService, AuditProcessingService>();
    testBuilder.Services.AddSingleton<BkmArgus.Services.Events.IEventBus, BkmArgus.Services.Events.InMemoryEventBus>();
    testBuilder.Services.AddScoped<BkmArgus.Services.AI.IAIOrchestratorService, BkmArgus.Services.AI.AIOrchestratorService>();
    testBuilder.Services.AddScoped<BkmArgus.Services.AI.AIContextBuilder>();
    testBuilder.Services.AddScoped<BkmArgus.Repositories.ISkillRepository, BkmArgus.Repositories.SkillRepository>();
    testBuilder.Services.AddScoped<BkmArgus.Repositories.ICorrectiveActionRepository, BkmArgus.Repositories.CorrectiveActionRepository>();
    testBuilder.Services.AddScoped<IFindingsService, FindingsService>();
    testBuilder.Logging.SetMinimumLevel(LogLevel.Information);
    testBuilder.Logging.AddConsole();
    var testApp = testBuilder.Build();

    using var scope = testApp.Services.CreateScope();
    var processing = scope.ServiceProvider.GetRequiredService<IAuditProcessingService>();
    Console.WriteLine($"=== Pipeline Test: Audit #{testAuditId} ===");
    await processing.ProcessAuditAsync(testAuditId);
    Console.WriteLine("=== Pipeline Test Tamamlandi ===");
    Environment.Exit(0);
}

var builder = WebApplication.CreateBuilder(args);

// .env dosyasindan environment variable'lari yukle
var envPath = Path.Combine(builder.Environment.ContentRootPath, ".env");
if (File.Exists(envPath))
{
    foreach (var line in File.ReadAllLines(envPath))
    {
        var trimmed = line.Trim();
        if (string.IsNullOrEmpty(trimmed) || trimmed.StartsWith('#')) continue;
        var eq = trimmed.IndexOf('=');
        if (eq <= 0) continue;
        var key = trimmed[..eq].Trim();
        var val = trimmed[(eq + 1)..].Trim();
        Environment.SetEnvironmentVariable(key, val);
    }
}
builder.Configuration.AddEnvironmentVariables();

// Razor Pages - varsayılan authorize, Login/Logout hariç
builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizeFolder("/");
    options.Conventions.AllowAnonymousToPage("/Account/Login");
    options.Conventions.AllowAnonymousToPage("/Account/Logout");
    options.Conventions.AllowAnonymousToPage("/Account/Setup");
    options.Conventions.AllowAnonymousToPage("/Error");
});

// Veritabani baglanti factory - DI ile inject edilebilir
builder.Services.AddSingleton<IDbConnectionFactory, SqlConnectionFactory>();

// AI servisleri - Claude API, rapor olusturma, risk tahmin
builder.Services.AddAiServices();

// Data Intelligence - tekrar/sistemik tespit, risk eskalasyonu
builder.Services.AddScoped<IDataIntelligenceService, DataIntelligenceService>();

// Dashboard - metrikler ve raporlama sorgulari
builder.Services.AddScoped<IDashboardService, DashboardService>();

// Repositories - veri erisim katmani
builder.Services.AddScoped<BkmArgus.Repositories.ISkillRepository, BkmArgus.Repositories.SkillRepository>();
builder.Services.AddScoped<BkmArgus.Repositories.ICorrectiveActionRepository, BkmArgus.Repositories.CorrectiveActionRepository>();

// Finding servisi - zenginlestirilmis bulgu katmani
builder.Services.AddScoped<IFindingsService, FindingsService>();

// Insight servisi - otomatik uyari/oneri uretimi
builder.Services.AddScoped<IInsightService, InsightService>();

// Audit Processing - pipeline orchestrator
builder.Services.AddScoped<IAuditProcessingService, AuditProcessingService>();

// Event Bus - in-process event system
builder.Services.AddSingleton<BkmArgus.Services.Events.IEventBus, BkmArgus.Services.Events.InMemoryEventBus>();

// AI Orchestrator - merkezi karar motoru
builder.Services.AddScoped<BkmArgus.Services.AI.IAIOrchestratorService, BkmArgus.Services.AI.AIOrchestratorService>();

// AI Context Builder
builder.Services.AddScoped<BkmArgus.Services.AI.AIContextBuilder>();

// AI Background Worker - kuyruk isleme servisi
builder.Services.AddHostedService<BkmArgus.Services.AI.AiBackgroundWorker>();

// Cookie Authentication - simdilik herkes admin
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.ExpireTimeSpan = TimeSpan.FromDays(7);
        options.SlidingExpiration = true;
    });

var app = builder.Build();

// Veritabanı migration - eksik sütunları ekle (IsFinalized, FinalizedAt, LocationType vb.)
await BkmArgus.Data.DbMigration.RunMigrationsAsync(app.Services.GetRequiredService<IConfiguration>());
// Veritabanı seed - admin kullanıcısı yoksa oluştur
await BkmArgus.Data.DbInitializer.SeedAsync(app.Services.GetRequiredService<IConfiguration>());

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

// Security headers
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    await next();
});

app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
