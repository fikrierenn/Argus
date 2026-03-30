using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Yonetim;

public class IndexModel : PageModel
{
    private readonly SqlDb _db;
    private int? CurrentUserId => 1;

    public IndexModel(SqlDb db)
    {
        _db = db;
    }

    public EntegrasyonDurum Durum { get; private set; } = new();
    public IReadOnlyList<EntegrasyonLogRow> Loglar { get; private set; } = Array.Empty<EntegrasyonLogRow>();
    public IReadOnlyList<EslemeRow> Eslemeler { get; private set; } = Array.Empty<EslemeRow>();
    public string? StatusMessage => TempData["StatusMessage"] as string;

    public async Task OnGetAsync()
    {
        await LoadAsync();
    }

    public async Task<IActionResult> OnPostKapatAsync(long baglantiId)
    {
        if (baglantiId <= 0)
        {
            TempData["StatusMessage"] = "Esleme bulunamadi.";
            return RedirectToPage();
        }

        await _db.ExecuteAsync(
            "ref.sp_UserPersonnelLink_Close",
            new
            {
                BaglantiId = baglantiId,
                KullaniciId = CurrentUserId,
                Aciklama = "Gun sonu kapatildi"
            });

        TempData["StatusMessage"] = "Esleme kapatildi.";
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostGunSonuKapatAsync()
    {
        await _db.ExecuteAsync(
            "ref.sp_UserPersonnelLink_CloseAll",
            new
            {
                KullaniciId = CurrentUserId,
                Aciklama = "Gun sonu kapatildi"
            });

        TempData["StatusMessage"] = "Gun sonu kapatma tamamlandi.";
        return RedirectToPage();
    }

    private async Task LoadAsync()
    {
        var durumRow = await _db.QuerySingleAsync<EntegrasyonDurumRaw>("log.sp_PersonnelSync_Summary");
        Durum = durumRow is null
            ? new EntegrasyonDurum
            {
                KaynakSistem = "-",
                SonCalisma = "-",
                SonrakiCalisma = "-",
                Toplam = 0,
                Eklenen = 0,
                Guncellenen = 0,
                PasifEdilen = 0
            }
            : new EntegrasyonDurum
            {
                KaynakSistem = durumRow.KaynakSistem ?? "-",
                SonCalisma = FormatDateTime(durumRow.SonCalisma),
                SonrakiCalisma = FormatDateTime(durumRow.SonrakiCalisma),
                Toplam = durumRow.Toplam ?? 0,
                Eklenen = durumRow.Eklenen ?? 0,
                Guncellenen = durumRow.Guncellenen ?? 0,
                PasifEdilen = durumRow.PasifEdilen ?? 0
            };

        var logRows = await _db.QueryAsync<EntegrasyonLogRaw>(
            "log.sp_PersonnelSync_Log_List",
            new { Top = 10 });

        Loglar = logRows
            .Select(row => new EntegrasyonLogRow(
                FormatDateTime(row.Tarih),
                row.Durum ?? "-",
                row.Toplam ?? 0,
                row.NotAciklama))
            .ToList();

        var eslemeRows = await _db.QueryAsync<EslemeRaw>("ref.sp_UserPersonnelLink_List");

        Eslemeler = eslemeRows
            .Select(row => new EslemeRow(
                row.BaglantiId,
                row.KullaniciAdi ?? "-",
                row.PersonelAd ?? "-",
                string.IsNullOrWhiteSpace(row.RolKodu) ? "-" : row.RolKodu,
                FormatDateTime(row.BaslangicTarihi),
                row.AktifMi))
            .ToList();
    }

    private static string FormatDateTime(DateTime? value)
    {
        return value.HasValue ? value.Value.ToString("yyyy-MM-dd HH:mm") : "-";
    }

    private sealed class EntegrasyonDurumRaw
    {
        public string? KaynakSistem { get; init; }
        public DateTime? SonCalisma { get; init; }
        public DateTime? SonrakiCalisma { get; init; }
        public int? Toplam { get; init; }
        public int? Eklenen { get; init; }
        public int? Guncellenen { get; init; }
        public int? PasifEdilen { get; init; }
    }

    private sealed record EntegrasyonLogRaw(DateTime? Tarih, string? Durum, int? Toplam, string? NotAciklama);
    private sealed record EslemeRaw(long BaglantiId, string? KullaniciAdi, string? PersonelAd, string? RolKodu, DateTime? BaslangicTarihi, bool AktifMi);

    public class EntegrasyonDurum
    {
        public string KaynakSistem { get; set; } = string.Empty;
        public string SonCalisma { get; set; } = string.Empty;
        public string SonrakiCalisma { get; set; } = string.Empty;
        public int Toplam { get; set; }
        public int Eklenen { get; set; }
        public int Guncellenen { get; set; }
        public int PasifEdilen { get; set; }
    }

    public record EntegrasyonLogRow(string Tarih, string Durum, int Toplam, string? Not);
    public record EslemeRow(long BaglantiId, string Kullanici, string Personel, string Rol, string Baslangic, bool AktifMi);
}
