namespace BkmArgus.AiWorker;

public sealed record AnalysisQueueRow
{
    public long? RequestId { get; init; }
    public DateTime? SnapshotDate { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public int LocationId { get; init; }
    public int ProductId { get; init; }
    public string? MekanAd { get; init; }
    public string? UrunKod { get; init; }
    public string? UrunAd { get; init; }
    public int? RiskScore { get; init; }
    public int Priority { get; init; }
    public string Status { get; init; } = string.Empty;
    public string? EvidencePlan { get; init; }
    public string? RuleNote { get; init; }
    public DateTime? CreatedAt { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public string? ErrorMessage { get; init; }
}

public sealed record AnalysisQueueLlmRow
{
    public long RequestId { get; init; }
    public DateTime? SnapshotDate { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public int LocationId { get; init; }
    public int ProductId { get; init; }
    public string? EvidencePlan { get; init; }
    public string? EvidenceJson { get; init; }
    public string? RuleNote { get; init; }
}

public sealed record RiskSummaryRow
{
    public DateTime? SnapshotDate { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public int LocationId { get; init; }
    public string MekanAd { get; init; } = string.Empty;
    public int ProductId { get; init; }
    public string UrunKod { get; init; } = string.Empty;
    public string UrunAd { get; init; } = string.Empty;
    public int RiskScore { get; init; }
    public string? RiskComment { get; init; }
    public bool FlagDataQuality { get; init; }
    public bool FlagSalesWithoutEntry { get; init; }
    public bool FlagDeadStock { get; init; }
    public bool FlagNetAccumulation { get; init; }
    public bool FlagHighReturn { get; init; }
    public bool FlagHighDamagedReturn { get; init; }
    public bool FlagHighCountAdjustment { get; init; }
    public bool FlagHighInternalUse { get; init; }
    public bool FlagFastTurnover { get; init; }
    public bool FlagSalesAging { get; init; }
}

public sealed record RuleDecision
{
    public string RootCauseClass { get; init; } = "DIGER";
    public string EvidencePlan { get; init; } = "BASIC";
    public bool LlmRequired { get; init; }
    public int PriorityScore { get; init; }
    public string? BriefSummary { get; init; }
    public string? FeatureJson { get; init; }
    public string? SemanticNote { get; init; }
}

public sealed record LlmResultRow
{
    public string ModelName { get; init; } = string.Empty;
    public string PromptVersion { get; init; } = "v1";
    public string? RootCauseHypotheses { get; init; }
    public string? VerificationSteps { get; init; }
    public string? RecommendedActions { get; init; }
    public string? DofDraftJson { get; init; }
    public string? ExecutiveSummary { get; init; }
    public int? ConfidenceScore { get; init; }
    public string RawJson { get; init; } = string.Empty;
    public string? ParseError { get; init; }
}

public sealed record LlmCallResult
{
    public LlmResultRow? Result { get; init; }
    public string? Error { get; init; }
    public bool Success => Result is not null;
}

public sealed record SemanticVectorRow
{
    public long VectorId { get; init; }
    public long SourceId { get; init; }
    public long? DofId { get; init; }
    public string? Title { get; init; }
    public string? SummaryText { get; init; }
    public bool IsCritical { get; init; }
    public string VectorJson { get; init; } = string.Empty;
}

public sealed record SemanticMatch
{
    public long SourceId { get; init; }
    public long? DofId { get; init; }
    public string Title { get; init; } = "Gecmis kayit";
    public double Similarity { get; init; }
    public bool IsCritical { get; init; }
}

public sealed record DofRecordRow
{
    public long DofId { get; init; }
    public string? DofImza { get; init; }
    public string Baslik { get; init; } = string.Empty;
    public string? Aciklama { get; init; }
    public string? KaynakAnahtar { get; init; }
    public int RiskSeviyesi { get; init; }
    public string Durum { get; init; } = string.Empty;
}
