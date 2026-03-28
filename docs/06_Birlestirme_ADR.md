# BkmArgus Platform — Birleştirme Geçiş Planı

**Tarih:** 29.03.2026  
**Hazırlayan:** Fikri Eren — Genel Müdür, BKM Kitap  
**Durum:** TASLAK — Mimari Karar Dokümanı + Claude Code Prompt Seti

---

## 1. MEVCUT DURUM ANALİZİ

### 1.1 İcDenetim Projesi (`D:\Dev\icdenetim`)

| Özellik | Değer |
|---------|-------|
| Satır sayısı | ~6.300 |
| Yapı | Tek proje (IcDenetim.csproj), ASP.NET Core Razor Pages |
| Veri kaynağı | İnsan gözlemi — saha denetçisi mağazaya gider, checklist doldurur |
| Risk modeli | Olasılık(1-5) × Etki(1-5) = RiskScore, 3 seviye |
| DOF | dbo.CorrectiveActions (flat tablo, lifecycle kısıtlı) |
| AI | Claude API (Anthropic), skeleton hazır, aktif değil |
| DB şeması | dbo.* (flat) — Users, Audits, AuditItems, AuditResults, AuditResultPhotos, CorrectiveActions, Skills, SkillVersions, AiAnalyses, AuditLog |
| Güçlü yanları | DataIntelligenceService (tekrar/sistemik tespit), InsightService (kural+AI), RiskPredictionService (lokasyon risk), ReportGeneratorService (3 tip rapor), FindingsService (zengin bulgu), DOF etkinlik ölçümü, fotoğraf kanıtı |

### 1.2 RiskAnaliz Projesi (`D:\Dev\RiskAnaliz`)

| Özellik | Değer |
|---------|-------|
| Satır sayısı | ~49.000 |
| Yapı | Multi-proje: BkmArgus.Web + AiWorker + Installer + McpServer + SchemaManagement.Library |
| Veri kaynağı | ERP stok/evrak hareketleri — gece ETL job'ları |
| Risk modeli | 10 flag + ağırlıklı skor (0-100), parametre tablosundan okunur |
| DOF | dof.DofKayit/Bulgu/Aksiyon/Kanit/DurumGecmis (tam lifecycle) |
| AI | Ollama (embedding + LLM) + Gemini (fallback), multi-provider, semantik hafıza |
| DB şeması | 7 şema (src/ref/rpt/dof/ai/log/etl), 40+ tablo, SP-first |
| Güçlü yanları | LmRules (deterministik karar), SemanticMemoryService (vektör benzerlik), LlmService (provider zinciri, retry, quality validation), AiJobScheduler, Installer, McpServer, sağlık kontrol SP'leri |

### 1.3 Çakışma ve Boşluk Matrisi

| Alan | İcDenetim | RiskAnaliz | Karar |
|------|-----------|------------|-------|
| Kullanıcı yönetimi | dbo.Users (BCrypt) | ref.Personel + ref.Kullanici | RiskAnaliz'inki (hiyerarşi var) |
| DOF/Aksiyon | dbo.CorrectiveActions | dof.DofKayit/* | RiskAnaliz'inki (lifecycle tam) |
| AI motor | Claude API tek çağrı | LM→Semantik→LLM kuyruk | RiskAnaliz altyapısı + Claude eklenir |
| Risk analizi | Niteliksel (saha gözlem) | Niceliksel (ERP metrik) | İKİSİ DE korunur, birleştirilir |
| Raporlama | C# StringBuilder + Claude | SP-first (rpt.*) | Birleşik — SP + AI rapor |
| Fotoğraf kanıtı | AuditResultPhotos | dof.DofKanit | Birleştirilir — DofKanit genişletilir |
| Tekrar/Sistemik tespit | DataIntelligenceService | Yok (yeni eklenir) | İcDenetim mantığı taşınır |
| Sağlık kontrol | Yok | log.sp_SaglikKontrol_Calistir | RiskAnaliz'inki |
| Installer | Yok | BkmArgus.Installer | Korunur |
| MCP Server | Yok | BkmArgus.McpServer | Korunur |

---

## 2. HEDEF MİMARİ

### 2.1 Unified Solution Yapısı

```
D:\Dev\BkmArgus\                         ← YENİ birleşik root
├── BkmArgus.sln
├── docs/
│   ├── 00_GenelBakis.md                   ← RiskAnaliz docs + İcDenetim eklentileri
│   ├── 01_Model.md
│   ├── 02_RiskKurallari.md
│   ├── 03_Runbook.md
│   ├── 04_AI_Risk_Analiz.md
│   ├── 05_SahaDenetim.md                  ← YENİ — İcDenetim domain mantığı
│   └── 06_Birlestirme_ADR.md              ← YENİ — mimari karar kaydı
├── sql/
│   ├── 00_create_db.sql
│   ├── 01_schemas.sql                     ← + audit şeması eklenir
│   ├── 02_tables.sql                      ← + audit.* tabloları
│   ├── ...mevcut...
│   └── 20_migration_icdenetim.sql         ← YENİ — saha denetim tabloları
├── src/
│   ├── BkmArgus.Web/                    ← RiskAnaliz Web + İcDenetim sayfaları
│   │   ├── Features/
│   │   │   ├── Dashboard/                 ← Birleşik dashboard
│   │   │   ├── Risk/                      ← ERP risk (mevcut)
│   │   │   ├── Audit/                     ← YENİ — Saha denetim modülü
│   │   │   │   ├── Index.cshtml(.cs)      ← Denetim listesi
│   │   │   │   ├── Create.cshtml(.cs)     ← Yeni denetim başlat
│   │   │   │   ├── Edit.cshtml(.cs)       ← Denetim formu (Evet/Hayır)
│   │   │   │   ├── Detail.cshtml(.cs)     ← Denetim detay + fotoğraf
│   │   │   │   ├── Items.cshtml(.cs)      ← Master madde yönetimi
│   │   │   │   └── Reports.cshtml(.cs)    ← Karne + AI rapor
│   │   │   ├── Dof/                       ← DOF (mevcut + genişletilmiş)
│   │   │   ├── Ref/                       ← Referans yönetimi
│   │   │   ├── Urun/                      ← Ürün risk gezgini
│   │   │   ├── Ai/                        ← AI dashboard
│   │   │   └── Yonetim/                   ← Personel/Kullanıcı
│   │   └── Data/
│   │       └── SqlDb.cs                   ← Mevcut
│   ├── BkmArgus.AiWorker/              ← Mevcut + İcDenetim AI servisleri
│   │   ├── Jobs/
│   │   │   ├── RiskPredictionJob.cs       ← Mevcut
│   │   │   ├── AuditInsightJob.cs         ← YENİ — saha denetim insight
│   │   │   ├── AuditReportJob.cs          ← YENİ — AI rapor üretimi
│   │   │   └── DofEffectivenessJob.cs     ← YENİ — DOF etkinlik kontrolü
│   │   ├── Services/
│   │   │   ├── DataIntelligenceService.cs ← İcDenetim'den taşınır
│   │   │   ├── InsightService.cs          ← İcDenetim'den taşınır
│   │   │   └── AuditReportService.cs      ← İcDenetim'den taşınır
│   │   ├── LlmService.cs                 ← + Claude API provider eklenir
│   │   ├── LmRules.cs                    ← + saha denetim kuralları eklenir
│   │   └── SemanticMemoryService.cs      ← + denetim bulguları embedding
│   ├── BkmArgus.Installer/             ← Mevcut + audit modülü
│   ├── BkmArgus.McpServer/             ← Mevcut
│   └── SchemaManagement.Library/          ← Mevcut
└── CLAUDE.md                              ← Birleşik proje bağlamı
```

### 2.2 DB Şema Genişlemesi

Mevcut 7 şemaya `audit` şeması eklenir:

```
src   — ERP soyutlama (mevcut)
ref   — referans/mapping (mevcut, + AuditItem master)
rpt   — rapor tabloları (mevcut, + denetim metrikleri)
dof   — DÖF süreci (mevcut, genişletilir)
ai    — AI analiz (mevcut, genişletilir)
log   — çalışma logları (mevcut)
etl   — ETL süreci (mevcut)
audit — YENİ: Saha denetim tabloları
```

### 2.3 AI Motor Birleşmesi

```
                ┌─────────────────────────────────┐
                │        AI Orchestrator           │
                │   (AiWorkerService genişletilir) │
                └──────────┬──────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼─────┐    ┌─────▼──────┐   ┌──────▼──────┐
    │ LM Rules │    │  Semantik  │   │   Provider  │
    │ (kural)  │    │  Hafıza    │   │   Zinciri   │
    │          │    │            │   │             │
    │ ERP risk │    │ Ollama     │   │ 1. Gemini   │
    │ kuralları│    │ embedding  │   │ 2. Claude   │
    │    +     │    │ + cosine   │   │ 3. Ollama   │
    │ Saha     │    │ similarity │   │    LLM      │
    │ denetim  │    │            │   │             │
    │ kuralları│    │ DOF+Denetim│   │ retry +     │
    └──────────┘    │ vektörleri │   │ quality     │
                    └────────────┘   │ validation  │
                                     └─────────────┘
```

---

## 3. GEÇİŞ FAZLARI

### FAZ 0 — Hazırlık (1 gün)

- [ ] Yeni solution klasörü oluştur (`D:\Dev\BkmArgus`)
- [ ] RiskAnaliz'i olduğu gibi kopyala (temel yapı)
- [ ] Git repo başlat
- [ ] İcDenetim kodunu referans olarak `_archive/icdenetim/` altına kopyala
- [ ] Bu dokümanı `docs/06_Birlestirme_ADR.md` olarak ekle

### FAZ 1 — DB Schema Genişletme (2-3 gün)

- [ ] `audit` şeması oluştur
- [ ] Saha denetim tabloları: `audit.Denetimler`, `audit.DenetimMaddeleri`, `audit.DenetimSonuclari`, `audit.SonucFotograflari`, `audit.Beceriler`, `audit.BeceriVersiyonlari`
- [ ] `dof.DofKayit`'a `KaynakTip = 'SAHA_DENETIM'` desteği ekle
- [ ] `ai.AiAnalizIstegi`'ne `KaynakTip = 'AUDIT'` desteği ekle
- [ ] SP'ler: `audit.sp_Denetim_*`, `audit.sp_Madde_*`, `audit.sp_Sonuc_*`
- [ ] View'lar: `audit.vw_DenetimOzet`, `audit.vw_TekrarBulgu`, `audit.vw_SistemikBulgu`
- [ ] `rpt.sp_Dashboard_Kpi` genişlet — saha denetim KPI'ları ekle

### FAZ 2 — AiWorker Genişletme (3-5 gün)

- [ ] İcDenetim'in `DataIntelligenceService` mantığını AiWorker'a taşı
- [ ] İcDenetim'in `InsightService` kural-tabanlı kısmını `LmRules`'a entegre et
- [ ] İcDenetim'in `ReportGeneratorService`'ini `AuditReportJob` olarak yeniden yaz
- [ ] `LlmService`'e Claude API provider ekle (3. fallback)
- [ ] `SemanticMemoryService`'e denetim bulgu vektörleri ekle
- [ ] İcDenetim'in DOF etkinlik kontrolünü `DofEffectivenessJob` olarak ekle
- [ ] İcDenetim'in risk eskalasyon formülünü (tekrar×0.15, sistemik×1.3) taşı

### FAZ 3 — Web Modül (3-5 gün)

- [ ] `Features/Audit/` klasörü oluştur
- [ ] İcDenetim'in Razor Pages'lerini RiskAnaliz'in pattern'ına uyarla
- [ ] Dashboard'a saha denetim kartları ekle
- [ ] DOF sayfalarını genişlet (saha denetim kaynağı)
- [ ] AI sayfalarına denetim insight'ları ekle

### FAZ 4 — Entegrasyon ve Test (2-3 gün)

- [ ] Installer'a audit modülü ekle
- [ ] McpServer'a denetim sorgu endpoint'leri ekle
- [ ] Smoke test SP'lerini genişlet
- [ ] Sağlık kontrolüne denetim kontrolleri ekle
- [ ] End-to-end test: saha denetim → bulgu → DOF → AI analiz → rapor

### FAZ 5 — Veri Göçü (1 gün)

- [ ] Mevcut İcDenetim verisini (BKMDenetim DB'deki dbo.* tabloları) audit.* şemasına taşı
- [ ] dbo.CorrectiveActions → dof.DofKayit dönüşümü
- [ ] dbo.AiAnalyses → ai.AiAnalizIstegi dönüşümü
- [ ] Eski dbo.* tablolarını bırak (drop etme, arşivle)

---

## 4. CLAUDE CODE PROMPT SETİ

Her prompt **bağımsız** çalışır. Sırayla, birer birer kullanılacak.

---

### PROMPT 1 — Audit Schema Oluşturma

```
## GÖREV
BKMDenetim veritabanında `audit` şeması oluştur ve saha denetim tablolarını ekle.

## BAĞLAM
Mevcut BKMDenetim DB'de 7 şema var: src, ref, rpt, dof, ai, log, etl.
Şimdi 8. şema olarak `audit` ekliyoruz — saha iç denetim verileri için.

## KURAL
- Tüm tablolar IF NOT EXISTS / IF OBJECT_ID IS NULL pattern'i ile
- datetime2(0) kullan, datetime KULLANMA
- PK = IDENTITY(1,1) veya composite key
- Audit alanları: OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi
- FK'lar explicit CONSTRAINT adıyla
- İndeksler: FK kolonları + sık sorgulananlar
- sql/ klasöründe `20_migration_audit.sql` dosyası olarak oluştur

## TABLOLAR

### audit.Beceriler (Skills)
- BeceriId int IDENTITY PK
- Kod varchar(30) UNIQUE NOT NULL
- Ad nvarchar(100) NOT NULL
- Aciklama nvarchar(500) NULL
- AktifMi bit DEFAULT(1)
- audit alanları

### audit.BeceriVersiyonlari (SkillVersions)
- VersiyonId int IDENTITY PK
- BeceriId int FK → audit.Beceriler
- VersiyonNo int NOT NULL
- AktifMi bit DEFAULT(1)
- GecerlilikBaslangic datetime2(0)
- GecerlilikBitis datetime2(0) NULL
- RiskKurallari nvarchar(max) NULL — JSON
- AiPromptBaglam nvarchar(max) NULL
- audit alanları
- UNIQUE (BeceriId, VersiyonNo)

### audit.DenetimMaddeleri (AuditItems — master liste)
- MaddeId int IDENTITY PK
- LokasyonTipi varchar(20) NOT NULL DEFAULT('HerIkisi') — Magaza/Kafe/HerIkisi
- DenetimGrubu nvarchar(100) NOT NULL
- Alan nvarchar(100) NOT NULL — SatisAlani/Kasa/Depo vb.
- RiskTipi nvarchar(100) NOT NULL — OperasyonelRisk/NakitKaybi vb.
- MaddeMetni nvarchar(500) NOT NULL
- SiraNo int NOT NULL
- BulguTipi char(1) NULL — H(Harici)/E(Exempt)
- Olasilik tinyint NOT NULL — 1-5
- Etki tinyint NOT NULL — 1-5
- BeceriId int NULL FK → audit.Beceriler
- AktifMi bit DEFAULT(1)
- audit alanları
- INDEX: (DenetimGrubu, SiraNo)

### audit.Denetimler (Audits)
- DenetimId int IDENTITY PK
- LokasyonAdi nvarchar(100) NOT NULL
- LokasyonTipi varchar(20) NOT NULL
- MekanId int NULL — ref.AyarMekanKapsam ile eşleşme (ERP bağlantı)
- DenetimTarihi datetime2(0) NOT NULL
- RaporTarihi datetime2(0) NOT NULL
- RaporNo varchar(30) NOT NULL
- DenetciKullaniciId int FK → ref.Kullanici
- Yonetici nvarchar(100) NULL
- Mudurluk nvarchar(100) NULL
- KesinlestiMi bit DEFAULT(0)
- KesinlesmeTarihi datetime2(0) NULL
- audit alanları
- INDEX: (LokasyonAdi, DenetimTarihi)
- INDEX: (KesinlestiMi, DenetimTarihi)

### audit.DenetimSonuclari (AuditResults — snapshot)
- SonucId int IDENTITY PK
- DenetimId int FK → audit.Denetimler
- MaddeId int FK → audit.DenetimMaddeleri
- DenetimGrubu nvarchar(100) NOT NULL — snapshot
- Alan nvarchar(100) NOT NULL — snapshot
- RiskTipi nvarchar(100) NOT NULL — snapshot
- MaddeMetni nvarchar(500) NOT NULL — snapshot
- SiraNo int NOT NULL — snapshot
- BulguTipi char(1) NULL — snapshot
- Olasilik tinyint NOT NULL — snapshot
- Etki tinyint NOT NULL — snapshot
- RiskSkor AS (CAST(Olasilik AS int) * CAST(Etki AS int)) PERSISTED
- RiskSeviyesi AS (CASE WHEN CAST(Olasilik AS int)*CAST(Etki AS int) <= 8 THEN 'Dusuk' WHEN CAST(Olasilik AS int)*CAST(Etki AS int) <= 15 THEN 'Orta' ELSE 'Yuksek' END) PERSISTED
- GectiMi bit NOT NULL — true=EVET, false=HAYIR
- Not nvarchar(500) NULL
- IlkGorulenTarih datetime2(0) NULL
- SonGorulenTarih datetime2(0) NULL
- TekrarSayisi int DEFAULT(0)
- SistemikMi bit DEFAULT(0)
- INDEX: (DenetimId, GectiMi)
- INDEX: (MaddeId, GectiMi)

### audit.SonucFotograflari (AuditResultPhotos)
- FotografId int IDENTITY PK
- SonucId int FK → audit.DenetimSonuclari
- DosyaYolu nvarchar(400) NOT NULL
- Not nvarchar(200) NULL
- OlusturmaTarihi datetime2(0) DEFAULT(SYSDATETIME())

## AYRICA
- `dof.DofKayit`'a kontrol ekle: KaynakTip alanında 'SAHA_DENETIM' değeri desteklenmeli. KaynakTip varchar(30) ise zaten uygun. KaynakSistemKodu = 'SAHA_DENETIM' olarak ref.KaynakSistem'e seed data ekle.
- ref.KaynakNesne'ye 'DENETIM_BULGU' ve 'DENETIM_MADDE' ekle.
- Tüm audit.* tablolarının FK constraint'lerini ref.Kullanici ile kur.
```

---

### PROMPT 2 — Audit Stored Procedure'ları

```
## GÖREV
audit şeması için stored procedure'ları oluştur.

## BAĞLAM
- BKMDenetim DB, audit.* tabloları FAZ 1'de oluşturuldu
- Tüm web sayfaları SP üzerinden çalışacak (Dapper + SP-first pattern)
- RiskAnaliz'in mevcut SP pattern'ini takip et (parametre adları Türkçe, hata yönetimi TRY-CATCH)

## SP LİSTESİ

### CRUD
- audit.sp_Denetim_Listele (@LokasyonAdi, @BaslangicTarih, @BitisTarih, @KesinlestiMi, @Top)
- audit.sp_Denetim_Getir (@DenetimId)
- audit.sp_Denetim_Ekle (tüm alanlar, OUTPUT @DenetimId)
- audit.sp_Denetim_Guncelle
- audit.sp_Denetim_Kesinlestir (@DenetimId) — KesinlestiMi=1, KesinlesmeTarihi=SYSDATETIME()
- audit.sp_Denetim_Sil (@DenetimId) — sadece kesinleşmemiş silinebilir

- audit.sp_Madde_Listele (@LokasyonTipi, @DenetimGrubu, @AktifMi)
- audit.sp_Madde_Getir (@MaddeId)
- audit.sp_Madde_Ekle / _Guncelle
- audit.sp_Madde_Import — toplu madde ekleme (Excel'den)

- audit.sp_Sonuc_DenetimeGoreListele (@DenetimId)
- audit.sp_Sonuc_DenetimBaslat (@DenetimId, @LokasyonTipi) — master listeyi snapshot olarak kopyalar
- audit.sp_Sonuc_Guncelle (@SonucId, @GectiMi, @Not)
- audit.sp_Sonuc_TopluGuncelle (@DenetimId, @JsonData) — JSON ile toplu güncelle

### ANALİZ (İcDenetim'in DataIntelligenceService mantığı)
- audit.sp_Analiz_TekrarTespit (@DenetimId) — aynı madde + aynı lokasyon + önceki tarihler
- audit.sp_Analiz_SistemikTespit (@MaddeId) — son 12 ayda 3+ farklı lokasyonda başarısız
- audit.sp_Analiz_RiskEskalasyon (@SonucId) — BaseRisk × (1+TekrarSayisi×0.15) × (SistemikMi?1.3:1.0)
- audit.sp_Analiz_DofEtkinlik (@DenetimId) — kapatılan DOF'un tekrar edip etmediği
- audit.sp_Analiz_TumPipeline (@DenetimId) — yukarıdaki 4 SP'yi sırayla çağırır

### RAPORLAMA
- audit.sp_Rapor_DenetimOzet (@DenetimId) — toplam/geçen/kalan, oran, risk dağılımı
- audit.sp_Rapor_Karne (@LokasyonAdi, @BaslangicTarih, @BitisTarih) — lokasyon bazlı skor
- audit.sp_Rapor_TekrarBulgular (@MinTekrar, @Top) — en çok tekrarlayan maddeler
- audit.sp_Rapor_SistemikBulgular — 3+ lokasyonda başarısız maddeler
- audit.sp_Rapor_AylikTrend (@LokasyonAdi, @AySayisi) — aylık uyum oranı trendi

### DASHBOARD
- audit.sp_Dashboard_SahaDenetim_Kpi — son denetim tarihi, toplam denetim, uyum oranı, bekleyen DOF
- audit.sp_Dashboard_TopRiskliBulgu (@Top) — en riskli başarısız maddeler
- audit.sp_Dashboard_LokasyonSkor (@Top) — lokasyonlar arası karşılaştırma

## KURALLAR
- Parametre adları @ ile başlar, Türkçe
- Tarih literal'ları DMY formatında
- Tüm SP'ler SET NOCOUNT ON ile başlar
- Hata yönetimi: TRY-CATCH + RAISERROR
- Idempotent: IF EXISTS (SELECT * FROM sys.procedures WHERE ...) DROP/CREATE pattern
```

---

### PROMPT 3 — LlmService'e Claude API Provider Ekleme

```
## GÖREV
BkmArgus.AiWorker projesindeki LlmService.cs'e Claude API (Anthropic) provider ekle.

## BAĞLAM
Mevcut LlmService şu provider zincirini destekliyor:
1. Gemini (birincil) veya Ollama (birincil)
2. Gemini fallback modeli
3. Ollama (fallback)

Claude API'yi 3. provider olarak ekleyeceğiz:
1. Gemini primary
2. Gemini fallback
3. Claude API (Anthropic)
4. Ollama LLM

## DOSYA: src/BkmArgus.AiWorker/LlmService.cs

## YAPILACAKLAR

1. AiWorkerOptions.cs'e ekle:
   - ClaudeApiKey (string)
   - ClaudeModel (string, default "claude-sonnet-4-20250514")
   - ClaudeMaxTokens (int, default 2048)

2. appsettings.json'a ekle:
   - AiWorker.ClaudeApiKey
   - AiWorker.ClaudeModel

3. LlmService'e ekle:
   - private const string ProviderClaude = "claude";
   - HttpClient _claude (IHttpClientFactory ile "claude" named client)
   - CallClaudeWithRetryAsync metodu
   - CallClaudeAsync metodu (https://api.anthropic.com/v1/messages endpoint)
   - GetProviderChain'e Claude'u 3. sıraya ekle

4. Claude API çağrısı:
   - Header: x-api-key, anthropic-version: 2023-06-01
   - Body: { model, max_tokens, system: "...", messages: [{ role: "user", content: prompt }] }
   - Response: content[0].text
   - JSON format zorla (system prompt'a "JSON yanıt ver" ekle)

5. Program.cs'de HttpClient kaydı:
   builder.Services.AddHttpClient("claude", c => {
       c.BaseAddress = new Uri("https://api.anthropic.com/");
       c.Timeout = TimeSpan.FromSeconds(120);
   });

## MEVCUT KOD PATTERN'İ
RiskAnaliz'in LlmService.cs pattern'ini takip et:
- Retry + exponential backoff
- Quality validation (ValidateResult)
- Error formatting (BuildError)
- LlmCallResult döner
```

---

### PROMPT 4 — DataIntelligenceService'i AiWorker'a Taşıma

```
## GÖREV
İcDenetim projesindeki DataIntelligenceService mantığını BkmArgus.AiWorker'a taşı.

## KAYNAK
İcDenetim/Services/DataIntelligenceService.cs — tekrar tespit, sistemik tespit, DOF etkinlik, risk eskalasyonu

## HEDEF
src/BkmArgus.AiWorker/Jobs/AuditAnalysisJob.cs — BaseAiJob'dan türer

## MANTIK AKTARIMI

### Tekrar Tespiti
- Aynı madde + aynı lokasyon + daha önceki tarihlerde başarısız olanları bul
- RepeatCount = önceki başarısızlık sayısı
- FirstSeenAt = ilk başarısızlık tarihi
- LastSeenAt = en son başarısızlık tarihi
- audit.DenetimSonuclari tablosunu güncelle

### Sistemik Tespit
- Son 12 ayda aynı maddenin 3+ farklı lokasyonda başarısız olması
- SistemikMi = true olarak işaretle
- Tüm ilgili sonuçları güncelle

### DOF Etkinlik Kontrolü
- Başarısız sonuç için daha önce kapatılmış DOF var mı?
- Varsa DOF'u "etkisiz" olarak işaretle
- Her tekrarda etkinlik skoru -0.25 (minimum 0.0)
- dof.DofKayit tablosunda yeni alanlar gerekebilir: EtkinlikSkoru decimal(5,2), EtkinMi bit

### Risk Eskalasyonu
- EscalatedRisk = BaseRisk × (1 + RepeatCount × 0.15) × (IsSystemic ? 1.3 : 1.0)
- Sonuç: risk seviyesi yükseltme önerisi

## İŞ AKIŞI
1. AuditAnalysisJob tetiklenir (denetim kesinleştirildiğinde veya gece job olarak)
2. Kesinleşmiş ama henüz analiz edilmemiş denetimleri bul
3. Her denetim için:
   a. Başarısız sonuçları al
   b. Tekrar tespiti yap ve güncelle
   c. Sistemik tespit yap ve güncelle
   d. DOF etkinlik kontrolü yap
   e. ai.AiAnalizIstegi'ne kayıt ekle (KaynakTip='AUDIT')
4. Loglama: kaç denetim işlendi, kaç insight üretildi

## SP ÇAĞRILARI
Doğrudan SQL yerine SP'ler tercih edilir:
- audit.sp_Analiz_TumPipeline(@DenetimId) çağır
- Sonuç olarak ai.AiAnalizIstegi'ne yaz
```

---

### PROMPT 5 — InsightService Kural Entegrasyonu

```
## GÖREV
İcDenetim'in InsightService kural-tabanlı insight mantığını RiskAnaliz'in LmRules.cs'e entegre et.

## KAYNAK
İcDenetim/Services/InsightService.cs — kural-tabanlı uyarılar:
- Kritik tekrar uyarısı (3+ kez tekrar)
- Sistemik sorun uyarısı
- Yüksek risk eskalasyonu (escalatedRisk > 20)
- Etkisiz DOF uyarısı

## HEDEF
src/BkmArgus.AiWorker/LmRules.cs — mevcut Decide() metoduna ek olarak DecideAudit() metodu

## YENİ METOTLAR

### LmRules.DecideAudit(AuditBulguRow bulgu) → AuditLmDecision
- Input: AuditBulguRow { SonucId, MaddeId, MaddeMetni, RiskSkor, TekrarSayisi, SistemikMi, LokasyonAdi, DenetimTarihi }
- Output: AuditLmDecision { InsightTipi, Onem, Ozet, LlmGerekliMi, OncelikPuan }

### Kurallar:
1. TekrarSayisi >= 3 → InsightTipi="TEKRAR_KRITIK", Onem=TekrarSayisi>=5?"Critical":"High"
2. SistemikMi == true → InsightTipi="SISTEMIK", Onem="Critical"
3. EscalatedRisk > 20 → InsightTipi="RISK_ESKALASYON", Onem="Critical"
4. DOF etkinlik skoru < 0.5 → InsightTipi="DOF_ETKISIZ", Onem="High"
5. Yukarıdakilerden herhangi biri + RiskSkor >= 15 → LlmGerekliMi=true

### Yeni Model Sınıfları (Models.cs'e ekle):

public sealed record AuditBulguRow
{
    public int SonucId { get; init; }
    public int MaddeId { get; init; }
    public string MaddeMetni { get; init; } = string.Empty;
    public int RiskSkor { get; init; }
    public int TekrarSayisi { get; init; }
    public bool SistemikMi { get; init; }
    public string LokasyonAdi { get; init; } = string.Empty;
    public DateTime DenetimTarihi { get; init; }
}

public sealed record AuditLmDecision
{
    public string InsightTipi { get; init; } = "DIGER";
    public string Onem { get; init; } = "Low";
    public string Ozet { get; init; } = string.Empty;
    public bool LlmGerekliMi { get; init; }
    public int OncelikPuan { get; init; }
}
```

---

### PROMPT 6 — SemanticMemoryService Genişletme

```
## GÖREV
BkmArgus.AiWorker'daki SemanticMemoryService'e saha denetim bulgularını ekle.

## BAĞLAM
Mevcut sistem sadece DOF kayıtlarından vektör üretiyor.
Şimdi saha denetim bulgularından da vektör üretilecek:
- Başarısız maddeler + kontekst → embedding
- Benzer bulgular bulunca "bu sorun daha önce X lokasyonunda da yaşandı" bilgisi

## YAPILACAKLAR

### 1. SyncAuditVectorsAsync metodu ekle
- Kesinleşmiş denetimlerden başarısız sonuçları al
- Her sonuç için metin oluştur:
  "DENETIM BULGU: Lokasyon={LokasyonAdi}; Madde={MaddeMetni}; Alan={Alan}; Grup={DenetimGrubu}; Risk={RiskSkor}; Tekrar={TekrarSayisi}"
- Embedding üret (Ollama mxbai-embed-large)
- ai.AiGecmisVektorler'e yaz (KritikMi = RiskSkor > 15 OR TekrarSayisi >= 3)

### 2. FindBestAuditMatchAsync metodu ekle
- Input: denetim bulgu metni
- Output: SemanticMatch (en yakın geçmiş bulgu, benzerlik > 0.80)
- Sadece denetim bulgularını ara (DOF vektörlerini karıştırma)

### 3. AiWorkerService.SyncVectorsIfNeededAsync'e ekle
- Mevcut DOF vektör senkronundan sonra audit vektör senkronunu çağır

### SQL
- ai.sp_Ai_GecmisVektor_DenetimKaynakListe (@Top) — henüz vektörü olmayan başarısız denetim sonuçları
- ai.sp_Ai_GecmisVektor_Upsert SP'sini kullan (mevcut, RiskId parametresiyle)
```

---

### PROMPT 7 — Web Audit Modülü

```
## GÖREV
BkmArgus.Web projesinde Features/Audit/ modülü oluştur.

## BAĞLAM
Mevcut web projesi Razor Pages, feature-based yapı:
- Features/Dashboard/Index.cshtml(.cs)
- Features/Risk/Index.cshtml(.cs)
- Features/Dof/Index.cshtml(.cs)
- Data/SqlDb.cs — tek Dapper erişim katmanı

## SAYFALAR

### 1. Features/Audit/Index.cshtml.cs — Denetim Listesi
- SP: audit.sp_Denetim_Listele
- Filtreler: lokasyon, tarih aralığı, kesinleşme durumu
- Tablo: RaporNo, Lokasyon, Tarih, Denetçi, Durum(Taslak/Kesinleşmiş), UyumOranı%
- Aksiyonlar: Yeni Denetim, Düzenle, Detay, Sil

### 2. Features/Audit/Create.cshtml.cs — Yeni Denetim Başlat
- Form: LokasyonAdi (dropdown), LokasyonTipi (Magaza/Kafe), DenetimTarihi, RaporNo
- OnPost: SP audit.sp_Denetim_Ekle + audit.sp_Sonuc_DenetimBaslat

### 3. Features/Audit/Edit.cshtml.cs — Denetim Formu (Evet/Hayır)
- DenetimId ile sonuçları yükle
- Madde madde: EVET/HAYIR butonu + not alanı + fotoğraf yükle
- DenetimGrubu bazında accordion
- Kaydet: audit.sp_Sonuc_TopluGuncelle
- Kesinleştir butonu: audit.sp_Denetim_Kesinlestir → audit.sp_Analiz_TumPipeline tetikle

### 4. Features/Audit/Detail.cshtml.cs — Denetim Detay
- Özet kartları: toplam madde, geçen, kalan, uyum oranı, ortalama risk
- Başarısız bulgular tablosu (risk skoru ile renkli)
- Tekrar ve sistemik uyarıları
- Fotoğraflar galerisi
- AI raporları: Anlatımsal Rapor / Aksiyon Planı / Yönetici Özeti butonları
- İlişkili DOF'lar

### 5. Features/Audit/Items.cshtml.cs — Master Madde Yönetimi
- CRUD: DenetimGrubu, Alan, RiskTipi, MaddeMetni, Olasilik, Etki
- Import: Excel'den toplu yükleme
- BeceriId ile beceri bağlantısı

### 6. Features/Audit/Reports.cshtml.cs — Karne
- Lokasyon bazlı skor kartı
- Trend grafik (aylık uyum oranı)
- En riskli 10 madde
- Sistemik sorunlar listesi

## UI PATTERN
- RiskAnaliz'in mevcut Tailwind CSS pattern'ini kullan
- KPI kartları: dashboard pattern'inden kopyala
- Tablo: mevcut RiskRow pattern'ini takip et
- SVG trend: mevcut BuildTrendPoints pattern'ini kullan
```

---

### PROMPT 8 — Dashboard Birleştirme

```
## GÖREV
Mevcut dashboard'a saha denetim KPI'larını ve kartlarını ekle.

## BAĞLAM
Features/Dashboard/Index.cshtml.cs mevcut KPI'lar:
- KritikRiskDeger (80+ risk skor)
- BekleyenDofDeger (SLA takibi)
- TarananStokDeger (son gece)
- SistemDurum (PASS/WARN/FAIL)
- RiskPano (Top 10 risk)
- DofList (Top 5 DOF)
- HealthChecks
- TrendPoints

## EKLENECEKLER

### YENİ KPI'lar
- SahaDenetimSayisi — bu ay yapılan denetim sayısı
- OrtalamaUyumOrani — tüm lokasyonların uyum oranı ortalaması
- TekrarBulguSayisi — 3+ kez tekrarlayan aktif bulgular
- SistemikBulguSayisi — sistemik sorunlar

### YENİ KARTLAR
- SahaDenetimOzet — son 5 denetim (lokasyon, tarih, uyum%, durum)
- TekrarBulgular — top 5 tekrarlayan madde (madde, tekrar sayısı, lokasyon sayısı)
- LokasyonSkor — lokasyonlar arası karşılaştırma barı

### YENİ SP
- audit.sp_Dashboard_SahaDenetim_Kpi → 4 KPI satırı döner
- audit.sp_Dashboard_SonDenetimler (@Top) → son denetimler
- audit.sp_Dashboard_TopRiskliBulgu (@Top) → en riskli başarısız maddeler

### Layout
Dashboard sayfasını 2 bölüme ayır:
1. ÜST: Genel KPI kartları (mevcut 4 + yeni 4 = 8 kart, 2 satır × 4 kolon)
2. ORTA-SOL: ERP Risk Panosu (mevcut) + Saha Denetim Özeti (yeni) — tab ile geçiş
3. ORTA-SAĞ: DOF listesi + AI Insight listesi
4. ALT: Trend grafiği (ERP risk + saha denetim üst üste) + Sağlık kontrol
```

---

### PROMPT 9 — AI Rapor Üretimi (İcDenetim ReportGeneratorService Taşıma)

```
## GÖREV
İcDenetim'in ReportGeneratorService mantığını AiWorker'a AuditReportJob olarak taşı.

## KAYNAK
İcDenetim/Services/ReportGeneratorService.cs:
- GenerateNarrativeReportAsync — anlatımsal iç denetim raporu
- GenerateActionPlanAsync — aksiyon planı (risk gruplarına göre)
- GenerateExecutiveSummaryAsync — yönetici özeti

## HEDEF
src/BkmArgus.AiWorker/Jobs/AuditReportJob.cs

## İŞ AKIŞI

### On-demand çağrı (web'den tetiklenir)
1. Web sayfasında "AI Rapor Üret" butonu
2. ai.AiAnalizIstegi'ne kayıt eklenir (KaynakTip='AUDIT_REPORT', alt tip: NARRATIVE/ACTION/EXECUTIVE)
3. AiWorker kuyruktan alır
4. SP ile denetim verisini çeker
5. Veri raporu oluşturur (fallback — AI yoksa bile çalışır)
6. LLM provider zinciriyle zenginleştirir
7. ai.AiAnalizSonucu'na yazar
8. Web sayfası polling ile sonucu gösterir

### Prompt Şablonları
System prompt'ları src/BkmArgus.AiWorker/Prompts/ klasöründe .md dosyaları olarak sakla:
- audit.narrative.system.md
- audit.actionplan.system.md  
- audit.executive.system.md

### Veri Formatı (LLM'e gönderilecek)
İcDenetim'in FormatNarrativeReport, FormatActionPlan, FormatExecutiveSummary metotlarını aynen taşı.
Beceri bağlamı (AiPromptBaglam) varsa system prompt'a ekle.

### Fallback
AI yoksa bile anlamlı rapor döner — İcDenetim'in StringBuilder formatı korunur.
```

---

### PROMPT 10 — Installer Genişletme

```
## GÖREV
BkmArgus.Installer'a audit modülü kurulum bileşeni ekle.

## BAĞLAM
Mevcut installer bileşenleri:
1. Şemalar (src, ref, rpt, dof, ai, log, etl)
2. Tablolar (AI ve ETL)
3. ETL System (SP'ler)
4. AI V2 System

## EKLENECEKLER

### Yeni bileşen: "Saha Denetim Modülü"
Sıra: mevcut bileşenlerden sonra (5. sıra)

### Kurulum adımları:
1. audit şeması oluştur
2. audit.* tabloları oluştur
3. ref.KaynakSistem'e 'SAHA_DENETIM' ekle
4. ref.KaynakNesne'ye 'DENETIM_BULGU', 'DENETIM_MADDE' ekle
5. audit.sp_* stored procedure'larını kur
6. rpt.sp_Dashboard_Kpi güncelle (saha denetim KPI'ları)

### SQL dosyaları
Installer sql/ klasörüne ekle:
- sql/20_migration_audit.sql (şema + tablolar)
- sql/21_sps_audit.sql (SP'ler)
- sql/22_sps_audit_dashboard.sql (dashboard SP'leri)
- sql/23_seed_audit.sql (ref seed data)

### ConsoleInstaller.cs ve WebInstaller.cs güncelle
- Yeni bileşen menüsü ekle
- Kurulum doğrulaması: audit.Denetimler tablosu var mı? SP'ler yüklü mü?
```

---

### PROMPT 11 — CLAUDE.md Birleşik Proje Bağlamı

```
## GÖREV
Projenin kök dizininde CLAUDE.md dosyası oluştur — Claude Code için birleşik proje bağlamı.

## İÇERİK YAPISI

# BkmArgus — AI-Powered Audit & Risk Intelligence Platform

## Proje Özeti
BKM Kitap iç denetim ve risk yönetim platformu. İki ana kanal:
1. ERP Risk Analizi: Stok/evrak hareketlerinden otomatik risk sinyali (gece ETL)
2. Saha Denetimi: Denetçinin mağaza/kafe ziyareti, checklist, fotoğraf kanıtı

## Tech Stack
- Web: ASP.NET Core Razor Pages, Dapper, SP-first
- DB: SQL Server (BKMDenetim), 8 şema (src/ref/rpt/dof/ai/log/etl/audit)
- AI: LM Rules (deterministik) → Semantik Hafıza (Ollama embedding) → LLM (Gemini/Claude/Ollama)
- Worker: BkmArgus.AiWorker (BackgroundService)
- Installer: Console + Web UI
- MCP: BkmArgus.McpServer

## Şema Haritası
src — ERP soyutlama view'leri
ref — referans/mapping (mekan, tip, parametre, personel, kullanıcı)
rpt — rapor snapshot tabloları (risk günlük/aylık, stok bakiye)
dof — DÖF süreci (kayıt/bulgu/aksiyon/kanıt/durum geçmişi)
ai  — AI analiz (istek/sonuç/vektör/embedding/tahmin)
log — çalışma logları ve sağlık kontrol
etl — ETL sync durum
audit — saha denetim (denetimler/maddeler/sonuçlar/fotoğraflar/beceriler)

## AI Akışı
1. ERP risk: Gece ETL → flag + skor → LmRules.Decide() → Semantik benzerlik → LLM kuyruk
2. Saha denetim: Kesinleştir → TekrarTespit → SistemikTespit → DofEtkinlik → LmRules.DecideAudit() → LLM kuyruk
3. Ortak: SemanticMemoryService (DOF + denetim bulguları), LlmService (Gemini→Claude→Ollama)

## Kodlama Kuralları
- SP-first: Tüm veri erişimi stored procedure üzerinden
- Parametre adları Türkçe
- Tarih literal'ları DMY (dd.MM.yyyy)
- datetime2(0) kullan, datetime KULLANMA
- Hata yönetimi: TRY-CATCH
- Config: env var öncelikli, yoksa appsettings.json
- SQL injection: parametreli SP, string concat YASAK

## Komutlar
- Web: dotnet run --project src/BkmArgus.Web
- Worker: dotnet run --project src/BkmArgus.AiWorker
- Installer: dotnet run --project src/BkmArgus.Installer
- MCP: dotnet run --project src/BkmArgus.McpServer
- Risk ETL: EXEC log.sp_RiskUrunOzet_Calistir;
- Stok ETL: EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=120;
- Sağlık: EXEC log.sp_SaglikKontrol_Calistir;
- Denetim Analiz: EXEC audit.sp_Analiz_TumPipeline @DenetimId=X;

## Güvenlik
- Gizli bilgi: env var veya appsettings, ASLA kod içinde
- Auth: ref.Kullanici + cookie-based (planlanıyor)
- Dosya upload: sadece image, max 5MB, validate
- SQL: parametreli SP, enjeksiyon koruması
```

---

## 5. ÖNCELİK SIRASI VE TAHMİNİ SÜRE

| Faz | Süre | Öncelik | Bağımlılık |
|-----|------|---------|------------|
| Faz 0 — Hazırlık | 1 gün | P0 | — |
| Faz 1 — DB Schema (Prompt 1-2) | 2-3 gün | P0 | Faz 0 |
| Faz 2 — AiWorker (Prompt 3-6) | 3-5 gün | P1 | Faz 1 |
| Faz 3 — Web Modül (Prompt 7-8) | 3-5 gün | P1 | Faz 1 |
| Faz 4 — AI Rapor + Installer (Prompt 9-10) | 2-3 gün | P2 | Faz 2 |
| Faz 5 — Veri Göçü | 1 gün | P2 | Faz 1-4 |
| CLAUDE.md (Prompt 11) | Faz 0 ile birlikte | P0 | — |
| **TOPLAM** | **12-18 gün** | | |

---

## 6. RİSK ve AZALTMA

| Risk | Olasılık | Etki | Azaltma |
|------|----------|------|---------|
| Mevcut İcDenetim verisi kaybolur | Düşük | Yüksek | Göç öncesi full DB backup + dbo tabloları arşivle |
| RiskAnaliz'in mevcut SP'leri bozulur | Orta | Yüksek | Yeni SP'ler ayrı dosyada, mevcut SP'lere dokunma |
| AI provider zinciri karmaşıklaşır | Düşük | Orta | Claude sadece 3. fallback, mevcut akış bozulmaz |
| Web sayfaları çakışır | Düşük | Düşük | Features/Audit/ tamamen izole modül |
| Installer mevcut kurulumu bozar | Orta | Yüksek | Yeni bileşen eklentisi, mevcut bileşenler değişmez |

---

## 7. BAŞARI KRİTERLERİ

- [ ] Mevcut RiskAnaliz web'i aynı çalışır (regresyon yok)
- [ ] Mevcut AI Worker aynı çalışır (ERP risk analizi etkilenmez)
- [ ] Saha denetim CRUD çalışır (oluştur → düzenle → kesinleştir)
- [ ] Kesinleştirme sonrası pipeline çalışır (tekrar → sistemik → DOF etkinlik → insight)
- [ ] AI rapor üretimi çalışır (veri fallback + LLM zenginleştirme)
- [ ] Dashboard'da hem ERP risk hem saha denetim KPI'ları görünür
- [ ] DOF sistemi her iki kaynaktan (ERP risk + saha denetim) kayıt alır
- [ ] Semantik hafızada denetim bulguları aranabilir
- [ ] Installer yeni modülü kurabilir
- [ ] Sağlık kontrolünde denetim kontrolleri var

---

## 8. OLMAYAN AMA OLMASI GEREKEN — KRİTİK EKSİKLER

Her iki projede de **hiç yok** veya **iskelet halinde** olan, ama profesyonel bir platformda **olmazsa olmaz** olan özellikler. Bunlar birleştirme ile birlikte inşa edilmeli.

### 8.1 Kimlik Doğrulama ve Yetkilendirme (RBAC)

**Durum:** İcDenetim'de basit cookie auth var (BCrypt, tek rol). RiskAnaliz'de ref.Kullanici + ref.Personel var ama auth mekanizması yok, sayfalar açık.

**Olması gereken:**
- Tam RBAC sistemi: Admin, Denetçi, Yönetici, Analist, Salt Okunur
- Sayfa bazlı yetki kontrolü (her Razor Page'de `[Authorize(Roles="...")]`)
- ref.Kullanici tablosuna şifre hash (HMACSHA256 veya BCrypt), RolKodu genişletme
- Oturum yönetimi: Cookie auth + sliding expiration + remember me
- Şifre sıfırlama akışı
- Başarısız giriş kilitleme (5 deneme → 15 dk lock)
- Audit log: her giriş/çıkış kaydı
- İlk kurulumda admin hesap oluşturma wizard'ı

### 8.2 DOF Onay İş Akışı (State Machine)

**Durum:** RiskAnaliz'de dof.DofDurumGecmis var ama geçişler manuel. İcDenetim'de status alanı var ama onay zinciri yok.

**Olması gereken:**
- Tam state machine: TASLAK → ACIK → AKSIYONDA → DOGRULAMA_BEKLIYOR → KAPANDI / RED
- Her geçişte yetki kontrolü (kim hangi geçişi yapabilir?)
- Onay zinciri: Açan → Sorumlu → Onayci (ref.Personel hiyerarşisi)
- SLA takibi: HedefTarih yaklaşınca uyarı, aşılınca eskalasyon
- Otomatik eskalasyon: SLA+7 gün aşılırsa üst yöneticiye bildirim
- Toplu durum güncelleme
- DOF'a yorum ekleme (dof.DofYorum tablosu — thread)

### 8.3 Bildirim Sistemi

**Durum:** Her iki projede de bildirim sistemi **sıfır**.

**Olması gereken:**
- DB tablosu: `log.Bildirimler` (KullaniciId, Baslik, Mesaj, Tip, OkunduMu, OlusturmaTarihi)
- Bildirim tipleri: DOF_SLA_YAKLASTI, DOF_SLA_ASIMI, DENETIM_KESINLESTI, AI_RAPOR_HAZIR, RISK_KRITIK, SISTEMIK_SORUN
- UI: Navbar'da bildirim ikonu + badge + dropdown
- Email bildirim: MailKit ile (opsiyonel, config'den açılır)
- AI insight bildirimi: Kritik bulgu → otomatik bildirim
- Bildirim tercihleri: Kullanıcı hangi bildirimleri alacağını seçebilir

### 8.4 Çapraz Korelasyon — ERP Risk ↔ Saha Denetim

**Durum:** İki sistem birbirinden habersiz çalışıyor. **Bu birleştirmenin en büyük katma değeri bu.**

**Olması gereken:**
- MekanId köprüsü: audit.Denetimler.MekanId = rpt.RiskUrunOzet_Gunluk.MekanId
- Korelasyon SP'si: `rpt.sp_Korelasyon_MekanRisk(@MekanId)` — aynı mağazanın ERP risk skoru + saha denetim uyum oranı yan yana
- AI korelasyon: "Bu mağazada ERP'de yüksek iade riski var VE saha denetimde kasa kontrol maddesi 3 kez başarısız" → birleşik insight
- Korelasyon dashboard kartı: Mağaza bazlı hem ERP hem saha skoru gösteren ısı haritası
- Tetikleme: ERP riski 80+ olan mağaza için otomatik saha denetim önerisi
- Risk matrisi: X ekseni ERP risk, Y ekseni saha denetim skoru → 4 kadran (yüksek-yüksek = acil müdahale)

### 8.5 Raporlama ve Export

**Durum:** İcDenetim'de text-based rapor var ama dosya export yok. RiskAnaliz'de hiç rapor export yok.

**Olması gereken:**
- PDF rapor export: Denetim raporu, karne, yönetici özeti → PDF
- Excel export: Risk tablosu, bulgu listesi, DOF listesi → .xlsx
- Zamanlanmış rapor: Her Pazartesi sabah yöneticiye haftalık özet email
- Her ay sonu aylık denetim raporu otomatik üretim
- Rapor şablonları: BKM Kitap kurumsal başlık/logo
- AI rapor arşivi: Üretilen tüm AI raporları tarih bazlı saklanır

### 8.6 Mobil Uyumlu Saha Denetim UI

**Durum:** Her iki proje de desktop-first. Saha denetçisi tablet/telefon kullanıyor.

**Olması gereken:**
- Responsive tasarım: Denetim formu mobilde kullanılabilir
- Touch-friendly: Büyük EVET/HAYIR butonları, swipe ile geçiş
- Fotoğraf çekme: Kamera API entegrasyonu (HTML5 MediaCapture)
- Offline desteği (PWA): İnternet olmadan denetim yapabilme, bağlantı gelince senkronize
- GPS konum kaydı: Denetim başlatıldığında konum logla
- Barcode/QR tarama: Mağaza/raf kodu ile hızlı madde seçimi (gelecek faz)

### 8.7 AI Geri Bildirim Döngüsü (Feedback Loop)

**Durum:** RiskAnaliz'de ai.AiGeriBildirim planlanmış ama bağlanmamış. İcDenetim'de AiAnalysis.ActionTaken var ama AI'ı eğitmiyor.

**Olması gereken:**
- Her AI çıktısında 👍/👎 butonu
- Geri bildirim DB'ye yazılır: ai.AiGeriBildirim (IstekId, Puan, Yorum, Kullanici, Tarih)
- Golden memory: 👍 alan çıktılar "onaylı pattern" olarak saklanır
- Prompt iyileştirme: 👎 oranı yüksek skill'ler için otomatik uyarı
- AI dashboard'da feedback metrikleri: doğruluk oranı, kullanıcı memnuniyeti
- Few-shot learning: Onaylı pattern'ler sonraki prompt'lara enjekte edilir
- Haftalık AI performans raporu

### 8.8 Test Altyapısı

**Durum:** İcDenetim'de test **sıfır**. RiskAnaliz'de `99_smoke_tests.sql` var ama unit test yok.

**Olması gereken:**
- SQL smoke tests genişletme: Her yeni SP için smoke test
- C# unit testler: LmRules, risk hesaplama formülleri, eskalasyon katsayıları
- Integration testler: SP çağrısı → sonuç doğrulama
- AI test: Bilinen senaryolara karşı AI çıktısı kalite kontrolü
- Test projesi: BkmArgus.Tests (xUnit)
- SP test pattern: Her SP için test_sp_XYZ procedure'ü

### 8.9 Git ve CI/CD

**Durum:** Her iki projede de git **tanımsız**. Deployment tamamen manuel.

**Olması gereken:**
- Git repo başlatma + .gitignore (bin/obj/wwwroot/lib/.env/appsettings.*.json)
- Branch stratejisi: main (prod) + dev (geliştirme)
- DB migration versiyonlama: sql/ dosyaları numaralı, sıralı
- Basit deploy script: `deploy.ps1` (build → publish → copy → restart)
- Backup before deploy: DB backup + eski kod arşivi

### 8.10 Caching ve Performans

**Durum:** Her iki projede cache **sıfır**. Her sayfa açılışında SP çağrısı.

**Olması gereken:**
- Dashboard KPI cache: 5 dakika (MemoryCache)
- Referans tabloları cache: 30 dakika (mekan listesi, tip mapping)
- SP sonuç cache: Sık çağrılan listeler
- Sayfalama: Tüm liste sayfalarında server-side paging (@Offset, @PageSize)
- Index optimizasyonu: Yoğun sorguların execution plan analizi
- Connection pooling ayarları

### 8.11 Structured Logging ve İzleme

**Durum:** Temel ILogger var ama yapılandırılmış değil. Hata takibi zorlu.

**Olması gereken:**
- Serilog entegrasyonu: JSON formatında dosyaya yazma
- Correlation ID: Her HTTP isteğinde izlenebilir TraceId
- AI çağrı logları: Provider, model, token sayısı, süre, başarı/hata
- Performans logları: Yavaş SP'ler (>2sn) uyarı
- Log dosya rotasyonu: Günlük dosya, 30 gün tutma
- Hata dashboard'ı: Son 24 saat hata özeti

### 8.12 Veri Saklama ve Arşiv Politikası

**Durum:** PRD'de "5 yıl saklama" yazıyor ama uygulama yok.

**Olması gereken:**
- Arşiv SP'si: `log.sp_ArsivCalistir(@YilSayisi)` — X yıldan eski veriyi arşiv tablolarına taşı
- Arşiv tabloları: `archive.RiskUrunOzet_Gunluk`, `archive.DenetimSonuclari` vb.
- Yumuşak silme: Hiçbir tablo gerçek DELETE yapmaz, AktifMi/SilindiMi flag
- DB backup stratejisi: Günlük full backup + saatlik differential
- KVKK uyumu: Personel verisi silme hakkı → anonimleştirme SP'si

### 8.13 API Katmanı (Gelecek Entegrasyon)

**Durum:** MCP Server var ama sadece schema okuma. İş mantığı API'si yok.

**Olması gereken (Phase 2):**
- REST API projesi: BkmArgus.Api (minimal API veya controller)
- Endpoint'ler: /api/denetimler, /api/risk, /api/dof, /api/ai/rapor
- API key auth: Dış sistemler için
- Rate limiting: AI endpoint'leri için dakikada max çağrı
- Swagger/OpenAPI dokümantasyonu
- Webhook: DOF durum değişikliğinde dış sisteme bildirim

### 8.14 AI Proaktif Öneriler

**Durum:** İcDenetim'de InsightService var ama reaktif. RiskAnaliz'de batch çalışıyor ama proaktif değil.

**Olması gereken:**
- Denetim planlama önerisi: "X mağazasının son denetiminden 45 gün geçti, ERP riski yükseldi → denetim planla"
- Madde önerisi: "Y maddesi tüm mağazalarda başarısız → madde metnini gözden geçir veya eğitim ver"
- Trend uyarısı: "Z lokasyonunun uyum oranı 3 aydır düşüyor → müdahale öner"
- Kaynak önceliklendirme: "Denetçi 1 haftada 3 mağaza yapabilir → en riskli 3 mağazayı öner"
- Anomali tespiti: "A mağazasının uyum oranı aniden %95'ten %60'a düştü → acil uyarı"
- Kök neden önerisi: "B maddesi 5 mağazada başarısız → muhtemel kök neden: eğitim eksikliği / prosedür değişikliği"

### 8.15 Risk Isı Haritası ve Görselleştirme

**Durum:** Dashboard'da basit sayılar ve tablolar var. Görsel analiz aracı yok.

**Olması gereken:**
- Mağaza × Madde ısı haritası: Hangi mağazada hangi madde başarısız (renk kodlu)
- Trend grafikleri: Aylık uyum oranı trendi (mağaza bazlı overlay)
- Risk dağılım grafiği: Düşük/Orta/Yüksek risk pasta grafik
- DOF yaşam döngüsü: Ortalama kapatma süresi, SLA uyum oranı
- AI insight timeline: Kronolojik insight akışı
- Karşılaştırma: Mağaza vs mağaza, dönem vs dönem

---

## 9. GENİŞLETİLMİŞ CLAUDE CODE PROMPT SETİ — YENİ ÖZELLİKLER

Mevcut 11 prompt'a ek olarak, eksik özellikleri inşa eden prompt'lar:

---

### PROMPT 12 — RBAC ve Kimlik Doğrulama

```
## GÖREV
BkmArgus.Web'e tam RBAC tabanlı kimlik doğrulama sistemi ekle.

## BAĞLAM
- Mevcut ref.Kullanici tablosu var (KullaniciAdi, PersonelId, RolKodu, AktifMi)
- Şifre alanı YOK — eklenmeli
- Auth mekanizması YOK — cookie auth eklenecek
- İcDenetim'in BCrypt pattern'i referans

## DB DEĞİŞİKLİKLERİ

### ref.Kullanici tablosuna ekle:
- SifreHash varchar(120) NULL
- SifreTuzu varchar(64) NULL  
- BasarisizGirisSayisi int DEFAULT(0)
- HesapKilitliMi bit DEFAULT(0)
- KilitAcilmaTarihi datetime2(0) NULL
- SonSifreDegisim datetime2(0) NULL
- SifreSifirlamaToken varchar(120) NULL
- SifreSifirlamaTokenSonlanma datetime2(0) NULL

### ref.Rol tablosu (yeni):
- RolId int IDENTITY PK
- RolKodu varchar(30) UNIQUE — ADMIN, DENETCI, YONETICI, ANALIST, SALT_OKUNUR
- RolAdi nvarchar(60)
- Aciklama nvarchar(200)
- AktifMi bit

### ref.RolYetki tablosu (yeni):
- YetkiId int IDENTITY PK
- RolKodu varchar(30) FK → ref.Rol
- SayfaKodu varchar(100) — 'AUDIT_CREATE', 'DOF_APPROVE', 'RISK_VIEW', 'ADMIN_SETTINGS'
- OkumaYetkisi bit
- YazmaYetkisi bit
- SilmeYetkisi bit

### log.GirisLog tablosu (yeni):
- LogId bigint IDENTITY PK
- KullaniciId int FK
- GirisTarihi datetime2(0)
- IpAdresi varchar(45)
- BasariliMi bit
- HataMesaji nvarchar(200) NULL

### Seed Data:
5 varsayılan rol + admin kullanıcı oluştur

## SP'LER
- ref.sp_Kullanici_GirisDogrula (@KullaniciAdi, @SifreHash) → kullanıcı + rol bilgisi
- ref.sp_Kullanici_GirisBasarisiz (@KullaniciId) → sayacı artır, 5'te kilitle
- ref.sp_Kullanici_GirisBasarili (@KullaniciId) → sayacı sıfırla, SonGirisTarihi güncelle
- ref.sp_Kullanici_SifreDegistir (@KullaniciId, @YeniSifreHash)
- ref.sp_Kullanici_SifreSifirlamaTalep (@KullaniciAdi) → token üret
- ref.sp_Kullanici_SifreSifirla (@Token, @YeniSifreHash) → token doğrula + şifre değiştir
- ref.sp_Yetki_KullaniciYetkileri (@KullaniciId) → tüm yetkileri getir

## WEB SAYFALARI
- Features/Auth/Login.cshtml — giriş formu
- Features/Auth/Logout.cshtml — çıkış
- Features/Auth/ChangePassword.cshtml — şifre değiştir
- Features/Auth/ForgotPassword.cshtml — şifre sıfırlama talebi
- Features/Admin/Users.cshtml — kullanıcı yönetimi (CRUD)
- Features/Admin/Roles.cshtml — rol ve yetki yönetimi

## Program.cs
- Cookie Authentication ekle
- Authorization policy'ler: her sayfa için [Authorize(Roles="...")] veya policy-based
- Middleware: her istekte kullanıcı yetki cache'i kontrol

## ŞİFRE KURALI
- BCrypt workFactor: 11
- Minimum 8 karakter
- İlk kurulumda Setup sayfası (admin hesap oluşturma — İcDenetim pattern'i)
```

---

### PROMPT 13 — DOF Onay İş Akışı (State Machine)

```
## GÖREV
dof.DofKayit için tam onay iş akışı state machine'i oluştur.

## STATE DİYAGRAMI
```
TASLAK ──→ ACIK ──→ AKSIYONDA ──→ DOGRULAMA_BEKLIYOR ──→ KAPANDI
  │          │          │                │                    
  │          │          │                └──→ RED             
  │          │          └──→ ACIK (geri gönder)               
  │          └──→ RED                                         
  └──→ (silme — sadece taslak silinebilir)                   
```

## DB DEĞİŞİKLİKLERİ

### dof.DofDurumKural tablosu (yeni):
- KuralId int IDENTITY PK
- EskiDurum varchar(20) NOT NULL
- YeniDurum varchar(20) NOT NULL
- GerekliRol varchar(30) NOT NULL — hangi rol bu geçişi yapabilir
- AktifMi bit DEFAULT(1)
- UNIQUE (EskiDurum, YeniDurum)

### dof.DofYorum tablosu (yeni):
- YorumId bigint IDENTITY PK
- DofId bigint FK → dof.DofKayit
- YorumMetni nvarchar(max) NOT NULL
- YorumTipi varchar(20) DEFAULT('NOT') — NOT, ONAY, RED, SORU, CEVAP
- YazanKullaniciId int FK → ref.Kullanici
- OlusturmaTarihi datetime2(0) DEFAULT(SYSDATETIME())

### dof.DofKayit'a ekle:
- EtkinlikSkoru decimal(5,2) NULL
- EtkinMi bit NULL
- EtkinlikNotu nvarchar(500) NULL
- SonEskalasyonTarihi datetime2(0) NULL
- EskalasyonSeviyesi tinyint DEFAULT(0)

### Seed: DofDurumKural tablosuna geçerli geçişler ekle

## SP'LER
- dof.sp_Dof_DurumDegistir (@DofId, @YeniDurum, @KullaniciId, @Yorum)
  → Kural kontrolü (ref.DofDurumKural)
  → Yetki kontrolü (kullanıcının rolü uygun mu?)
  → dof.DofDurumGecmis'e yaz
  → dof.DofYorum'a yorum ekle
  → Durum güncelle
  
- dof.sp_Dof_SlaKontrol
  → SLA_HedefTarih geçmiş + Durum kapanmamış olanları bul
  → EskalasyonSeviyesi artır (0→1: uyarı, 1→2: üst yönetici, 2→3: GM)
  → log.Bildirimler'e bildirim ekle

- dof.sp_Dof_YorumEkle (@DofId, @YorumMetni, @YorumTipi, @KullaniciId)
- dof.sp_Dof_Yorumlar (@DofId) → tüm yorumları getir (thread)
```

---

### PROMPT 14 — Bildirim Sistemi

```
## GÖREV
Platform genelinde bildirim sistemi oluştur.

## DB

### log.Bildirimler tablosu:
- BildirimId bigint IDENTITY PK
- KullaniciId int FK → ref.Kullanici
- Baslik nvarchar(200) NOT NULL
- Mesaj nvarchar(max) NOT NULL
- BildirimTipi varchar(50) NOT NULL
  — DOF_SLA_YAKLASTI, DOF_SLA_ASIMI, DOF_DURUM_DEGISTI
  — DENETIM_KESINLESTI, DENETIM_PLANLAMA
  — AI_RAPOR_HAZIR, AI_KRITIK_INSIGHT
  — RISK_KRITIK, RISK_ESKALASYON
  — SISTEMIK_SORUN, TEKRAR_UYARI
  — SISTEM_HATA, SISTEM_UYARI
- KaynakTip varchar(30) NULL — DOF, DENETIM, RISK, AI, SISTEM
- KaynakId bigint NULL — ilgili kaydın ID'si
- OnemSeviyesi varchar(10) DEFAULT('BILGI') — BILGI, UYARI, KRITIK, ACIL
- OkunduMu bit DEFAULT(0)
- OkunmaTarihi datetime2(0) NULL
- EmailGonderildiMi bit DEFAULT(0)
- EmailGonderimTarihi datetime2(0) NULL
- OlusturmaTarihi datetime2(0) DEFAULT(SYSDATETIME())
- INDEX: (KullaniciId, OkunduMu, OlusturmaTarihi DESC)

### ref.BildirimTercihi tablosu:
- TercihId int IDENTITY PK
- KullaniciId int FK
- BildirimTipi varchar(50)
- UiGoster bit DEFAULT(1)
- EmailGonder bit DEFAULT(0)
- AktifMi bit DEFAULT(1)

## SP'LER
- log.sp_Bildirim_Olustur (@KullaniciId, @Baslik, @Mesaj, @BildirimTipi, @KaynakTip, @KaynakId, @OnemSeviyesi)
- log.sp_Bildirim_Listele (@KullaniciId, @SadeceOkunmamis, @Top)
- log.sp_Bildirim_OkunduIsaretle (@BildirimId, @KullaniciId)
- log.sp_Bildirim_TopluOkundu (@KullaniciId) — tümünü okundu yap
- log.sp_Bildirim_Sayac (@KullaniciId) → okunmamış sayısı
- log.sp_Bildirim_EmailKuyruk (@Top) → email gönderilmemiş bildirimleri al

## WEB
- Shared/_Layout.cshtml'de navbar'a bildirim ikonu + badge
- AJAX endpoint: /api/bildirim/sayac (her 30 saniye polling)
- Bildirim dropdown: son 10 bildirim, "tümünü gör" linki
- Features/Bildirimler/Index.cshtml — tam bildirim listesi
- Features/Profil/BildirimTercihleri.cshtml — tercih yönetimi

## AI WORKER ENTEGRASYONU
- AuditAnalysisJob: Kritik insight üretildiğinde bildirim oluştur
- DofEffectivenessJob: Etkisiz DOF tespit edildiğinde bildirim
- RiskPredictionJob: Kritik risk tahmini varsa bildirim
- AiWorkerService: Her döngüde dof.sp_Dof_SlaKontrol çağır → SLA bildirimleri
```

---

### PROMPT 15 — Çapraz Korelasyon (ERP Risk ↔ Saha Denetim)

```
## GÖREV
ERP stok riski ile saha denetim bulgularını çapraz korelasyon analizi ile birleştir.

## BAĞLAM
- ERP risk: rpt.RiskUrunOzet_Gunluk (MekanId, StokId, RiskSkor, Flag'ler)
- Saha denetim: audit.DenetimSonuclari (DenetimId → audit.Denetimler.MekanId)
- Köprü: MekanId — aynı mağaza her iki sistemde de aynı MekanId ile tanımlı

## YENİ TABLOLAR

### rpt.KorelasyonOzet tablosu:
- KesimTarihi datetime2(0) NOT NULL
- MekanId int NOT NULL
- MekanAdi nvarchar(100)
- ErpRiskSkor int — ortalama ERP risk skoru (o mağazanın tüm ürünleri)
- ErpKritikUrunSayisi int — risk skoru 80+ ürün sayısı
- ErpTopFlag int — toplam aktif flag sayısı
- SahaDenetimSayisi int — son 12 ayda yapılan denetim sayısı
- SahaUyumOrani decimal(5,2) — son denetim uyum oranı
- SahaTekrarBulguSayisi int — tekrarlayan bulgu sayısı
- SahaSistemikBulguSayisi int
- BirlesikRiskSkor int — (ErpRiskSkor×0.4 + (100-SahaUyumOrani)×0.4 + TekrarFaktor×0.2)
- RiskKadran varchar(20) — YUKSEK_YUKSEK, YUKSEK_DUSUK, DUSUK_YUKSEK, DUSUK_DUSUK
- SonGuncellemeTarihi datetime2(0)
- PK: (KesimTarihi, MekanId)

## SP'LER
- rpt.sp_Korelasyon_Hesapla — günlük çalışır, tüm mağazalar için birleşik skor hesaplar
- rpt.sp_Korelasyon_MekanDetay (@MekanId) — tek mağazanın ERP + saha detayı
- rpt.sp_Korelasyon_TopRiskli (@Top) — BirlesikRiskSkor'a göre sıralı mağazalar
- rpt.sp_Korelasyon_DenetimOneri (@Top) — ERP riski yüksek + son denetim eski → denetim öner
- rpt.sp_Korelasyon_IsiHaritasi — tüm mağaza × kategori (DenetimGrubu) matrisi

## AI ENTEGRASYONU
- LmRules.DecideCorrelation(KorelasyonRow row) → yeni kural tipi
  - YUKSEK_YUKSEK kadranı → Acil müdahale, LLM analiz gerekli
  - YUKSEK_DUSUK (ERP yüksek, saha düşük) → "Saha denetimi sorun görmüyor ama ERP riskli — derinlemesine inceleme"
  - DUSUK_YUKSEK (ERP düşük, saha yüksek) → "Saha sorunlu ama ERP'de görünmüyor — operasyonel sorun"
- AI prompt: "Bu mağazada ERP X riski var + saha denetimde Y maddesi başarısız → kök neden analizi yap"

## DASHBOARD
- Yeni kart: "Çapraz Risk Matrisi" — scatter plot (ERP risk vs saha uyum)
- Mağaza tıklanınca detay popup: ERP riskleri + saha bulguları yan yana
- "Denetim Öner" butonu: AI'ın önceliklendirdiği mağaza listesi
```

---

### PROMPT 16 — Export Sistemi (PDF + Excel)

```
## GÖREV
Platform genelinde rapor export sistemi oluştur.

## BAĞLAM
NuGet paketleri:
- QuestPDF (PDF üretimi — açık kaynak, ücretsiz)
- EPPlus veya ClosedXML (Excel üretimi)

## EXPORT TİPLERİ

### 1. Denetim Raporu PDF
- Kapak: BKM Kitap logosu, rapor no, lokasyon, tarih, denetçi
- Özet: Toplam madde, geçen, kalan, uyum oranı, risk dağılımı
- Detay: Madde bazlı sonuçlar (geçti/kaldı renk kodlu)
- Bulgular: Başarısız maddeler detaylı (risk skor, tekrar sayısı, not)
- Fotoğraflar: İlişkili fotoğraflar embed edilmiş
- AI Analiz: Üretilmiş AI raporu varsa ekle
- DOF Özeti: İlişkili DOF'lar ve durumları

### 2. Karne PDF
- Lokasyon bazlı skor kartı
- Trend grafik (son 12 ay)
- En riskli maddeler
- Karşılaştırma: Lokasyonlar arası

### 3. Risk Tablosu Excel
- Sheet 1: RiskUrunOzet_Gunluk (filtreli)
- Sheet 2: Top 100 riskli ürün
- Sheet 3: Flag dağılımı pivot
- Sheet 4: Mağaza özeti

### 4. DOF Listesi Excel
- Tüm DOF'lar: durum, sorumlu, SLA, aksiyonlar
- Pivot: durum bazlı sayılar
- SLA aşım listesi

### 5. Yönetici Özeti PDF (Aylık)
- KPI kartları
- ERP risk trendi + saha denetim trendi
- Çapraz korelasyon özeti
- Kritik DOF'lar
- AI insight özeti
- Sonraki ay önerileri

## YAPILACAKLAR
- Services/ExportService.cs — PDF ve Excel üretim merkezi
- Her export tipi için ayrı metot
- SP ile veri çek → model'e dönüştür → PDF/Excel oluştur → byte[] döndür
- Web'de: İlgili sayfalara "PDF İndir" / "Excel İndir" butonları ekle
- Content-Disposition: attachment header ile indirme

## ZAMANLANMIŞ RAPOR
- ref.ZamanlanmisRapor tablosu: RaporTipi, Periyot(HAFTALIK/AYLIK), Alicilar(JSON), SonCalisma
- AiWorker'a ScheduledReportJob ekle: Pazartesi 08:00 haftalık, Ayın 1'i aylık
- MailKit ile email gönderimi (PDF attachment)
```

---

### PROMPT 17 — AI Proaktif Öneri Motoru

```
## GÖREV
Platform genelinde AI proaktif öneri motoru oluştur.

## BAĞLAM
Mevcut AI reaktif — kullanıcı istiyor, AI yapıyor.
Hedef: AI kendi başına analiz yapıp öneri sunar.

## YENİ JOB: ProactiveInsightJob.cs (BaseAiJob'dan türer)

### Çalışma periyodu: Her gün sabah 06:00 (gece ETL'den sonra)

### Öneri Tipleri:

1. DENETIM_PLANLA
   - Kural: Son denetimden 30+ gün geçmiş + ERP riski 60+ olan mağazalar
   - SP: audit.sp_ProaktifDenetimOneri(@GunEsik, @RiskEsik, @Top)
   - Çıktı: "X mağazasının son denetimi 45 gün önce, ERP riski 78 → denetim planla"

2. MADDE_GOZDEN_GECIR
   - Kural: Aynı madde son 12 ayda 5+ farklı lokasyonda başarısız
   - SP: audit.sp_ProaktifMaddeOneri(@MinLokasyon)
   - Çıktı: "Y maddesi 7 mağazada başarısız → madde metni/eğitim/prosedür gözden geçir"

3. TREND_UYARI
   - Kural: Lokasyonun uyum oranı son 3 ayda %10+ düşüş gösterdi
   - SP: audit.sp_ProaktifTrendUyari(@AySayisi, @DususEsik)
   - Çıktı: "Z lokasyonu 3 ayda %92'den %78'e düştü → müdahale gerekli"

4. KAYNAK_ONCELIKLENDIRME
   - Kural: Haftada max N denetim yapılabilir, en değerli N mağazayı seç
   - SP: rpt.sp_Korelasyon_DenetimOneri ile birleşik risk skoru
   - LLM: "Bu hafta 3 denetim planla → önerilen sıra: A, B, C (gerekçe: ...)"

5. ANOMALI_TESPIT
   - Kural: Lokasyonun son denetim skoru tarihsel ortalamasından 2 standart sapma uzak
   - SP: audit.sp_ProaktifAnomali(@StdSapmaEsik)
   - Çıktı: "A mağazası normalde %88 uyum, son denetim %62 → anormal düşüş"

6. KOK_NEDEN_ONERISI
   - Kural: Aynı madde 3+ lokasyonda başarısız (sistemik) → LLM kök neden analizi
   - LLM prompt: madde metni + başarısız lokasyonlar + tekrar sayıları → hipotez

### AI Insight Kayıt
- Tüm öneriler ai.AiAnalizIstegi'ne yazılır (KaynakTip='PROAKTIF')
- Dashboard'da ayrı "AI Önerileri" kartı
- Bildirim sistemiyle entegre (kritik öneriler → bildirim)
- Kullanıcı geri bildirimi: Faydalı mıydı? (AI feedback loop)
```

---

### PROMPT 18 — Test Altyapısı

```
## GÖREV
BkmArgus.Tests projesi oluştur.

## PROJE YAPISI
src/BkmArgus.Tests/BkmArgus.Tests.csproj (xUnit + FluentAssertions + Moq)

## TEST KATEGORİLERİ

### 1. Unit Tests — LmRules
- LmRules.Decide() — her flag kombinasyonu için beklenen çıktı
- LmRules.DecideAudit() — tekrar/sistemik/eskalasyon kuralları
- Risk eskalasyon formülü: BaseRisk × (1+Repeat×0.15) × (Systemic?1.3:1.0)
- RiskSkor hesaplama: Olasılık × Etki → seviye eşleşmesi
- DOF etkinlik skoru: 1.0 - (TekrarSayisi × 0.25), min 0.0

### 2. Unit Tests — Korelasyon
- BirlesikRiskSkor hesaplama
- RiskKadran belirleme
- Anomali tespit eşikleri

### 3. Integration Tests — SP Doğrulama
- Test DB oluştur (in-memory veya LocalDB)
- Test verisi seed et
- SP çağır → sonuç doğrula
- Pattern: TestFixture → seed → act → assert → cleanup

### 4. SQL Smoke Tests (genişletme)
- sql/99_smoke_tests.sql'e audit SP testleri ekle
- Her SP için: çağır → hata yok → satır sayısı > 0

### 5. AI Quality Tests
- Bilinen senaryo → AI çıktısı → beklenen alanlar mevcut mu?
- Hallucination testi: Olmayan veri referansı var mı?
- JSON format doğrulama: AI çıktısı parseable mı?

## TEST VERİSİ
- TestDataBuilder sınıfı: Builder pattern ile test verisi oluştur
  - .WithMekan("Test Magaza")
  - .WithDenetim(tarih, raporNo)
  - .WithSonuc(gectiMi: false, riskSkor: 20, tekrarSayisi: 3)
  - .WithDof(durum: "ACIK", sla: bugün+7)
  - .Build() → DB'ye yaz, ID'leri döndür
```

---

### PROMPT 19 — Git, CI/CD ve Deploy

```
## GÖREV
Proje için Git yapısı, deployment script ve temel CI/CD oluştur.

## GIT

### .gitignore
bin/, obj/, .vs/, .vscode/, *.user, *.suo
appsettings.Development.json, appsettings.*.local.json
.env, *.pfx, *.key
wwwroot/lib/, node_modules/
REPO_AUDIT_BUNDLE*.txt, all_files_dump.txt
*.bak, *.log

### Branch stratejisi
- main — production-ready
- dev — aktif geliştirme
- feature/* — özellik dalları (opsiyonel, tek geliştirici için basit tut)

### İlk commit mesajı
"feat: RiskAnaliz + İcDenetim birleşik platform — BkmArgus v1.0"

## DEPLOY SCRIPT — deploy.ps1

```powershell
# BkmArgus Deploy Script
param(
    [string]$Target = "Web",  # Web, AiWorker, All
    [string]$Config = "Release",
    [switch]$BackupFirst
)

$publishDir = "D:\Deploy\BkmArgus"
$backupDir = "D:\Backup\BkmArgus\$(Get-Date -Format 'yyyyMMdd_HHmmss')"

if ($BackupFirst) {
    # Mevcut deployment'ı yedekle
    # DB backup al (sqlcmd ile)
}

# Build + Publish
dotnet publish src/BkmArgus.Web -c $Config -o "$publishDir\Web"
dotnet publish src/BkmArgus.AiWorker -c $Config -o "$publishDir\AiWorker"

# IIS restart veya kestrel restart
```

## DB MİGRASYON YÖNETİMİ
- sql/ klasöründeki dosyalar numaralı (00, 01, ..., 20, 21, ...)
- Her migration dosyasının başında: -- Migration: XXXX, Tarih: dd.MM.yyyy
- log.DbMigration tablosu: MigrationNo, DosyaAdi, UygulamaTarihi, BasariliMi
- Installer her çalıştığında hangi migration'ların uygulandığını kontrol eder
- Yeni migration → sadece uygulanmamışları çalıştırır
```

---

### PROMPT 20 — Performans: Cache, Sayfalama, Index

```
## GÖREV
Platform genelinde performans iyileştirmeleri uygula.

## 1. MEMORY CACHE

### SqlDb.cs'e cache katmanı ekle:
- IMemoryCache DI ile enjekte et
- CacheKey pattern: "{SP_ADI}:{PARAM_HASH}"
- Dashboard KPI: 5 dk cache
- Ref tabloları: 30 dk cache  
- Risk listesi: 2 dk cache
- Cache invalidation: Yazma işlemlerinde ilgili cache'i temizle

### Yeni metot:
```csharp
public async Task<T> QueryCachedAsync<T>(string sp, object param, 
    TimeSpan? ttl = null, string? cacheGroup = null)
```

## 2. SAYFALAMA

### Tüm liste SP'lerine ekle:
- @Sayfa int = 1
- @SayfaBoyutu int = 50
- OUTPUT @ToplamKayit int

### SP pattern:
```sql
SELECT @ToplamKayit = COUNT(*) FROM ...;
SELECT ... 
ORDER BY ... 
OFFSET (@Sayfa - 1) * @SayfaBoyutu ROWS 
FETCH NEXT @SayfaBoyutu ROWS ONLY;
```

### UI: Shared/Pager component — ilk/önceki/sonraki/son butonları

## 3. INDEX OPTİMİZASYONU

### Eksik index analizi:
```sql
-- Sık sorgulanan ama index'i olmayan kombinasyonlar
-- dm_db_missing_index_details kullanarak öner
```

### Bilinen ihtiyaçlar:
- audit.DenetimSonuclari: (DenetimId, GectiMi) INCLUDE (RiskSkor, TekrarSayisi)
- audit.DenetimSonuclari: (MaddeId, GectiMi) INCLUDE (DenetimId)
- dof.DofKayit: (Durum, SLA_HedefTarih) — SLA kontrol SP'si için
- ai.AiAnalizIstegi: (Durum, Oncelik, KaynakTip)
- log.Bildirimler: (KullaniciId, OkunduMu) INCLUDE (OlusturmaTarihi)

## 4. CONNECTION POOLING
- appsettings.json'da connection string'e:
  Min Pool Size=5; Max Pool Size=100; Connection Timeout=30;
```

---

### PROMPT 21 — Structured Logging (Serilog)

```
## GÖREV
Serilog ile structured logging ekle.

## NuGet
- Serilog.AspNetCore
- Serilog.Sinks.File
- Serilog.Sinks.Console
- Serilog.Enrichers.Environment
- Serilog.Enrichers.Thread

## appsettings.json
```json
{
  "Serilog": {
    "MinimumLevel": { "Default": "Information", "Override": { "Microsoft": "Warning" } },
    "WriteTo": [
      { "Name": "Console" },
      { "Name": "File", "Args": { 
          "path": "logs/bkmargus-.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30,
          "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] [{TraceId}] {SourceContext} {Message:lj}{NewLine}{Exception}"
      }}
    ],
    "Enrich": ["FromLogContext", "WithMachineName", "WithThreadId"]
  }
}
```

## LOGGING NOKTALARI
- Her SP çağrısında: SP adı, süre (ms), parametre özeti
- AI çağrılarında: provider, model, token, süre, başarı/hata
- Auth: giriş/çıkış, başarısız deneme
- DOF durum değişikliği: eski durum → yeni durum, kullanıcı
- Hata: full exception + stack trace
- Yavaş sorgu uyarısı: > 2000ms → Warning log

## MIDDLEWARE
- RequestLoggingMiddleware: Her HTTP isteğinde TraceId üret, response süresini logla
- AI metrik toplama: Günlük AI çağrı sayısı, ortalama süre, hata oranı
```

---

## 10. GENİŞLETİLMİŞ ÖNCELİK SIRASI

| Faz | Prompt | Süre | Öncelik | Not |
|-----|--------|------|---------|-----|
| 0 — Hazırlık | — | 1 gün | P0 | Git + CLAUDE.md |
| 1 — DB Schema | 1, 2 | 2-3 gün | P0 | Temel |
| 2 — RBAC | 12 | 2-3 gün | P0 | Auth olmadan hiçbir şey güvenli değil |
| 3 — AiWorker | 3, 4, 5, 6 | 3-5 gün | P1 | AI motor birleşmesi |
| 4 — Web Modül | 7, 8 | 3-5 gün | P1 | Saha denetim UI |
| 5 — DOF İş Akışı | 13 | 2 gün | P1 | State machine |
| 6 — Bildirimler | 14 | 2 gün | P1 | Kullanıcı farkındalığı |
| 7 — AI Rapor + Proaktif | 9, 17 | 3 gün | P2 | AI değer katmanı |
| 8 — Korelasyon | 15 | 2-3 gün | P2 | Platform'un killer feature'ı |
| 9 — Export | 16 | 2 gün | P2 | Çıktı üretme |
| 10 — Test | 18 | 2 gün | P2 | Kalite güvencesi |
| 11 — Logging | 21 | 1 gün | P2 | İzlenebilirlik |
| 12 — Performans | 20 | 1-2 gün | P3 | Ölçekleme |
| 13 — CI/CD | 19 | 1 gün | P3 | Sürdürülebilirlik |
| 14 — Installer + Göç | 10, 11 | 2 gün | P3 | Dağıtım |
| 15 — Mobil UI | — | 3-5 gün | P3 | Saha kullanımı |
| **TOPLAM** | **21 prompt** | **30-45 gün** | | |

---

## 11. GELECEKTEKİ FAZLAR (v3.0+)

Bu plan v2.0 kapsamıdır. İleride eklenebilecek ama şu an kapsam dışı:

- **PWA / Offline denetim** — ServiceWorker ile offline form, senkronizasyon
- **REST API katmanı** — BkmArgus.Api projesi, dış entegrasyon
- **Webhook'lar** — DOF durum değişikliğinde dış sisteme bildirim
- **Barcode/QR tarama** — mağaza/raf kodu ile hızlı madde seçimi
- **GPS konum kaydı** — denetim başlatıldığında konum logla
- **Multi-tenant** — birden fazla şirket desteği
- **Lokalizasyon** — Türkçe/İngilizce çoklu dil
- **AI model fine-tuning** — golden memory ile model iyileştirme
- **Grafana/Prometheus entegrasyonu** — operasyonel metrik izleme
- **Active Directory / SSO** — kurumsal kimlik entegrasyonu
