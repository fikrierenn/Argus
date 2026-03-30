namespace BkmArgus.AiWorker.Skills;

public class SkillDefinition
{
    public string SkillId { get; init; } = "";           // e.g., "audit.analyze"
    public string Name { get; init; } = "";               // e.g., "Denetim Analizi"
    public string Description { get; init; } = "";        // What it does
    public SkillCategory Category { get; init; }          // Audit, DOF, Risk, Report, General
    public TriggerMode Trigger { get; init; }             // Reactive, Proactive, Hybrid
    public string[] RequiredContext { get; init; } = [];   // What data it needs
    public OutputType Output { get; init; }               // Text, StructuredJson, ActionList, Suggestion
    public double Temperature { get; init; } = 0.2;
    public int MaxTokens { get; init; } = 2048;
    public string SystemPromptTemplate { get; init; } = "";
    public string UserPromptTemplate { get; init; } = "";
}

public enum SkillCategory { Audit, DOF, Risk, Report, General, Semantic }
public enum TriggerMode { Reactive, Proactive, Hybrid }
public enum OutputType { Text, StructuredJson, ActionList, Suggestion }
