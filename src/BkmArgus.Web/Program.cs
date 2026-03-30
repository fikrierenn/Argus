using Microsoft.AspNetCore.Authentication.Cookies;
using BkmArgus.Web.Services;
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

// Add services to the container.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromDays(7);
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddAuthorization();

builder.Services.AddRazorPages(options =>
{
    options.RootDirectory = "/Features";
});
builder.Services.AddSingleton<BkmArgus.Web.Data.SqlDb>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<NotificationService>();
builder.Services.AddSingleton<ExcelExportService>();

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

app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthentication();
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
    await svc.MarkReadAsync(notifId, userId);
    return Results.Ok();
}).RequireAuthorization();

app.MapPost("/api/notifications/mark-all-read", async (HttpContext ctx, NotificationService svc) =>
{
    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();
    await svc.MarkAllReadAsync(userId);
    return Results.Ok();
}).RequireAuthorization();

app.Run();
