# BkmArgus Master Plan — Nihai Uygulama Rehberi

**Son Guncelleme:** 29.03.2026
**Durum:** FAZ 1 tamamlandi, FAZ 2 bekliyor

---

## 1. TAMAMLANAN ISLER

| FAZ | Is | Tarih | Commit |
|-----|----|-------|--------|
| 0 | Proje olusturma (D:\Dev\BkmArgus), RiskAnaliz kopyalama, BkmDenetim->BkmArgus rename | 29.03 | dccb05f |
| 0 | Git init, .gitignore, CLAUDE.md, _archive/icdenetim | 29.03 | dccb05f |
| 1 | audit schema olusturma (6 yeni tablo + 58 SP) | 29.03 | f5e3d10 |
| 1 | dbo.* -> audit.* schema tasima (10 tablo) | 29.03 | f5e3d10 |
| 1 | ref.* Turkce -> Ingilizce rename (9 tablo + tum kolonlar) | 29.03 | f5e3d10 |
| 1 | dof.* Turkce -> Ingilizce rename (5 tablo + tum kolonlar) | 29.03 | f5e3d10 |
| 1 | ai.* Turkce -> Ingilizce rename (8 tablo + tum kolonlar) | 29.03 | f5e3d10 |
| 1 | rpt.* Turkce -> Ingilizce rename (3 tablo + 43+ kolonlar) | 29.03 | f5e3d10 |
| 1 | log.* + etl.* rename | 29.03 | f5e3d10 |
| 1 | Dogrulama: 40 tablo, 8 schema, hepsi Ingilizce | 29.03 | f5e3d10 |

---

## 2. YAPILACAK ISLER (Oncelik Sirasina Gore)

### FAZ 2 — SP + C# Kod Guncelleme (3-5 gun)

**2.1 Mevcut SP'leri yeni tablo/kolon adlariyla guncelle (~50 SP)**
- ref.sp_* -> Ingilizce tablo/kolon referanslari
- rpt.sp_* -> DailyProductRisk, MonthlyProductRisk, DailyStockBalance
- dof.sp_* -> Findings, FindingDetails, Actions, Evidence, StatusHistory
- ai.sp_* -> AnalysisQueue, SemanticVectors, LlmResults
- log.sp_* -> RiskEtlRuns, StockEtlRuns
- etl.sp_* -> SalesStaging, StockMovementStaging, StockStaging
- SP adlarini da Ingilizce'ye cevir (sp_RiskUrunOzet_Calistir -> sp_DailyProductRisk_Run)
- NOT: src.* view'leri DEGISMEZ, SP'ler alias kulllanir

**2.2 C# kod guncelleme (RiskAnaliz kodlari)**
- BkmArgus.AiWorker/Models.cs: Turkce property adlari -> Ingilizce
- BkmArgus.AiWorker/AiWorkerService.cs: SQL string'lerdeki tablo/kolon adlari
- BkmArgus.AiWorker/SemanticMemoryService.cs: SQL string'ler
- BkmArgus.AiWorker/LmRules.cs: Property referanslari
- BkmArgus.AiWorker/Jobs/*.cs: SP cagrilari
- BkmArgus.Web/Data/SqlDb.cs: SP cagrilari
- BkmArgus.Web/Features/**/*.cshtml.cs: Model ve SP referanslari

**2.3 Build + test**
- dotnet build = 0 hata
- Web calisir (dashboard, risk, dof sayfalari)
- AiWorker calisir (kuyruk isleme)

### FAZ 3 — Audit UI Port (3-5 gun)

**3.1 Features/Audit/ modulu olustur**
- _archive/icdenetim kodlarindan Razor Pages tasima
- audit.sp_* SP'lerini kullanan sayfalar:
  - Index (denetim listesi)
  - Create (yeni denetim)
  - Edit (Evet/Hayir formu)
  - Detail (detay + foto + AI rapor)
  - Items (master madde yonetimi)
  - Reports (karne + trend)

**3.2 Dashboard birlestirme**
- ERP risk KPI'lari (mevcut) + saha denetim KPI'lari (yeni)
- Tab ile gecis: ERP Risk / Saha Denetim
- audit.sp_Dashboard_FieldAudit_Kpi, sp_Dashboard_RecentAudits, sp_Dashboard_TopRiskFindings

**3.3 LlmService'e Claude API provider ekleme**
- Gemini (1. sirada) -> Claude (2. sirada) -> Ollama (3. sirada)
- HttpClient ile Anthropic API cagrisi
- Mevcut retry + quality validation pattern korunur

### FAZ 4 — RBAC + Auth (2-3 gun)

**4.1 audit.Users genisletme**
- SifreHash, BasarisizGirisSayisi, HesapKilitliMi, SonSifreDegisim
- ref.Users ile birlesim (tek kullanici tablosu karari)

**4.2 Rol/Yetki tablolari**
- ref.Roles (ADMIN, AUDITOR, MANAGER, ANALYST, READONLY)
- ref.RolePermissions (sayfa bazli yetki)
- log.LoginHistory

**4.3 Cookie auth + sayfa bazli yetki**
- BCrypt workFactor: 11
- Sliding expiration 7 gun
- Setup wizard (ilk admin olusturma)

### FAZ 5 — Eksik Ozellikler (5-10 gun)

**5.1 DOF State Machine**
- DRAFT -> OPEN -> INACTION -> VALIDATION_PENDING -> CLOSED/REJECTED
- dof.StatusRules (gecis kurallari + rol kontrolu)
- dof.Comments (yorum thread)
- SLA takibi + otomatik eskalasyon

**5.2 Bildirim Sistemi**
- log.Notifications tablosu
- UI: navbar bildirim ikonu + badge
- Tipler: DOF_SLA, AUDIT_FINALIZED, AI_REPORT_READY, RISK_CRITICAL

**5.3 Capraz Korelasyon (ERP Risk <-> Saha Denetim)**
- rpt.CrossCorrelation tablosu
- MekanId koprsu (audit.Audits.LocationId = rpt.DailyProductRisk.LocationId)
- Birlesik risk skoru: ERP*0.4 + Saha*0.4 + TekrarFaktor*0.2
- 4 kadran: YUKSEK_YUKSEK (acil), YUKSEK_DUSUK, DUSUK_YUKSEK, DUSUK_DUSUK

**5.4 Export (PDF + Excel)**
- QuestPDF (denetim raporu, karne)
- ClosedXML (risk tablosu, DOF listesi)
- Zamanlanmis rapor (haftalik/aylik email)

**5.5 AI Proaktif Oneriler**
- ProactiveInsightJob (her gun 06:00)
- DENETIM_PLANLA: Son 30+ gun + ERP risk 60+ -> denetim oner
- TREND_UYARI: Uyum orani 3 ayda %10+ dusus -> mudahale oner
- ANOMALI_TESPIT: Tarihsel ortalamadan 2 std sapma uzak -> uyari

**5.6 AI Feedback Loop**
- Her AI ciktisinda 👍/👎
- Golden memory (onaylanan pattern'ler)
- Few-shot learning (onaylanan patternler prompt'a enjekte)

### FAZ 6 — Test + Deploy (2-3 gun)

**6.1 SQL smoke tests**
- 99_smoke_tests.sql genisletme (audit SP'ler dahil)

**6.2 C# unit tests**
- BkmArgus.Tests projesi (xUnit)
- LmRules.Decide + LmRules.DecideAudit testleri
- Risk eskalasyon formulu testi

**6.3 Structured logging**
- Serilog entegrasyonu
- SP suresi, AI cagrisi, auth loglari

**6.4 Deploy**
- deploy.ps1 script
- DB backup + migration + publish

---

## 3. KAYNAK DOKUMANLAR

| Dokuman | Konum | Icerik |
|---------|-------|--------|
| V3 Gecis Plani | docs/BKMARGUS_PLATFORM_GECIS_PLANI_V3_FINAL.md | Detayli tablo rename mapping |
| Birlestirme Detay | docs/BKMARGUS_BIRLESTIRME_PLANI_DETAY.md | Gap analizi, konsolidasyon |
| PRD | docs/PRD.md | V1 fonksiyonel gereksinimler |
| Mimari | docs/ARCH.md | ADR'ler, component yaklasimi |
| Algoritma | docs/ALGO.md | Risk hesaplama, ETL akisi, AI akisi |
| AI Enhancement | docs/05_AI_Enhancement_Plan.md | V2 multi-agent, learning |
| Ilaveler | docs/ilaveler.txt | Gelecek vizyon (Copilot, Vision AI, gamification) |

---

## 4. ARSIV (IcDenetim'den Korunacak Kodlar)

`_archive/icdenetim/` altinda referans olarak saklanir. FAZ 3'te Audit UI port edilirken kullanilacak:

| Dosya | Amac | Tasima Hedefi |
|-------|------|---------------|
| Services/AI/AIOrchestratorService.cs | Hybrid karar motoru | AiWorker/Jobs/ altina |
| Services/AI/AIContextBuilder.cs | Zengin AI context | AiWorker/Services/ |
| Services/AI/AiBackgroundWorker.cs | Kuyruk isleme | AiWorker entegre |
| Services/Events/* | Event bus sistemi | AiWorker/Events/ |
| Services/AuditProcessingService.cs | Pipeline orchestrator | AiWorker/Jobs/ |
| Services/DataIntelligenceService.cs | Repeat/systemic/DOF | SP'lere tasinmis (audit.sp_Analysis_*) |
| Services/InsightService.cs | Kural + AI insight | LmRules.DecideAudit() |
| Services/FindingsService.cs | Zengin bulgu sorgu | audit.sp_* SP'ler |
| Pages/Dashboard/* | Dashboard UI | Features/Audit/ |
| Pages/Denetimler/* | Denetim CRUD | Features/Audit/ |
| Pages/Aksiyon/* | DOF yonetimi | Features/Dof/ genisletme |
| Pages/Beceriler/* | Skill yonetimi | Features/Audit/Skills |
| Pages/Shared/_Layout.cshtml | Sidebar UI | Features/Shared/ entegre |
| .env | Claude API key + DB conn | Korunacak |

---

## 5. DB DOGRULAMA SCRIPTI

```sql
-- Tum Ingilizce tablo adlarinin dogrulamasi (NULL = eksik)
SELECT 'ref.LocationSettings' AS T, OBJECT_ID('ref.LocationSettings') AS Id
UNION ALL SELECT 'ref.Personnel', OBJECT_ID('ref.Personnel')
UNION ALL SELECT 'ref.Users', OBJECT_ID('ref.Users')
UNION ALL SELECT 'dof.Findings', OBJECT_ID('dof.Findings')
UNION ALL SELECT 'ai.AnalysisQueue', OBJECT_ID('ai.AnalysisQueue')
UNION ALL SELECT 'rpt.DailyProductRisk', OBJECT_ID('rpt.DailyProductRisk')
UNION ALL SELECT 'audit.Audits', OBJECT_ID('audit.Audits')
UNION ALL SELECT 'audit.AuditResults', OBJECT_ID('audit.AuditResults')
UNION ALL SELECT 'audit.Users', OBJECT_ID('audit.Users')
UNION ALL SELECT 'etl.SalesStaging', OBJECT_ID('etl.SalesStaging')
UNION ALL SELECT 'log.RiskEtlRuns', OBJECT_ID('log.RiskEtlRuns')
ORDER BY T;
-- Hepsi NOT NULL olmali
```

---

## 6. TAHMINI SURE

| FAZ | Sure | Oncelik |
|-----|------|---------|
| FAZ 2: SP + C# guncelleme | 3-5 gun | P0 |
| FAZ 3: Audit UI + Dashboard + Claude | 3-5 gun | P0 |
| FAZ 4: RBAC + Auth | 2-3 gun | P0 |
| FAZ 5: Eksik ozellikler | 5-10 gun | P1-P2 |
| FAZ 6: Test + Deploy | 2-3 gun | P2 |
| **TOPLAM** | **15-26 gun** | |
