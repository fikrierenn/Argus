using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;
using BkmArgus.Web.Domain;

namespace BkmArgus.Web.Features.Dof;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;
    public IndexModel(SqlDb db) => _db = db;

    /// <summary>Panonun cektigi kayit siniri — kirpma uyarisi bunu gosterir.</summary>
    public const int Limit = 100;

    public IReadOnlyList<FindingRow> Findings { get; private set; } = Array.Empty<FindingRow>();
    public DofKpiRow? Kpi { get; private set; }

    /// <summary>
    /// KPI satiri GERCEKTEN geldi mi. `Kpi` bos nesneye dusurulunce butun
    /// sayilar 0 oluyor ve "SLA geciken 0" YESIL gorunuyordu — veri yoklugu
    /// iyi haber olarak sunuluyordu (denetim bulgusu 3.3).
    /// </summary>
    public bool KpiVar { get; private set; }

    /// <summary>Liste sinira dayandi mi — dayandiysa gecikmis bulgular dusmus olabilir.</summary>
    public bool Kirpildi => Findings.Count >= Limit;

    // Kanban kolonlari — durum kodlari DofStatus sabitlerinden (magic string yasagi)
    public IEnumerable<FindingRow> Draft => Findings.Where(f => f.Status == DofStatus.Taslak);
    public IEnumerable<FindingRow> Open => Findings.Where(f => f.Status == DofStatus.Acik);
    public IEnumerable<FindingRow> InProgress => Findings.Where(f => f.Status == DofStatus.DevamEdiyor);
    public IEnumerable<FindingRow> PendingValidation => Findings.Where(f => f.Status == DofStatus.OnayBekliyor);
    public IEnumerable<FindingRow> Closed => Findings.Where(f => DofStatus.AkisBitti(f.Status));

    public async Task OnGetAsync()
    {
        Findings = await _db.QueryAsync<FindingRow>("dof.sp_Finding_List", new { Top = Limit });

        // Is kurali: KPI satiri yoksa uydurma sifir uretilmez, "veri yok" denir.
        var kpi = await _db.QuerySingleAsync<DofKpiRow>("dof.sp_Finding_Dashboard");
        KpiVar = kpi is not null;
        Kpi = kpi;
    }

    public sealed record FindingRow
    {
        public long DofId { get; init; }
        public string Title { get; init; } = "";
        public string? Description { get; init; }
        public int RiskLevel { get; init; }
        public string Status { get; init; } = "";
        public string? AssignedTo { get; init; }
        public DateTime? SlaDueDate { get; init; }
        public string? FindingSignature { get; init; }
        public DateTime CreatedAt { get; init; }

        public string RiskLabel => RiskLevel switch
        {
            >= 5 => "Kritik",
            >= 4 => "Yuksek",
            >= 3 => "Orta",
            _ => "Dusuk"
        };

        public int SlaDaysLeft => SlaDueDate.HasValue
            ? (int)(SlaDueDate.Value.Date - DateTime.Today).TotalDays
            : 0;
    }

    public sealed record DofKpiRow
    {
        public int TotalCount { get; init; }
        public int DraftCount { get; init; }
        public int OpenCount { get; init; }
        public int InProgressCount { get; init; }
        public int PendingValidationCount { get; init; }
        public int ClosedCount { get; init; }
        public int RejectedCount { get; init; }
        public int OverdueCount { get; init; }
        public decimal AvgResolutionDays { get; init; }
    }
}
