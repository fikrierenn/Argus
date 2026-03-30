using Microsoft.Extensions.Logging;

namespace BkmArgus.AiWorker.Skills;

public class SkillExecutor
{
    private readonly SkillRegistry _registry;
    private readonly LlmService _llm;
    private readonly ILogger<SkillExecutor> _logger;

    public SkillExecutor(SkillRegistry registry, LlmService llm, ILogger<SkillExecutor> logger)
    {
        _registry = registry;
        _llm = llm;
        _logger = logger;
    }

    public async Task<SkillResult> ExecuteAsync(
        string skillId,
        Dictionary<string, string> variables,
        CancellationToken cancellationToken = default)
    {
        var skill = _registry.Get(skillId);
        if (skill is null)
            return SkillResult.Fail($"Skill bulunamadi: {skillId}");

        // Build prompts from templates
        var systemPrompt = RenderTemplate(skill.SystemPromptTemplate, variables);
        var userPrompt = RenderTemplate(skill.UserPromptTemplate, variables);

        var fullPrompt = $"<|system|>{systemPrompt}<|/system|>\n\n{userPrompt}";

        _logger.LogInformation("Executing skill {SkillId} with {VarCount} variables", skillId, variables.Count);

        try
        {
            var result = await _llm.GenerateAsync(fullPrompt, cancellationToken);

            if (result.Error is not null)
                return SkillResult.Fail(result.Error);

            return new SkillResult
            {
                Success = true,
                SkillId = skillId,
                Output = result.Result?.RawJson ?? result.Result?.ExecutiveSummary ?? "",
                ModelName = result.Result?.ModelName ?? "unknown",
                ConfidenceScore = result.Result?.ConfidenceScore ?? 0,
                ExecutedAt = DateTime.UtcNow
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Skill execution failed: {SkillId}", skillId);
            return SkillResult.Fail(ex.Message);
        }
    }

    private static string RenderTemplate(string template, Dictionary<string, string> variables)
    {
        var result = template;
        foreach (var (key, value) in variables)
        {
            result = result.Replace($"{{{{{key}}}}}", value ?? "");
        }
        return result;
    }
}

public class SkillResult
{
    public bool Success { get; init; }
    public string? Error { get; init; }
    public string SkillId { get; init; } = "";
    public string Output { get; init; } = "";
    public string ModelName { get; init; } = "";
    public int? ConfidenceScore { get; init; }
    public DateTime ExecutedAt { get; init; }

    public static SkillResult Fail(string error) => new() { Success = false, Error = error };
}
