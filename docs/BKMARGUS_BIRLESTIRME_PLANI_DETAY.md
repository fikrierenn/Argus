# BkmArgus — İki Kaynağın Birleştirilmesi (Detaylı Plan)

**Belge sürümü:** 1.2  
**Tarih:** 29.03.2026  
**Kapsam:** `D:\Dev\icdenetim` (saha denetimi / eski tam uygulama), `D:\Dev\RiskAnaliz` (ERP risk analizi hattı), `D:\Dev\BkmArgus` (hedef birleşik repo)

---

## 1. Yönetici özeti

### 1.1 Problem tanımı

İki ayrı yazılım hattı uzun süredir paralel yaşadı:

| Kaynak | İş değeri | Teknoloji özeti |
|--------|-----------|-----------------|
| **icdenetim** | Mağaza/kafe saha denetimi, checklist, fotoğraf, DOF/aksiyon, rapor | Razor Pages, repository katmanı, cookie auth, `dbo.*` tablolar, AI orchestrator (arşiv kodu) |
| **RiskAnaliz** | ERP’ten türeyen stok/evrak riski, ETL, günlük özet, AI kuyruğu | `BkmDenetim.Web` + `BkmDenetim.AiWorker`, şemalı SQL (`ref`, `rpt`, `ai`…), SP-first |

**Hedef:** Tek ürün **BkmArgus** — tek veritabanı **BKMDenetim**, tek web uygulaması, tek worker, tutarlı yapılandırma ve güvenlik.

### 1.2 Mevcut stratejik kararlar (repodan)

- **SP-first:** Tüm veri erişimi stored procedure üzerinden; parametre adları Türkçe.
- **Şema haritası:** `src`, `ref`, `rpt`, `dof`, `ai`, `log`, `etl`, `audit`.
- **Saha denetimi:** `audit.*` şeması + `21_sps_audit.sql`, `22_sps_audit_dashboard.sql`, `20_migration_audit.sql` ile İngilizce tablo/kolon adları.
- **Eski icdenetim UI:** `_archive/icdenetim` altında tutuluyor; **canlı BkmArgus.Web** şu an risk/dashboard ağırlıklı ve denetim modülü için SP katmanı hazır, UI tam taşınmış değil.

### 1.3 Bu belgenin amacı

Yüzeysel “birleştir” listesi yerine:

- Üç kaynağın **envanteri** (dosya, proje, bağımlılık).
- **Boşluk analizi** (ne eksik, ne çift).
- **Sıralı uygulama fazları**, her fazda **tanımı tamamlanan iş (DoD)**.
- **Risk kaydı** ve **geri alma** prosedürü.
- **Test ve operasyon** gereksinimleri.

### 1.4 Veritabanı dil ve isimlendirme kuralları (Türkçe mi, İngilizce mi?)

Bu kurallar **birleştirme planına özel değil**; proje genelinde şöyle sabitlendi:

| Katman | Dil / stil | Açıklama |
|--------|------------|----------|
| **Tablo, kolon, view, index, constraint** | **İngilizce** | Hedef standart: PascalCase tablo adları, anlamlı İngilizce kolon adları (`LocationId`, `RiskScore`, `CreatedAt`, …). Mevcut **Türkçe** tablo/kolon adları (`ref.RiskParam`, `MekanId`, …) **geçici teknik borç** kabul edilir; uzun vadede İngilizce’ye dönüştürülür. |
| **Şema adları** | Küçük harf, kısa | `ref`, `rpt`, `dof`, `ai`, `audit`, … |
| **Stored procedure adları** | `schema.sp_Entity_Action` | Örn. `audit.sp_Audit_List`, `rpt.sp_Dashboard_Kpi`. |
| **SP parametreleri ve değişkenler** | **Türkçe** | Proje kuralı: `@MekanId`, `@BaslangicTarihi` vb. — uygulama ve SQL tarafında tutarlılık için. |
| **Yeni geliştirme** | DB nesnesi İngilizce | Yeni tablo/kolon eklerken Türkçe ad **kullanılmamalı**; eski Türkçe nesneler rename veya yeni nesne ile değiştirilir. |

**Tam kurallar listesi, kolon eşleme tabloları ve rename sırası** şu belgede:  
`BKMARGUS_PLATFORM_GECIS_PLANI_V2.md` — **Bölüm 2 (İsimlendirme standardı)** ve ilgili fazlar.

Kısa özet ayrıca: `docs/AI_Enhancement_Implementation_Summary.md` içinde “Veritabanı: tablo/kolon İngilizce” ifadesi geçer.

**Özet cümle:** Veritabanı **şema nesneleri (tablo/kolon/view)** hedef olarak **İngilizce**; **SP parametreleri** kurallarımız gereği **Türkçe**. İkisi çelişki değil — farklı katmanlar.

---

## 2. Kaynak sistem envanteri

### 2.1 Dizin kökleri ve rol

| Kök | Rol | Git / kanonik |
|-----|-----|----------------|
| `D:\Dev\BkmArgus` | **Hedef birleşik repo** | Birleştirme sonrası tek yazma kaynağı |
| `D:\Dev\RiskAnaliz` | Risk hattının “BkmDenetim” adlı kopyası | BkmArgus ile aynı aile; **diff kaynağı** |
| `D:\Dev\icdenetim` | Eski kök; içinde iç içe `BkmArgus` klasörü olabilir | **Çiftleşme riski** — tek canonical `D:\Dev\BkmArgus` |

**Kural:** Yeni geliştirme yalnızca `D:\Dev\BkmArgus`. Diğer iki kök yalnızca karşılaştırma veya salt okunur arşiv.

### 2.2 Çözüm (solution) karşılaştırması

#### RiskAnaliz.sln (`D:\Dev\RiskAnaliz\RiskAnaliz.sln`)

| Proje GUID | Proje adı | Yol |
|------------|-----------|-----|
| 99A6BB77-… | BkmDenetim.Web | `src\BkmDenetim.Web\BkmDenetim.Web.csproj` |
| A4B0E9E7-… | BkmDenetim.AiWorker | `src\BkmDenetim.AiWorker\BkmDenetim.AiWorker.csproj` |
| 5116BCE2-… | SchemaManagement.Library | `src\SchemaManagement.Library\SchemaManagement.Library.csproj` |

**Not:** `BkmDenetim.McpServer`, `BkmDenetim.Installer` bu solution’da **yok**; `D:\Dev\RiskAnaliz\src\` altında ayrı projeler olarak duruyor.

#### BkmArgus.sln (`D:\Dev\BkmArgus\BkmArgus.sln`)

| Proje | Durum |
|-------|--------|
| BkmArgus.Web | RiskAnaliz Web ile aynı “Features” yapısı, namespace `BkmArgus.Web` |
| BkmArgus.AiWorker | RiskAnaliz AiWorker ile dosya listesi aynı aile |
| SchemaManagement.Library | Aynı |
| BkmArgus.McpServer | **Solution dışı** (klasörde var) |
| BkmArgus.Installer | **Solution dışı** (klasörde var) |

**Aksiyon:** Solution’a McpServer + Installer eklenmeli veya “bilinçli olarak dışarıda” kararı yazılı dokümante edilmeli.

### 2.3 Web uygulaması — sayfa/envanter

#### BkmArgus.Web (`Features/` kökü)

| Özellik klasörü | Sayfalar | PageModel |
|-----------------|----------|-----------|
| (kök) | `Index` | `Index.cshtml.cs` |
| Dashboard | `Index` | KPI, trend, risk, DOF, sağlık |
| Risk | `Index` | Risk listesi |
| Urun | `Index` | Ürün detay |
| Dof | `Index` | DOF listesi |
| Ai | `Index`, `Detay` | AI istekleri |
| Ref | `Index` | Referans özet |
| Ayarlar | `Index` | Ayarlar |
| Yonetim | `Index` | Yönetim |
| Shared | `_Layout` | Ortak şablon |
| — | `Error` | Hata |

**Toplam (üretim sayfaları):** ~12 Razor çifti (Index ağırlıklı).

#### RiskAnaliz — BkmDenetim.Web

Dosya yapısı **BkmArgus.Web ile aynı ağaç** (Features/Dashboard, Risk, …). Birleştirme açısından: **RiskAnaliz Web = BkmArgus Web’in `BkmDenetim` adlı ikizi**; düzenli `diff` ile sapma tespiti yeterli.

#### Arşiv — `_archive/icdenetim` (eski tam denetim uygulaması)

**Pages (Razor):**

| Rota alanı | Dosyalar | Birleştirme notu |
|------------|----------|------------------|
| Account | Login, Logout, Setup | Cookie auth; BkmArgus’ta yeniden kurulacak |
| Denetimler | Index, Create, Edit, Delete, Detail, ResultPhotos | **Çekirdek iş** — `audit.sp_*` ile yeniden yazılmalı |
| Maddeler | Index, Create, Edit, Import | Denetim maddeleri / Excel import |
| Beceriler | Index, Create, Edit | Skills |
| Aksiyon | Index, Create, Detail | Düzeltici aksiyonlar |
| Raporlar | Index, Karne, KarneDetay | Raporlama |
| Dashboard | Index | Metrikler (eski) |
| Shared | _Layout, _LayoutMinimal, _SidebarNav, _ValidationScriptsPartial | Yeni layout ile birleştirme |

**Servis katmanı (arşiv):**

| Servis / arayüz | Görev |
|-----------------|--------|
| `IAuditProcessingService` / `AuditProcessingService` | Finalize → tekrar → sistemik → DOF pipeline |
| `IDataIntelligenceService` / `DataIntelligenceService` | Veri istihbaratı |
| `IInsightService` / `InsightService` | Öngörü |
| `IFindingsService` / `FindingsService` | Bulgu |
| `IDashboardService` / `DashboardService` | Pano |
| `IAIOrchestratorService` / `AIOrchestratorService` | AI karar |
| `AIContextBuilder` | Prompt bağlamı |
| `AiBackgroundWorker` | Arka plan AI |
| `IEventBus` / `InMemoryEventBus` | Olay yayını |
| `IClaudeApiService` / `ClaudeApiService` | Claude API |
| `IRiskPredictionService` / `RiskPredictionService` | Risk tahmini |
| `IReportGeneratorService` / `ReportGeneratorService` | Rapor üretimi |
| Repository: `ISkillRepository`, `ICorrectiveActionRepository` | Veri erişimi (doğrudan SQL/ADO) |

**Kritik fark:** Arşiv uygulama **repository + doğrudan DB** kullanıyor; BkmArgus standartları **SP + Dapper** istiyor. Birleştirme = **iş kurallarını koruyup veri erişimini SP’ye taşımak**.

### 2.4 Worker envanteri

**BkmArgus.AiWorker** ve **RiskAnaliz BkmDenetim.AiWorker** — aynı dosya seti (Program, AiWorkerService, Db, EmbeddingService, SemanticMemoryService, LlmService, LmRules, Models, Jobs: AiJobScheduler, RiskPredictionJob, AgentPipelineMonitorJob, BaseAiJob, test yardımcıları).

**Birleştirme:** İki klasör arasında periyodik `diff`; tek kopya `BkmArgus.AiWorker`. RiskAnaliz’de ek commit varsa **cherry-pick veya manuel port**.

### 2.5 SQL envanteri — BkmArgus `sql/`

#### 2.5.1 Çalıştırma sırası (önerilen)

| Sıra | Dosya | İçerik |
|------|--------|--------|
| 1 | `00_create_db.sql` | Veritabanı oluşturma (ortam uygunsa) |
| 2 | `01_schemas.sql` | `src`, `ref`, `rpt`, `dof`, `ai`, `log`, `etl` (**not:** `audit` burada yok) |
| 3 | `02_tables.sql` | ref, rpt, dof, ai, log tabloları |
| 4 | `03_views_src.sql` | ERP soyutlama view’leri |
| 5 | `04_sps_etl.sql` | ETL + log çalıştırıcı SP’ler |
| 6 | `05_views_reports.sql` | Rapor view’leri |
| 7 | `06_healthcheck_sp.sql` | `log.sp_SaglikKontrol_Calistir` |
| 8 | `07_seed.sql` | Seed veriler |
| 9 | `08_sps_ref.sql` | Referans SP’ler |
| 10 | `09_sps_yonetim.sql` | Yönetim / personel entegrasyonu |
| 11 | `10_sps_dashboard.sql` | Genel bakış KPI |
| 12 | `11_sps_dashboard.sql` | Dashboard KPI, risk trend, DOF, ref özet |
| 13 | `12_sps_risk.sql` | Risk listeleri |
| 14 | `13_sps_urun.sql` | Ürün detay / hareket |
| 15 | `14_sps_ai.sql` | AI kuyruk ve sonuç SP’leri |
| 16 | `15_ai_enhancement_v2.sql` | AI v2, anomaly, prediction, health |
| 17 | `20_migration_audit.sql` | **audit şeması + tablolar** |
| 18 | `21_sps_audit.sql` | Saha denetim CRUD + analiz pipeline SP’leri |
| 19 | `22_sps_audit_dashboard.sql` | Saha denetim dashboard + rapor SP’leri |
| 20 | `99_smoke_tests.sql` | Doğrulama |

**Bağımlılık notu:** `01_schemas` içinde `audit` yok; `20_migration_audit.sql` audit şemasını oluşturur. Eski ortamda `dbo.Users` vb. varsa migration script’indeki **taşıma adımları** sırayla uygulanmalı.

#### 2.5.2 Stored procedure envanteri (özet liste)

**log / ref / yönetim**

- `log.sp_PersonelEntegrasyon_Ozet`, `log.sp_PersonelEntegrasyon_Log_Liste`
- `ref.sp_KullaniciPersonel_Liste`, `ref.sp_KullaniciPersonel_Kapat`, `ref.sp_KullaniciPersonel_GunSonuKapat`
- `log.sp_SaglikKontrol_Calistir`

**ETL / rapor altyapı**

- `rpt.sp_StokBakiyeTarihGetir`, `log.sp_StokBakiyeGunluk_Calistir`, `log.sp_RiskUrunOzet_Calistir`, `log.sp_AylikKapanis_Calistir`
- `etl.sp_ErpStok_Extract`, `etl.sp_ErpSatis_Extract`, `etl.sp_ErpStokHareket_Extract`, `etl.sp_StagingToMain_Load`

**Dashboard / risk / ürün**

- `rpt.sp_GenelBakis_Kpi`, `rpt.sp_GenelBakis_Not`
- `rpt.sp_RiskMekan_Liste`, `rpt.sp_RiskListe`
- `rpt.sp_UrunDetay_Getir`, `rpt.sp_UrunRiskFlag_Liste`, `rpt.sp_UrunHareket_Liste`
- `rpt.sp_Dashboard_Kpi`, `rpt.sp_Dashboard_RiskTrend`, `rpt.sp_Dashboard_TopRisk`
- `dof.sp_Dashboard_Dof_Liste`, `ref.sp_Dashboard_Ref_Ozet`

**AI**

- `ai.sp_Ai_*` (İstek oluştur/al/güncelle, Risk özet, vektör, LLM sonuç, reset)
- `ai.sp_AiMultiModal_Upsert`, `ai.sp_AiMemory_LayerMaintenance`, `ai.sp_AiAgent_ExecutePipeline`, `ai.sp_AiFeedback_Process`, `ai.sp_AiModel_UpdatePerformance`, `ai.sp_AiAnomaly_Detect`, `ai.sp_AiRisk_Predict`, `ai.sp_AiMigration_V1toV2`, `ai.sp_AiSystem_HealthCheck`
- `ai.vw_AiGecmisVektorler_Legacy`

**Saha denetim (audit)**

- CRUD: `audit.sp_Audit_List`, `Get`, `Insert`, `Update`, `Finalize`, `Delete`
- Maddeler: `audit.sp_Item_*`
- Sonuçlar: `audit.sp_Result_*`
- Analiz: `audit.sp_Analysis_DetectRepeats`, `DetectSystemic`, `DofEffectiveness`, `FullPipeline`
- Rapor/dashboard: `audit.sp_Report_*`, `audit.sp_Dashboard_*`

**View’ler**

- `src.vw_*` (stok hareket, evrak, mekan, ürün…)
- `rpt.vw_RiskUrunOzet_*`

---

## 3. Boşluk analizi (gap analysis)

### 3.1 Web: Risk hattı vs arşiv denetim hattı

| Alan | BkmArgus.Web (güncel) | _archive/icdenetim |
|------|------------------------|---------------------|
| ERP risk panoları | Var | Eski dashboard (farklı sorgular) |
| Saha denetim CRUD UI | **Yok** (SP hazır) | Tam (Denetimler, Maddeler, …) |
| Kimlik | Yok / açık | Cookie + BCrypt, Authorize |
| Veri erişimi | SqlDb → SP | Repository, migration, seed |
| AI pipeline (denetim) | AiWorker + DB | AIOrchestrator + in-process worker |

**Sonuç:** Birleştirmenin **en büyük işi** = arşivdeki denetim sayfalarını **BkmArgus.Web** altına taşımak ve **tüm okuma/yazmayı** `audit.sp_*` üzerinden yapmak.

### 3.2 Veri modeli: dbo vs audit

Geçiş planı ve `20_migration_audit.sql` hedefi: denetim tablolarının **`audit.*`** altında İngilizce adlarla yaşaması. Eski icdenetim **`dbo.Audits`** vb. kullanıyorsa:

- Ya **tek seferlik migration** (veri kopyalama + FK),
- Ya da **uyumluluk view’ı** (`dbo.Audits` → `audit.Audits`) geçici süre.

### 3.3 Yapılandırma tutarsızlığı

| Konum | Anahtar | Kod beklentisi |
|-------|---------|----------------|
| `appsettings.json` | `ConnectionStrings:BkmArgus` | Birçok yerde `GetConnectionString("BkmDenetim")` |

**Zorunlu düzeltme:** Tek anahtar adı veya kodda fallback (`BkmArgus` yoksa `BkmDenetim`).

### 3.4 Güvenlik

- Repoda düz metin şifre — **birleştirme tamamlanmadan üretime çıkmamalı**.
- McpServer `AllowAnyOrigin` — üretimde kısıtlanmalı.

### 3.5 Ortak kavramlar: ayrı ayrı duran tabloları tek “pota”da eritme

İki uygulama aynı gerçek dünya nesnelerini farklı tablolarda tutmuş olabilir. Birleşik platformda **her iş kavramı için tek doğruluk kaynağı (single source of truth)** olmalı; aksi halde rapor, yetki ve FK’ler çakışır.

#### 3.5.1 Tipik çakışma alanları (envanter)

| Kavram | RiskAnaliz / şemalı hat | icdenetim (eski dbo / arşiv) | Hedef “pota” (tekilleştirme) |
|--------|-------------------------|------------------------------|-------------------------------|
| **Kullanıcı / giriş** | `ref.Kullanici` (personel bağlantılı) | `dbo.Users` veya ayrı kullanıcı tablosu | **Tek kullanıcı master:** geçiş planında `ref.Users` (rename sonrası) veya `audit.Users` ile **birleştirme**; şifre hash ve RBAC tek yerde. `BKMARGUS_PLATFORM_GECIS_PLANI_V2.md` Faz 3: `audit.Users` genişletme + `ref.Kullanici` ile birleşim. |
| **Personel** | `ref.Personel` | Aynı veya kopya | **Yalnızca `ref.Personel`**; uygulama personel listesi buradan. |
| **Mekan / lokasyon** | ERP `src.vw_Mekan`, `ref.AyarMekanKapsam` | Denetimde metin veya ayrı ID | **ERP `MekanId`** referansı; `audit.Audits.LocationId` ile bağlanır (`20_migration_audit.sql` zemin). İsim alanları snapshot olabilir; master ID tek. |
| **Saha denetimi çekirdeği** | `audit.Audits`, `AuditItems`, `AuditResults`, … | `dbo.Audits`, … | **`audit.*` tek doğru**; `dbo.*` → `ALTER SCHEMA audit TRANSFER` veya veri migrate + eski tablo kaldırma (plan Prompt 3). |
| **DÖF / aksiyon** | `dof.DofKayit`, `DofAksiyon`, … | `dbo.CorrectiveActions` vb. | **`dof.*` şeması**; bulgu–aksiyon tek zincir; dbo kopyası kaldırılır veya view ile geçiş. |
| **AI denetim analizi** | `ai.*` kuyruk ve sonuçlar | `dbo.AiAnalyses` (varsa) | **`ai.*` tek**; eski dbo kayıtları `ai` tablolarına veya arşiv SP’ye taşınır; çift yazım kapatılır. |
| **Kaynak sistem / nesne** | `ref.KaynakSistem`, `ref.KaynakNesne` | — | Zaten köprü; **tek**; `20_migration_audit.sql` seed’i ile uyumlu. |

#### 3.5.2 Eritme süreci (her çift tablo için)

1. **Envanter:** `SELECT` ile satır sayıları, örnek çakışan anahtarlar (ör. aynı e-posta iki tabloda).
2. **Kanonik seçim:** Hangi tablo “master” kalacak (genelde şemalı yeni: `audit.*`, `ref.*`, `dof.*`, `ai.*`).
3. **Eşleme:** Eski `UserId` → yeni `UserId` mapping tablosu (geçici `merge.UserIdMap`) veya tek seferlik `UPDATE` ile FK uyumu.
4. **Veri taşıma:** `INSERT INTO ... SELECT` (dönüşüm kolonları ile), sonra uygulama kodu yeni tabloya geçirilir.
5. **Çift yazımı kapatma:** Uygulama ve job’lar yalnızca kanonik tabloyu günceller.
6. **Temizlik:** Eski tablo `DROP` veya salt okunur arşiv şeması; mümkünse `DROP` (veya yedek DB’de saklama).

#### 3.5.3 Öncelik sırası (öneri)

| Öncelik | Çift | Neden önce |
|--------|------|------------|
| 1 | Kullanıcı (`ref` / `audit` / `dbo`) | Tüm FK’ler ve auth buna bağlı |
| 2 | Denetim ana tabloları (`dbo` → `audit`) | İş akışının omurgası |
| 3 | DOF / aksiyon (`dbo` ↔ `dof`) | Raporlama ve kapanış |
| 4 | AI satırı (`dbo` ↔ `ai`) | Worker ve rapor tutarlılığı |

#### 3.5.4 Dokümantasyon bağlantısı

- Şema hedefi ve `dbo` → `audit` taşıma: `BKMARGUS_PLATFORM_GECIS_PLANI_V2.md` (bölüm 3.2, Prompt 3).
- `ref.Kullanici` / `audit.Users` birleşimi: aynı belge Faz 3 ve tablo haritası.

---

## 4. Birleştirme fazları (detaylı)

### Faz 0 — Repo ve yapılandırma temeli

**Süre (tahmini):** 1–3 gün (1 FTE)

| # | Görev | Açıklama | Çıktı / DoD |
|---|--------|-----------|-------------|
| 0.1 | Canonical kök | `D:\Dev\BkmArgus` tek yazma kaynağı; icdenetim içindeki iç içe kopyanın güncellenmemesi | Ekip içi duyuru + README |
| 0.2 | Bağlantı dizesi | `BKM_DENETIM_CONN` veya tek `ConnectionStrings` adı; tüm projelerde aynı | Web, Worker, Installer, McpServer derlenir ve DB’ye bağlanır |
| 0.3 | Sırları repodan çıkarma | `appsettings.Development.json` + User Secrets / env; `sa` kaldırılması veya düşük yetkili login | Gizli bilgi taraması temiz |
| 0.4 | Solution bütünlüğü | McpServer + Installer `.sln` içine veya dokümante “hariç” | Tek `dotnet build` stratejisi net |
| 0.5 | `Directory.Build.props` (isteğe bağlı) | Ortak `TargetFramework`, `Nullable`, paket sürümleri | Sürüm sapması azalır |

**Çıkış kriteri:** Yeni klon + env ile Web ve Worker ayağa kalkar; bağlantı hatası yok.

---

### Faz 1 — Veritabanı tekilleştirme ve sıralı deploy

**Süre:** 3–14 gün (rename dahil değilse kısa; `sp_rename` programı dahilse uzun)

#### 1.1 Ortam hazırlığı

- Üretim öncesi: **tam yedek** BKMDenetim.
- Staging: üretim verisinin anonimleştirilmiş kopyası veya son yedek.

#### 1.2 Script uygulama runbook’u

1. Blokaj: bakım penceresi veya salt okuma modu (mümkünse).
2. Sıra: Bölüm **2.5.1** dosya sırası.
3. Her dosya sonrası: `99_smoke_tests.sql` veya kritik SP’lerin `EXEC` ile smoke.
4. Log: hangi script, kim, hangi sunucu, süre, hata.

#### 1.3 İsim standardizasyonu (opsiyonel alt-proje)

`BKMARGUS_PLATFORM_GECIS_PLANI_V2.md` içindeki Türkçe → İngilizce tablo/kolon rename **ayrı proje** olarak planlanmalı:

- Önce uyumluluk view’ları,
- Sonra `sp_rename` dalgaları (ref → dof → ai → rpt → log),
- Tüm SP/view güncellemeleri,
- Uzun regresyon testi.

**Öneri:** Çekirdek birleştirme **rename olmadan** tamamlansın; rename sonraki çeyrekte.

**DoD:** Tek DB şeması; ETL ve AI worker kesintisiz; smoke yeşil.

---

### Faz 2 — Web birleştirme (en yoğun faz)

**Süre:** 2–6 hafta (kapsama göre)

#### 2.1 Mimari hedef

- **Tek Razor Pages** uygulaması: `BkmArgus.Web`.
- **Tek veri kapısı:** `SqlDb` (veya ince bir servis katmanı) → yalnızca SP.
- **Özellik klasörleri:** Mevcut `Features/` yapısı korunur; denetim için `Features/Denetim/`, `Features/Maddeler/` vb. eklenir (veya `Features/Audit/` altında gruplanır).

#### 2.2 Sayfa taşıma matrisi (arşiv → hedef)

| Eski rota (özet) | Hedef | Veri kaynağı (hedef) |
|------------------|-------|----------------------|
| `/Denetimler/Index` | `Features/Denetim/Index` | `audit.sp_Audit_List` |
| `/Denetimler/Create` | `Denetim/Create` | `audit.sp_Audit_Insert` + ref verileri |
| `/Denetimler/Edit` | `Denetim/Edit` | `audit.sp_Audit_Get`, `Update` |
| `/Denetimler/Detail` | `Denetim/Detail` | `Get`, sonuçlar `sp_Result_*` |
| `/Denetimler/ResultPhotos` | `Denetim/ResultPhotos` | Foto SP + dosya depolama politikası |
| `/Maddeler/*` | `Maddeler/*` | `audit.sp_Item_*` |
| `/Beceriler/*` | `Beceriler/*` | `audit.Skills` / SP (gerekirse yeni SP) |
| `/Aksiyon/*` | `Aksiyon/*` | dof + `ref` ile uyum |
| `/Account/Login` | `Account/Login` | `ref.sp_Kullanici_*` veya `audit.Users` politikası |
| `/Raporlar/*` | `Raporlar/*` veya `audit` rapor SP’leri | `audit.sp_Report_*` |

Her sayfa için **PageModel** içinde:

1. Handler’da parametreli SP çağrısı.
2. Türkçe parametre adları.
3. Hata: `Try`-`Catch` + kullanıcıya güvenli mesaj.

#### 2.3 Servis katmanı stratejisi

Arşivdeki **AuditProcessingService** mantığı:

- SQL tarafında karşılığı: `audit.sp_Analysis_FullPipeline` ve alt SP’ler.
- Uygulama tarafı: “Kesinleştir” butonu → `EXEC audit.sp_Audit_Finalize` + `EXEC audit.sp_Analysis_FullPipeline @DenetimId` (parametre adları SP ile uyumlu olmalı — mevcut SP’de `@AuditId` kullanımını kontrol edin).

**AIOrchestrator / EventBus:** İlk aşamada **SQL pipeline yeterliyse** yeniden yazmayın; gerekiyorsa ikinci dalgada in-process orchestrator eklenebilir.

#### 2.4 Layout ve navigasyon

- `_Layout.cshtml` içine **Risk** ve **Saha denetimi** menü grupları.
- Arşivdeki `_SidebarNav` içerikleri yeni tasarıma uyarlanır.

#### 2.5 RiskAnaliz Web ile senkron

Periyodik:

```text
diff -r D:\Dev\RiskAnaliz\src\BkmDenetim.Web D:\Dev\BkmArgus\src\BkmArgus.Web
```

Sapma varsa BkmArgus’a port veya bilinçli olarak “RiskAnaliz’deki deneme geri alındı” notu.

**DoD:** Denetim kullanıcı akışı uçtan uca; risk panoları bozulmadı; tek auth (en azından cookie).

---

### Faz 3 — Kimlik, yetki, çoklu rol

**Süre:** 1–3 hafta

| # | Görev |
|---|--------|
| 3.1 | Cookie veya kurumsal SSO kararı |
| 3.2 | `ref.Kullanici` / `audit.Users` tekilleştirme (plan dokümanındaki gibi) |
| 3.3 | Sayfa/klasör bazlı `[Authorize]` veya convention |
| 3.4 | Denetçi / okuyucu / admin rolleri |

**DoD:** Anonim erişim kapatıldı (veya sadece iç ağ + VPN ile sınırlı olduğu yazılı).

---

### Faz 4 — Worker ve arka plan işleri

| # | Görev |
|---|--------|
| 4.1 | Tek `BkmArgus.AiWorker` — RiskAnaliz diff’i sürdürülebilir şekilde birleştir |
| 4.2 | SQL Agent / zamanlanmış job: ETL sırası dokümante (`log.sp_RiskUrunOzet_Calistir` vb.) |
| 4.3 | Ollama/Gemini uçları için ortam değişkenleri ve sağlık kontrolü |

**DoD:** Worker tek instance veya bilinçli çoklu instance (kuyruk kilidi zaten var).

---

### Faz 5 — Installer, MCP, operasyon

| # | Görev |
|---|--------|
| 5.1 | Installer’daki `sql` klasörü = `BkmArgus/sql` tek kaynak (kopya build adımı) |
| 5.2 | McpServer: geliştirme dışı ortamda auth veya devre dışı |
| 5.3 | `/health` ASP.NET Health Checks (Web + isteğe bağlı Worker) |
| 5.4 | Serilog veya yapılandırılmış log |

---

### Faz 6 — Test, performans, kabul

| Tür | İçerik |
|------|--------|
| SQL | `99_smoke_tests.sql` + audit SP’ler için ek INSERT/SELECT testleri |
| Entegrasyon | Denetim oluştur → sonuç gir → finalize → pipeline |
| Yük | Dashboard ve risk listesi için temel sorgu süreleri |
| Güvenlik | Bağlantı sırları, SQL injection (parametreli SP), dosya yükleme (sadece resim, boyut) |

---

## 5. Risk kaydı ve azaltma

| ID | Risk | Olasılık | Etki | Azaltma |
|----|------|-----------|------|---------|
| R1 | İki kökte paralel geliştirme | Yüksek | Yüksek | Tek canonical repo |
| R2 | Rename dalgası regresyonu | Orta | Çok yüksek | Rename’i ayır; uyumluluk view |
| R3 | Arşiv mantığının kötü portu | Orta | Yüksek | Önce SP’leri doğrula, sonra UI |
| R4 | Auth eksikliği | Yüksek | Yüksek | Faz 3 önceliği |
| R5 | ETL sırası bozulması | Düşük | Yüksek | Runbook + staging |

---

## 6. Geri alma (rollback)

1. **DB:** Script öncesi alınan yedekten restore; veya migration’ın tersini yazan script (mümkünse).
2. **Uygulama:** Önceki sürüm artefaktı (DLL) veya önceki git tag deploy.
3. **Worker:** Durdur → eski sürüm → kuyruk durumunu kontrol (`ai.AiAnalizIstegi` durumları).

---

## 7. Süre özeti (teknik kişi-ay yaklaşık)

| Faz | Süre |
|-----|------|
| 0 | 0.2–0.5 kişi-ay |
| 1 | 0.2–0.8 kişi-ay |
| 2 | 0.5–1.5 kişi-ay |
| 3 | 0.2–0.6 kişi-ay |
| 4–6 | 0.3–0.8 kişi-ay |

**Çekirdek birleşme (0–2):** ~1–2.5 kişi-ay; rename ve ileri özellikler ayrıca.

---

## 8. İlgili belgeler

- `BKMARGUS_PLATFORM_GECIS_PLANI_V2.md` — isimlendirme, hedef şema, rename prompt’ları
- `CLAUDE.md` / `AGENTS.md` — proje kuralları
- `sql/99_smoke_tests.sql` — doğrulama

---

## 9. Ek: Arşiv `Program.cs` bağımlılık listesi (referans)

Arşiv uygulama şu servisleri kayıt eder (yeniden kurarken eşdeğer veya SP ile değiştir):

- `IDbConnectionFactory` → SqlConnectionFactory  
- `AddAiServices()`  
- `IDataIntelligenceService`, `IInsightService`, `IAuditProcessingService`  
- `ISkillRepository`, `ICorrectiveActionRepository`, `IFindingsService`  
- `IAIOrchestratorService`, `AIContextBuilder`  
- `IEventBus` (InMemory)  
- `AiBackgroundWorker` (hosted)  
- Cookie Authentication  

**Hedef BkmArgus:** Denetim için öncelik **SP + gerekirse tek `AuditOrchestrator` sınıfı**; gereksiz çoğaltmadan kaçının.

---

## 10. Ek: SQL dosyası tutarlılığı (kritik)

Üç yerde SQL kopyası bulunabilir:

| Konum | Dosya sayısı (gözlemlenen) | Not |
|-------|------------------------------|-----|
| `BkmArgus/sql/` | 20 dosya (`00`–`22`, `99`) | **Ana kaynak**; `20`, `21`, `22` saha denetimi |
| `BkmArgus/src/BkmArgus.Installer/sql/` | 17 dosya | **`20_migration_audit.sql`, `21_sps_audit.sql`, `22_sps_audit_dashboard.sql` eksik** — installer ile tam DB kurulumu saha denetimi SP’lerini içermeyebilir |
| `RiskAnaliz/sql/` ve `RiskAnaliz/src/BkmDenetim.Installer/sql/` | Risk hattı ile uyumlu | Diff için karşılaştır |

**Aksiyon:** Installer’a `20`, `21`, `22` eklenmeli veya kurulum runbook’unda “Bu üç dosya manuel uygulanır” denmeli. Aksi halde yeni ortamda **audit modülü eksik** kalır.

---

## 11. Ek: Haftalık çalışma örneği (çekirdek birleşme)

| Hafta | Odak | Somut çıktı |
|-------|------|-------------|
| 1 | Faz 0 + Faz 1 (staging) | Bağlantı düzeltmesi, yedek, script sırası doğrulandı |
| 2–3 | Faz 2 başlangıç | Layout + Account + Denetimler/Index, List SP bağlandı |
| 4–5 | Faz 2 devam | Create/Edit/Detail, Item sayfaları, foto yükleme politikası |
| 6 | Faz 2 kapanış | Aksiyon, beceriler, raporlar (veya MVP’de ertelenenler işaretlendi) |
| 7 | Faz 3 | Auth tamam |
| 8 | Faz 4–6 | Worker hizalama, smoke, dokümantasyon |

*(Kaynak yoğunluğuna göre haftalar ölçeklenir.)*

---

## 12. Ek: AiWorker dosya eşlemesi (RiskAnaliz ↔ BkmArgus)

| RiskAnaliz (`BkmDenetim.AiWorker`) | BkmArgus (`BkmArgus.AiWorker`) | Not |
|-----------------------------------|----------------------------------|-----|
| `Program.cs` | `Program.cs` | Bağlantı ve `test-embedding` / `test-db` girişleri |
| `AiWorkerService.cs` | `AiWorkerService.cs` | Kuyruk + LLM döngüsü |
| `Db.cs` | `Db.cs` | Connection factory |
| `LmRules.cs` | `LmRules.cs` | Kural motoru |
| `LlmService.cs` | `LlmService.cs` | Sağlayıcılar |
| `EmbeddingService.cs` | `EmbeddingService.cs` | Ollama |
| `SemanticMemoryService.cs` | `SemanticMemoryService.cs` | Benzerlik |
| `AiWorkerOptions.cs` | `AiWorkerOptions.cs` | Yapılandırma |
| `Models.cs` | `Models.cs` | DTO’lar |
| `Jobs/*.cs` | `Jobs/*.cs` | Zamanlanmış işler |

**Süreç:** Her sprint başında `git diff` veya WinMerge ile iki klasör karşılaştırılır; fark varsa BkmArgus’a tek commit ile alınır.

---

*Bu belge, birleştirme sırasında güncellenmelidir: tamamlanan fazlar, tarih, sorumlu ve sapmalar.*
