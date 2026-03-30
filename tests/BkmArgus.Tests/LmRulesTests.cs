using BkmArgus.AiWorker;

namespace BkmArgus.Tests;

public class LmRulesTests
{
    private readonly LmRules _rules = new();

    // --- LlmRequired tests ---

    [Fact]
    public void Decide_HighRiskScore_RequiresLlm()
    {
        var risk = CreateRisk(riskScore: 95);
        var decision = _rules.Decide(risk);
        Assert.True(decision.LlmRequired);
    }

    [Fact]
    public void Decide_RiskScoreExactly90_RequiresLlm()
    {
        var risk = CreateRisk(riskScore: 90);
        var decision = _rules.Decide(risk);
        Assert.True(decision.LlmRequired);
    }

    [Fact]
    public void Decide_LowRiskScore_NoLlm()
    {
        var risk = CreateRisk(riskScore: 50);
        var decision = _rules.Decide(risk);
        Assert.False(decision.LlmRequired);
    }

    [Fact]
    public void Decide_RiskScore89_NoLlm()
    {
        var risk = CreateRisk(riskScore: 89);
        var decision = _rules.Decide(risk);
        Assert.False(decision.LlmRequired);
    }

    [Fact]
    public void Decide_FlagDataQuality_RequiresLlm()
    {
        var risk = CreateRisk(riskScore: 10, flagDataQuality: true);
        var decision = _rules.Decide(risk);
        Assert.True(decision.LlmRequired);
    }

    [Fact]
    public void Decide_FlagHighCountAdjustment_RequiresLlm()
    {
        var risk = CreateRisk(riskScore: 10, flagHighCountAdjustment: true);
        var decision = _rules.Decide(risk);
        Assert.True(decision.LlmRequired);
    }

    // --- RootCauseClass tests (priority order) ---

    [Fact]
    public void Decide_FlagDataQuality_ClassifiesVeriKalite()
    {
        var risk = CreateRisk(flagDataQuality: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("VERI_KALITE", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagSalesWithoutEntry_ClassifiesGirissizSatis()
    {
        var risk = CreateRisk(flagSalesWithoutEntry: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("GIRISSIZ_SATIS", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagHighCountAdjustment_ClassifiesSayimDuzeltme()
    {
        var risk = CreateRisk(flagHighCountAdjustment: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("SAYIM_DUZELTME", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagHighReturn_ClassifiesIadeSicrama()
    {
        var risk = CreateRisk(flagHighReturn: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("IADE_SICRAMA", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagFastTurnover_ClassifiesHizliDevir()
    {
        var risk = CreateRisk(flagFastTurnover: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("HIZLI_DEVIR", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagSalesAging_ClassifiesSatisYaslanma()
    {
        var risk = CreateRisk(flagSalesAging: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("SATIS_YASLANMA", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagDeadStock_ClassifiesOluStok()
    {
        var risk = CreateRisk(flagDeadStock: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("OLU_STOK", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_FlagNetAccumulation_ClassifiesNetBirikim()
    {
        var risk = CreateRisk(flagNetAccumulation: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("NET_BIRIKIM", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_NoFlags_ClassifiesDiger()
    {
        var risk = CreateRisk();
        var decision = _rules.Decide(risk);
        Assert.Equal("DIGER", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_DataQualityTakesPriorityOverSalesWithoutEntry()
    {
        var risk = CreateRisk(flagDataQuality: true, flagSalesWithoutEntry: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("VERI_KALITE", decision.RootCauseClass);
    }

    [Fact]
    public void Decide_SalesWithoutEntryTakesPriorityOverHighReturn()
    {
        var risk = CreateRisk(flagSalesWithoutEntry: true, flagHighReturn: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("GIRISSIZ_SATIS", decision.RootCauseClass);
    }

    // --- EvidencePlan tests ---

    [Fact]
    public void Decide_RiskScore90Plus_EvidencePlanFull()
    {
        var risk = CreateRisk(riskScore: 95);
        var decision = _rules.Decide(risk);
        Assert.Equal("FULL", decision.EvidencePlan);
    }

    [Fact]
    public void Decide_FlagDataQuality_EvidencePlanMove50()
    {
        var risk = CreateRisk(riskScore: 50, flagDataQuality: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("MOVE50", decision.EvidencePlan);
    }

    [Fact]
    public void Decide_FlagSalesWithoutEntry_EvidencePlanMove50()
    {
        var risk = CreateRisk(riskScore: 50, flagSalesWithoutEntry: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("MOVE50", decision.EvidencePlan);
    }

    [Fact]
    public void Decide_FlagHighCountAdjustment_EvidencePlanMove50()
    {
        var risk = CreateRisk(riskScore: 50, flagHighCountAdjustment: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("MOVE50", decision.EvidencePlan);
    }

    [Fact]
    public void Decide_LowRiskNoSpecialFlags_EvidencePlanBasic()
    {
        var risk = CreateRisk(riskScore: 30, flagHighReturn: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("BASIC", decision.EvidencePlan);
    }

    [Fact]
    public void Decide_HighRiskOverridesMove50Flags_EvidencePlanFull()
    {
        var risk = CreateRisk(riskScore: 95, flagDataQuality: true);
        var decision = _rules.Decide(risk);
        Assert.Equal("FULL", decision.EvidencePlan);
    }

    // --- PriorityScore tests ---

    [Theory]
    [InlineData(50, 50)]
    [InlineData(0, 0)]
    [InlineData(100, 100)]
    [InlineData(-5, 0)]
    [InlineData(150, 100)]
    public void Decide_PriorityScore_ClampedTo0And100(int riskScore, int expectedPriority)
    {
        var risk = CreateRisk(riskScore: riskScore);
        var decision = _rules.Decide(risk);
        Assert.Equal(expectedPriority, decision.PriorityScore);
    }

    // --- BriefSummary test ---

    [Fact]
    public void Decide_BriefSummary_EqualsRiskComment()
    {
        var risk = CreateRisk(riskScore: 50);
        var decision = _rules.Decide(risk);
        Assert.Equal("Test comment", decision.BriefSummary);
    }

    // --- FeatureJson test ---

    [Fact]
    public void Decide_FeatureJson_IsNotNullOrEmpty()
    {
        var risk = CreateRisk(riskScore: 50);
        var decision = _rules.Decide(risk);
        Assert.False(string.IsNullOrEmpty(decision.FeatureJson));
        Assert.Contains("\"RiskScore\":50", decision.FeatureJson);
    }

    // --- Helper ---

    private static RiskSummaryRow CreateRisk(
        int riskScore = 50,
        bool flagDataQuality = false,
        bool flagSalesWithoutEntry = false,
        bool flagDeadStock = false,
        bool flagNetAccumulation = false,
        bool flagHighReturn = false,
        bool flagHighDamagedReturn = false,
        bool flagHighCountAdjustment = false,
        bool flagHighInternalUse = false,
        bool flagFastTurnover = false,
        bool flagSalesAging = false)
    {
        return new RiskSummaryRow
        {
            SnapshotDate = DateTime.UtcNow,
            PeriodCode = "2026-03",
            LocationId = 1,
            MekanAd = "Test Mekan",
            ProductId = 100,
            UrunKod = "TST001",
            UrunAd = "Test Urun",
            RiskScore = riskScore,
            RiskComment = "Test comment",
            FlagDataQuality = flagDataQuality,
            FlagSalesWithoutEntry = flagSalesWithoutEntry,
            FlagDeadStock = flagDeadStock,
            FlagNetAccumulation = flagNetAccumulation,
            FlagHighReturn = flagHighReturn,
            FlagHighDamagedReturn = flagHighDamagedReturn,
            FlagHighCountAdjustment = flagHighCountAdjustment,
            FlagHighInternalUse = flagHighInternalUse,
            FlagFastTurnover = flagFastTurnover,
            FlagSalesAging = flagSalesAging
        };
    }
}
