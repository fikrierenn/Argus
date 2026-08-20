# 02 — Şema Uzlaştırma: `sql/` ↔ Canlı DB

**Tier:** 3 · **Durum:** taslak — onay bekliyor
**Tarih:** 2026-08-20 · **Bloklar:** `01-audit-log.md` ve FAZ A'nın tamamı

## Problem

`sql/` migration zinciri canlı veritabanının **iki nesil gerisinde**. Kanıt:

| | Sayı |
|---|---|
| `sql/` yaratıyor, canlıda yok (Türkçe, ölü tanım) | **41** |
| Canlıda var, `sql/` yaratmıyor (kaynak kontrolü dışı) | **34** |
| Örtüşen | 27 |
| **Canlı toplam** | **61 tablo, 9 şema** |

FAZ 1/2 "Türkçe→İngilizce" tablo rename'i **elle yapılmış, `sql/`'e hiç girmemiş**. `sql/33` yalnız *kolon* rename'i yapıyor — üstelik zaten İngilizce olduğunu varsaydığı tablolara.

Eşleşme birebir: `ai.AiLlmSonuc`→`ai.LlmResults`, `dof.DofKayit`→`dof.Findings`, `ref.Kullanici`→`ref.Users`, `rpt.RiskUrunOzet_Gunluk`→`rpt.DailyProductRisk`…

**Sonuç:** Temiz kurulum bugün çalıştırılırsa kodun kullanamayacağı Türkçe bir veritabanı çıkar. Bu düzelmeden yazılacak her migration kurgusal bir şemaya yazılmış olur.

### Yan bulgular (aynı taramada çıktı)

**(a) Canlı runtime bug — bloklayıcı.** `AiWorkerService.cs` `MERGE ai.RuleResults` yapıyor; **`ai.RuleResults` canlıda yok**. LM hattı her koşuda patlıyor. `ai.AnalysisQueue` (0 satır) ve `ai.LlmResults` (0 satır) boşluğunun kök nedeni bu — TODO A2/A7 aslında tek bir bugmuş.

**(b) Dört ölü tablo.** Hiçbir SP'den *ve* hiçbir C#'tan referans almıyor:

| Tablo | Satır | Durum |
|---|---|---|
| `audit.AiAnalyses` | **14** | Eski nesil AI sonuç tablosu. Veri var, kimse okumuyor |
| `audit.CorrectiveActions` | 1 | Eski tek-tablo CAPA; `dof.Findings` (84) + `StatusHistory` (104) ile aşıldı |
| `audit.Skills` + `SkillVersions` | 1 + 1 | Denetçi yetkinlik alanı; hiç kullanılmamış. `ai.Skills` (10) ile isim çakışması |
| `audit.AuditLog` | 0 | Şema makul (`Id, UserId, Operation, TableName, RecordId, OldValues, NewValues, CreatedAt`) ama hiç bağlanmamış |

**(c) AiWorker'da 24 inline SQL ihlali.** TODO C5'te tek bir olay (`log.Notifications`) kaydetmiştim — gerçek sayı 24, altı dosyada. Web katmanı **temiz** (sıfır ihlal).

**(d) Ölü test dosyaları ölü şemaya bakıyor.** `DbTest.cs`/`DebugTest.cs` artık var olmayan `ai.AiAnalizIstegi`, `ai.AiLlmSonuc`, `rpt.RiskUrunOzet_Gunluk` tablolarını sorguluyor.

**(e) Üç ETL koşum log tablosu.** `etl.EtlRuns` (11 satır, 2 SP) · `log.RiskEtlRuns` (14, 3 SP) · `log.StockEtlRuns` (9, 3 SP). Hepsi canlı, kısmi duplikasyon.

## Kapsam

**Dahil:** runtime bug düzeltmesi · ölü tablo kararı + veri taşıma · AiWorker inline SQL → SP · canlıdan baseline üretimi · fresh-DB doğrulaması · legacy arşivleme · CLAUDE.md düzeltmesi

**Hariç:** `audit.AuditLog`'a yazma (plan 01, bunun ardından) · `ai.Skills`/`audit.Skills` yeniden adlandırma (isim çakışması can sıkıcı ama kırıcı değil) · ETL log konsolidasyonu (ayrı karar, üçü de çalışıyor)

## Reddedilen alternatifler

| Alternatif | Neden reddedildi |
|---|---|
| **Yalnız baseline al, duplikasyona dokunma** | En hızlısı ama ölü tabloları kalıcılaştırır. Bir kez baseline'a girerse bir daha kimse dokunmaz |
| **41 rename'i migration olarak yaz (ileri-uyum)** | Adım adım tarihçe korunur ama her rename'in kolon seti de değişmiş olabilir; 34 tablonun kolon-kolon eşlemesi elle çıkarılmalı. Haftalar sürer, kazancı yalnızca "tarihçe" — o tarihçe zaten çalışmıyor |
| **`sql/`'i tamamen sil, sıfırdan başla** | Seed verisi ve SP tanımları da gider. Legacy arşivlemek bedava, silmek geri alınamaz |
| **Ölü tabloları hemen DROP et** | `audit.AiAnalyses`'te 14 satır var. Önce ne olduğu anlaşılmalı — belki taşınmalı |

## Adımlar

### Faz 1 — Runtime bug (bloklayıcı, önce bu)

- [ ] `ai.RuleResults` ne olmalı: eksik tablo mu, yanlış isim mi? `AiWorkerService` MERGE gövdesini oku, `ai.AnalysisQueue` kolonlarıyla karşılaştır
- [ ] Karar: tabloyu yarat **veya** MERGE'ü doğru hedefe çevir
- [ ] Smoke: AiWorker'ı çalıştır → `ai.AnalysisQueue` satırı `LM_DONE`/`LLM_QUEUED`'a geçsin, `ai.LlmResults`'a satır düşsün
- [ ] Bu tek düzeltme TODO **A2 + A7**'yi birden kapatabilir

### Faz 2 — Ölü tablo kararı

- [ ] `audit.AiAnalyses`'teki 14 satırı incele — `ai.SkillExecutions`'a taşınmalı mı, arşiv mi, at mı?
- [ ] `audit.CorrectiveActions`'taki 1 satır — `dof.Findings` karşılığı var mı?
- [ ] Karar tablosu çıkar: **taşı / arşivle / bırak**. Kullanıcı onayı **şart** (`before-major-change.md`: yedek almadan DROP yasak)
- [ ] `sql/56_dead_table_retire.sql` — yedek (`SELECT INTO audit.<tablo>_Archive`) sonra DROP
- [ ] `audit.AuditLog` **korunur** — plan 01 onu genişletecek

### Faz 3 — AiWorker inline SQL → SP (24 ihlal)

- [ ] Ölü test dosyalarını sil: `DbTest.cs`, `DebugTest.cs`, `TestDebug.cs`, `TestEmbedding.cs` (TODO C4 — ölü şemaya bakıyorlar, taşımaya değmez)
- [ ] Kalan inline SQL'leri SP'ye çevir: `AiWorkerService` (8), `AgentPipelineMonitorJob` (12), `ProactiveInsightJob` (2), `RiskPredictionJob` (3)
- [ ] Her yeni SP: Türkçe parametre, `SET NOCOUNT/XACT_ABORT`, `TRY/CATCH`
- [ ] `sql-sp-reviewer` + `ai-pipeline-reviewer`

### Faz 4 — Baseline

- [ ] Canlıdan tam DDL çıkar: 61 tablo + 163 SP + view + index + computed kolon + FK + default
- [ ] `sql/60_baseline.sql` — idempotent (`IF OBJECT_ID IS NULL`)
- [ ] Seed verisi ayrı: `sql/61_baseline_seed.sql` (`ref.*`, `sem.*`, `ai.Skills` — iş verisi değil, kurulum verisi)
- [ ] `sql/00-55` → `sql/legacy/` (silinmez)

### Faz 5 — Fresh-DB doğrulaması (kanıt)

- [ ] Boş DB'ye `sql/60 → 61` uygula, **0 fail**
- [ ] Obje karşılaştırması: fresh DB'nin tablo/kolon/SP listesi canlıyla **birebir aynı** olmalı — çıktıyla kanıtla
- [ ] `src.*` cross-DB view'ları: obje varlığı doğrulanır, sorgu çalışmayabilir (ERP erişimi yok) — beklenen

### Faz 6 — Doküman düzeltmesi

- [ ] CLAUDE.md: "8 şema, 40 tablo" → **9 şema, 61 tablo**. `audit` tablo listesi gerçekle eşleşsin
- [ ] `sql/legacy/README.md` — neden arşivlendiği, hangi tarihte, baseline'ın nereden alındığı
- [ ] TODO A2/A7/C4/C5 güncelle (kök neden bulundu / sayı düzeltildi)

## Kısıt kontrolü

- [x] SP-first — Faz 3 bunu **onarıyor**
- [x] Türkçe SP parametresi (yeni SP'lerde)
- [x] `src.*` dokunulmuyor — baseline'a view tanımı olarak girer, içeriği değişmez
- [x] `rpt.*` snapshot — `DailyProductRisk` 65.960 satır, **veriye dokunulmuyor**, yalnız DDL çıkarılıyor
- [x] Yedek almadan DROP yok (`before-major-change.md`)

## 5 lens

- 🔴 **Contrarian:** Baseline canlıyı "doğru" kabul ediyor. Ya canlıda da hata varsa? Elle yapılmış rename'lerde eksik index, kayıp FK, yanlış tip olabilir. → Faz 4'te yalnız DDL kopyalamak yetmez; `sql-sp-reviewer`'a **canlı şemayı da** denetlet.
- 🔵 **First Principles:** Asıl soru "migration'lar düzgün mü" değil, **"bu projeyi ikinci bir makineye kurabiliyor muyum"**. Bugünkü cevap hayır. Bitiş kriteri bu olmalı.
- 🟢 **Expansionist:** Baseline çıkarma işi bir kez otomatikleşirse (`sqlcli` betiği) her faz sonunda tekrar çalıştırılabilir — şema kayması bir daha sessizce birikmez.
- ⚪ **Outsider:** 55 migration dosyası var ve hiçbiri çalışmıyor. Dosya sayısı çalışan bir kurulumla karıştırılmış.
- 🟡 **Executor:** Pazartesi ilk iş `ai.RuleResults`. Tek satırlık bug, iki TODO maddesini birden kapatıyor, kanıtı hemen görülür.

## Riskler

| Risk | Etki | Önlem |
|---|---|---|
| Ölü sandığımız tablo aslında kullanılıyor | Veri kaybı | SP + C# taraması yapıldı (ikisi de 0). DROP öncesi `SELECT INTO` arşiv + kullanıcı onayı |
| Baseline canlının hatalarını da kopyalar | Hata kalıcılaşır | Faz 4'te canlı şema denetimi (contrarian lens) |
| 65.960 satırlık snapshot etkilenir | Veri kaybı | Baseline yalnız DDL. Veriye **dokunulmuyor** |
| Legacy arşivlenince eski bilgi kaybolur | Tarihçe | Silme yok, `sql/legacy/` + README |
| Faz 3'te SP'ye çevirirken davranış değişir | Regresyon | Her SP çevrimi sonrası smoke; AiWorker'ı gerçek kayıtla koştur |

## Bitiş kriteri

- [ ] Boş bir SQL Server'a `sql/60 → 61` uygulanıyor, **0 fail**
- [ ] Fresh DB'nin obje listesi canlıyla **birebir** (çıktıyla kanıtlanmış)
- [ ] `dotnet build` 0 hata; AiWorker gerçek kayıtta koşuyor, `ai.LlmResults`'a satır düşüyor
- [ ] AiWorker'da inline SQL **0** (Web zaten 0)
- [ ] Ölü tablolar arşivlenmiş veya gerekçesiyle bırakılmış — belirsiz tek tablo kalmamış
- [ ] CLAUDE.md şema bölümü canlıyla eşleşiyor

## Geri alma

Faz 1-3 kod değişikliği — `git revert`.
Faz 2 DROP — arşiv tablosundan `INSERT INTO ... SELECT` ile geri yüklenir.
Faz 4-6 yalnız dosya ekleme/taşıma — `git revert`. Canlı DB'ye **hiç dokunulmuyor** (baseline okuma işlemidir).
