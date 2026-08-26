using System.Globalization;
using Solum.Web.Components;

namespace BkmArgus.Web.Features;

/// <summary>
/// Ortak biçimleme ve rozet yardımcıları.
///
/// NEDEN VAR (kural-uyum denetimi 2026-08-26): `TrCulture` alanı beş dosyada
/// birebir tekrarlıyordu, rozet sınıf dizesi altı `*View.cs` içinde 25+ kez
/// elle yazılıyordu ve `>= 90 good / >= 70 warn` eşik deseni iki dosyada
/// bağımsız iki kez yazılmıştı. Domaine özgü eşlemeler (kadran, bayrak, risk
/// tipi) burada DEĞİL — onlar tekrar değil, gerçek domain farkı.
/// </summary>
public static class ArgusFormat
{
    /// <summary>Tek kültür kaynağı — tüm ekranlar buradan besleniyor.</summary>
    public static readonly CultureInfo Tr = CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>
    /// MIKTAR biçimi — ondalık KORUNUR.
    ///
    /// Sessiz hata denetimi (2026-08-26) dört yerde `"N0"` buldu: stok
    /// `decimal(18,3)` olduğu için 0,4 ekranda "0", 2,5 ise "3" görünüyordu.
    /// Denetim aracında bu, uydurulmuş bulgu üretir: denetçi ekranı ERP
    /// dökümüyle kıyaslar, sayılar tutmaz, farkı "veri tutarsızlığı" diye
    /// yazar — oysa kaynak yalnız ekran biçimlemesidir.
    ///
    /// Tam sayı ise ondalık gösterilmez (kalabalık yapmasın), kesirli ise
    /// üç hane gösterilir (şema `decimal(18,3)`).
    /// </summary>
    public static string Quantity(decimal deger) =>
        deger == Math.Truncate(deger)
            ? deger.ToString("N0", Tr)
            : deger.ToString("N3", Tr);

    /// <summary>Miktar, boş olabilir — null "—" olur, sıfır "0" kalır.</summary>
    public static string Quantity(decimal? deger) => deger.HasValue ? Quantity(deger.Value) : "—";

    /// <summary>Adet (tam sayı) biçimi.</summary>
    public static string Count(int? deger) => (deger ?? 0).ToString("N0", Tr);

    /// <summary>Yüzde biçimi.</summary>
    public static string Percent(decimal? deger) => $"%{(deger ?? 0).ToString("0.0", Tr)}";

    /// <summary>Para biçimi — miktardan ayrı, iki hane sabit.</summary>
    public static string Money(decimal? deger) => deger?.ToString("N2", Tr) ?? "—";
}

/// <summary>
/// Rozet sınıfı üreticisi. Ham CSS dizesini tek yerde tutar.
/// </summary>
public static class ArgusBadge
{
    /// <summary>Tona göre rozet sınıfı. <paramref name="numeric"/> tabular-nums ekler.</summary>
    public static string Class(SolumTone ton, bool numeric = false)
    {
        var temel = numeric ? "solum-badge solum-badge-num" : "solum-badge";
        return ton switch
        {
            SolumTone.Good => $"{temel} solum-badge-good",
            SolumTone.Warn => $"{temel} solum-badge-warn",
            SolumTone.Bad => $"{temel} solum-badge-bad",
            _ => temel
        };
    }

    /// <summary>
    /// Eşiğe göre ton. <paramref name="yuksekKotu"/> = true ise yüksek değer
    /// KÖTÜ (risk skoru), false ise yüksek değer İYİ (uyum oranı).
    ///
    /// Bu ayrım kritik: aynı sayı iki metrikte ters renk ister. Tek fonksiyona
    /// indirip bayrağı atlamak yarısını ters renkte gösterirdi.
    /// </summary>
    public static SolumTone Tone(decimal deger, decimal kotuEsik, decimal uyariEsik, bool yuksekKotu)
    {
        if (yuksekKotu)
        {
            return deger >= kotuEsik ? SolumTone.Bad
                 : deger >= uyariEsik ? SolumTone.Warn
                 : SolumTone.Good;
        }

        return deger < kotuEsik ? SolumTone.Bad
             : deger < uyariEsik ? SolumTone.Warn
             : SolumTone.Good;
    }

    /// <summary>Eşiğe göre doğrudan sınıf — en sık kullanılan kısayol.</summary>
    public static string ForThreshold(decimal deger, decimal kotuEsik, decimal uyariEsik,
                                      bool yuksekKotu, bool numeric = true) =>
        Class(Tone(deger, kotuEsik, uyariEsik, yuksekKotu), numeric);
}
