using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Logging;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Ref;

public class IndexModel : PageModel
{
    private static readonly List<TipGrupSecenekRow> TipGrupSecenekStore = new()
    {
        new TipGrupSecenekRow("SATIS", "Satis"),
        new TipGrupSecenekRow("IADE", "Musteri Iade"),
        new TipGrupSecenekRow("ALIS", "Alis"),
        new TipGrupSecenekRow("TRANSFER", "Transfer"),
        new TipGrupSecenekRow("SAYIM", "Sayim"),
        new TipGrupSecenekRow("DUZELTME", "Duzeltme"),
        new TipGrupSecenekRow("ICKULLANIM", "Ic Kullanim"),
        new TipGrupSecenekRow("BOZUK", "Bozuk Imha")
    };

    private static readonly HashSet<string> AllowedTabs = new(StringComparer.OrdinalIgnoreCase)
    {
        "kaynak",
        "irstip",
        "mekan",
        "tipmap",
        "riskparam",
        "skor",
        "personel",
        "kullanici"
    };

    private readonly SqlDb _db;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(SqlDb db, ILogger<IndexModel> logger)
    {
        _db = db;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public string? Tab { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? EditSistem { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? EditNesne { get; set; }

    [BindProperty(SupportsGet = true)]
    public int? EditMekanId { get; set; }

    [BindProperty(SupportsGet = true)]
    public int? EditTipId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? EditParamKodu { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? EditFlagKodu { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? EditPersonelKodu { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? EditKullaniciAdi { get; set; }

    [BindProperty(SupportsGet = true)]
    public bool IrsTipEksik { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? IrsTipArama { get; set; }

    [BindProperty]
    public MekanKapsamInput NewMekan { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public TipGrupInput NewTipMap { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public RiskParamInput NewRiskParam { get; set; } = new();

    [BindProperty]
    public SkorAgirlikInput NewSkor { get; set; } = new() { AktifMi = true, Puan = 10, Oncelik = 1 };

    [BindProperty]
    public KaynakSistemInput NewKaynakSistem { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public KaynakNesneInput NewKaynakNesne { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public PersonelInput NewPersonel { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public KullaniciInput NewKullanici { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public IrsTipMapInput NewIrsTipMap { get; set; } = new() { AktifMi = true };

    [BindProperty]
    public List<int> SelectedIrsTipIds { get; set; } = new();

    [BindProperty]
    public IrsTipBulkInput BulkIrsTip { get; set; } = new() { AktifMi = true };

    public IReadOnlyList<MekanKapsamRow> Mekanlar { get; private set; } = Array.Empty<MekanKapsamRow>();
    public IReadOnlyList<TipGrupRow> TipMaplar { get; private set; } = Array.Empty<TipGrupRow>();
    public IReadOnlyList<RiskParamRow> RiskParamlar { get; private set; } = Array.Empty<RiskParamRow>();
    public IReadOnlyList<SkorAgirlikRow> SkorAgirliklar { get; private set; } = Array.Empty<SkorAgirlikRow>();
    public IReadOnlyList<KaynakSistemRow> KaynakSistemler { get; private set; } = Array.Empty<KaynakSistemRow>();
    public IReadOnlyList<KaynakNesneRow> KaynakNesneler { get; private set; } = Array.Empty<KaynakNesneRow>();
    public IReadOnlyList<IrsTipRow> IrsTipler { get; private set; } = Array.Empty<IrsTipRow>();
    public IReadOnlyList<TipGrupSecenekRow> TipGrupSecenekleri { get; private set; } = Array.Empty<TipGrupSecenekRow>();
    public IReadOnlyList<PersonelRow> Personeller { get; private set; } = Array.Empty<PersonelRow>();
    public IReadOnlyList<KullaniciRow> Kullanicilar { get; private set; } = Array.Empty<KullaniciRow>();

    public int MekanToplam => Mekanlar.Count;
    public int MekanAktif => Mekanlar.Count(x => x.AktifMi);
    public int TipMapToplam => TipMaplar.Count;
    public int RiskParamToplam => RiskParamlar.Count;
    public int SkorToplam => SkorAgirliklar.Count;
    public int KaynakSistemToplam => KaynakSistemler.Count;
    public int KaynakNesneToplam => KaynakNesneler.Count;
    public int IrsTipEksikToplam => _irsTipEksikToplam;
    public int IrsTipToplam => _irsTipToplam;
    public int PersonelToplam => Personeller.Count;
    public int KullaniciToplam => Kullanicilar.Count;

    public string? StatusMessage => TempData["StatusMessage"] as string;

    private int? CurrentUserId => 1;
    public string ActiveTab => NormalizeTab(Tab);
    public bool IsEditingSistem => !string.IsNullOrWhiteSpace(EditSistem);
    public bool IsEditingNesne => !string.IsNullOrWhiteSpace(EditNesne);
    public bool IsEditingMekan => EditMekanId.HasValue;
    public bool IsEditingTipMap => EditTipId.HasValue;
    public bool IsEditingRiskParam => !string.IsNullOrWhiteSpace(EditParamKodu);
    public bool IsEditingSkor => !string.IsNullOrWhiteSpace(EditFlagKodu);
    public bool IsEditingPersonel => !string.IsNullOrWhiteSpace(EditPersonelKodu);
    public bool IsEditingKullanici => !string.IsNullOrWhiteSpace(EditKullaniciAdi);

    private int _irsTipToplam;
    private int _irsTipEksikToplam;

    public async Task OnGetAsync()
    {
        await LoadAllAsync();
        ApplyEditDefaults();
    }

    public async Task<IActionResult> OnPostAddMekanAsync()
    {
        if (NewMekan.MekanId <= 0)
        {
            ModelState.AddModelError("NewMekan.MekanId", "MekanId gerekir");
        }

        if (!ModelState.IsValid)
        {
            TempData["StatusMessage"] = "Mekan bilgisi gerekli.";
            await LoadAllAsync();
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_LocationSettings_Save",
            new
            {
                MekanId = NewMekan.MekanId,
                AktifMi = NewMekan.AktifMi,
                Aciklama = NormalizeText(NewMekan.Aciklama),
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingMekan ? "Mekan guncellendi" : "Mekan eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddTipMapAsync()
    {
        if (NewTipMap.TipId < 0)
        {
            ModelState.AddModelError("NewTipMap.TipId", "TipId gerekir");
        }

        if (string.IsNullOrWhiteSpace(NewTipMap.GrupKodu))
        {
            ModelState.AddModelError("NewTipMap.GrupKodu", "GrupKodu gerekir");
        }

        if (string.IsNullOrWhiteSpace(NewTipMap.GrupAdi))
        {
            ModelState.AddModelError("NewTipMap.GrupAdi", "GrupAdi gerekir");
        }

        if (!ModelState.IsValid)
        {
            await LoadAllAsync();
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_TransactionTypeMap_Save",
            new
            {
                TipId = NewTipMap.TipId,
                GrupKodu = NormalizeText(NewTipMap.GrupKodu),
                GrupAdi = NormalizeText(NewTipMap.GrupAdi),
                IslemAdi = NormalizeText(NewTipMap.IslemAdi),
                AktifMi = NewTipMap.AktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingTipMap ? "Tip map guncellendi" : "Tip map eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddRiskParamAsync()
    {
        if (string.IsNullOrWhiteSpace(NewRiskParam.ParamKodu))
        {
            ModelState.AddModelError("NewRiskParam.ParamKodu", "ParamKodu gerekir");
        }

        if (!ModelState.IsValid)
        {
            await LoadAllAsync();
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_RiskParameters_Save",
            new
            {
                ParamKodu = NormalizeText(NewRiskParam.ParamKodu),
                DegerInt = NewRiskParam.DegerInt,
                DegerDec = NewRiskParam.DegerDec,
                DegerStr = NormalizeText(NewRiskParam.DegerStr),
                AktifMi = NewRiskParam.AktifMi,
                Aciklama = NormalizeText(NewRiskParam.Aciklama),
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingRiskParam ? "Risk param guncellendi" : "Risk param eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddSkorAsync()
    {
        if (string.IsNullOrWhiteSpace(NewSkor.FlagKodu))
        {
            ModelState.AddModelError("NewSkor.FlagKodu", "FlagKodu gerekir");
        }

        if (NewSkor.Puan <= 0)
        {
            ModelState.AddModelError("NewSkor.Puan", "Puan 0'dan buyuk olmali");
        }

        if (NewSkor.Oncelik <= 0)
        {
            ModelState.AddModelError("NewSkor.Oncelik", "Oncelik 0'dan buyuk olmali");
        }

        if (!ModelState.IsValid)
        {
            await LoadAllAsync();
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_RiskScoreWeights_Save",
            new
            {
                FlagKodu = NormalizeText(NewSkor.FlagKodu),
                Puan = NewSkor.Puan,
                Oncelik = NewSkor.Oncelik,
                AktifMi = NewSkor.AktifMi,
                Aciklama = NormalizeText(NewSkor.Aciklama),
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingSkor ? "Skor agirlik guncellendi" : "Skor agirlik eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddKaynakSistemAsync()
    {
        if (string.IsNullOrWhiteSpace(NewKaynakSistem.SistemKodu))
        {
            ModelState.AddModelError("NewKaynakSistem.SistemKodu", "SistemKodu gerekir");
        }

        if (string.IsNullOrWhiteSpace(NewKaynakSistem.SistemAdi))
        {
            ModelState.AddModelError("NewKaynakSistem.SistemAdi", "SistemAdi gerekir");
        }

        if (!ModelState.IsValid)
        {
            await LoadAllAsync();
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_SourceSystems_Save",
            new
            {
                SistemKodu = NormalizeText(NewKaynakSistem.SistemKodu),
                SistemAdi = NormalizeText(NewKaynakSistem.SistemAdi),
                AktifMi = NewKaynakSistem.AktifMi,
                Aciklama = NormalizeText(NewKaynakSistem.Aciklama),
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingSistem ? "Kaynak sistem guncellendi" : "Kaynak sistem eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddKaynakNesneAsync()
    {
        if (string.IsNullOrWhiteSpace(NewKaynakNesne.NesneKodu))
        {
            ModelState.AddModelError("NewKaynakNesne.NesneKodu", "NesneKodu gerekir");
        }

        if (string.IsNullOrWhiteSpace(NewKaynakNesne.NesneAdi))
        {
            ModelState.AddModelError("NewKaynakNesne.NesneAdi", "NesneAdi gerekir");
        }

        if (!ModelState.IsValid)
        {
            await LoadAllAsync();
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_SourceObjects_Save",
            new
            {
                NesneKodu = NormalizeText(NewKaynakNesne.NesneKodu),
                NesneAdi = NormalizeText(NewKaynakNesne.NesneAdi),
                AktifMi = NewKaynakNesne.AktifMi,
                Aciklama = NormalizeText(NewKaynakNesne.Aciklama),
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingNesne ? "Kaynak nesne guncellendi" : "Kaynak nesne eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleKaynakSistemAsync(string sistemKodu, bool aktifMi)
    {
        if (string.IsNullOrWhiteSpace(sistemKodu))
        {
            TempData["StatusMessage"] = "Sistem kodu bos olamaz";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var sistem = KaynakSistemler.FirstOrDefault(x => string.Equals(x.SistemKodu, sistemKodu, StringComparison.OrdinalIgnoreCase));
        if (sistem is null)
        {
            TempData["StatusMessage"] = "Kaynak sistem bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_SourceSystems_Save",
            new
            {
                SistemKodu = sistem.SistemKodu,
                SistemAdi = sistem.SistemAdi,
                AktifMi = aktifMi,
                Aciklama = sistem.Aciklama,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Kaynak sistem aktif edildi" : "Kaynak sistem pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleKaynakNesneAsync(string nesneKodu, bool aktifMi)
    {
        if (string.IsNullOrWhiteSpace(nesneKodu))
        {
            TempData["StatusMessage"] = "Nesne kodu bos olamaz";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var nesne = KaynakNesneler.FirstOrDefault(x => string.Equals(x.NesneKodu, nesneKodu, StringComparison.OrdinalIgnoreCase));
        if (nesne is null)
        {
            TempData["StatusMessage"] = "Kaynak nesne bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_SourceObjects_Save",
            new
            {
                NesneKodu = nesne.NesneKodu,
                NesneAdi = nesne.NesneAdi,
                AktifMi = aktifMi,
                Aciklama = nesne.Aciklama,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Kaynak nesne aktif edildi" : "Kaynak nesne pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleMekanAsync(int mekanId, bool aktifMi)
    {
        if (mekanId <= 0)
        {
            TempData["StatusMessage"] = "Mekan bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var mekan = Mekanlar.FirstOrDefault(x => x.MekanId == mekanId);
        if (mekan is null)
        {
            TempData["StatusMessage"] = "Mekan bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_LocationSettings_Save",
            new
            {
                MekanId = mekan.MekanId,
                AktifMi = aktifMi,
                Aciklama = mekan.Aciklama,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Mekan aktif edildi" : "Mekan pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleTipMapAsync(int tipId, bool aktifMi)
    {
        if (tipId < 0)
        {
            TempData["StatusMessage"] = "Tip bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var tipMap = TipMaplar.FirstOrDefault(x => x.TipId == tipId);
        if (tipMap is null)
        {
            TempData["StatusMessage"] = "Tip map bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_TransactionTypeMap_Save",
            new
            {
                TipId = tipMap.TipId,
                GrupKodu = tipMap.GrupKodu,
                GrupAdi = tipMap.GrupAdi,
                IslemAdi = tipMap.IslemAdi,
                AktifMi = aktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Tip map aktif edildi" : "Tip map pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleRiskParamAsync(string paramKodu, bool aktifMi)
    {
        if (string.IsNullOrWhiteSpace(paramKodu))
        {
            TempData["StatusMessage"] = "Param bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var param = RiskParamlar.FirstOrDefault(x => string.Equals(x.ParamKodu, paramKodu, StringComparison.OrdinalIgnoreCase));
        if (param is null)
        {
            TempData["StatusMessage"] = "Param bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_RiskParameters_Save",
            new
            {
                ParamKodu = param.ParamKodu,
                DegerInt = param.DegerInt,
                DegerDec = param.DegerDec,
                DegerStr = param.DegerStr,
                AktifMi = aktifMi,
                Aciklama = param.Aciklama,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Risk param aktif edildi" : "Risk param pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleSkorAsync(string flagKodu, bool aktifMi)
    {
        if (string.IsNullOrWhiteSpace(flagKodu))
        {
            TempData["StatusMessage"] = "Skor bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var skor = SkorAgirliklar.FirstOrDefault(x => string.Equals(x.FlagKodu, flagKodu, StringComparison.OrdinalIgnoreCase));
        if (skor is null)
        {
            TempData["StatusMessage"] = "Skor bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_RiskScoreWeights_Save",
            new
            {
                FlagKodu = skor.FlagKodu,
                Puan = skor.Puan,
                Oncelik = skor.Oncelik,
                AktifMi = aktifMi,
                Aciklama = skor.Aciklama,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Skor aktif edildi" : "Skor pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostTogglePersonelAsync(string personelKodu, bool aktifMi)
    {
        if (string.IsNullOrWhiteSpace(personelKodu))
        {
            TempData["StatusMessage"] = "Personel bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var personel = Personeller.FirstOrDefault(x => string.Equals(x.PersonelKodu, personelKodu, StringComparison.OrdinalIgnoreCase));
        if (personel is null)
        {
            TempData["StatusMessage"] = "Personel bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_Personnel_Save",
            new
            {
                PersonelKodu = personel.PersonelKodu,
                Ad = personel.Ad,
                Soyad = personel.Soyad,
                Unvan = personel.Unvan,
                Birim = personel.Birim,
                UstPersonelId = personel.UstPersonelId,
                Eposta = personel.Eposta,
                Telefon = personel.Telefon,
                AktifMi = aktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Personel aktif edildi" : "Personel pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostToggleKullaniciAsync(string kullaniciAdi, bool aktifMi)
    {
        if (string.IsNullOrWhiteSpace(kullaniciAdi))
        {
            TempData["StatusMessage"] = "Kullanici bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await LoadAllAsync();
        var kullanici = Kullanicilar.FirstOrDefault(x => string.Equals(x.KullaniciAdi, kullaniciAdi, StringComparison.OrdinalIgnoreCase));
        if (kullanici is null)
        {
            TempData["StatusMessage"] = "Kullanici bulunamadi";
            return RedirectToPage(new { tab = ActiveTab });
        }

        await _db.ExecuteAsync(
            "ref.sp_Users_Save",
            new
            {
                KullaniciAdi = kullanici.KullaniciAdi,
                PersonelId = kullanici.PersonelId,
                RolKodu = kullanici.RolKodu,
                AktifMi = aktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = aktifMi ? "Kullanici aktif edildi" : "Kullanici pasife alindi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddPersonelAsync()
    {
        await LoadAllAsync();

        if (string.IsNullOrWhiteSpace(NewPersonel.Ad))
        {
            ModelState.AddModelError("NewPersonel.Ad", "Ad gerekir");
        }

        if (string.IsNullOrWhiteSpace(NewPersonel.Soyad))
        {
            ModelState.AddModelError("NewPersonel.Soyad", "Soyad gerekir");
        }

        if (NewPersonel.UstPersonelId.HasValue && Personeller.All(x => x.PersonelId != NewPersonel.UstPersonelId.Value))
        {
            ModelState.AddModelError("NewPersonel.UstPersonelId", "Ust personel bulunamadi");
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_Personnel_Save",
            new
            {
                PersonelKodu = NormalizeText(NewPersonel.PersonelKodu),
                Ad = NormalizeText(NewPersonel.Ad),
                Soyad = NormalizeText(NewPersonel.Soyad),
                Unvan = NormalizeText(NewPersonel.Unvan),
                Birim = NormalizeText(NewPersonel.Birim),
                UstPersonelId = NewPersonel.UstPersonelId,
                Eposta = NormalizeText(NewPersonel.Eposta),
                Telefon = NormalizeText(NewPersonel.Telefon),
                AktifMi = NewPersonel.AktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingPersonel ? "Personel guncellendi" : "Personel eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostAddKullaniciAsync()
    {
        await LoadAllAsync();

        if (string.IsNullOrWhiteSpace(NewKullanici.KullaniciAdi))
        {
            ModelState.AddModelError("NewKullanici.KullaniciAdi", "KullaniciAdi gerekir");
        }

        if (NewKullanici.PersonelId.HasValue && Personeller.All(x => x.PersonelId != NewKullanici.PersonelId.Value))
        {
            ModelState.AddModelError("NewKullanici.PersonelId", "Personel bulunamadi");
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        await _db.ExecuteAsync(
            "ref.sp_Users_Save",
            new
            {
                KullaniciAdi = NormalizeText(NewKullanici.KullaniciAdi),
                PersonelId = NewKullanici.PersonelId,
                RolKodu = NormalizeText(NewKullanici.RolKodu),
                AktifMi = NewKullanici.AktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = IsEditingKullanici ? "Kullanici guncellendi" : "Kullanici eklendi";
        return RedirectToPage(new { tab = ActiveTab });
    }

    public async Task<IActionResult> OnPostMapIrsTipAsync(bool irsTipEksik = false, string? irsTipArama = null)
    {
        var tipId = NewIrsTipMap.TipId;
        var grupKoduClean = NormalizeText(NewIrsTipMap.GrupKodu);
        if (Request.HasFormContentType)
        {
            var formDump = string.Join(";", Request.Form.Select(kvp => $"{kvp.Key}={kvp.Value}"));
            _logger.LogInformation("IrsTip map form data: {FormDump}", formDump);
        }

        _logger.LogInformation("IrsTip map request: tipId={TipId}, grupKodu={GrupKodu}, islemAdi={IslemAdi}, aktifMi={AktifMi}",
            tipId,
            NewIrsTipMap.GrupKodu,
            NewIrsTipMap.IslemAdi,
            NewIrsTipMap.AktifMi);

        if (tipId < 0)
        {
            ModelState.AddModelError("NewIrsTipMap.TipId", "Tip secilmeli");
        }

        if (string.IsNullOrWhiteSpace(grupKoduClean))
        {
            ModelState.AddModelError("NewIrsTipMap.GrupKodu", "Grup secilmeli");
        }

        var grup = TipGrupSecenekStore.FirstOrDefault(x =>
            string.Equals(x.GrupKodu, grupKoduClean, StringComparison.OrdinalIgnoreCase));

        if (grup is null)
        {
            ModelState.AddModelError("NewIrsTipMap.GrupKodu", "Gecerli bir grup secin");
        }

        if (!ModelState.IsValid)
        {
            var errors = ModelState
                .Where(entry => entry.Value is not null && entry.Value.Errors.Count > 0)
                .Select(entry => $"{entry.Key}:{string.Join(",", entry.Value!.Errors.Select(e => e.ErrorMessage))}");
            _logger.LogWarning("IrsTip map validation failed: tipId={TipId}, grupKodu={GrupKodu}, errors={Errors}", tipId, NewIrsTipMap.GrupKodu, string.Join(" | ", errors));
            TempData["StatusMessage"] = "Tip ve grup secilmeli.";
            await LoadAllAsync();
            return Page();
        }

        _logger.LogInformation(
            "IrsTip map save: tipId={TipId}, grupKodu={GrupKodu}, grupAdi={GrupAdi}, islemAdi={IslemAdi}, aktifMi={AktifMi}",
            tipId,
            grup?.GrupKodu,
            grup?.GrupAdi,
            NormalizeText(NewIrsTipMap.IslemAdi),
            NewIrsTipMap.AktifMi);

        await _db.ExecuteAsync(
            "ref.sp_TransactionTypeMap_Save",
            new
            {
                TipId = tipId,
                GrupKodu = grup?.GrupKodu,
                GrupAdi = grup?.GrupAdi,
                IslemAdi = NormalizeText(NewIrsTipMap.IslemAdi),
                AktifMi = NewIrsTipMap.AktifMi,
                KullaniciId = CurrentUserId
            });

        TempData["StatusMessage"] = "Tip eslestirildi";
        return RedirectToPage(new { tab = ActiveTab, irsTipEksik, irsTipArama });
    }

    public async Task<IActionResult> OnPostBulkIrsTipAsync(bool irsTipEksik = false, string? irsTipArama = null)
    {
        var grupKoduClean = NormalizeText(BulkIrsTip.GrupKodu);
        var selectedIds = SelectedIrsTipIds ?? new List<int>();
        if (selectedIds.Count == 0)
        {
            ModelState.AddModelError("SelectedIrsTipIds", "En az bir tip secilmeli");
        }

        if (string.IsNullOrWhiteSpace(grupKoduClean))
        {
            ModelState.AddModelError("BulkIrsTip.GrupKodu", "Grup secilmeli");
        }

        var grup = TipGrupSecenekStore.FirstOrDefault(x =>
            string.Equals(x.GrupKodu, grupKoduClean, StringComparison.OrdinalIgnoreCase));

        if (grup is null)
        {
            ModelState.AddModelError("BulkIrsTip.GrupKodu", "Gecerli bir grup secin");
        }

        if (!ModelState.IsValid)
        {
            TempData["StatusMessage"] = "Toplu eslestirme icin tip ve grup secilmeli.";
            await LoadAllAsync();
            return Page();
        }

        var tipIds = selectedIds
            .Where(x => x >= 0)
            .Distinct()
            .ToList();

        foreach (var tipId in tipIds)
        {
            await _db.ExecuteAsync(
                "ref.sp_TransactionTypeMap_Save",
                new
                {
                    TipId = tipId,
                    GrupKodu = grup?.GrupKodu,
                    GrupAdi = grup?.GrupAdi,
                    IslemAdi = NormalizeText(BulkIrsTip.IslemAdi),
                    AktifMi = BulkIrsTip.AktifMi,
                    KullaniciId = CurrentUserId
                });
        }

        TempData["StatusMessage"] = $"{tipIds.Count} tip eslestirildi";
        return RedirectToPage(new { tab = ActiveTab, irsTipEksik, irsTipArama });
    }

    private async Task LoadAllAsync()
    {
        Mekanlar = await _db.QueryAsync<MekanKapsamRow>("ref.sp_LocationSettings_List");

        TipMaplar = await _db.QueryAsync<TipGrupRow>("ref.sp_TransactionTypeMap_GroupList");

        RiskParamlar = await _db.QueryAsync<RiskParamRow>("ref.sp_RiskParameters_List");

        SkorAgirliklar = await _db.QueryAsync<SkorAgirlikRow>("ref.sp_RiskScoreWeights_List");

        KaynakSistemler = await _db.QueryAsync<KaynakSistemRow>("ref.sp_SourceSystems_List");

        KaynakNesneler = await _db.QueryAsync<KaynakNesneRow>("ref.sp_SourceObjects_List");

        var irsTiplerAll = await _db.QueryAsync<IrsTipRow>("ref.sp_TransactionTypeMap_List");
        _irsTipToplam = irsTiplerAll.Count;

        var aktifMapTipIds = new HashSet<int>(TipMaplar.Where(x => x.AktifMi).Select(x => x.TipId));
        _irsTipEksikToplam = irsTiplerAll.Count(x => !aktifMapTipIds.Contains(x.TipId));

        var filtered = irsTiplerAll.AsEnumerable();
        if (IrsTipEksik)
        {
            filtered = filtered.Where(x => !aktifMapTipIds.Contains(x.TipId));
        }

        var arama = NormalizeText(IrsTipArama);
        if (!string.IsNullOrWhiteSpace(arama))
        {
            filtered = filtered.Where(x =>
            {
                if (x.TipAdi.Contains(arama, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                if (x.TipId.ToString().Contains(arama, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                var map = TipMaplar.FirstOrDefault(m => m.TipId == x.TipId);
                if (map is null)
                {
                    return false;
                }

                return map.GrupKodu.Contains(arama, StringComparison.OrdinalIgnoreCase)
                    || map.GrupAdi.Contains(arama, StringComparison.OrdinalIgnoreCase);
            });
        }

        var filteredList = filtered.ToList();
        IrsTipler = filteredList;

        if (IrsTipler.Count > 0)
        {
            var sample = IrsTipler.Take(5).Select(x => $"{x.TipId}:{x.TipAdi}");
            _logger.LogInformation("IrsTip list loaded: count={Count}, min={Min}, max={Max}, sample={Sample}",
                IrsTipler.Count,
                IrsTipler.Min(x => x.TipId),
                IrsTipler.Max(x => x.TipId),
                string.Join(", ", sample));
        }

        TipGrupSecenekleri = TipGrupSecenekStore.OrderBy(x => x.GrupKodu).ToList();

        Personeller = await _db.QueryAsync<PersonelRow>("ref.sp_Personnel_List");

        Kullanicilar = await _db.QueryAsync<KullaniciRow>("ref.sp_Users_List");
    }

    private void ApplyEditDefaults()
    {
        if (!string.IsNullOrWhiteSpace(EditSistem))
        {
            var sistem = KaynakSistemler.FirstOrDefault(x => string.Equals(x.SistemKodu, EditSistem, StringComparison.OrdinalIgnoreCase));
            if (sistem is not null)
            {
                NewKaynakSistem = new KaynakSistemInput
                {
                    SistemKodu = sistem.SistemKodu,
                    SistemAdi = sistem.SistemAdi,
                    AktifMi = sistem.AktifMi,
                    Aciklama = sistem.Aciklama
                };
            }
        }

        if (!string.IsNullOrWhiteSpace(EditNesne))
        {
            var nesne = KaynakNesneler.FirstOrDefault(x => string.Equals(x.NesneKodu, EditNesne, StringComparison.OrdinalIgnoreCase));
            if (nesne is not null)
            {
                NewKaynakNesne = new KaynakNesneInput
                {
                    NesneKodu = nesne.NesneKodu,
                    NesneAdi = nesne.NesneAdi,
                    AktifMi = nesne.AktifMi,
                    Aciklama = nesne.Aciklama
                };
            }
        }

        if (EditMekanId.HasValue)
        {
            var mekan = Mekanlar.FirstOrDefault(x => x.MekanId == EditMekanId.Value);
            if (mekan is not null)
            {
                NewMekan = new MekanKapsamInput
                {
                    MekanId = mekan.MekanId,
                    AktifMi = mekan.AktifMi,
                    Aciklama = mekan.Aciklama
                };
            }
        }

        if (EditTipId.HasValue)
        {
            var tipMap = TipMaplar.FirstOrDefault(x => x.TipId == EditTipId.Value);
            if (tipMap is not null)
            {
                NewTipMap = new TipGrupInput
                {
                    TipId = tipMap.TipId,
                    GrupKodu = tipMap.GrupKodu,
                    GrupAdi = tipMap.GrupAdi,
                    IslemAdi = tipMap.IslemAdi,
                    AktifMi = tipMap.AktifMi
                };
            }
        }

        if (!string.IsNullOrWhiteSpace(EditParamKodu))
        {
            var param = RiskParamlar.FirstOrDefault(x => string.Equals(x.ParamKodu, EditParamKodu, StringComparison.OrdinalIgnoreCase));
            if (param is not null)
            {
                NewRiskParam = new RiskParamInput
                {
                    ParamKodu = param.ParamKodu,
                    DegerInt = param.DegerInt,
                    DegerDec = param.DegerDec,
                    DegerStr = param.DegerStr,
                    AktifMi = param.AktifMi,
                    Aciklama = param.Aciklama
                };
            }
        }

        if (!string.IsNullOrWhiteSpace(EditFlagKodu))
        {
            var skor = SkorAgirliklar.FirstOrDefault(x => string.Equals(x.FlagKodu, EditFlagKodu, StringComparison.OrdinalIgnoreCase));
            if (skor is not null)
            {
                NewSkor = new SkorAgirlikInput
                {
                    FlagKodu = skor.FlagKodu,
                    Puan = skor.Puan,
                    Oncelik = skor.Oncelik,
                    AktifMi = skor.AktifMi,
                    Aciklama = skor.Aciklama
                };
            }
        }

        if (!string.IsNullOrWhiteSpace(EditPersonelKodu))
        {
            var personel = Personeller.FirstOrDefault(x => string.Equals(x.PersonelKodu, EditPersonelKodu, StringComparison.OrdinalIgnoreCase));
            if (personel is not null)
            {
                NewPersonel = new PersonelInput
                {
                    PersonelKodu = personel.PersonelKodu,
                    Ad = personel.Ad,
                    Soyad = personel.Soyad,
                    Unvan = personel.Unvan,
                    Birim = personel.Birim,
                    UstPersonelId = personel.UstPersonelId,
                    Eposta = personel.Eposta,
                    Telefon = personel.Telefon,
                    AktifMi = personel.AktifMi
                };
            }
        }

        if (!string.IsNullOrWhiteSpace(EditKullaniciAdi))
        {
            var kullanici = Kullanicilar.FirstOrDefault(x => string.Equals(x.KullaniciAdi, EditKullaniciAdi, StringComparison.OrdinalIgnoreCase));
            if (kullanici is not null)
            {
                NewKullanici = new KullaniciInput
                {
                    KullaniciAdi = kullanici.KullaniciAdi,
                    PersonelId = kullanici.PersonelId,
                    RolKodu = kullanici.RolKodu,
                    AktifMi = kullanici.AktifMi
                };
            }
        }
    }

    private static string NormalizeTab(string? tab)
    {
        var trimmed = tab?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return "kaynak";
        }

        return AllowedTabs.Contains(trimmed) ? trimmed.ToLowerInvariant() : "kaynak";
    }

    private static string? NormalizeText(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? null : trimmed;
    }

    public string GetPersonelAd(int? personelId)
    {
        if (!personelId.HasValue)
        {
            return "-";
        }

        var personel = Personeller.FirstOrDefault(x => x.PersonelId == personelId.Value);
        return personel is null ? "-" : $"{personel.Ad} {personel.Soyad}";
    }

    public TipGrupRow? GetTipMap(int tipId)
    {
        return TipMaplar.FirstOrDefault(x => x.TipId == tipId);
    }

    public sealed class MekanKapsamRow
    {
        public int MekanId { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public sealed class TipGrupRow
    {
        public int TipId { get; set; }
        public string GrupKodu { get; set; } = string.Empty;
        public string GrupAdi { get; set; } = string.Empty;
        public string? IslemAdi { get; set; }
        public bool AktifMi { get; set; }
    }

    public sealed class RiskParamRow
    {
        public string ParamKodu { get; set; } = string.Empty;
        public int? DegerInt { get; set; }
        public decimal? DegerDec { get; set; }
        public string? DegerStr { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public sealed class SkorAgirlikRow
    {
        public string FlagKodu { get; set; } = string.Empty;
        public int Puan { get; set; }
        public int Oncelik { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public sealed class KaynakSistemRow
    {
        public string SistemKodu { get; set; } = string.Empty;
        public string SistemAdi { get; set; } = string.Empty;
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public sealed class KaynakNesneRow
    {
        public string NesneKodu { get; set; } = string.Empty;
        public string NesneAdi { get; set; } = string.Empty;
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public sealed class IrsTipRow
    {
        public int TipId { get; set; }
        public string TipAdi { get; set; } = string.Empty;
    }
    public record TipGrupSecenekRow(string GrupKodu, string GrupAdi);
    public sealed class PersonelRow
    {
        public int PersonelId { get; set; }
        public string? PersonelKodu { get; set; }
        public string Ad { get; set; } = string.Empty;
        public string Soyad { get; set; } = string.Empty;
        public string? Unvan { get; set; }
        public string? Birim { get; set; }
        public int? UstPersonelId { get; set; }
        public string? Eposta { get; set; }
        public string? Telefon { get; set; }
        public bool AktifMi { get; set; }
    }

    public sealed class KullaniciRow
    {
        public int KullaniciId { get; set; }
        public string KullaniciAdi { get; set; } = string.Empty;
        public int? PersonelId { get; set; }
        public string? RolKodu { get; set; }
        public bool AktifMi { get; set; }
    }

    public class MekanKapsamInput
    {
        public int MekanId { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public class TipGrupInput
    {
        public int TipId { get; set; }
        public string? GrupKodu { get; set; }
        public string? GrupAdi { get; set; }
        public string? IslemAdi { get; set; }
        public bool AktifMi { get; set; }
    }

    public class RiskParamInput
    {
        public string? ParamKodu { get; set; }
        public int? DegerInt { get; set; }
        public decimal? DegerDec { get; set; }
        public string? DegerStr { get; set; }
        public bool AktifMi { get; set; } = true;
        public string? Aciklama { get; set; }
    }

    public class IrsTipBulkInput
    {
        public string? GrupKodu { get; set; }
        public string? IslemAdi { get; set; }
        public bool AktifMi { get; set; } = true;
    }

    public class SkorAgirlikInput
    {
        public string? FlagKodu { get; set; }
        public int Puan { get; set; }
        public int Oncelik { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public class KaynakSistemInput
    {
        public string? SistemKodu { get; set; }
        public string? SistemAdi { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public class KaynakNesneInput
    {
        public string? NesneKodu { get; set; }
        public string? NesneAdi { get; set; }
        public bool AktifMi { get; set; }
        public string? Aciklama { get; set; }
    }

    public class PersonelInput
    {
        public string? PersonelKodu { get; set; }
        public string? Ad { get; set; }
        public string? Soyad { get; set; }
        public string? Unvan { get; set; }
        public string? Birim { get; set; }
        public int? UstPersonelId { get; set; }
        public string? Eposta { get; set; }
        public string? Telefon { get; set; }
        public bool AktifMi { get; set; }
    }

    public class KullaniciInput
    {
        public string? KullaniciAdi { get; set; }
        public int? PersonelId { get; set; }
        public string? RolKodu { get; set; }
        public bool AktifMi { get; set; }
    }

    public class IrsTipMapInput
    {
        public int TipId { get; set; }
        public string? GrupKodu { get; set; }
        public string? IslemAdi { get; set; }
        public bool AktifMi { get; set; }
    }
}
