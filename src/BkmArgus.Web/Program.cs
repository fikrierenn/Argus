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

// DOF drag & drop transition API
app.MapPost("/api/dof/transition", async (HttpContext ctx, BkmArgus.Web.Data.SqlDb db) =>
{
    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    var role = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value ?? "DENETCI";
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();

    var dofId = long.Parse(ctx.Request.Query["dofId"].ToString());
    var newStatus = ctx.Request.Query["newStatus"].ToString();

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
        return Results.Ok(new { success = true });
    }
    catch (Exception ex)
    {
        return Results.BadRequest(new { success = false, error = ex.Message });
    }
}).RequireAuthorization();

// --- AI Skill Execution API ---
app.MapPost("/api/ai/skill/execute", async (HttpContext ctx, BkmArgus.Web.Data.SqlDb db) =>
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

    return Results.Ok(new { executionId = result?.Id ?? 0 });
}).RequireAuthorization();

app.MapGet("/api/ai/skill/status/{id:int}", async (int id, BkmArgus.Web.Data.SqlDb db) =>
{
    var result = await db.QuerySingleAsync<SkillStatusResult>(
        "ai.sp_SkillExecution_Get", new { ExecutionId = id });
    return result is null ? Results.NotFound() : Results.Ok(result);
}).RequireAuthorization();

// --- AI Feedback API ---
app.MapPost("/api/ai/feedback", async (HttpContext ctx, BkmArgus.Web.Data.SqlDb db) =>
{
    var form = await ctx.Request.ReadFromJsonAsync<FeedbackRequest>();
    if (form is null) return Results.BadRequest();

    var uid = ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    if (!int.TryParse(uid, out var userId)) return Results.Unauthorized();

    await db.ExecuteAsync("ai.sp_Feedback_Upsert",
        new { form.RequestId, form.SkillExecutionId, Onay = form.IsApproved,
              Puan = form.Rating, Yorum = form.Comment, KullaniciId = userId });

    return Results.Ok();
}).RequireAuthorization();

app.Run();

// --- DTO Records for Minimal API ---
record SkillExecuteRequest(string SkillId, string EntityType, int EntityId, string? InputJson);
record FeedbackRequest(int? RequestId, int? SkillExecutionId, bool IsApproved, int? Rating, string? Comment);
record ExecutionIdResult(int Id);
record SkillStatusResult(int ExecutionId, string SkillId, string Status, string? OutputJson,
    string? ModelName, int? ConfidenceScore, string? ErrorMessage, DateTime CreatedAt, DateTime? CompletedAt);
