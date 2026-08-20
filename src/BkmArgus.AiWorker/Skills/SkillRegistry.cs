using System.Data;
using Dapper;
using Microsoft.Extensions.Logging;

namespace BkmArgus.AiWorker.Skills;

/// <summary>
/// AI skill kayit defteri. Kaynak onceligi: ai.Skills tablosu (DB) > koddaki yerlesik tanimlar.
/// Prompt'lar DB'de versiyonlu tutulur (ai.SkillVersions); kod tanimlari yalniz fallback'tir
/// (DB erisilemezse veya skill henuz seed edilmemisse worker calismaya devam eder).
/// Bkz. .claude/rules/ai-layer.md 3.
/// </summary>
public class SkillRegistry
{
    private readonly Dictionary<string, SkillDefinition> _skills = new(StringComparer.OrdinalIgnoreCase);
    private readonly Db? _db;
    private readonly ILogger<SkillRegistry>? _logger;
    private DateTime _lastLoadedAt = DateTime.MinValue;
    private readonly SemaphoreSlim _loadLock = new(1, 1);

    /// <summary>DB'den yeniden yukleme araligi. Prompt degisikligi worker restart'i gerektirmesin.</summary>
    private static readonly TimeSpan ReloadInterval = TimeSpan.FromMinutes(10);

    public SkillRegistry(Db db, ILogger<SkillRegistry> logger)
    {
        _db = db;
        _logger = logger;
        RegisterAll();          // once kod fallback'i
    }

    /// <summary>Parametresiz kurucu — test ve DB'siz senaryolar icin (yalniz kod tanimlari).</summary>
    public SkillRegistry()
    {
        RegisterAll();
    }

    public SkillDefinition? Get(string skillId) => _skills.GetValueOrDefault(skillId);
    public IReadOnlyList<SkillDefinition> GetAll() => _skills.Values.ToList();
    public IReadOnlyList<SkillDefinition> GetByCategory(SkillCategory category) =>
        _skills.Values.Where(s => s.Category == category).ToList();

    /// <summary>
    /// DB'deki tanimlari yukler ve ayni SkillId'li kod tanimini EZER.
    /// Soft-fail: DB erisilemezse uyari loglanir, kod tanimlariyla devam edilir.
    /// </summary>
    public async Task<int> ReloadFromDbAsync(bool zorla = false, CancellationToken ct = default)
    {
        if (_db is null) return 0;
        if (!zorla && DateTime.UtcNow - _lastLoadedAt < ReloadInterval) return 0;

        await _loadLock.WaitAsync(ct);
        try
        {
            if (!zorla && DateTime.UtcNow - _lastLoadedAt < ReloadInterval) return 0;

            await using var conn = _db.CreateConnection();
            var rows = await conn.QueryAsync<SkillRow>(
                new CommandDefinition("ai.sp_Skill_List",
                    new { SadeceAktif = true },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: ct));

            var yuklenen = 0;
            foreach (var r in rows)
            {
                // Prompt'suz kayit kullanilamaz — kod fallback'i korunur
                if (string.IsNullOrWhiteSpace(r.SystemPromptTemplate) || string.IsNullOrWhiteSpace(r.UserPromptTemplate))
                {
                    _logger?.LogWarning("Skill {SkillId} DB'de prompt'suz — kod tanimi korunuyor.", r.SkillId);
                    continue;
                }

                _skills[r.SkillId] = new SkillDefinition
                {
                    SkillId              = r.SkillId,
                    Name                 = r.Name ?? r.SkillId,
                    Description          = r.Description ?? "",
                    Category             = ParseEnum(r.Category, SkillCategory.General),
                    Trigger              = ParseEnum(r.TriggerMode, TriggerMode.Reactive),
                    Output               = ParseEnum(r.OutputType, OutputType.Text),
                    RequiredContext      = (r.RequiredContext ?? "")
                                               .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries),
                    Temperature          = (double)(r.Temperature ?? 0.20m),
                    MaxTokens            = r.MaxTokens ?? 2048,
                    VersionNo            = r.CurrentVersion,
                    SystemPromptTemplate = r.SystemPromptTemplate,
                    UserPromptTemplate   = r.UserPromptTemplate
                };
                yuklenen++;
            }

            _lastLoadedAt = DateTime.UtcNow;
            _logger?.LogInformation("Skill registry DB'den yuklendi: {Adet} skill (toplam {Toplam}).", yuklenen, _skills.Count);
            return yuklenen;
        }
        catch (Exception ex)
        {
            // Soft-fail: AI hatti DB skill'i olmadan da kod tanimlariyla calisir
            _logger?.LogWarning(ex, "Skill registry DB'den yuklenemedi — kod tanimlariyla devam ediliyor.");
            return 0;
        }
        finally
        {
            _loadLock.Release();
        }
    }

    private static TEnum ParseEnum<TEnum>(string? deger, TEnum varsayilan) where TEnum : struct
        => Enum.TryParse<TEnum>(deger, ignoreCase: true, out var sonuc) ? sonuc : varsayilan;

    /// <summary>ai.sp_Skill_List donus satiri.</summary>
    private sealed class SkillRow
    {
        public string SkillId { get; init; } = "";
        public string? Name { get; init; }
        public string? Description { get; init; }
        public string? Category { get; init; }
        public string? TriggerMode { get; init; }
        public string? OutputType { get; init; }
        public string? RequiredContext { get; init; }
        public decimal? Temperature { get; init; }
        public int? MaxTokens { get; init; }
        public int CurrentVersion { get; init; }
        public string? SystemPromptTemplate { get; init; }
        public string? UserPromptTemplate { get; init; }
    }

    private void RegisterAll()
    {
        Register(new SkillDefinition
        {
            SkillId = "audit.analyze",
            Name = "Denetim Analizi",
            Description = "Kesinlestirilen denetimin bulgularini analiz eder, tekrar eden pattern'leri tespit eder, root cause onerir",
            Category = SkillCategory.Audit,
            Trigger = TriggerMode.Proactive,
            RequiredContext = ["auditResults", "locationHistory", "riskFlags", "semanticDefinitions"],
            Output = OutputType.StructuredJson,
            Temperature = 0.2,
            MaxTokens = 3000,
            SystemPromptTemplate = """
                Sen BKMKitap ic denetim uzmanisin. Turkce yanit ver. Gorevin: magaza denetim bulgularini analiz etmek, tekrar eden sorunlari tespit etmek, kok neden onerileri sunmak.

                Cikti formati (JSON):
                {
                  "ozet": "Yonetici ozeti (2-3 cumle)",
                  "kritikBulgular": ["bulgu1", "bulgu2"],
                  "kokNedenler": ["neden1", "neden2"],
                  "tekrarEdenler": ["madde1 (Xn)"],
                  "onerilenAksiyonlar": ["aksiyon1", "aksiyon2"],
                  "oncelikSirasi": "acil/yuksek/orta",
                  "guvenSkoru": 85
                }
                """,
            UserPromptTemplate = """
                Denetim Bilgileri:
                Magaza: {{locationName}}
                Tarih: {{auditDate}}
                Toplam Madde: {{totalItems}}, Basarisiz: {{failedItems}}

                Basarisiz Bulgular:
                {{failedItemsList}}

                Tekrar Eden Maddeler:
                {{repeatItems}}

                Semantik Baglamlar:
                {{semanticContext}}

                Bu denetimi analiz et ve JSON formatinda yanit ver.
                """
        });

        Register(new SkillDefinition
        {
            SkillId = "dof.recommend",
            Name = "DOF Aksiyon Onerisi",
            Description = "Basarisiz bulgu icin duzeltici/onleyici aksiyon onerir",
            Category = SkillCategory.DOF,
            Trigger = TriggerMode.Reactive,
            RequiredContext = ["finding", "riskLevel", "pastDofs", "similarCases"],
            Output = OutputType.StructuredJson,
            Temperature = 0.3,
            MaxTokens = 2000,
            SystemPromptTemplate = """
                Sen BKMKitap ic denetim DOF (Duzeltici/Onleyici Faaliyet) uzmanisin. Turkce yanit ver.

                Cikti formati (JSON):
                {
                  "baslik": "DOF basligi",
                  "aciklama": "Detayli aciklama",
                  "aksiyonlar": ["adim1", "adim2"],
                  "sorumluluk": "Kim yapmali",
                  "sla": "Kac gun icinde",
                  "oncelik": "kritik/yuksek/orta/dusuk",
                  "guvenSkoru": 80
                }
                """,
            UserPromptTemplate = """
                Bulgu: {{findingTitle}}
                Risk Seviyesi: {{riskLevel}}
                Denetim Grubu: {{auditGroup}}
                Alan: {{area}}

                Gecmis Benzer DOF'lar:
                {{pastDofs}}

                Benzer Vakalar:
                {{similarCases}}

                Bu bulgu icin DOF aksiyonu oner.
                """
        });

        Register(new SkillDefinition
        {
            SkillId = "risk.explain",
            Name = "Risk Aciklamasi",
            Description = "Risk skorunu ve aktif flag'leri Turkce aciklar",
            Category = SkillCategory.Risk,
            Trigger = TriggerMode.Reactive,
            RequiredContext = ["riskScore", "activeFlags", "movementSummary"],
            Output = OutputType.Text,
            Temperature = 0.2,
            MaxTokens = 1500,
            SystemPromptTemplate = "Sen BKMKitap risk analisti. Turkce, sade ve anlasilir dilde yanit ver. Risk skorlarini ve flag'leri isletme diliyle acikla.",
            UserPromptTemplate = """
                Urun: {{productName}} ({{productCode}})
                Mekan: {{locationName}}
                Risk Skoru: {{riskScore}}/100

                Aktif Flag'ler:
                {{activeFlags}}

                Hareket Ozeti:
                {{movementSummary}}

                Semantik Tanimlar:
                {{semanticContext}}

                Bu riskin nedenlerini ve onerileri acikla.
                """
        });

        Register(new SkillDefinition
        {
            SkillId = "dof.comment",
            Name = "DOF Yorum Onerisi",
            Description = "DOF surecinde AI destekli yorum/mesaj onerisi",
            Category = SkillCategory.DOF,
            Trigger = TriggerMode.Reactive,
            RequiredContext = ["dofTitle", "dofStatus", "previousComments"],
            Output = OutputType.Suggestion,
            Temperature = 0.4,
            MaxTokens = 500,
            SystemPromptTemplate = "Sen BKMKitap ic denetim asistanisin. DOF surecinde yardimci yorum onerileri sun. Kisa, net, aksiyona yonelik.",
            UserPromptTemplate = """
                DOF: {{dofTitle}}
                Durum: {{dofStatus}}
                Onceki Yorumlar:
                {{previousComments}}

                Bir sonraki adim icin yorum oner.
                """
        });

        Register(new SkillDefinition
        {
            SkillId = "report.executive",
            Name = "Yonetici Ozeti",
            Description = "Haftalik/aylik denetim performans ozeti uretir",
            Category = SkillCategory.Report,
            Trigger = TriggerMode.Proactive,
            RequiredContext = ["auditStats", "dofStats", "riskTrend", "topFindings"],
            Output = OutputType.Text,
            Temperature = 0.3,
            MaxTokens = 2500,
            SystemPromptTemplate = "Sen BKMKitap ust yonetime raporlama yapan ic denetim muduru yardimcisisin. Profesyonel, ozlu, veriye dayali raporlar yaz.",
            UserPromptTemplate = """
                Donem: {{periodLabel}}

                Denetim Istatistikleri:
                {{auditStats}}

                DOF Durumu:
                {{dofStats}}

                Risk Trendi:
                {{riskTrend}}

                En Kritik Bulgular:
                {{topFindings}}

                Yonetici ozeti yaz.
                """
        });

        Register(new SkillDefinition
        {
            SkillId = "audit.scorecard",
            Name = "Magaza Karnesi Yorumu",
            Description = "Magaza karnesi uzerinden trend analizi ve karsilastirma yapar",
            Category = SkillCategory.Audit,
            Trigger = TriggerMode.Reactive,
            RequiredContext = ["locationScores", "complianceTrend", "peerComparison"],
            Output = OutputType.Text,
            Temperature = 0.3,
            MaxTokens = 1500,
            SystemPromptTemplate = "Sen BKMKitap ic denetim analisti. Magaza karne verilerini yorumla, trend goster, iyilestirme oner.",
            UserPromptTemplate = """
                Magaza: {{locationName}}
                Uyum Orani: %{{complianceRate}}
                Denetim Sayisi: {{auditCount}}

                Trend:
                {{complianceTrend}}

                Diger Magazalarla Karsilastirma:
                {{peerComparison}}

                Bu magazanin durumunu degerlendir.
                """
        });

        Register(new SkillDefinition
        {
            SkillId = "semantic.enrich",
            Name = "Semantik Zenginlestirme",
            Description = "Yeni eklenen referans tanimini semantik olarak zenginlestirir (alias, aciklama uret)",
            Category = SkillCategory.Semantic,
            Trigger = TriggerMode.Reactive,
            RequiredContext = ["termName", "termType", "existingDefinitions"],
            Output = OutputType.StructuredJson,
            Temperature = 0.4,
            MaxTokens = 1000,
            SystemPromptTemplate = """
                Sen bir semantik analiz uzmanisin. Verilen is terimi icin Turkce es anlamlilar, aciklama ve ornek degerler uret.

                Cikti (JSON):
                {
                  "aliases": "es anlam1, es anlam2, es anlam3",
                  "description": "Detayli aciklama",
                  "sampleValues": "ornek1, ornek2"
                }
                """,
            UserPromptTemplate = """
                Terim: {{termName}}
                Tip: {{termType}}
                Kategori: {{category}}

                Mevcut Tanimlar:
                {{existingDefinitions}}

                Bu terim icin semantik zenginlestirme yap.
                """
        });
    }

    private void Register(SkillDefinition skill) => _skills[skill.SkillId] = skill;
}
