namespace BkmArgus.Tests;

public class RiskEscalationTests
{
    /// <summary>
    /// Risk escalation formula:
    /// EscalatedScore = BaseRisk * (1 + RepeatCount * 0.15) * (IsSystemic ? 1.3 : 1.0)
    /// </summary>
    [Theory]
    [InlineData(6, 0, false, 6.0)]
    [InlineData(6, 3, false, 8.7)]
    [InlineData(6, 3, true, 11.31)]
    [InlineData(10, 0, true, 13.0)]
    [InlineData(15, 5, true, 34.125)]
    [InlineData(0, 10, true, 0.0)]
    [InlineData(25, 0, false, 25.0)]
    [InlineData(1, 1, false, 1.15)]
    public void CalculateEscalation_ReturnsExpected(
        int baseRisk, int repeatCount, bool isSystemic, double expected)
    {
        var result = CalculateEscalation(baseRisk, repeatCount, isSystemic);
        Assert.Equal(expected, result, precision: 2);
    }

    [Fact]
    public void CalculateEscalation_ZeroBaseRisk_AlwaysZero()
    {
        Assert.Equal(0.0, CalculateEscalation(0, 5, true), precision: 2);
    }

    [Fact]
    public void CalculateEscalation_SystemicMultiplier_Is1Point3()
    {
        var withSystemic = CalculateEscalation(10, 0, true);
        var withoutSystemic = CalculateEscalation(10, 0, false);
        Assert.Equal(1.3, withSystemic / withoutSystemic, precision: 2);
    }

    [Fact]
    public void CalculateEscalation_EachRepeat_Adds15Percent()
    {
        var zero = CalculateEscalation(10, 0, false);
        var one = CalculateEscalation(10, 1, false);
        Assert.Equal(1.5, one - zero, precision: 2);
    }

    private static double CalculateEscalation(int baseRisk, int repeatCount, bool isSystemic)
    {
        return baseRisk * (1.0 + repeatCount * 0.15) * (isSystemic ? 1.3 : 1.0);
    }
}
