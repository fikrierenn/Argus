# BkmArgus — AI-Powered Audit & Risk Intelligence Platform

## Proje Ozeti
BKM Kitap ic denetim ve risk yonetim platformu. Iki ana kanal:
1. ERP Risk Analizi: Stok/evrak hareketlerinden otomatik risk sinyali (gece ETL)
2. Saha Denetimi: Denetcinin magaza/kafe ziyareti, checklist, fotograf kaniti

## Tech Stack
- Web: ASP.NET Core Razor Pages, Dapper, SP-first
- DB: SQL Server (BKMDenetim), 8 sema (src/ref/rpt/dof/ai/log/etl/audit)
- AI: LM Rules (deterministik) -> Semantik Hafiza (Ollama embedding) -> LLM (Gemini/Claude/Ollama)
- Worker: BkmArgus.AiWorker (BackgroundService)
- Installer: Console + Web UI
- MCP: BkmArgus.McpServer

## Sema Haritasi
src   — ERP soyutlama view'leri (DerinSISBkm cross-DB)
ref   — referans/mapping (mekan, tip, parametre, personel, kullanici)
rpt   — rapor snapshot tablolari (risk gunluk/aylik, stok bakiye)
dof   — DOF sureci (kayit/bulgu/aksiyon/kanit/durum gecmisi)
ai    — AI analiz (istek/sonuc/vektor/embedding/tahmin)
log   — calisma loglari ve saglik kontrol
etl   — ETL sync durum
audit — saha denetim (denetimler/maddeler/sonuclar/fotograflar/beceriler)

## AI Akisi
1. ERP risk: Gece ETL -> flag + skor -> LmRules.Decide() -> Semantik benzerlik -> LLM kuyruk
2. Saha denetim: Kesinlestir -> TekrarTespit -> SistemikTespit -> DofEtkinlik -> LmRules.DecideAudit() -> LLM kuyruk
3. Ortak: SemanticMemoryService (DOF + denetim bulgulari), LlmService (Gemini->Claude->Ollama)

## Kodlama Kurallari
- SP-first: Tum veri erisimi stored procedure uzerinden
- Parametre adlari Turkce
- Tarih literal'lari DMY (dd.MM.yyyy)
- datetime2(0) kullan, datetime KULLANMA
- Hata yonetimi: TRY-CATCH
- Config: env var oncelikli, yoksa appsettings.json
- SQL injection: parametreli SP, string concat YASAK

## Komutlar
- Web: dotnet run --project src/BkmArgus.Web
- Worker: dotnet run --project src/BkmArgus.AiWorker
- Installer: dotnet run --project src/BkmArgus.Installer
- MCP: dotnet run --project src/BkmArgus.McpServer
- Risk ETL: EXEC log.sp_RiskUrunOzet_Calistir;
- Stok ETL: EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=120;
- Saglik: EXEC log.sp_SaglikKontrol_Calistir;
- Denetim Analiz: EXEC audit.sp_Analiz_TumPipeline @DenetimId=X;

## Guvenlik
- Gizli bilgi: env var veya appsettings, ASLA kod icinde
- Auth: ref.Kullanici + cookie-based (planlaniyir)
- Dosya upload: sadece image, max 5MB, validate
- SQL: parametreli SP, enjeksiyon korumasi

## Proje Yapisi
```
D:\Dev\BkmArgus\
├── BkmArgus.sln
├── sql/           (tum SQL dosyalari: schema, tablolar, SP'ler, seed)
├── docs/          (dokumantasyon)
├── _archive/      (IcDenetim referans arsiv)
└── src/
    ├── BkmArgus.Web/           (Razor Pages web app)
    ├── BkmArgus.AiWorker/      (AI background worker)
    ├── BkmArgus.Installer/     (kurulum araci)
    ├── BkmArgus.McpServer/     (schema API)
    └── SchemaManagement.Library/ (DbUp migration)
```

## DB Baglanti
- Dev: Server=192.168.40.201; Database=BKMDenetim
- ERP: DerinSISBkm (ayni sunucu, cross-DB view'lar)
- Env var: BKM_DENETIM_CONN veya ConnectionStrings:BkmArgus
