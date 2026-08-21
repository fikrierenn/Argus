using System.Globalization;
using System.Text;

namespace BkmArgus.AiWorker;

/// <summary>
/// Bellek ici BM25 anahtar kelime indeksi.
///
/// Neden gerekli: saf vektor aramasi tanimlayici terimlerde coker. Azure'un
/// olcumunde kisa/tanimlayici sorgularda keyword 79,2 alirken vektor 11,7'ye
/// dusuyor. Bizim alanimizda "Ozluce", "yangin tupu", DOF numarasi, urun kodu
/// tam olarak bu tur terimler — e5 bunlari anlamca yakin baska bir seye
/// benzetip kaciriyor.
///
/// Neden SQL Server FULLTEXT degil: sunucuda Full-Text Search KURULU DEGIL
/// (FULLTEXTSERVICEPROPERTY('IsFullTextInstalled') = 0). Kurulum instance
/// seviyesinde bir degisiklik ve yeniden baslatma gerektirebilir. Ayrica
/// FREETEXTTABLE'in dondurdugu RANK degeri Microsoft'un kendi ifadesiyle
/// sorgular arasi anlamsizdir, yani zaten yalniz SIRA olarak kullanilabilirdi —
/// ki bu da bizim RRF yaklasimimizla ayni. 189 kayitlik bir korpus icin
/// sunucu degisikligi beklemenin karsiligi yok.
///
/// Indeks her vektor senkronundan sonra yeniden kurulur; 189 kayitta maliyeti
/// olculemeyecek kadar dusuk.
/// </summary>
public sealed class KeywordIndex
{
    // Okapi BM25 standart parametreleri
    private const double K1 = 1.2;
    private const double B = 0.75;

    /// <summary>
    /// Turkce durak kelimeleri. Ayirt edicilige katkisi olmayan, neredeyse her
    /// belgede gecen kelimeler — indekse girerlerse IDF'leri sifira yaklasir
    /// ama gereksiz yer kaplar ve kisa sorgularda gurultu uretir.
    /// Denetim metinlerine ozgu kalip kelimeler de eklendi ("ediliyor", "mu").
    /// </summary>
    private static readonly HashSet<string> StopWords = new(StringComparer.Ordinal)
    {
        "acaba","ama","ancak","artik","asla","aslinda","az","bana","bazi","belki",
        "ben","beni","benim","beri","bile","bir","biraz","birkac","bircok","biz",
        "bize","bizim","bu","buna","bunda","bundan","bunu","bunun","burada","cok",
        "cunku","da","daha","de","defa","degil","diger","diye","dolayi","edilir",
        "ediliyor","edilmis","ederek","eger","en","fakat","gibi","hala","hangi",
        "hem","henuz","hep","hepsi","her","hic","icin","ile","ilgili","ise","kadar",
        "karsin","katrilyon","kendi","kez","ki","kim","mi","mu","mus","mi̇","na",
        "nasil","ne","neden","nerde","nerede","nereye","niye","o","olan","olarak",
        "oldu","olduğu","olmak","olan","olup","ona","ondan","onlar","onu","onun",
        "oysa","sanki","sadece","se","siz","sonra","su","tarafindan","trilyon","tum",
        "uzere","var","ve","veya","ya","yani","yine","yoksa","zaten"
    };

    private readonly Dictionary<string, Dictionary<int, int>> _postings = new(StringComparer.Ordinal);
    private int[] _docLengths = [];
    private double _avgDocLength;
    private int _docCount;

    /// <summary>Indeksi sifirdan kurar. Belge sirasi cagiranin listesiyle aynidir.</summary>
    public void Build(IReadOnlyList<string> documents)
    {
        _postings.Clear();
        _docCount = documents.Count;
        _docLengths = new int[_docCount];

        for (var i = 0; i < _docCount; i++)
        {
            var terms = Tokenize(documents[i]);
            _docLengths[i] = terms.Count;

            foreach (var term in terms)
            {
                if (!_postings.TryGetValue(term, out var posting))
                {
                    posting = new Dictionary<int, int>();
                    _postings[term] = posting;
                }

                posting[i] = posting.GetValueOrDefault(i) + 1;
            }
        }

        _avgDocLength = _docCount == 0 ? 0 : _docLengths.Average();
    }

    /// <summary>
    /// Sorgu icin BM25 skorlarini dondurur (belge indeksi -> skor).
    /// Hic terim eslesmeyen belgeler sonuca girmez.
    /// </summary>
    public Dictionary<int, double> Score(string query)
    {
        var scores = new Dictionary<int, double>();

        if (_docCount == 0)
        {
            return scores;
        }

        foreach (var term in Tokenize(query).Distinct(StringComparer.Ordinal))
        {
            if (!_postings.TryGetValue(term, out var posting))
            {
                continue;
            }

            // Okapi IDF. 189 kayitlik korpusta bu istatistik gurultulu —
            // tek belgede gecen terim buyuk agirlik alir. RRF sira kullandigi
            // icin bu sismenin siralamaya zarari sinirli kalir.
            var idf = Math.Log(1 + (_docCount - posting.Count + 0.5) / (posting.Count + 0.5));

            foreach (var (docId, tf) in posting)
            {
                var lengthNorm = 1 - B + B * (_docLengths[docId] / Math.Max(1e-9, _avgDocLength));
                var contribution = idf * (tf * (K1 + 1)) / (tf + K1 * lengthNorm);
                scores[docId] = scores.GetValueOrDefault(docId) + contribution;
            }
        }

        return scores;
    }

    /// <summary>
    /// Turkce duyarli sadelestirme: kucuk harfe cevir (I/İ tuzagi icin
    /// Turkce kultur), aksani kaldir, noktalamayi at, durak kelimeleri ele.
    ///
    /// Govdeleme (stemming) YOK. Turkce sondan eklemeli; yanlis govdeleme
    /// "kasa" ile "kasap"i birlestirebilir. Bunun yerine 4 karakterden uzun
    /// kelimelerde onek eslesmesi ayri bir terim olarak indekslenir — kaba
    /// ama yanlis birlestirme yapmayan bir yaklasim.
    /// </summary>
    private static List<string> Tokenize(string? text)
    {
        var result = new List<string>();

        if (string.IsNullOrWhiteSpace(text))
        {
            return result;
        }

        var lowered = text.ToLower(CultureInfo.GetCultureInfo("tr-TR"));
        var buffer = new StringBuilder();

        foreach (var ch in lowered)
        {
            if (char.IsLetterOrDigit(ch))
            {
                buffer.Append(Fold(ch));
            }
            else if (buffer.Length > 0)
            {
                Emit(buffer.ToString(), result);
                buffer.Clear();
            }
        }

        if (buffer.Length > 0)
        {
            Emit(buffer.ToString(), result);
        }

        return result;
    }

    private static void Emit(string token, List<string> result)
    {
        if (token.Length < 2 || StopWords.Contains(token))
        {
            return;
        }

        result.Add(token);

        // Ek almis bicimleri yakalamak icin govde adayi: "sayimda" -> "sayim#"
        // Ayri terim olarak eklenir, orijinali ezmez.
        if (token.Length > 5)
        {
            result.Add(token[..5] + "#");
        }
    }

    /// <summary>Turkce aksanlari ASCII karsiligina indirger — yazim farklarini tolere eder.</summary>
    private static char Fold(char c) => c switch
    {
        'ç' => 'c', 'ğ' => 'g', 'ı' => 'i', 'ö' => 'o', 'ş' => 's', 'ü' => 'u',
        'â' => 'a', 'î' => 'i', 'û' => 'u',
        _ => c
    };
}
