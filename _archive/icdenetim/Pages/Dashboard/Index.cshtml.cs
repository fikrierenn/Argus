using BkmArgus.Models;
using BkmArgus.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Dashboard;

public class IndexModel : PageModel
{
    private readonly IDashboardService _dashboard;

    public IndexModel(IDashboardService dashboard) => _dashboard = dashboard;

    public ActionSummary Actions { get; set; } = new();
    public double AvgResolutionDays { get; set; }
    public List<LocationRisk> RiskiestLocations { get; set; } = [];
    public List<RepeatedFinding> RepeatedFindings { get; set; } = [];
    public List<MonthlyScore> ScoreTrend { get; set; } = [];
    public List<DepartmentRisk> DepartmentRisks { get; set; } = [];
    public List<AiAlert> RecentAlerts { get; set; } = [];

    public async Task OnGetAsync()
    {
        var t1 = _dashboard.GetCorrectiveActionSummaryAsync();
        var t2 = _dashboard.GetAverageResolutionTimeAsync();
        var t3 = _dashboard.GetRiskiestLocationsAsync();
        var t4 = _dashboard.GetMostRepeatedFindingsAsync();
        var t5 = _dashboard.GetScoreTrendAsync();
        var t6 = _dashboard.GetDepartmentRisksAsync();
        var t7 = _dashboard.GetRecentAiAlertsAsync();

        await Task.WhenAll(t1, t2, t3, t4, t5, t6, t7);

        Actions = t1.Result;
        AvgResolutionDays = t2.Result;
        RiskiestLocations = t3.Result;
        RepeatedFindings = t4.Result;
        ScoreTrend = t5.Result;
        DepartmentRisks = t6.Result;
        RecentAlerts = t7.Result;
    }
}
