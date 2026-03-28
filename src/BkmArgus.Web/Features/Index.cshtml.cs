using System.Globalization;
using BkmArgus.Web.Data;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class IndexModel : PageModel
{
    private static readonly CultureInfo TrCulture = CultureInfo.GetCultureInfo("tr-TR");
    private readonly SqlDb _db;

    public IReadOnlyList<QuickStatus> StatusCards { get; private set; } = Array.Empty<QuickStatus>();
    public IReadOnlyList<string> QuickNotes { get; private set; } = Array.Empty<string>();

    public IndexModel(SqlDb db)
    {
        _db = db;
    }

    public async Task OnGetAsync()
    {
        var kpis = await _db.QueryAsync<KpiRow>("rpt.sp_GenelBakis_Kpi");
        StatusCards = kpis
            .Select(kpi => new QuickStatus(
                kpi.Baslik,
                FormatNumber(kpi.Deger),
                kpi.NotAciklama,
                kpi.Tone))
            .ToList();

        var notes = await _db.QueryAsync<NoteRow>("rpt.sp_GenelBakis_Not");
        QuickNotes = notes.Select(n => n.Metin).ToList();
    }

    private static string FormatNumber(int value) => value.ToString("N0", TrCulture);

    public record QuickStatus(string Baslik, string Deger, string Not, string Tone);

    public sealed record KpiRow
    {
        public string Baslik { get; init; } = string.Empty;
        public int Deger { get; init; }
        public string NotAciklama { get; init; } = string.Empty;
        public string Tone { get; init; } = string.Empty;
    }

    public sealed record NoteRow
    {
        public string Metin { get; init; } = string.Empty;
    }
}
