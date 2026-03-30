namespace BkmArgus.AiWorker.Skills;

public class SkillRegistry
{
    private readonly Dictionary<string, SkillDefinition> _skills = new(StringComparer.OrdinalIgnoreCase);

    public SkillRegistry()
    {
        RegisterAll();
    }

    public SkillDefinition? Get(string skillId) => _skills.GetValueOrDefault(skillId);
    public IReadOnlyList<SkillDefinition> GetAll() => _skills.Values.ToList();
    public IReadOnlyList<SkillDefinition> GetByCategory(SkillCategory category) =>
        _skills.Values.Where(s => s.Category == category).ToList();

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
