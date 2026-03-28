using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Web.Features;

public class DofModel : PageModel
{
    private static readonly IReadOnlyList<string> ColumnList = new[]
    {
        "Taslak",
        "Acik",
        "Incelemede",
        "Kapandi"
    };

    public IReadOnlyList<string> Columns => ColumnList;
    public IReadOnlyList<DofCard> Cards { get; private set; } = Array.Empty<DofCard>();

    public void OnGet()
    {
        Cards = new List<DofCard>
        {
            new(501, 101, "Girissiz satis kontrolu", "Mekan-4477", "Urun-1120", "F. Yilmaz", "Taslak", "2 gun", "Kritik"),
            new(502, 103, "Sayim duzeltme sapmasi", "Mekan-12", "Urun-88", "S. Kara", "Acik", "5 gun", "Yuksek"),
            new(503, 104, "Iade orani artisi", "Mekan-18", "Urun-912", "E. Demir", "Acik", "8 gun", "Orta"),
            new(504, 105, "Net birikim kontrolu", "Mekan-22", "Urun-508", "T. Aydin", "Incelemede", "3 gun", "Yuksek"),
            new(505, 101, "Stok yok uyari", "Mekan-4477", "Urun-1120", "F. Yilmaz", "Kapandi", "0 gun", "Kritik")
        };
    }

    public IEnumerable<DofCard> CardsByStatus(string status) =>
        Cards.Where(card => string.Equals(card.Durum, status, StringComparison.OrdinalIgnoreCase));

    public int CountByStatus(string status) =>
        Cards.Count(card => string.Equals(card.Durum, status, StringComparison.OrdinalIgnoreCase));

    public record DofCard(
        int Id,
        int UrunId,
        string Baslik,
        string Mekan,
        string Urun,
        string Sorumlu,
        string Durum,
        string SLA,
        string Seviye);
}
