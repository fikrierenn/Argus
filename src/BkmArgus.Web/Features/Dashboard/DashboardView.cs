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
    private const KpiPolarity RiskScorePolarity = KpiPolarity.LowerIsBetter;

    /// <summary>Bos liste icin tek-sayfa sarmalayici (dashboard'da sayfalama yok).</summary>
    // SortDecision.None = "istenen siralama UYGULANMADI" (Solum 2026-09
    // sozlesmesi). Dashboard tablolari kullanici siralamasi kabul etmiyor,
    // sira SP'den geldigi gibi; bunu tip uzerinde BEYAN ediyoruz.
    private static PagedResult<T> SinglePage<T>(IReadOnlyList<T> satirlar) =>
        new(satirlar, satirlar.Count, 1, Math.Max(1, satirlar.Count), SortDecision.None);

    // ─────────────────────────── ERP RISK SEKMESI ───────────────────────

    /// <summary>ERP risk sekmesi kutucuklari.</summary>
    public static IReadOnlyList<KpiCard> RiskKpis(DashboardModel m) =>
    [
        new KpiCard
        {
            Label = "Kritik risk",
            Value = m.KritikRiskDeger,
            // Is kurali: kritik risk sayisi sifirdan buyukse bu bir uyaridir.
            Tone = m.KritikRiskDeger == "0" ? SolumTone.Neutral : SolumTone.Bad,
            Hint = m.KritikRiskNot,
            Href = SafeUrl.Create("/Risk")
        },
        new KpiCard
        {
            Label = "Bekleyen DÖF",
            Value = m.BekleyenDofDeger,
            Tone = m.BekleyenDofDeger == "0" ? SolumTone.Good : SolumTone.Warn,
            Hint = m.BekleyenDofNot,
            Href = SafeUrl.Create("/Dof")
        },
        new KpiCard
        {
            Label = "Taranan stok",
            Value = m.TarananStokDeger,
            Tone = SolumTone.Neutral,
            Hint = m.TarananStokNot
        },
        new KpiCard
        {
            Label = "Sistem sağlığı",
            Value = m.SistemDurum,
            Tone = m.SistemDurum switch
            {
                "PASS" => SolumTone.Good,
                "WARN" => SolumTone.Warn,
                _ => SolumTone.Bad
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
    public static KpiDelta? TrendDelta(IReadOnlyList<decimal> seri)
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

        return new KpiDelta(metin, hareket, RiskScorePolarity)
        {
            Hint = "son 30 gün"
        };
    }

    /// <summary>En yüksek riskli ürünler tablosu.</summary>
    public static TableModel<DashboardModel.RiskRow> RiskTable(IReadOnlyList<DashboardModel.RiskRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.RiskRow>()
            .Text(r => r.Mekan, "Mekan")
            .Text(r => r.Urun, "Ürün")
            .Text(r => r.Donem, "Dönem")
            .Numeric(r => r.Skor, "Skor")
            .Text(r => r.Flag, "Bayrak")
            .Build(),
        Page = SinglePage(satirlar),
        // Satir tiklanabilir: urun-mekan kirilimina gider (eski "Incele" dugmesi).
        RowUrl = r => $"/Urun/Index?id={r.UrunId}&mekanId={r.MekanId}",
        EmptyTitle = "Riskli ürün bulunamadı.",
        EmptyHint = "Gecelik ETL çalıştıktan sonra liste dolar."
    };

    // ─────────────────────────── SAHA DENETIM SEKMESI ───────────────────

    /// <summary>Saha denetim kutucuklari (alti esit agirlikli olcum).</summary>
    public static IReadOnlyList<KpiCard> AuditKpis(DashboardModel m)
    {
        var k = m.AuditKpi;
        return
        [
            new KpiCard { Label = "Toplam denetim", Value = FormatCount(k?.TotalAudits) },
            new KpiCard { Label = "Bu ay", Value = FormatCount(k?.ThisMonthAudits) },
            new KpiCard
            {
                Label = "Uyum oranı",
                Value = FormatPercent(k?.AvgComplianceRate),
                Tone = ComplianceTone(k?.AvgComplianceRate ?? 0)
            },
            new KpiCard
            {
                Label = "Tekrar eden",
                Value = FormatCount(k?.RepeatingFindingCount),
                Tone = (k?.RepeatingFindingCount ?? 0) > 0 ? SolumTone.Warn : SolumTone.Good
            },
            new KpiCard
            {
                Label = "Sistemik",
                Value = FormatCount(k?.SystemicCount),
                Tone = (k?.SystemicCount ?? 0) > 0 ? SolumTone.Bad : SolumTone.Good
            },
            new KpiCard { Label = "Bekleyen DÖF", Value = FormatCount(k?.PendingDofCount), Href = SafeUrl.Create("/Dof") }
        ];
    }

    /// <summary>Son denetimler tablosu.</summary>
    public static TableModel<DashboardModel.RecentAuditRow> RecentAuditsTable(IReadOnlyList<DashboardModel.RecentAuditRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.RecentAuditRow>()
            .Text(r => r.LocationName, "Lokasyon")
            .Text(r => r.AuditDate.ToString("dd.MM.yyyy"), "Tarih")
            .Numeric(r => FormatPercent(r.ComplianceRate), "Uyum")
            .Text(r => r.IsFinalized ? "Kesin" : "Taslak", "Durum")
            .Build(),
        Page = SinglePage(satirlar),
        RowUrl = r => $"/Denetimler/Detay?id={r.Id}",
        EmptyTitle = "Denetim kaydı yok.",
        EmptyHint = "Saha denetimi girildikçe burada listelenir."
    };

    /// <summary>En riskli bulgular tablosu.</summary>
    public static TableModel<DashboardModel.TopRiskFindingRow> TopFindingsTable(IReadOnlyList<DashboardModel.TopRiskFindingRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.TopRiskFindingRow>()
            .Text(r => r.ItemText, "Madde")
            .Numeric(r => r.FailureCount, "Başarısız")
            .Numeric(r => r.DistinctLocations, "Lokasyon")
            .Numeric(r => r.AvgRiskScore.ToString("0.0"), "Ort. risk")
            .Check(r => r.IsSystemic, "Sistemik")
            .Build(),
        Page = SinglePage(satirlar),
        EmptyTitle = "Bulgu yok.",
        EmptyHint = "Tamamlanan denetimlerden sonra doldurulur."
    };

    /// <summary>Mağaza skorlari tablosu.</summary>
    public static TableModel<DashboardModel.LocationScoreRow> LocationScoresTable(IReadOnlyList<DashboardModel.LocationScoreRow> satirlar) => new()
    {
        Columns = new ColumnBuilder<DashboardModel.LocationScoreRow>()
            .Text(r => r.LocationName, "Lokasyon")
            .Numeric(r => r.AuditCount, "Denetim")
            .Numeric(r => FormatPercent(r.AvgComplianceRate), "Ort. uyum")
            .Text(r => r.LastAuditDate?.ToString("dd.MM.yyyy") ?? "—", "Son denetim")
            .Numeric(r => r.RepeatingFindingCount, "Tekrar eden")
            .Build(),
        Page = SinglePage(satirlar),
        EmptyTitle = "Lokasyon skoru yok."
    };

    // ─────────────────────────── AI SEKMESI ─────────────────────────────

    /// <summary>AI kutucuklari.</summary>
    public static IReadOnlyList<KpiCard> AiKpis(DashboardModel m)
    {
        var k = m.AiKpi;
        return
        [
            new KpiCard { Label = "Aktif insight", Value = FormatCount(k?.ActiveInsights), Hint = "Proaktif öneriler" },
            new KpiCard { Label = "Onay oranı", Value = FormatPercent(k?.ApprovalRate), Hint = "Kabul edilen öneriler" },
            new KpiCard { Label = "Haftalık çalışma", Value = FormatCount(k?.WeeklyExecutions), Hint = "Son 7 gün skill çalışma" },
            new KpiCard { Label = "Ort. güven", Value = FormatPercent(k?.AvgConfidence), Hint = "AI güven skoru" }
        ];
    }

    // ─────────────────────────── Bicimleyiciler ─────────────────────────

    private static string FormatCount(int? deger) => ArgusFormat.Count(deger);

    private static string FormatPercent(decimal? deger) => ArgusFormat.Percent(deger);


    /// <summary>Uyum orani tonu: eski ekranin esikleri korundu (%90 / %70).</summary>
    private static SolumTone ComplianceTone(decimal oran) => oran switch
    {
        >= 90m => SolumTone.Good,
        >= 70m => SolumTone.Warn,
        _ => SolumTone.Bad
    };

    /// <summary>
    /// Hareket oku. Ok HAREKETI gosterir, rengi YARGI verir — ikisi ayri
    /// (Solum sozlesmesi): risk dususunde ok asagi bakar ama renk yesildir.
    /// Solum'un MovementGlyph'i renderer icinde protected oldugu icin burada.
    /// </summary>
    public static string MovementGlyph(KpiMovement hareket) => hareket switch
    {
        KpiMovement.Increase => "↑",
        KpiMovement.Decrease => "↓",
        _ => "→"
    };

    /// <summary>Ekran okuyucu metni: yon ve yargi yalniz renkte kalmasin.</summary>
    public static string DeltaScreenReaderText(KpiDelta delta)
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
    public static string BadgeClass(string? durum) => (durum ?? "").ToUpperInvariant() switch
    {
        "PASS" or "DONE" or "KESIN" => "solum-badge solum-badge-good",
        "WARN" or "RUNNING" or "QUEUED" or "ORTA" or "BEKLIYOR" => "solum-badge solum-badge-warn",
        "FAIL" or "ERROR" or "KRITIK" or "YUKSEK" or "AKSIYON" => "solum-badge solum-badge-bad",
        _ => "solum-badge"
    };
}
