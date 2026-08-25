using Solum.Core.Crud;
using Solum.Web.Components;

namespace BkmArgus.Web.Features;

/// <summary>
/// Dashboard sunum haritasi: SP satirlarini Solum ilkellerine (KpiCard, TableModel)
/// cevirir (plan: 04, Faz 3).
///
/// NEDEN AYRI DOSYA: Index.cshtml.cs veri erisimidir (SP cagrilari) ve 283 satir;
/// sunum haritasini oraya koymak 300 satir sinirini asardi (csharp-conventions.md).
///
/// BURADA HESAP YOK: SUM/CASE/join yok — yalniz "hangi deger hangi kutucuga,
/// hangi ton, hangi kolon" eslemesi. Rakamlar SP'den gelir.
/// </summary>
public static class DashboardView
{
    // ── Polarite: metrigin yonu (KpiDelta sozlesmesi) ────────────────────
    // Risk skoru DUSERSE iyidir. Polarite metrige aittir, karta degil —
    // ayni metrik baska bir ekranda gosterilirse ayni sabit kullanilir.
    private const KpiPolarity RiskSkoruPolaritesi = KpiPolarity.LowerIsBetter;

    /// <summary>Bos liste icin tek-sayfa sarmalayici (dashboard'da sayfalama yok).</summary>
    private static PagedResult<T> TekSayfa<T>(IReadOnlyList<T> satirlar) =>
        new(satirlar, satirlar.Count, 1, Math.Max(1, satirlar.Count));

    // ─────────────────────────── ERP RISK SEKMESI ───────────────────────

    /// <summary>ERP risk sekmesi kutucuklari.</summary>
    public static IReadOnlyList<KpiCard> RiskKpileri(DashboardModel m) =>
    [
        new KpiCard
        {
            Label = "Kritik risk",
            Value = m.KritikRiskDeger,
            // Is kurali: kritik risk sayisi sifirdan buyukse bu bir uyaridir.
            Tone = m.KritikRiskDeger == "0" ? KpiTone.Neutral : KpiTone.Bad,
            Hint = m.KritikRiskNot,
            Href = "/Risk"
        },
        new KpiCard
        {
            Label = "Bekleyen DÖF",
            Value = m.BekleyenDofDeger,
            Tone = m.BekleyenDofDeger == "0" ? KpiTone.Good : KpiTone.Warn,
            Hint = m.BekleyenDofNot,
            Href = "/Dof"
        },
        new KpiCard
        {
            Label = "Taranan stok",
            Value = m.TarananStokDeger,
            Tone = KpiTone.Neutral,
            Hint = m.TarananStokNot
        },
        new KpiCard
        {
            Label = "Sistem sağlığı",
            Value = m.SistemDurum,
            Tone = m.SistemDurum switch
            {
                "PASS" => KpiTone.Good,
                "WARN" => KpiTone.Warn,
                _ => KpiTone.Bad
            },
            Hint = m.SistemNot
        }
    ];

    /// <summary>
    /// Risk trendi degisimi: seri ilk ile son degeri arasindaki fark.
    ///
    /// UYDURMA YOK: SP yalnizca gunluk ortalama skor serisi donuyor, "onceki
    /// donem" karsilastirmasi vermiyor. Bu yuzden delta SERININ KENDISINDEN
    /// turetiliyor (ilk gun -> son gun). Seri iki noktadan kisaysa delta
    /// gosterilmez — olcum yok demektir.
    /// </summary>
    public static KpiDelta? TrendDeltasi(IReadOnlyList<decimal> seri)
    {
        if (seri.Count < 2)
        {
            return null;
        }

        var fark = seri[^1] - seri[0];
        var hareket = fark switch
        {
            > 0 => KpiMovement.Increase,
            < 0 => KpiMovement.Decrease,
            _ => KpiMovement.Flat
        };

        // Metin isaretsiz yazilir: isaret ile hareketin celismesi Solum
        // sozlesmesinde hata veriyor, mutlak deger + hareket yeterli.
        var metin = $"{Math.Abs(fark):0.0} puan";

        return new KpiDelta(metin, hareket, RiskSkoruPolaritesi)
        {
            Note = "son 30 gün"
        };
    }

    /// <summary>En yüksek riskli ürünler tablosu.</summary>
    public static TableModel<DashboardModel.RiskRow> RiskTablosu(IReadOnlyList<DashboardModel.RiskRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.RiskRow>()
            .Text(r => r.Mekan, "Mekan")
            .Text(r => r.Urun, "Ürün")
            .Text(r => r.Donem, "Dönem")
            .Number(r => r.Skor, "Skor")
            .Text(r => r.Flag, "Bayrak")
            .Build(),
        Page = TekSayfa(satirlar),
        // Satir tiklanabilir: urun-mekan kirilimina gider (eski "Incele" dugmesi).
        RowUrl = r => $"/Urun/Index?id={r.UrunId}&mekanId={r.MekanId}",
        EmptyTitle = "Riskli ürün bulunamadı.",
        EmptyHint = "Gecelik ETL çalıştıktan sonra liste dolar."
    };

    // ─────────────────────────── SAHA DENETIM SEKMESI ───────────────────

    /// <summary>Saha denetim kutucuklari (alti esit agirlikli olcum).</summary>
    public static IReadOnlyList<KpiCard> DenetimKpileri(DashboardModel m)
    {
        var k = m.AuditKpi;
        return
        [
            new KpiCard { Label = "Toplam denetim", Value = Sayi(k?.TotalAudits) },
            new KpiCard { Label = "Bu ay", Value = Sayi(k?.ThisMonthAudits) },
            new KpiCard
            {
                Label = "Uyum oranı",
                Value = Yuzde(k?.AvgComplianceRate),
                Tone = UyumTonu(k?.AvgComplianceRate ?? 0)
            },
            new KpiCard
            {
                Label = "Tekrar eden",
                Value = Sayi(k?.RepeatingFindingCount),
                Tone = (k?.RepeatingFindingCount ?? 0) > 0 ? KpiTone.Warn : KpiTone.Good
            },
            new KpiCard
            {
                Label = "Sistemik",
                Value = Sayi(k?.SystemicCount),
                Tone = (k?.SystemicCount ?? 0) > 0 ? KpiTone.Bad : KpiTone.Good
            },
            new KpiCard { Label = "Bekleyen DÖF", Value = Sayi(k?.PendingDofCount), Href = "/Dof" }
        ];
    }

    /// <summary>Son denetimler tablosu.</summary>
    public static TableModel<DashboardModel.RecentAuditRow> SonDenetimler(IReadOnlyList<DashboardModel.RecentAuditRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.RecentAuditRow>()
            .Text(r => r.LocationName, "Lokasyon")
            .Text(r => r.AuditDate.ToString("dd.MM.yyyy"), "Tarih")
            .Number(r => Yuzde(r.ComplianceRate), "Uyum")
            .Text(r => r.IsFinalized ? "Kesin" : "Taslak", "Durum")
            .Build(),
        Page = TekSayfa(satirlar),
        RowUrl = r => $"/Denetimler/Detay?id={r.Id}",
        EmptyTitle = "Denetim kaydı yok.",
        EmptyHint = "Saha denetimi girildikçe burada listelenir."
    };

    /// <summary>En riskli bulgular tablosu.</summary>
    public static TableModel<DashboardModel.TopRiskFindingRow> RiskliBulgular(IReadOnlyList<DashboardModel.TopRiskFindingRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.TopRiskFindingRow>()
            .Text(r => r.ItemText, "Madde")
            .Number(r => r.FailureCount, "Başarısız")
            .Number(r => r.DistinctLocations, "Lokasyon")
            .Number(r => r.AvgRiskScore.ToString("0.0"), "Ort. risk")
            .Check(r => r.IsSystemic, "Sistemik")
            .Build(),
        Page = TekSayfa(satirlar),
        EmptyTitle = "Bulgu yok.",
        EmptyHint = "Tamamlanan denetimlerden sonra doldurulur."
    };

    /// <summary>Mağaza skorlari tablosu.</summary>
    public static TableModel<DashboardModel.LocationScoreRow> MagazaSkorlari(IReadOnlyList<DashboardModel.LocationScoreRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.LocationScoreRow>()
            .Text(r => r.LocationName, "Lokasyon")
            .Number(r => r.AuditCount, "Denetim")
            .Number(r => Yuzde(r.AvgComplianceRate), "Ort. uyum")
            .Text(r => r.LastAuditDate?.ToString("dd.MM.yyyy") ?? "—", "Son denetim")
            .Number(r => r.RepeatingFindingCount, "Tekrar eden")
            .Build(),
        Page = TekSayfa(satirlar),
        EmptyTitle = "Lokasyon skoru yok."
    };

    // ─────────────────────────── AI SEKMESI ─────────────────────────────

    /// <summary>AI kutucuklari.</summary>
    public static IReadOnlyList<KpiCard> AiKpileri(DashboardModel m)
    {
        var k = m.AiKpi;
        return
        [
            new KpiCard { Label = "Aktif insight", Value = Sayi(k?.ActiveInsights), Hint = "Proaktif öneriler" },
            new KpiCard { Label = "Onay oranı", Value = Yuzde(k?.ApprovalRate), Hint = "Kabul edilen öneriler" },
            new KpiCard { Label = "Haftalık çalışma", Value = Sayi(k?.WeeklyExecutions), Hint = "Son 7 gün skill çalışma" },
            new KpiCard { Label = "Ort. güven", Value = Yuzde(k?.AvgConfidence), Hint = "AI güven skoru" }
        ];
    }

    // ─────────────────────────── Bicimleyiciler ─────────────────────────

    private static string Sayi(int? deger) => (deger ?? 0).ToString("N0", Tr);

    private static string Yuzde(decimal? deger) => $"%{(deger ?? 0).ToString("0.0", Tr)}";

    private static readonly System.Globalization.CultureInfo Tr =
        System.Globalization.CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>Uyum orani tonu: eski ekranin esikleri korundu (%90 / %70).</summary>
    private static KpiTone UyumTonu(decimal oran) => oran switch
    {
        >= 90m => KpiTone.Good,
        >= 70m => KpiTone.Warn,
        _ => KpiTone.Bad
    };

    /// <summary>
    /// Hareket oku. Ok HAREKETI gosterir, rengi YARGI verir — ikisi ayri
    /// (Solum sozlesmesi): risk dususunde ok asagi bakar ama renk yesildir.
    /// Solum'un MovementGlyph'i renderer icinde protected oldugu icin burada.
    /// </summary>
    public static string HareketOku(KpiMovement hareket) => hareket switch
    {
        KpiMovement.Increase => "↑",
        KpiMovement.Decrease => "↓",
        _ => "→"
    };

    /// <summary>Ekran okuyucu metni: yon ve yargi yalniz renkte kalmasin.</summary>
    public static string DeltaErisim(KpiDelta delta)
    {
        var yon = delta.Movement switch
        {
            KpiMovement.Increase => "arttı",
            KpiMovement.Decrease => "azaldı",
            _ => "değişmedi"
        };
        var yargi = delta.Judge() switch
        {
            KpiJudgement.Good => ", iyi yönde",
            KpiJudgement.Bad => ", kötü yönde",
            _ => ""
        };
        return $"{yon}{yargi}: {delta.Text}";
    }

    /// <summary>Durum kodunu Solum rozet sinifina cevirir.</summary>
    public static string RozetSinifi(string? durum) => (durum ?? "").ToUpperInvariant() switch
    {
        "PASS" or "DONE" or "KESIN" => "solum-badge solum-badge-good",
        "WARN" or "RUNNING" or "QUEUED" or "ORTA" or "BEKLIYOR" => "solum-badge solum-badge-warn",
        "FAIL" or "ERROR" or "KRITIK" or "YUKSEK" or "AKSIYON" => "solum-badge solum-badge-bad",
        _ => "solum-badge"
    };
}
