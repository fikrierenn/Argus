using System.Text.Json;

namespace BkmArgus.AiWorker;

public sealed class LmRules
{
    public RuleDecision Decide(RiskSummaryRow risk)
    {
        var root = ResolveRootCause(risk);
        var plan = ResolveEvidencePlan(risk);
        var llm = risk.RiskScore >= 90 || risk.FlagDataQuality || risk.FlagHighCountAdjustment;

        var features = new
        {
            risk.RiskScore,
            risk.FlagDataQuality,
            risk.FlagSalesWithoutEntry,
            risk.FlagDeadStock,
            risk.FlagNetAccumulation,
            risk.FlagHighReturn,
            risk.FlagHighDamagedReturn,
            risk.FlagHighCountAdjustment,
            risk.FlagHighInternalUse,
            risk.FlagFastTurnover,
            risk.FlagSalesAging
        };

        return new RuleDecision
        {
            RootCauseClass = root,
            EvidencePlan = plan,
            LlmRequired = llm,
            PriorityScore = Math.Clamp(risk.RiskScore, 0, 100),
            BriefSummary = risk.RiskComment,
            FeatureJson = JsonSerializer.Serialize(features)
        };
    }

    private static string ResolveRootCause(RiskSummaryRow risk)
    {
        if (risk.FlagDataQuality) return "VERI_KALITE";
        if (risk.FlagSalesWithoutEntry) return "GIRISSIZ_SATIS";
        if (risk.FlagHighCountAdjustment) return "SAYIM_DUZELTME";
        if (risk.FlagHighReturn) return "IADE_SICRAMA";
        if (risk.FlagFastTurnover) return "HIZLI_DEVIR";
        if (risk.FlagSalesAging) return "SATIS_YASLANMA";
        if (risk.FlagDeadStock) return "OLU_STOK";
        if (risk.FlagNetAccumulation) return "NET_BIRIKIM";
        return "DIGER";
    }

    private static string ResolveEvidencePlan(RiskSummaryRow risk)
    {
        if (risk.RiskScore >= 90)
        {
            return "FULL";
        }

        if (risk.FlagDataQuality || risk.FlagSalesWithoutEntry || risk.FlagHighCountAdjustment)
        {
            return "MOVE50";
        }

        return "BASIC";
    }
}
