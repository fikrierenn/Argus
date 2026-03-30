using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using BkmArgus.Web.Services;

namespace BkmArgus.Web.Features.Audit;

public class ReportsModel : PageModel
{
    private readonly SqlDb _db;
    private readonly ExcelExportService _export;

    public ReportsModel(SqlDb db, ExcelExportService export)
    {
        _db = db;
        _export = export;
    }

    [BindProperty(SupportsGet = true)] public string? Tab { get; set; }
    [BindProperty(SupportsGet = true)] public string? Location { get; set; }

    public IReadOnlyList<ScorecardRow> Scorecards { get; private set; } = Array.Empty<ScorecardRow>();
    public IReadOnlyList<TrendRow> Trends { get; private set; } = Array.Empty<TrendRow>();
    public IReadOnlyList<RepeatingRow> Repeating { get; private set; } = Array.Empty<RepeatingRow>();
    public IReadOnlyList<SystemicRow> Systemic { get; private set; } = Array.Empty<SystemicRow>();

    public async Task OnGetAsync()
    {
        Tab = string.IsNullOrWhiteSpace(Tab) ? "karne" : Tab.ToLowerInvariant();

        Scorecards = await _db.QueryAsync<ScorecardRow>("audit.sp_Report_Scorecard", new
        {
            MagazaAdi = Location,
            BaslangicTarihi = (DateTime?)null,
            BitisTarihi = (DateTime?)null
        });

        if (Tab == "trend")
        {
            Trends = await _db.QueryAsync<TrendRow>("audit.sp_Report_MonthlyTrend", new
            {
                MagazaAdi = Location,
                AySayisi = 12
            });
        }
        else if (Tab == "tekrar")
        {
            Repeating = await _db.QueryAsync<RepeatingRow>("audit.sp_Report_RepeatingFindings", new
            {
                MinTekrar = 2,
                Ust = 20
            });
        }
        else if (Tab == "sistemik")
        {
            Systemic = await _db.QueryAsync<SystemicRow>("audit.sp_Report_SystemicFindings");
        }
    }

    public async Task<IActionResult> OnGetExportAsync()
    {
        var tab = string.IsNullOrWhiteSpace(Tab) ? "karne" : Tab.ToLowerInvariant();

        if (tab == "karne")
        {
            var data = await _db.QueryAsync<ScorecardRow>("audit.sp_Report_Scorecard", new
            {
                MagazaAdi = Location,
                BaslangicTarihi = (DateTime?)null,
                BitisTarihi = (DateTime?)null
            });

            var bytes = _export.Export(data, "Denetim Karnesi", new Dictionary<string, Func<ScorecardRow, object?>>
            {
                ["Magaza"] = r => r.LocationName,
                ["Denetim Sayisi"] = r => r.AuditCount,
                ["Ort. Uyum (%)"] = r => r.AvgComplianceRate,
                ["Son Denetim"] = r => r.LastAuditDate,
                ["Son Uyum (%)"] = r => r.LastComplianceRate
            });

            return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"denetim_karnesi_{DateTime.Today:yyyyMMdd}.xlsx");
        }
        else if (tab == "trend")
        {
            var data = await _db.QueryAsync<TrendRow>("audit.sp_Report_MonthlyTrend", new
            {
                MagazaAdi = Location,
                AySayisi = 12
            });

            var bytes = _export.Export(data, "Aylik Trend", new Dictionary<string, Func<TrendRow, object?>>
            {
                ["Yil"] = r => r.Year,
                ["Ay"] = r => r.Month,
                ["Denetim Sayisi"] = r => r.AuditCount,
                ["Ort. Uyum (%)"] = r => r.AvgComplianceRate
            });

            return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"aylik_trend_{DateTime.Today:yyyyMMdd}.xlsx");
        }
        else if (tab == "tekrar")
        {
            var data = await _db.QueryAsync<RepeatingRow>("audit.sp_Report_RepeatingFindings", new
            {
                MinTekrar = 2,
                Ust = 20
            });

            var bytes = _export.Export(data, "Tekrar Eden Bulgular", new Dictionary<string, Func<RepeatingRow, object?>>
            {
                ["Madde Metni"] = r => r.ItemText,
                ["Basarisizlik"] = r => r.TotalFailures,
                ["Magaza Sayisi"] = r => r.DistinctLocationCount,
                ["Denetim Sayisi"] = r => r.DistinctAuditCount,
                ["Ort. Risk"] = r => r.AvgRiskScore,
                ["Sistemik"] = r => r.IsSystemic
            });

            return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"tekrar_eden_bulgular_{DateTime.Today:yyyyMMdd}.xlsx");
        }
        else if (tab == "sistemik")
        {
            var data = await _db.QueryAsync<SystemicRow>("audit.sp_Report_SystemicFindings");

            var bytes = _export.Export(data, "Sistemik Bulgular", new Dictionary<string, Func<SystemicRow, object?>>
            {
                ["Madde Metni"] = r => r.ItemText,
                ["Magaza Sayisi"] = r => r.DistinctLocationCount,
                ["Toplam Basarisizlik"] = r => r.TotalFailures,
                ["Son Gorulme"] = r => r.LastSeenDate
            });

            return File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"sistemik_bulgular_{DateTime.Today:yyyyMMdd}.xlsx");
        }

        return RedirectToPage();
    }

    public sealed record ScorecardRow
    {
        public string LocationName { get; init; } = "";
        public int AuditCount { get; init; }
        public decimal AvgComplianceRate { get; init; }
        public DateTime? LastAuditDate { get; init; }
        public decimal LastComplianceRate { get; init; }
    }

    public sealed record TrendRow
    {
        public int Year { get; init; }
        public int Month { get; init; }
        public int AuditCount { get; init; }
        public decimal AvgComplianceRate { get; init; }
    }

    public sealed record RepeatingRow
    {
        public string ItemText { get; init; } = "";
        public int TotalFailures { get; init; }
        public int DistinctLocationCount { get; init; }
        public int DistinctAuditCount { get; init; }
        public decimal AvgRiskScore { get; init; }
        public bool IsSystemic { get; init; }
    }

    public sealed record SystemicRow
    {
        public string ItemText { get; init; } = "";
        public int DistinctLocationCount { get; init; }
        public int TotalFailures { get; init; }
        public DateTime? LastSeenDate { get; init; }
    }
}
