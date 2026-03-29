# BkmArgus Platform — Birleştirme Geçiş Planı v2

**Tarih:** 29.03.2026  
**Hazırlayan:** Fikri Eren — Genel Müdür, BKM Kitap  
**Durum:** REVİZE v2 — Tablo Standardizasyonu + Mevcut Durum Güncellemesi

---

## 1. MEVCUT DURUM (29.03.2026 02:33 itibariyle)

### 1.1 Tamamlanan İşler ✅

| İş | Detay |
|----|-------|
| Proje rename | IcDenetim → BkmArgus (solution, csproj, namespace, CLAUDE.md) |
| Event-Driven mimari | AuditEvent (9 event tipi) + IEventBus + InMemoryEventBus |
| AI Orchestrator | AIOrchestratorService — event dinler, rules engine ile karar verir |
| AI Context Builder | AIContextBuilder — bulgu + skill + lokasyon geçmişi → zengin prompt |
| AI Background Worker | AiBackgroundWorker — 30sn polling, kuyruk-based AI işleme |
| AuditProcessingService | Event-driven pipeline (Finalize → Repeat → Systemic → DOF → Insight) |
| Compatibility Layer | Migration_Compatibility.sql — BkmArgus ↔ RiskAnaliz view köprüleri |
| dbup-sqlserver | Proje bağımlılığı eklendi |

### 1.2 BKMDenetim DB'de Mevcut Tablolar

**İcDenetim/BkmArgus tarafı (dbo, İngilizce ✅):**

| Tablo | Durum |
|-------|-------|
| dbo.Users | ✅ İngilizce |
| dbo.Audits | ✅ İngilizce |
| dbo.AuditItems | ✅ İngilizce |
| dbo.AuditResults | ✅ İngilizce |
| dbo.AuditResultPhotos | ✅ İngilizce |
| dbo.CorrectiveActions | ✅ İngilizce |
| dbo.Skills | ✅ İngilizce |
| dbo.SkillVersions | ✅ İngilizce |
| dbo.AiAnalyses | ✅ İngilizce |
| dbo.AuditLog | ✅ İngilizce |

**RiskAnaliz tarafı (şemalı, Türkçe ❌):**

| Mevcut (Türkçe) | Hedef (İngilizce) | Şema |
|------------------|--------------------|------|
| ref.AyarMekanKapsam | ref.LocationSettings | ref |
| ref.IrsTipGrupMap | ref.TransactionTypeMap | ref |
| ref.RiskParam | ref.RiskParameters | ref |
| ref.RiskSkorAgirlik | ref.RiskScoreWeights | ref |
| ref.KaynakSistem | ref.SourceSystems | ref |
| ref.KaynakNesne | ref.SourceObjects | ref |
| ref.Personel | ref.Personnel | ref |
| ref.Kullanici | ref.Users | ref |
| ref.KullaniciPersonel | ref.UserPersonnelMap | ref |
| rpt.RiskUrunOzet_Gunluk | rpt.DailyProductRisk | rpt |
| rpt.RiskUrunOzet_Aylik | rpt.MonthlyProductRisk | rpt |
| rpt.StokBakiyeGunluk | rpt.DailyStockBalance | rpt |
| dof.DofKayit | dof.Findings | dof |
| dof.DofBulgu | dof.FindingDetails | dof |
| dof.DofAksiyon | dof.Actions | dof |
| dof.DofKanit | dof.Evidence | dof |
| dof.DofDurumGecmis | dof.StatusHistory | dof |
| ai.AiAnalizIstegi | ai.AnalysisQueue | ai |
| ai.AiGecmisVektorler | ai.SemanticVectors | ai |
| ai.AiLmSonuc | ai.RuleResults | ai |
| ai.AiLlmSonuc | ai.LlmResults | ai |
| ai.AiMigrationStatus | ai.MigrationStatus | ai |
| ai.AiMultiModalEmbedding | ai.Embeddings | ai |
| ai.AiAnomalyDetection | ai.AnomalyDetections | ai |
| ai.AiEnhancedFeedback | ai.EnhancedFeedback | ai |
| ai.AiGeriBildirim | ai.Feedback | ai |
| ai.AiLearningConfig | ai.LearningConfig | ai |
| ai.AiMemoryLayerConfig | ai.MemoryLayerConfig | ai |
| ai.AiModelPerformance | ai.ModelPerformance | ai |
| ai.AiPredictionModel | ai.PredictionModels | ai |
| ai.AiRiskPrediction | ai.RiskPredictions | ai |
| ai.AiSimilarityThreshold | ai.SimilarityThresholds | ai |
| log.RiskCalismaLog | log.RiskEtlRuns | log |
| log.StokCalismaLog | log.StockEtlRuns | log |
| etl.EtlDataQualityIssue | etl.DataQualityIssues | etl |
| etl.EtlLog | etl.EtlRuns | etl |
| etl.EtlSyncStatus | etl.SyncStatus | etl |

### 1.3 Henüz Yapılmayanlar ❌

- Root klasör hâlâ `D:\Dev\icdenetim` — `D:\Dev\BkmArgus`'a taşınmadı
- Git repo yok
- RiskAnaliz ile kod birleşmesi yapılmadı (DB'de tablolar var, kod ayrı)
- Türkçe tablo/kolon adları İngilizce'ye çevrilmedi
- RBAC, bildirim, korelasyon, export sistemi yok
- kodlari_topla_v2.bat hâlâ `yonetiq` arıyor

---

## 2. İSİMLENDİRME STANDARDI

### 2.1 Kurallar

| Kural | Örnek |
|-------|-------|
| Tablo adları İngilizce, PascalCase | `DailyProductRisk`, `AnalysisQueue` |
| Kolon adları İngilizce, PascalCase | `LocationId`, `RiskScore`, `IsActive` |
| Boolean kolonlar `Is` prefix | `IsActive`, `IsSystemic`, `IsCritical` |
| Tarih kolonlar `At` veya `Date` suffix | `CreatedAt`, `SnapshotDate`, `DueDate` |
| FK kolonlar `Id` suffix | `LocationId`, `ProductId`, `CreatedByUserId` |
| Audit kolonlar standart set | `CreatedAt`, `UpdatedAt`, `CreatedByUserId`, `UpdatedByUserId` |
| Schema adları lowercase, kısa | `src`, `ref`, `rpt`, `dof`, `ai`, `log`, `etl`, `audit` |
| SP adları `schema.sp_Entity_Action` | `audit.sp_Audit_List`, `dof.sp_Finding_Create` |
| View adları `schema.vw_Name` | `rpt.vw_RiskDashboard` |
| Index adları `IX_Table_Columns` | `IX_DailyProductRisk_SnapshotDate` |
| PK adları `PK_Table` | `PK_DailyProductRisk` |
| FK adları `FK_Child_Parent` | `FK_Actions_Findings` |

### 2.2 Kolon Rename Mapping (Sık Kullanılanlar)

| Türkçe (Mevcut) | İngilizce (Hedef) |
|------------------|-------------------|
| KesimTarihi | SnapshotDate |
| DonemKodu | PeriodCode |
| MekanId | LocationId |
| MekanAd / MekanAdi | LocationName |
| StokId | ProductId |
| UrunKod | ProductCode |
| UrunAd / UrunAdi | ProductName |
| RiskSkor | RiskScore |
| RiskYorum | RiskComment |
| AktifMi | IsActive |
| KritikMi | IsCritical |
| OlusturanKullaniciId | CreatedByUserId |
| GuncelleyenKullaniciId | UpdatedByUserId |
| OlusturmaTarihi | CreatedAt |
| GuncellemeTarihi | UpdatedAt |
| Aciklama | Description |
| Baslik | Title |
| Durum | Status |
| Oncelik | Priority |
| DenemeSayisi | RetryCount |
| HataMesaji | ErrorMessage |
| SonDenemeTarihi | LastRetryAt |
| KaynakTip | SourceType |
| KaynakAnahtar | SourceKey |
| KaynakSistemKodu | SourceSystemCode |
| KaynakNesneKodu | SourceObjectCode |
| SistemKodu | SystemCode |
| SistemAdi | SystemName |
| NesneKodu | ObjectCode |
| NesneAdi | ObjectName |
| PersonelId | PersonnelId |
| PersonelKodu | PersonnelCode |
| KullaniciId | UserId |
| KullaniciAdi | Username |
| RolKodu | RoleCode |
| SonGirisTarihi | LastLoginAt |
| Ad | FirstName |
| Soyad | LastName |
| Unvan | JobTitle |
| Birim | Department |
| UstPersonelId | SupervisorId |
| Eposta | Email |
| Telefon | Phone |
| BaslangicTarihi | StartDate |
| BitisTarihi | EndDate |
| DofId | FindingId |
| DofImza | FindingSignature |
| RiskSeviyesi | RiskLevel |
| SLA_HedefTarih | SlaDueDate |
| Olusturan | CreatedBy |
| Sorumlu | AssignedTo |
| Onayci | ApprovedBy |
| SorumluPersonelId | AssignedToPersonnelId |
| OnayciPersonelId | ApprovedByPersonnelId |
| AksiyonMetni | ActionText |
| HedefTarih | DueDate |
| TamamlandiMi | IsCompleted |
| TamamlanmaTarihi | CompletedDate |
| KanitTuru | EvidenceType |
| KanitYolu | EvidencePath |
| KanitMetni | EvidenceText |
| EskiDurum | OldStatus |
| YeniDurum | NewStatus |
| Degistiren | ChangedBy |
| DegisimTarihi | ChangedAt |
| IstekId | RequestId |
| OzetMetin | SummaryText |
| KokNedenAnalizi | RootCauseAnalysis |
| OnerilerJson | SuggestionsJson |
| GuvenilirlikSkoru | ConfidenceScore |
| EvidencePlan | EvidencePlan |
| VektorId | VectorId |
| VektorJson | VectorJson |
| SonucId | ResultId |
| ModelAdi | ModelName |
| PromptMetni | PromptText |
| SonucMetni | ResultText |
| TokenSayisi | TokenCount |
| SureMs | DurationMs |
| GuvenSkoru | ConfidenceScore |
| ParamKodu | ParamCode |
| DegerInt | IntValue |
| DegerDec | DecValue |
| DegerStr | StrValue |
| FlagKodu | FlagCode |
| Puan | Points |
| GrupKodu | GroupCode |
| GrupAdi | GroupName |
| IslemAdi | OperationName |
| TipId | TypeId |
| SiraNo | SortOrder |
| FlagVeriKalite | FlagDataQuality |
| FlagGirissizSatis | FlagSalesWithoutEntry |
| FlagOluStok | FlagDeadStock |
| FlagNetBirikim | FlagNetAccumulation |
| FlagIadeYuksek | FlagHighReturn |
| FlagBozukIadeYuksek | FlagHighDamagedReturn |
| FlagSayimDuzeltmeYuk | FlagHighCountAdjustment |
| FlagSirketIciYuksek | FlagHighInternalUse |
| FlagHizliDevir | FlagFastTurnover |
| FlagSatisYaslanma | FlagSalesAging |
| NetAdet | NetQty |
| BrutAdet | GrossQty |
| NetTutar | NetAmount |
| BrutTutar | GrossAmount |
| SonSatisTarihi | LastSaleDate |
| SatisYasiGun | SaleAgeDays |
| IadeOraniYuzde | ReturnRatePct |
| KesimGunu | SnapshotDay |
| DonemAy | PeriodMonth |
| StokMiktar | StockQty |

---

## 3. HEDEF SCHEMA TASARIMI

### 3.1 Schema Haritası (8 schema)

```
src    — ERP soyutlama view'leri (DerinSIS bağımlılığı sadece burada)
ref    — Referans/mapping (lokasyon, tip mapping, parametreler, personel, kullanıcı)
audit  — Saha denetim (dbo.* tablolarının yeni yeri)
rpt    — Rapor snapshot tabloları (günlük/aylık risk, stok bakiye)
dof    — DÖF süreci (finding/action/evidence/status)
ai     — AI analiz (kuyruk, sonuç, vektör, embedding, tahmin)
log    — Çalışma logları, sağlık kontrol, bildirimler
etl    — ETL sync durumu
```

### 3.2 Birleşik Tablo Yapısı

#### audit.* (Saha Denetim — dbo.*'dan taşınır)

| Yeni Tablo | Eski Kaynak | Not |
|------------|-------------|-----|
| audit.Users | dbo.Users | Auth + RBAC genişletilir |
| audit.Audits | dbo.Audits | MekanId eklenir (ERP bağlantı) |
| audit.AuditItems | dbo.AuditItems | Değişmez |
| audit.AuditResults | dbo.AuditResults | Değişmez |
| audit.AuditResultPhotos | dbo.AuditResultPhotos | Değişmez |
| audit.Skills | dbo.Skills | Değişmez |
| audit.SkillVersions | dbo.SkillVersions | Değişmez |
| audit.AuditLog | dbo.AuditLog | Değişmez |

#### ref.* (Referans — Türkçe → İngilizce)

| Yeni Tablo | Eski Kaynak |
|------------|-------------|
| ref.LocationSettings | ref.AyarMekanKapsam |
| ref.TransactionTypeMap | ref.IrsTipGrupMap |
| ref.RiskParameters | ref.RiskParam |
| ref.RiskScoreWeights | ref.RiskSkorAgirlik |
| ref.SourceSystems | ref.KaynakSistem |
| ref.SourceObjects | ref.KaynakNesne |
| ref.Personnel | ref.Personel |
| ref.Users | ref.Kullanici |
| ref.UserPersonnelMap | ref.KullaniciPersonel |

#### dof.* (DÖF — Türkçe → İngilizce)

| Yeni Tablo | Eski Kaynak |
|------------|-------------|
| dof.Findings | dof.DofKayit |
| dof.FindingDetails | dof.DofBulgu |
| dof.Actions | dof.DofAksiyon |
| dof.Evidence | dof.DofKanit |
| dof.StatusHistory | dof.DofDurumGecmis |
| dof.Comments | YENİ — yorum thread |
| dof.StatusRules | YENİ — geçiş kuralları |

#### ai.* (AI — Türkçe → İngilizce)

| Yeni Tablo | Eski Kaynak |
|------------|-------------|
| ai.AnalysisQueue | ai.AiAnalizIstegi |
| ai.SemanticVectors | ai.AiGecmisVektorler |
| ai.RuleResults | ai.AiLmSonuc |
| ai.LlmResults | ai.AiLlmSonuc |
| ai.Embeddings | ai.AiMultiModalEmbedding |
| ai.Feedback | ai.AiGeriBildirim |
| ai.PredictionModels | ai.AiPredictionModel |
| ai.RiskPredictions | ai.AiRiskPrediction |
| ai.ModelPerformance | ai.AiModelPerformance |
| ai.MigrationStatus | ai.AiMigrationStatus |

#### rpt.* (Rapor — Türkçe → İngilizce)

| Yeni Tablo | Eski Kaynak |
|------------|-------------|
| rpt.DailyProductRisk | rpt.RiskUrunOzet_Gunluk |
| rpt.MonthlyProductRisk | rpt.RiskUrunOzet_Aylik |
| rpt.DailyStockBalance | rpt.StokBakiyeGunluk |
| rpt.CrossCorrelation | YENİ — ERP↔saha korelasyon |

#### log.* (Log — Türkçe → İngilizce)

| Yeni Tablo | Eski Kaynak |
|------------|-------------|
| log.RiskEtlRuns | log.RiskCalismaLog |
| log.StockEtlRuns | log.StokCalismaLog |
| log.Notifications | YENİ — bildirim sistemi |
| log.LoginHistory | YENİ — giriş logları |

---

## 4. GEÇİŞ FAZLARI (REVİZE)

### FAZ 0 — Hazırlık (1 gün)
- [ ] Root klasörü `D:\Dev\BkmArgus`'a taşı
- [ ] Git repo başlat + .gitignore
- [ ] kodlari_topla_v2.bat güncelle (BkmArgus için)
- [ ] CLAUDE.md güncelle
- [ ] Bu dokümanı `docs/MIGRATION_PLAN.md` olarak ekle

### FAZ 1 — Tablo Standardizasyonu (3-5 gün)
- [ ] `sp_rename` ile Türkçe tablo adlarını İngilizce'ye çevir
- [ ] `sp_rename` ile Türkçe kolon adlarını İngilizce'ye çevir
- [ ] Tüm SP'leri yeni adlara göre güncelle
- [ ] Tüm view'ları yeni adlara göre güncelle
- [ ] dbo.* tablolarını audit.* schema'sına taşı
- [ ] Compatibility view'ları (Migration_Compatibility.sql) güncelle veya kaldır

### FAZ 2 — Kod Birleştirme (3-5 gün)
- [ ] RiskAnaliz C# kodundaki Türkçe tablo/kolon referanslarını İngilizce'ye çevir
- [ ] BkmArgus.Web + RiskAnaliz.Web → tek web projesi
- [ ] BkmArgus AI servisleri + RiskAnaliz AiWorker → birleşik AI katmanı
- [ ] LlmService'e Claude API provider ekle

### FAZ 3 — RBAC ve Auth (2-3 gün)
- [ ] audit.Users tablosunu genişlet (şifre politikası, rol, kilit)
- [ ] ref.Users (eski ref.Kullanici) ile audit.Users birleşimi
- [ ] Rol ve yetki tabloları
- [ ] Cookie auth + sayfa bazlı yetki kontrolü

### FAZ 4 — Eksik Özellikler (5-10 gün)
- [ ] DOF onay state machine
- [ ] Bildirim sistemi (log.Notifications)
- [ ] Çapraz korelasyon (rpt.CrossCorrelation)
- [ ] Export sistemi (PDF + Excel)
- [ ] AI proaktif öneriler
- [ ] AI feedback loop
- [ ] Structured logging (Serilog)
- [ ] Cache + performans

### FAZ 5 — Test ve Deploy (2-3 gün)
- [ ] SQL smoke tests
- [ ] C# unit tests
- [ ] Installer güncelle
- [ ] Deploy script

---

## 5. CLAUDE CODE PROMPT SETİ (REVİZE)

---

### PROMPT 1 — Tablo Rename: Türkçe → İngilizce (ref + dof)

```
## GÖREV
BKMDenetim veritabanındaki Türkçe tablo ve kolon adlarını İngilizce'ye çevir.
Bu prompt ref.* ve dof.* şemalarını kapsar.

## YÖNTEM
sp_rename ile tablo ve kolon adlarını değiştir.
Her işlem IF EXISTS kontrolü ile — idempotent olmalı.

## ref ŞEMASI

### Tablo rename:
EXEC sp_rename 'ref.AyarMekanKapsam', 'LocationSettings';
EXEC sp_rename 'ref.IrsTipGrupMap', 'TransactionTypeMap';
EXEC sp_rename 'ref.RiskParam', 'RiskParameters';
EXEC sp_rename 'ref.RiskSkorAgirlik', 'RiskScoreWeights';
EXEC sp_rename 'ref.KaynakSistem', 'SourceSystems';
EXEC sp_rename 'ref.KaynakNesne', 'SourceObjects';
EXEC sp_rename 'ref.Personel', 'Personnel';
EXEC sp_rename 'ref.Kullanici', 'Users';
EXEC sp_rename 'ref.KullaniciPersonel', 'UserPersonnelMap';

### ref.LocationSettings (eski AyarMekanKapsam) kolon rename:
EXEC sp_rename 'ref.LocationSettings.MekanId', 'LocationId', 'COLUMN';
EXEC sp_rename 'ref.LocationSettings.AktifMi', 'IsActive', 'COLUMN';
EXEC sp_rename 'ref.LocationSettings.Aciklama', 'Description', 'COLUMN';
EXEC sp_rename 'ref.LocationSettings.OlusturanKullaniciId', 'CreatedByUserId', 'COLUMN';
EXEC sp_rename 'ref.LocationSettings.GuncelleyenKullaniciId', 'UpdatedByUserId', 'COLUMN';
EXEC sp_rename 'ref.LocationSettings.OlusturmaTarihi', 'CreatedAt', 'COLUMN';
EXEC sp_rename 'ref.LocationSettings.GuncellemeTarihi', 'UpdatedAt', 'COLUMN';

### ref.TransactionTypeMap (eski IrsTipGrupMap) kolon rename:
EXEC sp_rename 'ref.TransactionTypeMap.TipId', 'TypeId', 'COLUMN';
EXEC sp_rename 'ref.TransactionTypeMap.GrupKodu', 'GroupCode', 'COLUMN';
EXEC sp_rename 'ref.TransactionTypeMap.GrupAdi', 'GroupName', 'COLUMN';
EXEC sp_rename 'ref.TransactionTypeMap.IslemAdi', 'OperationName', 'COLUMN';
EXEC sp_rename 'ref.TransactionTypeMap.AktifMi', 'IsActive', 'COLUMN';
-- + audit kolonları aynı pattern

### ref.RiskParameters (eski RiskParam):
EXEC sp_rename 'ref.RiskParameters.ParamKodu', 'ParamCode', 'COLUMN';
EXEC sp_rename 'ref.RiskParameters.DegerInt', 'IntValue', 'COLUMN';
EXEC sp_rename 'ref.RiskParameters.DegerDec', 'DecValue', 'COLUMN';
EXEC sp_rename 'ref.RiskParameters.DegerStr', 'StrValue', 'COLUMN';
-- + AktifMi, Aciklama, audit kolonları

### ref.RiskScoreWeights (eski RiskSkorAgirlik):
EXEC sp_rename 'ref.RiskScoreWeights.FlagKodu', 'FlagCode', 'COLUMN';
EXEC sp_rename 'ref.RiskScoreWeights.Puan', 'Points', 'COLUMN';
EXEC sp_rename 'ref.RiskScoreWeights.Oncelik', 'Priority', 'COLUMN';

### ref.SourceSystems (eski KaynakSistem):
EXEC sp_rename 'ref.SourceSystems.SistemKodu', 'SystemCode', 'COLUMN';
EXEC sp_rename 'ref.SourceSystems.SistemAdi', 'SystemName', 'COLUMN';

### ref.SourceObjects (eski KaynakNesne):
EXEC sp_rename 'ref.SourceObjects.NesneKodu', 'ObjectCode', 'COLUMN';
EXEC sp_rename 'ref.SourceObjects.NesneAdi', 'ObjectName', 'COLUMN';

### ref.Personnel (eski Personel):
EXEC sp_rename 'ref.Personnel.PersonelId', 'PersonnelId', 'COLUMN';
EXEC sp_rename 'ref.Personnel.PersonelKodu', 'PersonnelCode', 'COLUMN';
EXEC sp_rename 'ref.Personnel.Ad', 'FirstName', 'COLUMN';
EXEC sp_rename 'ref.Personnel.Soyad', 'LastName', 'COLUMN';
EXEC sp_rename 'ref.Personnel.Unvan', 'JobTitle', 'COLUMN';
EXEC sp_rename 'ref.Personnel.Birim', 'Department', 'COLUMN';
EXEC sp_rename 'ref.Personnel.UstPersonelId', 'SupervisorId', 'COLUMN';
EXEC sp_rename 'ref.Personnel.Eposta', 'Email', 'COLUMN';
EXEC sp_rename 'ref.Personnel.Telefon', 'Phone', 'COLUMN';

### ref.Users (eski Kullanici):
EXEC sp_rename 'ref.Users.KullaniciId', 'UserId', 'COLUMN';
EXEC sp_rename 'ref.Users.KullaniciAdi', 'Username', 'COLUMN';
EXEC sp_rename 'ref.Users.PersonelId', 'PersonnelId', 'COLUMN';
EXEC sp_rename 'ref.Users.RolKodu', 'RoleCode', 'COLUMN';
EXEC sp_rename 'ref.Users.SonGirisTarihi', 'LastLoginAt', 'COLUMN';

### ref.UserPersonnelMap (eski KullaniciPersonel):
EXEC sp_rename 'ref.UserPersonnelMap.BaglantiId', 'LinkId', 'COLUMN';
EXEC sp_rename 'ref.UserPersonnelMap.BaslangicTarihi', 'StartDate', 'COLUMN';
EXEC sp_rename 'ref.UserPersonnelMap.BitisTarihi', 'EndDate', 'COLUMN';

## dof ŞEMASI

### Tablo rename:
EXEC sp_rename 'dof.DofKayit', 'Findings';
EXEC sp_rename 'dof.DofBulgu', 'FindingDetails';
EXEC sp_rename 'dof.DofAksiyon', 'Actions';
EXEC sp_rename 'dof.DofKanit', 'Evidence';
EXEC sp_rename 'dof.DofDurumGecmis', 'StatusHistory';

### dof.Findings (eski DofKayit):
EXEC sp_rename 'dof.Findings.DofId', 'FindingId', 'COLUMN';
EXEC sp_rename 'dof.Findings.DofImza', 'FindingSignature', 'COLUMN';
EXEC sp_rename 'dof.Findings.KaynakSistemKodu', 'SourceSystemCode', 'COLUMN';
EXEC sp_rename 'dof.Findings.KaynakNesneKodu', 'SourceObjectCode', 'COLUMN';
EXEC sp_rename 'dof.Findings.KaynakAnahtar', 'SourceKey', 'COLUMN';
EXEC sp_rename 'dof.Findings.Baslik', 'Title', 'COLUMN';
EXEC sp_rename 'dof.Findings.Aciklama', 'Description', 'COLUMN';
EXEC sp_rename 'dof.Findings.RiskSeviyesi', 'RiskLevel', 'COLUMN';
EXEC sp_rename 'dof.Findings.SLA_HedefTarih', 'SlaDueDate', 'COLUMN';
EXEC sp_rename 'dof.Findings.Durum', 'Status', 'COLUMN';
EXEC sp_rename 'dof.Findings.Olusturan', 'CreatedBy', 'COLUMN';
EXEC sp_rename 'dof.Findings.Sorumlu', 'AssignedTo', 'COLUMN';
EXEC sp_rename 'dof.Findings.Onayci', 'ApprovedBy', 'COLUMN';
EXEC sp_rename 'dof.Findings.SorumluPersonelId', 'AssignedToPersonnelId', 'COLUMN';
EXEC sp_rename 'dof.Findings.OnayciPersonelId', 'ApprovedByPersonnelId', 'COLUMN';

### dof.FindingDetails (eski DofBulgu):
EXEC sp_rename 'dof.FindingDetails.BulguId', 'DetailId', 'COLUMN';
EXEC sp_rename 'dof.FindingDetails.DofId', 'FindingId', 'COLUMN';
EXEC sp_rename 'dof.FindingDetails.BulguMetni', 'DetailText', 'COLUMN';

### dof.Actions (eski DofAksiyon):
EXEC sp_rename 'dof.Actions.AksiyonId', 'ActionId', 'COLUMN';
EXEC sp_rename 'dof.Actions.DofId', 'FindingId', 'COLUMN';
EXEC sp_rename 'dof.Actions.AksiyonMetni', 'ActionText', 'COLUMN';
EXEC sp_rename 'dof.Actions.Sorumlu', 'AssignedTo', 'COLUMN';
EXEC sp_rename 'dof.Actions.HedefTarih', 'DueDate', 'COLUMN';
EXEC sp_rename 'dof.Actions.TamamlandiMi', 'IsCompleted', 'COLUMN';
EXEC sp_rename 'dof.Actions.TamamlanmaTarihi', 'CompletedDate', 'COLUMN';

### dof.Evidence (eski DofKanit):
EXEC sp_rename 'dof.Evidence.KanitId', 'EvidenceId', 'COLUMN';
EXEC sp_rename 'dof.Evidence.DofId', 'FindingId', 'COLUMN';
EXEC sp_rename 'dof.Evidence.KanitTuru', 'EvidenceType', 'COLUMN';
EXEC sp_rename 'dof.Evidence.KanitYolu', 'EvidencePath', 'COLUMN';
EXEC sp_rename 'dof.Evidence.KanitMetni', 'EvidenceText', 'COLUMN';

### dof.StatusHistory (eski DofDurumGecmis):
EXEC sp_rename 'dof.StatusHistory.DofId', 'FindingId', 'COLUMN';
EXEC sp_rename 'dof.StatusHistory.EskiDurum', 'OldStatus', 'COLUMN';
EXEC sp_rename 'dof.StatusHistory.YeniDurum', 'NewStatus', 'COLUMN';
EXEC sp_rename 'dof.StatusHistory.Degistiren', 'ChangedBy', 'COLUMN';
EXEC sp_rename 'dof.StatusHistory.DegisimTarihi', 'ChangedAt', 'COLUMN';

## CONSTRAINT VE INDEX RENAME
- FK constraint'leri de sp_rename ile güncelle
- Index'ler yeni tablo adlarıyla uyumlu olmalı

## DOĞRULAMA
Script sonunda tüm tabloların yeni adlarla erişilebilir olduğunu kontrol eden SELECT'ler ekle.
```

---

### PROMPT 2 — Tablo Rename: ai + rpt + log + etl

```
## GÖREV
BKMDenetim veritabanındaki ai.*, rpt.*, log.*, etl.* şemalarındaki Türkçe tablo ve kolon adlarını İngilizce'ye çevir.

## ai ŞEMASI

### Tablo rename:
EXEC sp_rename 'ai.AiAnalizIstegi', 'AnalysisQueue';
EXEC sp_rename 'ai.AiGecmisVektorler', 'SemanticVectors';
EXEC sp_rename 'ai.AiLlmSonuc', 'LlmResults';
EXEC sp_rename 'ai.AiMigrationStatus', 'MigrationStatus';
EXEC sp_rename 'ai.AiMultiModalEmbedding', 'Embeddings';
EXEC sp_rename 'ai.AiGeriBildirim', 'Feedback';
EXEC sp_rename 'ai.AiPredictionModel', 'PredictionModels';
EXEC sp_rename 'ai.AiRiskPrediction', 'RiskPredictions';
EXEC sp_rename 'ai.AiModelPerformance', 'ModelPerformance';
-- Diğer ai.Ai* tabloları da aynı pattern ile

### ai.AnalysisQueue (eski AiAnalizIstegi) kolon rename:
EXEC sp_rename 'ai.AnalysisQueue.IstekId', 'RequestId', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.KesimTarihi', 'SnapshotDate', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.DonemKodu', 'PeriodCode', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.MekanId', 'LocationId', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.StokId', 'ProductId', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.KaynakTip', 'SourceType', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.KaynakAnahtar', 'SourceKey', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.Oncelik', 'Priority', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.Durum', 'Status', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.DenemeSayisi', 'RetryCount', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.Baslik', 'Title', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.OzetMetin', 'SummaryText', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.KokNedenAnalizi', 'RootCauseAnalysis', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.OnerilerJson', 'SuggestionsJson', 'COLUMN';
EXEC sp_rename 'ai.AnalysisQueue.GuvenilirlikSkoru', 'ConfidenceScore', 'COLUMN';

### ai.SemanticVectors (eski AiGecmisVektorler):
EXEC sp_rename 'ai.SemanticVectors.VektorId', 'VectorId', 'COLUMN';
EXEC sp_rename 'ai.SemanticVectors.Baslik', 'Title', 'COLUMN';
EXEC sp_rename 'ai.SemanticVectors.OzetMetin', 'SummaryText', 'COLUMN';
EXEC sp_rename 'ai.SemanticVectors.KritikMi', 'IsCritical', 'COLUMN';
EXEC sp_rename 'ai.SemanticVectors.VektorJson', 'VectorJson', 'COLUMN';

### ai.LlmResults (eski AiLlmSonuc):
EXEC sp_rename 'ai.LlmResults.SonucId', 'ResultId', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.IstekId', 'RequestId', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.ModelAdi', 'ModelName', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.PromptMetni', 'PromptText', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.SonucMetni', 'ResultText', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.TokenSayisi', 'TokenCount', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.SureMs', 'DurationMs', 'COLUMN';
EXEC sp_rename 'ai.LlmResults.GuvenSkoru', 'ConfidenceScore', 'COLUMN';

## rpt ŞEMASI

### Tablo rename:
EXEC sp_rename 'rpt.RiskUrunOzet_Gunluk', 'DailyProductRisk';
EXEC sp_rename 'rpt.RiskUrunOzet_Aylik', 'MonthlyProductRisk';
EXEC sp_rename 'rpt.StokBakiyeGunluk', 'DailyStockBalance';

### rpt.DailyProductRisk kolon rename (kritik — 40+ kolon):
Bölüm 2.2'deki mapping tablosunu kullanarak tüm Türkçe kolonları çevir.
ÖNEMLİ: Flag kolon adları FlagXxx formatında kalır ama İngilizce olur.
COMPUTED column (KesimGunu) → SnapshotDay olarak yeniden oluştur.

### rpt.DailyStockBalance:
EXEC sp_rename 'rpt.DailyStockBalance.Tarih', 'Date', 'COLUMN';
EXEC sp_rename 'rpt.DailyStockBalance.StokMiktar', 'StockQty', 'COLUMN';

## log ŞEMASI
log.RiskCalismaLog → log.RiskEtlRuns (+ kolon rename)
log.StokCalismaLog → log.StockEtlRuns (+ kolon rename)

## etl ŞEMASI
etl.EtlDataQualityIssue → etl.DataQualityIssues
etl.EtlLog → etl.EtlRuns
etl.EtlSyncStatus → etl.SyncStatus

## ÖNEMLİ
- Her rename öncesi: OBJECT_ID kontrolü yap (tablo zaten rename edilmişse tekrar çalıştırma)
- FK constraint'leri geçici DROP + yeniden CREATE gerekebilir
- Index'leri güncelle
```

---

### PROMPT 3 — dbo.* → audit.* Schema Taşıma

```
## GÖREV
BkmArgus'un dbo.* tablolarını audit.* şemasına taşı.

## YÖNTEM
ALTER SCHEMA audit TRANSFER dbo.TableName;

## ADIMLAR
1. audit şeması oluştur (IF NOT EXISTS)
2. Her tablo için:
   ALTER SCHEMA audit TRANSFER dbo.Users;
   ALTER SCHEMA audit TRANSFER dbo.Audits;
   ALTER SCHEMA audit TRANSFER dbo.AuditItems;
   ALTER SCHEMA audit TRANSFER dbo.AuditResults;
   ALTER SCHEMA audit TRANSFER dbo.AuditResultPhotos;
   ALTER SCHEMA audit TRANSFER dbo.CorrectiveActions;
   ALTER SCHEMA audit TRANSFER dbo.Skills;
   ALTER SCHEMA audit TRANSFER dbo.SkillVersions;
   ALTER SCHEMA audit TRANSFER dbo.AiAnalyses;
   ALTER SCHEMA audit TRANSFER dbo.AuditLog;
3. BkmArgus C# kodundaki tüm SQL sorgularını "audit." prefix ile güncelle
4. Audits tablosuna LocationId (int NULL) ekle — ref.LocationSettings.LocationId ile FK
5. Migration_Compatibility.sql artık gereksiz — kaldır veya Deprecated olarak işaretle

## DOĞRULAMA
SELECT s.name AS SchemaName, t.name AS TableName 
FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id 
WHERE s.name = 'audit' ORDER BY t.name;
```

---

### PROMPT 4 — SP Güncelleme (Toplu)

```
## GÖREV
RiskAnaliz'in tüm stored procedure'larını yeni İngilizce tablo ve kolon adlarıyla güncelle.

## BAĞLAM
Tüm tablo ve kolon adları Prompt 1-2'de İngilizce'ye çevrildi.
Şimdi ~50 SP'nin içindeki SQL referanslarını güncellemek gerekiyor.

## YÖNTEM
Her SP için:
1. Mevcut SP tanımını oku (sp_helptext veya OBJECT_DEFINITION)
2. Türkçe tablo/kolon referanslarını İngilizce'ye çevir
3. SP'yi DROP + CREATE ile yeniden oluştur
4. SP adını da İngilizce'ye çevir

## SP AD RENAME KURALI
schema.sp_TurkceAd → schema.sp_EnglishName
Örnek:
- ref.sp_IrsTipGrupMap_Listele → ref.sp_TransactionTypeMap_List
- rpt.sp_Dashboard_Kpi → rpt.sp_Dashboard_Kpi (zaten İngilizce)
- rpt.sp_Dashboard_TopRisk → rpt.sp_Dashboard_TopRisk (zaten İngilizce)
- dof.sp_Dashboard_Dof_Liste → dof.sp_Dashboard_Finding_List
- log.sp_RiskUrunOzet_Calistir → log.sp_DailyProductRisk_Run
- log.sp_StokBakiyeGunluk_Calistir → log.sp_DailyStockBalance_Run
- log.sp_SaglikKontrol_Calistir → log.sp_HealthCheck_Run
- log.sp_AylikKapanis_Calistir → log.sp_MonthlyClose_Run
- ai.sp_Ai_RiskOzet_Getir → ai.sp_RiskSummary_Get
- ai.sp_Ai_Istek_Olustur → ai.sp_AnalysisQueue_Create
- ai.sp_Ai_GecmisVektor_Upsert → ai.sp_SemanticVector_Upsert
- ai.sp_Ai_GecmisVektor_KaynakListe → ai.sp_SemanticVector_SourceList

## ÖNEMLİ
- src.* view'leri DEĞİŞMEZ — bunlar ERP'ye bağlı, ERP Türkçe
- src view'lerinden İngilizce tablo/kolona yazarken aliasing kullan:
  SELECT ehMekanId AS LocationId, ehStokId AS ProductId FROM src.vw_StokHareket
```

---

### PROMPT 5 — C# Kod Güncelleme (RiskAnaliz)

```
## GÖREV
RiskAnaliz C# kodundaki Türkçe tablo/kolon referanslarını İngilizce'ye güncelle.

## DOSYALAR
- src/BkmArgus.AiWorker/Models.cs — tüm record'lardaki property adları
- src/BkmArgus.AiWorker/AiWorkerService.cs — SQL sorgu string'leri
- src/BkmArgus.AiWorker/LmRules.cs — property referansları
- src/BkmArgus.AiWorker/LlmService.cs — değişiklik yok (generic)
- src/BkmArgus.AiWorker/SemanticMemoryService.cs — SQL sorguları
- src/BkmArgus.AiWorker/EmbeddingService.cs — değişiklik yok
- src/BkmArgus.AiWorker/Jobs/*.cs — SQL ve SP referansları
- src/BkmArgus.Web/Data/SqlDb.cs — SP çağrıları
- src/BkmArgus.Web/Features/**/*.cshtml.cs — SP çağrıları ve model referansları

## MODEL RENAME ÖRNEKLERİ

### Models.cs:
AiIstekRow → AnalysisQueueRow
  - IstekId → RequestId
  - KesimTarihi → SnapshotDate
  - DonemKodu → PeriodCode
  - MekanId → LocationId
  - MekanAd → LocationName
  - StokId → ProductId
  - UrunKod → ProductCode
  - UrunAd → ProductName
  - RiskSkor → RiskScore
  - Oncelik → Priority
  - Durum → Status
  - HataMesaji → ErrorMessage

RiskOzetRow → RiskSummaryRow
  - Tüm Flag property'leri: FlagVeriKalite → FlagDataQuality, vs.

LmDecision:
  - RootCauseClass → (kalır, zaten İngilizce)
  - LlmGerekliMi → LlmRequired
  - OncelikPuan → PriorityScore
  - KisaOzet → ShortSummary
  - OzellikJson → FeaturesJson
  - SemanticNot → SemanticNote

DofKayitRow → FindingRow
  - DofId → FindingId
  - Baslik → Title
  - Aciklama → Description
  - KaynakAnahtar → SourceKey
  - RiskSeviyesi → RiskLevel
  - Durum → Status

## SQL STRING GÜNCELLEME
Tüm inline SQL sorgularındaki Türkçe tablo/kolon adlarını güncelle.
SP çağrılarındaki SP adlarını güncelle.
```

---

### PROMPT 6 — LlmService'e Claude API Provider Ekleme

```
(Önceki planın Prompt 3'ü ile aynı — değişiklik yok)
```

---

### PROMPT 7 — Event-Driven Pipeline Genişletme (Saha + ERP)

```
## GÖREV
Mevcut BkmArgus Event-Driven pipeline'ını hem saha denetim hem ERP risk olaylarını işleyecek şekilde genişlet.

## BAĞLAM
Mevcut AuditEventType:
- AuditFinalized, FindingDetected, RepeatDetected, SystemicDetected
- DofCreated, DofClosed, DofIneffective, RiskEscalated, InsightGenerated

## EKLENECEK EVENT'LER
- ErpRiskDetected — gece ETL'den yüksek risk sinyali
- ErpAnomalyDetected — anomali tespit
- CorrelationAlert — ERP risk + saha bulgu çapraz korelasyon
- SlaNearing — DOF SLA yaklaşıyor
- SlaBreached — DOF SLA aşıldı
- AuditScheduleRecommended — AI denetim planlama önerisi
- NotificationCreated — bildirim oluşturuldu

## AIOrchestratorService GENİŞLETME
- HandleErpRiskAsync: RiskScore >= 80 → ESCALATE, 60-79 → MONITOR
- HandleCorrelationAsync: Aynı mağazada ERP+saha çakışması → CRITICAL
- HandleSlaAsync: SLA uyarı ve eskalasyon kuralları

## AiBackgroundWorker GENİŞLETME
- ERP risk kuyruk işleme
- DOF SLA kontrol döngüsü (her 5 dk)
- Korelasyon kontrol döngüsü (her 30 dk)
```

---

### PROMPT 8 — Web Birleştirme + Dashboard

```
(Önceki planın Prompt 7-8 içeriği — ama tüm SQL referansları İngilizce tablo adlarıyla)
```

---

### PROMPT 9-17 — Eksik Özellikler

```
(Önceki planın Prompt 12-21 içerikleri — RBAC, DOF state machine, bildirimler,
 korelasyon, export, proaktif AI, test, logging, performans.
 Tüm tablo/kolon referansları İngilizce.)
```

---

## 6. İSİMLENDİRME ÖNCESİ / SONRASI DOĞRULAMA SCRIPTI

```sql
-- Bu scripti tüm rename işlemlerinden SONRA çalıştır
-- Her satır bir tablo kontrolü — hepsi başarılıysa migration tamamdır

SELECT 'ref.LocationSettings' AS Expected, OBJECT_ID('ref.LocationSettings') AS ObjectId
UNION ALL SELECT 'ref.TransactionTypeMap', OBJECT_ID('ref.TransactionTypeMap')
UNION ALL SELECT 'ref.RiskParameters', OBJECT_ID('ref.RiskParameters')
UNION ALL SELECT 'ref.RiskScoreWeights', OBJECT_ID('ref.RiskScoreWeights')
UNION ALL SELECT 'ref.SourceSystems', OBJECT_ID('ref.SourceSystems')
UNION ALL SELECT 'ref.SourceObjects', OBJECT_ID('ref.SourceObjects')
UNION ALL SELECT 'ref.Personnel', OBJECT_ID('ref.Personnel')
UNION ALL SELECT 'ref.Users', OBJECT_ID('ref.Users')
UNION ALL SELECT 'ref.UserPersonnelMap', OBJECT_ID('ref.UserPersonnelMap')
UNION ALL SELECT 'rpt.DailyProductRisk', OBJECT_ID('rpt.DailyProductRisk')
UNION ALL SELECT 'rpt.MonthlyProductRisk', OBJECT_ID('rpt.MonthlyProductRisk')
UNION ALL SELECT 'rpt.DailyStockBalance', OBJECT_ID('rpt.DailyStockBalance')
UNION ALL SELECT 'dof.Findings', OBJECT_ID('dof.Findings')
UNION ALL SELECT 'dof.FindingDetails', OBJECT_ID('dof.FindingDetails')
UNION ALL SELECT 'dof.Actions', OBJECT_ID('dof.Actions')
UNION ALL SELECT 'dof.Evidence', OBJECT_ID('dof.Evidence')
UNION ALL SELECT 'dof.StatusHistory', OBJECT_ID('dof.StatusHistory')
UNION ALL SELECT 'ai.AnalysisQueue', OBJECT_ID('ai.AnalysisQueue')
UNION ALL SELECT 'ai.SemanticVectors', OBJECT_ID('ai.SemanticVectors')
UNION ALL SELECT 'ai.LlmResults', OBJECT_ID('ai.LlmResults')
UNION ALL SELECT 'ai.Embeddings', OBJECT_ID('ai.Embeddings')
UNION ALL SELECT 'ai.Feedback', OBJECT_ID('ai.Feedback')
UNION ALL SELECT 'ai.PredictionModels', OBJECT_ID('ai.PredictionModels')
UNION ALL SELECT 'ai.RiskPredictions', OBJECT_ID('ai.RiskPredictions')
UNION ALL SELECT 'audit.Users', OBJECT_ID('audit.Users')
UNION ALL SELECT 'audit.Audits', OBJECT_ID('audit.Audits')
UNION ALL SELECT 'audit.AuditItems', OBJECT_ID('audit.AuditItems')
UNION ALL SELECT 'audit.AuditResults', OBJECT_ID('audit.AuditResults')
UNION ALL SELECT 'audit.AuditResultPhotos', OBJECT_ID('audit.AuditResultPhotos')
UNION ALL SELECT 'audit.Skills', OBJECT_ID('audit.Skills')
UNION ALL SELECT 'audit.SkillVersions', OBJECT_ID('audit.SkillVersions')
UNION ALL SELECT 'audit.AuditLog', OBJECT_ID('audit.AuditLog')
ORDER BY Expected;

-- NULL ObjectId = tablo bulunamadı = rename eksik
```

---

## 7. ÖNCELIK SIRASI (REVİZE)

| Sıra | Faz | Prompt | Süre | Not |
|------|-----|--------|------|-----|
| 1 | Hazırlık | — | 1 gün | Git + klasör taşıma |
| 2 | DB Standardizasyon | 1, 2 | 3-5 gün | Türkçe → İngilizce rename |
| 3 | Schema Taşıma | 3 | 1 gün | dbo → audit |
| 4 | SP Güncelleme | 4 | 2-3 gün | ~50 SP yeni adlarla |
| 5 | C# Kod Güncelleme | 5 | 2-3 gün | Model + SQL string'ler |
| 6 | AI Multi-Provider | 6 | 1-2 gün | Claude API ekleme |
| 7 | Event Genişletme | 7 | 2 gün | ERP + saha birleşik pipeline |
| 8 | Web + Dashboard | 8 | 3-5 gün | Birleşik UI |
| 9 | RBAC | 9 | 2-3 gün | Auth sistemi |
| 10 | Eksik Özellikler | 10-17 | 5-10 gün | DOF, bildirim, korelasyon, export |
| **TOPLAM** | | **17 prompt** | **25-40 gün** | |

---

## 8. OLMAYAN AMA OLMASI GEREKENLER

(Önceki planın Bölüm 8 içeriği aynen geçerli — 15 kritik eksik:
RBAC, DOF state machine, bildirim, çapraz korelasyon, export,
mobil UI, AI feedback loop, test, Git/CI/CD, cache, logging,
arşiv politikası, API katmanı, proaktif AI, görselleştirme.
Tüm tablo referansları artık İngilizce.)

---

## 9. src.* VIEW'LERİ — DOKUNMA

**KRİTİK KURAL:** `src.*` view'leri ERP'ye (DerinSIS) bağlıdır.
ERP Türkçe kolon adları kullanır (ehMekanId, ehStokId, ehAdetN, ehTutarN, ehTip, hrkTarih...).
Bu view'ler **DEĞİŞMEZ**. SP'ler src view'lerinden okurken aliasing kullanır:

```sql
SELECT 
    sh.ehMekanId AS LocationId,
    sh.ehStokId AS ProductId,
    sh.ehAdetN AS Qty,
    sh.ehTutarN AS Amount,
    sh.hrkTarih AS TransactionDate
FROM src.vw_StokHareket sh
```

Bu sayede ERP değişse sadece src view'leri güncellenir, tüm sistem İngilizce kalır.


---

## 10. SYSTEM BEHAVIOR KURALLARI

### 10.1 Pipeline Zorunlu
Audit → Finding → Intelligence → DOF → Insight → AI Decision  
Hiçbir adım atlanamaz.

---

### 10.2 AI Karar Mekanizmasıdır
AI:
- aksiyon başlatır
- risk yükseltir
- takip eder
- ignore eder  
İnsan sadece doğrular.

---

### 10.3 Event-Driven Zorunlu
Servisler birbirini direkt çağırmaz.  
Sadece event kullanılır.

---

### 10.4 Deterministic Startup
Sistem:
1. Migration çalıştırır
2. Schema validate eder
3. Sonra ayağa kalkar  

Hata varsa sistem çalışmaz.

---

### 10.5 Repeat Kuralı
Repeat = aynı AuditItem + aynı Location

---

### 10.6 Systemic Kuralı
≥ 3 farklı lokasyon → systemic

---

### 10.7 DOF Kuralı
DOF sonrası tekrar varsa:  
→ ineffective

---

### 10.8 AI Learning
Her AI kararı kaydedilir.

---

## 11. SİSTEM YÖNETİM KURALLARI

### 11.1 Tek SQL Kaynağı
Tüm SQL sadece /sql klasöründe olur.

---

### 11.2 Migration Zorunlu
Hiçbir DB değişikliği manuel yapılamaz.

---

### 11.3 Duplicate Yasak
Aynı tablo / logic birden fazla yerde olamaz.

---

### 11.4 Direkt DB Kullanımı Yasak
Sadece:
- stored procedure
- repository

---

### 11.5 Git Zorunlu
Versiyon kontrol olmadan sistem yoktur.

---

## 12. HATA YÖNETİMİ

### 12.1 Migration Fail
→ sistem durur

---

### 12.2 AI Fail
→ rule engine fallback

---

### 12.3 Event Fail
→ log + retry

---

### 12.4 Partial State Yasak
Yarım çalışan sistem kabul edilmez
