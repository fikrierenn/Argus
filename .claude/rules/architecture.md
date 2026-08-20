# Mimari ve Tasarım Kuralları (BkmArgus)

BkmArgus platformunun temel mimari yapısını, veri erişim prensiplerini, iki veri kanalını ve AI katmanını tanımlar. `paths:` yok — compact sonrası da geçerli.

---

## 1. İki Veri Kanalı

BkmArgus tek platformda iki bağımsız kanal birleştirir:

| Kanal | Kaynak | Akış |
|---|---|---|
| **ERP Risk Analizi** | DerinSISBkm (cross-DB) | Gecelik ETL → `rpt.DailyProductRisk` → risk skoru → DOF |
| **Saha Denetimi** | Denetçi (web/mobil) | Denetim + fotoğraf → `audit.*` → AI analiz → DOF |

İki kanal `dof.Findings` üzerinde birleşir. Cross-correlation (`sql/40_cross_correlation.sql`) iki kanalın aynı mekan/ürün için ürettiği sinyalleri eşler.

---

## 2. SP-First İş Mantığı (MUTLAK)

*   **Tüm veri erişimi stored procedure üzerinden.** Web katmanında inline SQL **YASAK** — tek istisna `SqlDb.GetDbInfoAsync` ping sorgusudur.
*   **İş mantığı SQL katmanında:** Risk skorlama, durum geçiş doğrulaması (`dof.sp_Finding_Transition`), SLA hesabı, ETL agregasyonu → SP/View/Function. C# yalın orkestratör: HTTP → yetki → Dapper SP çağrısı → sonuç/mesaj.
*   **Atomiklik:** Çok adımlı yazma (denetim finalize, DOF geçişi, ETL çalıştırma) tek SP + tek transaction içinde. Hata → SQL `THROW` ile **Türkçe** açıklayıcı mesaj.
*   Yeni SP: `.claude/skills/sql-migration-writer` + `.claude/rules/sql-conventions.md`.

---

## 3. Dapper Tek ORM

*   **Entity Framework YASAK.** Tüm erişim Dapper + `CommandType.StoredProcedure`.
*   Web'de tek giriş noktası: `src/BkmArgus.Web/Data/SqlDb.cs` (`QueryAsync` / `QuerySingleAsync` / `ExecuteAsync`). Yeni bir connection açan yol ekleme — `SqlDb`'yi genişlet (footprint-ladder basamak 1).
*   AiWorker karşılığı: `src/BkmArgus.AiWorker/Db.cs`.
*   `SELECT *` yasak — SP içinde de sadece ihtiyaç duyulan kolonlar.

---

## 4. `src.*` View'ları — DOKUNULMAZ

*   `src.vw_StokHareket`, `vw_EvrakBaslik`, `vw_EvrakDetay`, `vw_IrsTip`, `vw_Mekan`, `vw_Urun` ERP (DerinSISBkm) soyutlamasıdır.
*   **Bu view'lar asla değiştirilmez, kolonları asla yeniden adlandırılmaz.** ERP Türkçe kolon adlarını taşırlar.
*   Türkçe kolonlar **SP içinde alias'lanır**:
    ```sql
    SELECT sh.ehMekanId AS LocationId, sh.ehStokId AS ProductId
    FROM src.vw_StokHareket sh
    ```
*   ERP şeması değişirse düzeltme view tanımında değil, alias katmanında yapılır.

---

## 5. Şema Sorumlulukları (8 şema)

| Şema | Sorumluluk | Yazma hakkı |
|---|---|---|
| `src` | ERP soyutlama (view-only) | **YOK** — salt okuma |
| `ref` | Referans/eşleme (9 tablo) | Ref ekranı (ADMIN) |
| `audit` | Saha denetimi (10 tablo) | Audit modülü |
| `rpt` | Rapor snapshot (3 tablo) | Sadece ETL |
| `dof` | DÖF süreci (5 tablo) | DOF modülü + pipeline |
| `ai` | AI analiz (8 tablo) | AiWorker + AI ekranı |
| `log` | Çalıştırma logları (3 tablo) | ETL/job |
| `etl` | ETL staging (6 tablo) | Sadece ETL |

**Kural:** Bir modül kendi şeması dışına doğrudan yazmaz; ihtiyaç varsa hedef şemanın SP'sini çağırır.

---

## 6. Snapshot Disiplini (rpt)

*   **Günde bir snapshot:** Aynı gün/mekan/ürün/periyot için yeni kayıt eskisini **değiştirir** (insert değil replace).
*   `rpt.DailyProductRisk` PK'sı `PeriodCode` içerir — periyot bazlı ayrım korunur.
*   `SnapshotDay` **PERSISTED computed** kolondur (`SnapshotDate` bağımlı). Rename edilemez — DROP + ADD gerekir.
*   Stok miktarları `decimal(18,3)` — **float asla**.
*   `ehAltDepo = 0` kuralı (P0): sıfır dışı değer alarm üretir, sessizce filtrelenmez.

---

## 7. AI Katmanı — Kademeli Maliyet

```
İstek → LM Rules (deterministik, ücretsiz, hızlı)
      → Semantic Memory (Ollama mxbai-embed-large, cosine > 0.85)
      → LLM (Gemini → Claude → Ollama sırasıyla, sadece gerekirse)
      → ai.AnalysisQueue / ai.LlmResults
```

*   **Kural:** Bir üst katmana ancak alt katman çözemezse çıkılır. LLM son çare — her çağrı para ve gecikme.
*   Provider sırası ve enable/disable `AiWorkerOptions` üzerinden; kapalı provider **atlanır**, hata fırlatmaz.
*   Skill tanımları `ai.Skills` / `SkillRegistry` üzerinden; prompt template kod içine gömülmez.
*   Detay: `.claude/rules/ai-layer.md`.

---

## 8. Klasör Organizasyonu

```
src/BkmArgus.Web/
  Features/<Modül>/     Razor Pages (Index/Create/Edit/Detail...)
  Features/Shared/      _Layout, ortak partial
  Data/SqlDb.cs         tek veri erişim noktası
  Services/             AuthService, NotificationService, ExcelExportService
  Security/             Roles, Policies
src/BkmArgus.AiWorker/
  Jobs/                 zamanlanmış AI işleri (BaseAiJob türevleri)
  Skills/               SkillRegistry, SkillExecutor, SkillDefinition
sql/NN_<konu>.sql       numaralı, idempotent migration zinciri
```

*   Yeni ekran = footprint-ladder **son basamak**. Önce mevcut sayfaya sekme/bölüm eklenebilir mi diye sor.

---

## 9. Magic String Yasağı

Durum/tip kodları kod içinde çıplak string olarak yazılmaz. Sabit sınıfı kullanılır:

| Alan | Sabit |
|---|---|
| Kullanıcı rolü | `BkmArgus.Web.Security.Roles` |
| DÖF durumu | `BkmArgus.Web.Domain.DofStatus` |
| Risk tipi | `BkmArgus.Web.Domain.RiskType` |
| AI kuyruk durumu | `BkmArgus.Web.Domain.AiStatus` |

Yeni bir durum kümesi doğarsa önce sabit sınıfı, sonra kullanım.

---

## İlişkili

- `.claude/rules/sql-conventions.md` — SP/tablo standartları
- `.claude/rules/ai-layer.md` — AI worker disiplini
- `.claude/rules/etl-discipline.md` — ETL/snapshot kuralları
- `.claude/rules/security-principles.md` — RBAC, sır yönetimi
- `.claude/rules/footprint-ladder.md` — yeni yüzey en dar basamakta
