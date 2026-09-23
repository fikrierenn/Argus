using BkmArgus.Web.Features;
using Solum.Web.Components;

namespace BkmArgus.Web.Features.Audit;

/// <summary>
/// Saha denetim listesi sunum haritasi (plan: 05, Dalga 1).
/// Eski ekranda dort sinif-uretici Razor fonksiyonu vardi (ScorePercent,
/// ScoreBadge, StatusBadge, StatusText); hepsi buraya tasindi.
/// </summary>
public static class AuditView
{
    /// <summary>
    /// Gecen madde yuzdesi. Toplam sifirsa SIFIR doner — bolme yapilmaz.
    /// Not: "madde yok" ile "hicbiri gecmedi" ayni sey degil; ekranda
    /// gecen/toplam sayisi da gosteriliyor ki ayrim gorunur olsun.
    /// </summary>
    public static int ScorePercent(int gecen, int toplam) =>
        toplam > 0 ? (int)Math.Round(100.0 * gecen / toplam) : 0;

    /// <summary>Uyum orani IYI esigi — bu oranin ustu yesil.</summary>
    private const int UyumIyiEsik = 90;

    /// <summary>Uyum orani UYARI esigi — altina duserse kirmizi.</summary>
    private const int UyumUyariEsik = 70;

    /// <summary>
    /// Uyum yuzdesi rozeti — esikler eski ekrandan korundu (%90 / %70).
    /// `yuksekKotu: false` cunku YUKSEK uyum IYIdir (risk skorunun tersi).
    /// </summary>
    public static string ScoreBadgeClass(int yuzde) =>
        ArgusBadge.ForThreshold(yuzde, UyumIyiEsik, UyumUyariEsik, yuksekKotu: false);

    /// <summary>
    /// Durum rozeti. Kesinlestirilmis denetim IYI degil, TAMAMLANMIS'tir —
    /// bu yuzden yesil yerine notr ton; taslak da kotu degil, yalniz eksik.
    /// Eski ekran kesinlestirilmise yesil veriyordu ve "iyi denetim" izlenimi
    /// uretiyordu; uyum yuzdesi zaten ayri rozette.
    /// </summary>
    public static string StatusBadgeClass(bool kesinlestirildi) =>
        ArgusBadge.Class(kesinlestirildi ? SolumTone.Neutral : SolumTone.Warn);

    /// <summary>Durum metni.</summary>
    public static string StatusText(bool kesinlestirildi) =>
        kesinlestirildi ? "Kesinleştirildi" : "Taslak";

    /// <summary>
    /// Suzgec panelinde gosterilecek ETKIN olcut etiketleri (plan 07, Faz 4).
    /// Gerekce ve neyi saymadigi icin bkz. <see cref="RiskView.AktifSuzgecler"/> —
    /// iki ekranda ayni kural gecerli: yalnizca listeyi DARALTAN secim sayilir.
    /// </summary>
    public static IReadOnlyList<string> AktifSuzgecler(IndexModel m)
    {
        var etkin = new List<string>();

        if (!string.IsNullOrWhiteSpace(m.Search)) etkin.Add($"Magaza: {m.Search}");
        if (m.StartDate.HasValue) etkin.Add($"{m.StartDate:dd.MM.yyyy} sonrasi");
        if (m.EndDate.HasValue) etkin.Add($"{m.EndDate:dd.MM.yyyy} oncesi");
        if (m.IsFinalized.HasValue) etkin.Add(StatusText(m.IsFinalized.Value));

        return etkin;
    }

    /// <summary>
    /// Denetim maddesi risk rozeti (plan 08).
    ///
    /// ESIKLER DB'DEN ALINDI, EKRANDAN DEGIL. audit.AuditResults.RiskLevel
    /// PERSISTED computed kolonu su esikleri kullaniyor
    /// (sql/20_migration_audit.sql:145-149):
    ///     &lt;= 8  Low   ·  &lt;= 15 Medium  ·  else High
    /// Eski ekran ise "&gt;= 15 kirmizi, &gt;= 9 amber" diyordu; yani skor TAM
    /// 15 olan bir maddede DB "Medium" derken ekran "yuksek" gosteriyordu.
    ///
    /// Ekran DB'ye uyduruldu, tersi DEGIL: RiskLevel persisted bir kolondur,
    /// tanimini degistirmek SQL Server'a TUM GECMIS SATIRLARI yeniden
    /// hesaplatir ve gecmis raporlar degisir (sql-conventions.md §6 tuzagi).
    /// Ekrani degistirmek gecmisi bozmaz.
    /// </summary>
    public static string ItemRiskBadgeClass(int riskSkoru) =>
        ArgusBadge.ForThreshold(riskSkoru, kotuEsik: 16, uyariEsik: 9, yuksekKotu: true);

    /// <summary>
    /// Bulgu tipi kodu -&gt; Turkce metin. DB kolonu char(1) (U/G/I).
    /// Taninmayan kod GIZLENMEZ, kodun kendisi gosterilir: veride ne varsa
    /// kullanici onu gormeli — sessizce "bos" gostermek, eski ekranin
    /// yaptigi hatanin ta kendisiydi.
    /// </summary>
    public static string FindingTypeText(string? kod) => (kod ?? "").Trim().ToUpperInvariant() switch
    {
        "U" => "Uygunsuzluk",
        "G" => "Gozlem",
        "I" => "Iyilestirme",
        ""  => "—",
        _   => $"Bilinmeyen kod: {kod}"
    };

    /// <summary>
    /// Bulgu tipi secenekleri. Mevcut deger taninan kodlardan biri DEGILSE
    /// listeye AYRICA eklenir; aksi halde Solum'un &lt;solum-field&gt; korumasi
    /// "deger seceneklerin hicbirinde yok" diye hata verir ve duzenleme
    /// ekrani acilmaz — veri yuzunden ekran kirilmis olurdu.
    /// </summary>
    public static IReadOnlyList<SelectOption> FindingTypeOptions(string? mevcut)
    {
        var secenekler = new List<SelectOption>
        {
            new("U", "Uygunsuzluk"),
            new("G", "Gozlem"),
            new("I", "Iyilestirme")
        };

        var kod = (mevcut ?? "").Trim();
        if (kod.Length > 0 && !secenekler.Any(o => string.Equals(o.Value, kod, StringComparison.OrdinalIgnoreCase)))
        {
            secenekler.Add(new SelectOption(kod, FindingTypeText(kod)));
        }

        return secenekler;
    }
}
