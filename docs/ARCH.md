# BKMDenetim Mimarisi (V1)

## Ozet
Tek ASP.NET Core Razor Pages uygulamasi ve SQL Server. ERP verisi src view'ler uzerinden okunur, tum denetim verisi BKMDenetim'de tutulur.

## Bilesenler
- Web: Razor Pages (server-side), feature-based
- Data access: Dapper + stored procedure
- DB: BKMDenetim (src/ref/rpt/dof/ai/log)
- Scheduler: SQL Agent veya dis runner
- AI Worker: BkmDenetim.AiWorker (LM/LLM + semantik hafiza)
- Ollama: embedding ve LLM servisi (mxbai-embed-large, llama3/phi3)

## Feature yapisi
- `src/BkmDenetim.Web/Features/Dashboard`
- `src/BkmDenetim.Web/Features/Ref`
- `src/BkmDenetim.Web/Features/Yonetim`
- `src/BkmDenetim.Web/Features/Shared`

## Veri akis
1) Gece job'lari `log.sp_*` calistirir, `rpt` tablolarini yazar
2) UI ref/rpt stored procedure ve view'leri okur
3) DOF kayitlari `dof` semasinda tutulur (ERP'den bagimsiz)
4) AI istekleri `ai.AiAnalizIstegi` kuyruguna yazilir, worker LM/LLM ile isler

## Konfigurasyon
- Connection string: env `BKM_DENETIM_CONN` varsa onu kullanir, yoksa `appsettings.json`.
- Log: traceId ile, PII yazmayacak sekilde.

## ADR
- ADR-001 Dapper secimi: SP-first, performans ve kontrol
- ADR-002 Controller yok: Razor Pages transaction script
- ADR-003 Tek DB: ERP degisse de denetim verisi korunur

## Riskler ve onlemler
- IrsTip map eksigi -> metrik bozulur; saglik WARN + map zorunlulugu
- Gecmis duzeltme -> drift; backfill pencere + gun toplam kontrolu
- Uzun job -> indeks ve windowed isleme
- Semantik hafiza modeli yok -> LM sadece rule-based calisir, log uyarisi

## Guvenlik
- Admin/ref ekranlari auth gerektirir (planli).
- Tum inputlar backend'de validate edilir.
- Parametreli SP kullanilir.

## AI mimari notu
- LM karar + semantik hafiza: BkmDenetim.AiWorker icinde.
- LLM sadece gerekli risklerde kuyruga alinir.
- Detayli tasarim: docs/04_AI_Risk_Analiz.md
