using BkmArgus.Web.Features;
using Solum.Web.Components;
using Xunit;

namespace BkmArgus.Tests;

/// <summary>
/// Dashboard sunum haritasi testleri (plan: 04, Faz 3).
///
/// NEDEN BU TESTLER: Dashboard [Authorize] arkasinda, yani kabuk ve tablo
/// ciktisi kimlik bilgisi olmadan tarayicida gorulemiyor. Sunum haritasi ise
/// veritabanindan BAGIMSIZ — dogrudan cagrilabilir. Boylece "renk yargidan
/// gelir", "drill adresi UrlGuard'dan gecer" gibi iddialar oturum acmadan
/// kanitlanabiliyor.
///
/// Testler DAVRANIS dogrular, anlik veri sabitlemez (test-discipline.md).
/// </summary>
public class DashboardViewTests
{
    // ── Polarite: yon ile yargi ayri seylerdir ──────────────────────────

    [Fact]
    public void Risk_skoru_dususu_IYI_yargisi_uretir()
    {
        // Risk skoru dustu: hareket Decrease, ama metrik LowerIsBetter
        // oldugu icin yargi Good olmali. "Eksi = kirmizi" varsayimi yanlis.
        var delta = DashboardView.TrendDelta([80m, 60m, 40m]);

        Assert.NotNull(delta);
        Assert.Equal(KpiMovement.Decrease, delta!.Movement);
        Assert.Equal(KpiJudgement.Good, delta.Judge());
        Assert.Equal("↓", DashboardView.MovementGlyph(delta.Movement));
    }

    [Fact]
    public void Risk_skoru_artisi_KOTU_yargisi_uretir()
    {
        var delta = DashboardView.TrendDelta([40m, 60m, 90m]);

        Assert.NotNull(delta);
        Assert.Equal(KpiMovement.Increase, delta!.Movement);
        Assert.Equal(KpiJudgement.Bad, delta.Judge());
    }

    [Fact]
    public void Degismeyen_seri_notr_kalir()
    {
        var delta = DashboardView.TrendDelta([50m, 55m, 50m]);

        Assert.NotNull(delta);
        Assert.Equal(KpiMovement.Flat, delta!.Movement);
        Assert.Equal(KpiJudgement.Flat, delta.Judge());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    public void Iki_noktadan_kisa_seride_delta_gosterilmez(int noktaSayisi)
    {
        // Olcum yoksa degisim UYDURULMAZ — null doner, ekranda hic cizilmez.
        var seri = Enumerable.Repeat(50m, noktaSayisi).ToList();

        Assert.Null(DashboardView.TrendDelta(seri));
    }

    [Fact]
    public void Delta_metni_hareketle_celismez()
    {
        // Solum sozlesmesi isaret-hareket celiskisinde hata atiyor; bizim
        // urettigimiz metin isaretsiz oldugu icin bu kapiya hic takilmamali.
        var delta = DashboardView.TrendDelta([90m, 40m]);

        Assert.NotNull(delta);
        Assert.False(delta!.SignContradictsMovement());
    }

    [Fact]
    public void Erisim_metni_yon_ve_yargiyi_kelimeyle_soyler()
    {
        // Yon ve yargi yalniz renkte kalmamali (renk ayrimi olmayan kullanici).
        var delta = DashboardView.TrendDelta([80m, 50m])!;
        var metin = DashboardView.DeltaScreenReaderText(delta);

        Assert.Contains("azaldı", metin);
        Assert.Contains("iyi yönde", metin);
    }

    // ── Tablo haritasi ve drill adresi ──────────────────────────────────

    [Fact]
    public void Risk_tablosu_satir_adresi_goreli_yol_uretir()
    {
        var satir = new DashboardModel.RiskRow(42, 7, "FSM", "Kalem", "Son30Gun", 91, "STOKSUZ", "");
        var model = DashboardView.RiskTable([satir]);

        Assert.NotNull(model.RowUrl);
        var adres = model.RowUrl!(satir);

        // Goreli yol olmali: sema (javascript:, data:) TASIMAMALI.
        Assert.StartsWith("/", adres);
        Assert.DoesNotContain(":", adres);
        Assert.Contains("id=42", adres);
        Assert.Contains("mekanId=7", adres);
    }

    [Fact]
    public void Risk_tablosu_uretecten_gecer_ve_adres_reddedilmez()
    {
        // Solum UrlGuard'i sema denetimi yapiyor; mesru drill adresimizin
        // reddedilmedigini burada kanitliyoruz (hata atarsa test kirilir).
        var satir = new DashboardModel.RiskRow(42, 7, "FSM", "Kalem", "Son30Gun", 91, "STOKSUZ", "");
        var html = new HtmlTableRenderer()
            .Render(DashboardView.RiskTable([satir]))
            .ToString()!;

        Assert.Contains("solum-table", html);
        Assert.Contains("/Urun/Index?id=42", html);
    }

    [Fact]
    public void Bos_tablo_bos_durum_mesaji_cizer()
    {
        var html = new HtmlTableRenderer()
            .Render(DashboardView.RiskTable([]))
            .ToString()!;

        Assert.Contains("solum-empty", html);
        // DIKKAT: uretici HtmlEncoder.Default kullaniyor, yani Turkce karakterler
        // sayisal varlik olarak cikiyor (ı -> &#x131;). Ham metinle karsilastirmak
        // yanlis kirmiziya sebep olur; kaciris beklenen davranistir.
        Assert.Contains(
            System.Text.Encodings.Web.HtmlEncoder.Default.Encode("Riskli ürün bulunamadı."),
            html);
    }

    [Fact]
    public void Hucre_degeri_kacirilir()
    {
        // Mekan adi kullanici/DB verisi; betik olarak calismamali.
        var satir = new DashboardModel.RiskRow(1, 1, "<script>alert(1)</script>", "Kalem", "Son30Gun", 10, "-", "");
        var html = new HtmlTableRenderer()
            .Render(DashboardView.RiskTable([satir]))
            .ToString()!;

        Assert.DoesNotContain("<script>", html);
    }

    [Fact]
    public void Denetim_kolonlari_eksiksiz_ve_tablolar_ayni_grain_de()
    {
        // Kolon sayisi degisebilir; degismemesi gereken sey her tablonun
        // satir sayisinin verilen listeyle AYNI olmasi (join sismesi yok).
        var denetimler = new List<DashboardModel.RecentAuditRow>
        {
            new() { Id = 1, LocationName = "FSM", AuditDate = new DateTime(2026, 8, 1), ComplianceRate = 93m, IsFinalized = true },
            new() { Id = 2, LocationName = "Özlüce", AuditDate = new DateTime(2026, 8, 2), ComplianceRate = 61m, IsFinalized = false }
        };

        var model = DashboardView.RecentAuditsTable(denetimler);

        Assert.Equal(denetimler.Count, model.Page.Items.Count);
        Assert.Equal(denetimler.Count, model.Page.TotalCount);
        Assert.NotEmpty(model.Columns);
        Assert.All(model.Columns, k => Assert.False(string.IsNullOrWhiteSpace(k.Header)));
    }

    // ── Rozet haritasi ──────────────────────────────────────────────────

    [Theory]
    [InlineData("PASS", "solum-badge-good")]
    [InlineData("WARN", "solum-badge-warn")]
    [InlineData("FAIL", "solum-badge-bad")]
    [InlineData("KRITIK", "solum-badge-bad")]
    public void Durum_kodu_dogru_rozet_tonuna_gider(string durum, string beklenen)
    {
        Assert.Contains(beklenen, DashboardView.BadgeClass(durum));
    }

    [Fact]
    public void Bilinmeyen_durum_notr_rozet_alir()
    {
        // Bilinmeyen kod KIRMIZI gosterilmemeli — yanlis alarm uretir.
        var sinif = DashboardView.BadgeClass("HENUZ_YOK");

        Assert.Equal("solum-badge", sinif);
    }
}
