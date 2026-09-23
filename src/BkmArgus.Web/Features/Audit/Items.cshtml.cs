using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Audit;

/// <summary>
/// Master denetim maddesi katalogu (plan 08).
///
/// Bu katalog saha denetciSinin doldurdugu kontrol listesinin SABLONUDUR:
/// buradaki her madde, acilan her yeni denetime kopyalanir
/// (sql/21_sps_audit.sql snapshot seed). Yani bir maddenin etkisini
/// degistirmek GELECEKTEKI tum denetimlerin risk agirligini degistirir —
/// gecmis denetimler snapshot oldugu icin etkilenmez.
///
/// YETKI: Policies.AdminOnly (.cshtml basinda). Karar 2026-09-23, gerekcesi
/// denetim-surec-danismani turu: denetciNin kendi olctugu cetveli
/// degistirebilmesi denetlenebilirligi kaldirir ("gecen ay bu madde neden
/// dusuk skorluydu?" sorusunun cevabi kalmaz). Denetcinin saha ihtiyaci
/// katalogdan degil bulgu / Remark kanalindan karsilanir; katalogu denetim
/// ortasinda degistirmek ayni donemde yapilan denetimleri farkli listeyle
/// olcer ve MEKAN KARSILASTIRMASINI bozar.
/// </summary>
public sealed class ItemsModel(SqlDb db) : PageModel
{
    [BindProperty(SupportsGet = true)] public string? Group { get; set; }
    [BindProperty(SupportsGet = true)] public bool? Aktif { get; set; }
    [BindProperty] public ItemInput Input { get; set; } = new();
    [BindProperty(SupportsGet = true)] public int? EditId { get; set; }

    public IReadOnlyList<ItemRow> Items { get; private set; } = Array.Empty<ItemRow>();
    public IReadOnlyList<string> Groups { get; private set; } = Array.Empty<string>();

    public async Task OnGetAsync()
    {
        await LoadAsync();
        if (!EditId.HasValue) return;

        ItemRow? item;
        try
        {
            item = await db.QuerySingleAsync<ItemRow>("audit.sp_Item_Get", new { ItemId = EditId.Value });
        }
        catch (SqlException)
        {
            // Olmayan EditId ile gelinirse sp_Item_Get hata firlatir ve bu
            // cagri SpCalistir koprusunun DISINDA oldugu icin islenmemis bir
            // 500 uretiyordu — elle duzenlenmis bir URL sayfayi cokertiyordu
            // (sql-sp-reviewer bulgusu 2026-09-23). Liste zaten yuklendi;
            // kullanici "yeni madde" kipinde devam eder.
            TempData["Error"] = "Madde bulunamadi.";
            EditId = null;
            return;
        }

        if (item is null)
        {
            TempData["Error"] = "Madde bulunamadi.";
            EditId = null;
            return;
        }

        Input = new ItemInput
        {
            AuditGroup = item.AuditGroup,
            Area = item.Area,
            RiskType = item.RiskType,
            ItemText = item.ItemText,
            SortOrder = item.SortOrder,
            FindingType = item.FindingType,
            Probability = item.Probability,
            Impact = item.Impact
        };
    }

    /// <summary>Yeni madde ekler. Dogrulama gecmeden SP'ye gidilmez.</summary>
    public async Task<IActionResult> OnPostCreateAsync()
    {
        // Is kurali: gecersiz girdi SP'ye ULASMAZ. Eskiden hic kontrol yoktu;
        // bos madde metni ve sinir disi olasilik/etki dogrudan kaydediliyordu.
        if (!ModelState.IsValid)
        {
            await LoadAsync();
            return Page();
        }

        return await SpCalistir(
            () => db.ExecuteAsync("audit.sp_Item_Insert", new
            {
                LocationType = "Store",
                Input.AuditGroup,
                Input.Area,
                Input.RiskType,
                Input.ItemText,
                Input.SortOrder,
                Input.FindingType,
                Input.Probability,
                Input.Impact,
                SkillId = (int?)null,
                KullaniciId = KullaniciId()
            }),
            "Madde eklendi.");
    }

    /// <summary>Mevcut maddeyi gunceller. Dogrulama gecmeden SP'ye gidilmez.</summary>
    public async Task<IActionResult> OnPostUpdateAsync(int itemId)
    {
        // Is kurali: gecersiz girdi SP'ye ULASMAZ (bkz. OnPostCreateAsync).
        // EditId geri yazilir, yoksa hatali form "yeni madde" kipinde acilir
        // ve kullanici duzenledigi kaydi kaybeder.
        if (!ModelState.IsValid)
        {
            EditId = itemId;
            await LoadAsync();
            return Page();
        }

        return await SpCalistir(
            () => db.ExecuteAsync("audit.sp_Item_Update", new
            {
                ItemId = itemId,
                // LocationType NULL GONDERILIYOR ve bu bilincli: SP'de
                // COALESCE(@LocationType, LocationType) var, yani NULL =
                // "bu alani degistirme". Eskiden burada sabit "Store"
                // yaziyordu ve ekranda bu alan HIC yok — yani 'Both' ya da
                // 'Cafe' bir madde duzenlenince sessizce 'Store'a daralir,
                // sp_Result_StartAudit'in LocationType suzgeci yuzunden Kafe
                // denetimlerinden DUSERDI. Kullanici sadece metnini duzeltip
                // maddeyi kaybederdi. (sql-sp-reviewer bulgusu 2026-09-23.)
                LocationType = (string?)null,
                Input.AuditGroup,
                Input.Area,
                Input.RiskType,
                Input.ItemText,
                Input.SortOrder,
                Input.FindingType,
                Input.Probability,
                Input.Impact,
                SkillId = (int?)null,
                KullaniciId = KullaniciId()
            }),
            "Madde guncellendi.");
    }

    /// <summary>
    /// Maddeyi pasife alir ya da geri acar. SERT SILME YOK: silinen bir
    /// maddenin gecmis denetim sonuclari sahipsiz kalir ve "bu sonuc hangi
    /// maddeydi" sorusu cevapsizlasir.
    /// </summary>
    public async Task<IActionResult> OnPostSetActiveAsync(int itemId, bool aktif)
    {
        return await SpCalistir(
            () => db.ExecuteAsync("audit.sp_Item_SetActive", new
            {
                ItemId = itemId,
                Aktif = aktif,
                KullaniciId = KullaniciId()
            }),
            aktif ? "Madde yeniden etkinlestirildi." : "Madde pasife alindi.");
    }

    /// <summary>
    /// SP cagrisini calistirir ve hata koprusunu tek yerde kurar.
    /// SP 50000-59999 arasinda THROW ederse mesaj Turkce bir IS KURALIDIR ve
    /// kullaniciya gosterilir; digerleri sistem hatasidir, mesaji sizdirilmez
    /// (error-handling.md).
    /// </summary>
    private async Task<IActionResult> SpCalistir(Func<Task> cagri, string basariMesaji)
    {
        try
        {
            await cagri();
            TempData["StatusMessage"] = basariMesaji;
        }
        catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
        {
            TempData["Error"] = sqlEx.Message;
        }
        catch (SqlException)
        {
            TempData["Error"] = "Veritabani isleminde hata olustu.";
        }

        return RedirectToPage(new { Group, Aktif });
    }

    private async Task LoadAsync()
    {
        Items = await db.QueryAsync<ItemRow>("audit.sp_Item_List", new
        {
            LocationType = (string?)null,
            AuditGroup = Group,
            IsActive = Aktif
        });

        // Grup listesi GORUNEN maddelerden turetiliyor. Pasif suzgeci
        // acikken grup secenekleri de daralir — istenen davranis budur,
        // aksi halde secilince bos liste veren grup gosterilir.
        Groups = Items.Select(i => i.AuditGroup ?? "")
                      .Where(g => g != "")
                      .Distinct()
                      .OrderBy(g => g)
                      .ToList();
    }

    private int? KullaniciId() =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var uid) ? uid : null;

    /// <summary>
    /// Madde giris modeli.
    ///
    /// NEDEN BURADA SINIR VAR (plan 08): Olasilik ve Etki, RiskScore =
    /// Olasilik x Etki carpimini uretir ve rozet esikleri 5x5 = 25 olcegine
    /// gore konmustur. Bu sinir uzun sure HICBIR katmanda zorlanmiyordu:
    /// HTML'de min/max vardi (bir kolayliktir, kapi degildir), C#'ta hicbir
    /// sey, SP parametresi ise tinyint (0-255).
    ///
    /// SINIR ARTIK UC KATMANDA: DB CHECK (sql/83) tek gercek kapi, SP THROW
    /// Turkce mesaji verir, buradaki [Range] ise sunucu turu harcamadan
    /// kullaniciya alan hatasi gosterir.
    ///
    /// Mevcut 87 kaydin tamami 2-5 araliginda olculdu (2026-09-23), yani
    /// sinir geriye donuk hicbir kaydi gecersiz kilmiyor.
    /// </summary>
    public class ItemInput
    {
        [StringLength(100, ErrorMessage = "Denetim grubu en fazla 100 karakter olabilir.")]
        public string? AuditGroup { get; set; }

        [StringLength(100, ErrorMessage = "Alan en fazla 100 karakter olabilir.")]
        public string? Area { get; set; }

        [StringLength(100, ErrorMessage = "Risk tipi en fazla 100 karakter olabilir.")]
        public string? RiskType { get; set; }

        [Required(ErrorMessage = "Madde metni zorunlu.")]
        [StringLength(500, MinimumLength = 3, ErrorMessage = "Madde metni 3-500 karakter olmali.")]
        public string? ItemText { get; set; }

        [Range(1, 999, ErrorMessage = "Sira no 1-999 arasinda olmali.")]
        public int SortOrder { get; set; } = 1;

        /// <summary>
        /// DB kolonu char(1) — tek harf kodu tasir (U/G/I). Ekran uzun
        /// etiketi ("Uygunsuzluk") deger olarak gonderiyordu ve SQL Server
        /// parametre atamasinda SESSIZCE ilk harfe kirpiyordu; kayit
        /// donunce hicbir secenek eslesmedigi icin kullanici secimini
        /// kaybetmis goruyordu (olculdu 2026-09-23).
        /// </summary>
        [StringLength(1, ErrorMessage = "Bulgu tipi kodu tek karakter olmali.")]
        public string? FindingType { get; set; }

        [Range(1, 5, ErrorMessage = "Olasilik 1-5 arasinda olmali.")]
        public int Probability { get; set; } = 3;

        [Range(1, 5, ErrorMessage = "Etki 1-5 arasinda olmali.")]
        public int Impact { get; set; } = 3;
    }

    public sealed record ItemRow
    {
        public int Id { get; init; }
        public string? LocationType { get; init; }
        public string? AuditGroup { get; init; }
        public string? Area { get; init; }
        public string? RiskType { get; init; }
        public string ItemText { get; init; } = "";
        public int SortOrder { get; init; }
        public string? FindingType { get; init; }
        public int Probability { get; init; }
        public int Impact { get; init; }
        public int RiskScore { get; init; }
        public int? SkillId { get; init; }
        public bool IsActive { get; init; } = true;
        public DateTime? CreatedAt { get; init; }
        public DateTime? UpdatedAt { get; init; }
    }
}
