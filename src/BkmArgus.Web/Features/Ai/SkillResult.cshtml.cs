using System.Text.Json;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public sealed class SkillResultModel : PageModel
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly SqlDb _db;

    public SkillResultModel(SqlDb db) => _db = db;

    public ExecutionRow? Execution { get; private set; }
    public string OutputFormatted { get; private set; } = "-";

    public async Task<IActionResult> OnGetAsync(int? id)
    {
        if (!id.HasValue || id.Value <= 0)
            return NotFound();

        Execution = await _db.QuerySingleAsync<ExecutionRow>(
            "ai.sp_SkillExecution_Get",
            new { ExecutionId = id.Value });

        if (Execution is null)
            return NotFound();

        OutputFormatted = FormatJson(Execution.OutputJson);
        return Page();
    }

    private static string FormatJson(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "-";

        var clean = value.Trim();
        if (!clean.StartsWith("{") && !clean.StartsWith("["))
            return clean;

        try
        {
            using var doc = JsonDocument.Parse(clean);
            return JsonSerializer.Serialize(doc.RootElement, JsonOptions);
        }
        catch
        {
            return clean;
        }
    }

    public sealed record ExecutionRow
    {
        public int ExecutionId { get; init; }
        public string SkillId { get; init; } = string.Empty;
        public int RequestedByUserId { get; init; }
        public string EntityType { get; init; } = string.Empty;
        public int EntityId { get; init; }
        public string? InputJson { get; init; }
        public string Status { get; init; } = string.Empty;
        public string? OutputJson { get; init; }
        public string? ModelName { get; init; }
        public int? ConfidenceScore { get; init; }
        public string? ErrorMessage { get; init; }
        public DateTime CreatedAt { get; init; }
        public DateTime? CompletedAt { get; init; }
    }
}
