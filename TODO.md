# BkmArgus — Yapılacaklar

Süreç katmanı (`.claude/rules/session-memory.md`). Kimlik → `CLAUDE.md`, kurallar → `.claude/rules/`, Tier 3 planlar → `plans/NN-*.md`.

**Durum tarihi:** 2026-08-20 · **Build:** 0 hata / 62 uyarı · **DB:** 62 tablo, 163 SP (9 şema)

---

## Nerede duruyoruz

| Alan | Durum | Kanıt |
|---|---|---|
| ERP ETL | ✅ Çalışıyor | `rpt.DailyProductRisk` 65.960 satır |
| Saha denetimi CRUD | ✅ Çalışıyor | 5 denetim, 91 sonuç, 87 madde |
| DÖF süreci | ✅ Çalışıyor | 84 bulgu, 104 durum geçişi |
| Auth + RBAC | ✅ Bağlandı | `Roles`/`Policies`, AccessDenied, nav filtresi |
| Sır yönetimi | ✅ Temizlendi | Geçmiş yeniden yazıldı, `appsettings.Local.json` |
| AI skill motoru | ⚠️ Yarı | Prompt'lar DB'de (`ai.Skills` 10 kayıt) ama uçtan uca koşulmadı |
| Semantik katman | ⚠️ Yarı | `sem.*` kuruldu + seed edildi, AI context'e bağlanmadı |
| LLM sonuç kalıcılığı | ❌ Kopuk | `ai.LlmResults` **0 satır** |
| Denetim izi | ❌ Yok | `audit.AuditLog` **0 satır** |
| Test | ❌ %3 | 30 test, hepsi `LmRules` + risk eskalasyonu |

---

## FAZ A — Kopuk Hatlar (öncelik: en yüksek)

Boş tablolar "kullanılmıyor" değil, **yazılmıyor** demek. Her biri bir bug.

- [ ] **A1. `audit.AuditLog` hiç yazılmıyor** — `security-principles.md` denetim izi zorunlu kılıyor.
  Kapsam: login/logout/başarısız giriş, şifre değişimi, denetim finalize, DÖF durum geçişi, ref tanım değişikliği, ETL manuel tetikleme, AI skill çalıştırma, export.
  Kabul: her aksiyon sonrası `audit.AuditLog`'da satır; kim/ne/ne zaman/hangi kayıt.
  Tier 3 → `plans/01-audit-log.md`

- [ ] **A2. `ai.LlmResults` boş** — LLM cevapları kalıcı değil, maliyet ve tekrar-kullanım izi yok.
  Kabul: her LLM çağrısı sağlayıcı + model + süre + token + sonuç ile yazılıyor; aynı girdi tekrar sorulmadan önce burası kontrol ediliyor.

- [ ] **A3. `ai.AnalysisQueue` hiç kullanılmamış** — kuyruk mimarisi var, akış `SkillExecutions` üzerinden gidiyor. Karar: kuyruğu bağla **veya** tabloyu emekliye ayır. İkisi arası belirsizlik en kötüsü.

- [ ] **A4. `ai.Feedback` boş** — geri bildirim UI'ı var, tek kayıt yok. Uçtan uca test edilmemiş.
  Kabul: onay/red kaydediliyor **ve** sonraki skill çalıştırmasında context'e giriyor (öğrenme döngüsü kapanıyor).

- [ ] **A5. Boşta duran 6 AI SP'sini bağla** — `ai.sp_Insight_Insert/Action/Dashboard`, `ai.sp_Feedback_Stats`, `ai.sp_AiDashboard_FeedbackTrend`, `ai.sp_Trigger_PostRiskEtl`. Yazılmış ama çağıran yok.

- [ ] **A6. Semantik vektör sync hiç üretmemiş** — kod tam (`AiWorkerService.cs:181-215`, `VectorSyncMinutes: 60`) ama `ai.SemanticVectors` **0 satır**. Kaynak SP (`ai.sp_SemanticVector_SourceList`) boş mu dönüyor, yoksa Ollama embedding mi patlıyor? *(Eski TODO "Semantik hafıza vektör sync" — kod tarafı kapalı, veri tarafı açık.)*

- [ ] **A7. LLM kuyruğu hiç işlememiş** — `LLM_QUEUED` geçişi ve işleyici var (`AiWorkerService.cs:154,429`) ama `ai.LlmResults` **0 satır**. A2 ile aynı kök. *(Eski TODO "LLM queue işleme".)*

---

## FAZ B — Bu Oturumda Kurulanı Tamamla

- [ ] **B1. Semantik katmanı AI context'ine bağla** — `BuildSkillVariablesAsync` içinden `sem.sp_Context_Build` çağrılsın. Şu an semantik katman dolu ama LLM'e ulaşmıyor.
- [ ] **B2. 10 denetim skill'ini uçtan uca koş** — her biri için gerçek kayıtla bir çalıştırma + çıktı kalitesi değerlendirmesi. Zayıf çıktı veren prompt'u revize et (`ai.sp_Skill_Upsert` yeni sürüm üretir).
- [ ] **B4. `sem.vw_Stale` curator akışı** — `session-handoff` sırasında 7 günde bir bayat kayıt taraması.
- [ ] **B5. Skill yönetim ekranı** — `ai.Skills`/`SkillVersions` için Razor sayfası (prompt görüntüle, sürüm geçmişi, aktif/pasif). Şu an sadece SQL'den yönetilebiliyor. `Policies.AdminOnly`.

---

## FAZ C — Teknik Borç

- [ ] **C1. `Features/Ref/Index` böl** — 1214 satır PageModel + 1145 satır Razor, 8 sekme tek dosyada. Sekme başına partial + `RefService`. `csharp-conventions.md` 500 satır kırmızı çizgisi.
- [ ] **C2. `LlmService.cs` (1129) ve `AiWorkerService.cs` (936) böl** — sağlayıcı başına dosya.
- [ ] **C3. 62 build uyarısını sıfırla** — çoğu nullable (CS8618/8601/8603). Doğru çözüm `required`/`init`, pragma değil.
- [ ] **C4. Ölü dosyaları kaldır** — `TestDebug.cs` (ikinci `Main`, CS7022), `DbTest.cs`, `DebugTest.cs`, `TestEmbedding.cs` prod binary'sine giriyor.
- [ ] **C5. `AiWorkerService.cs:726` inline SQL** — `log.Notifications` INSERT'i SP'ye taşı (kendi SP-first kuralımızın ihlali).
- [ ] **C6. Kullanılmayan `timeoutMinutes`** — `AgentPipelineMonitorJob` ve `RiskPredictionJob`'da atanıp kullanılmıyor; timeout mantığı hiç yazılmamış.
- [ ] **C7. Eşikler config'e** — `ProactiveInsightJob` `RiskEsik`/`GunEsik` kodda sabit; `AiWorkerOptions`'a taşı (`ai-layer.md`).

---

## FAZ D — Güvenlik Kapanışı

- [ ] **D1. Anahtar rotasyonu** — 3 Gemini + 1 Claude key iptal + yenile, SQL `sa` şifresi değiştir. *(Geçmişten silindi ama daha önce görülmüş olabilir.)*
- [ ] **D2. `sa` ile bağlanmayı bırak** — uygulamaya kendi login'i, yalnız gerekli şemalarda `EXECUTE`.
- [ ] **D3. Dosya indirme kapısı** — `wwwroot/uploads/dof/` auth'suz servis ediliyor. Auth-gated download handler.
- [ ] **D4. IDOR taraması** — `dofId`/`auditId`/`executionId` alan her handler kullanıcı kapsamını SP'de doğruluyor mu.
- [ ] **D5. RBAC rol testi** — DENETCI ve YONETICI hesaplarıyla her ekranı dene. *(Bu oturumda yalnız kimlik doğrulama kapısı doğrulandı.)*

---

## FAZ E — Test

- [ ] **E1. Auth + RBAC testleri** — policy'ler gerçekten kapatıyor mu.
- [ ] **E2. SP parametre eşleşme testi** — Türkçe SP parametresi ↔ C# anonymous object. Eşleşmezse Dapper **sessizce** atlar; en sinsi hata sınıfı.
- [ ] **E3. ETL idempotency testi** — iki kez çalıştır, sonuç değişmesin.
- [ ] **E4. Skill executor testi** — boş context, JSON parse hatası, sağlayıcı kapalı senaryoları.

---

## FAZ F — Bilinen Açık Sorunlar

- [ ] **F1. Risk Gezgini** — filtre çalışıyor, SP veri dönüyor, tabloda görünmüyor. Kod bütün; muhtemelen `PeriodCode` filtresi (ETL PK düzeltmesi sonrası).
- [ ] **F2. Gemini JSON parse** — ham metin fallback çalışıyor, düzgün parse edilmiyor.
- [ ] **F3. `VectorSyncEnabled` bayrağı yok** — sync'i kapatmak için `VectorSyncMinutes`'a devasa değer vermek gerekiyordu; şu an 60'a çekilmiş ama açık bir aç/kapa bayrağı hâlâ yok.
- [ ] **F4. `docs/` içindeki 5 çakışan plan** — `PLAN.md`, `MASTER_PLAN.md`, `BKMARGUS_PLATFORM_GECIS_PLANI_V2/V3`, `BIRLESTIRME_PLANI_DETAY`. Hangisi geçerli? Biri kalsın, gerisi `docs/archive/`.
- [ ] **F5. Kök dizin temizliği** — `all_files_dump.txt`, `REPO_AUDIT_BUNDLE*.txt`, `utputFormat`, `temp_pw.sql`, çeşitli `.bat` dosyaları.

---

## Tamamlananlar

- [x] ✅ 2026-08-20 Sır temizliği — 4 API key + 2 DB şifresi tüm geçmişten kaldırıldı (`git filter-repo`)
- [x] ✅ 2026-08-20 RBAC — `Roles`/`Policies`, sayfa politikaları, AccessDenied, nav filtresi (`7712f74`)
- [x] ✅ 2026-08-20 `.claude` yığını — 23 kural, 15 ajan, 12 skill, 5 hook (`41f2946`)
- [x] ✅ 2026-08-20 DB tabanlı skill registry + 10 denetim skill'i + semantik katman (`48a5bc4`)
- [x] ✅ 2026-08-20 Cookie/HTTPS dev uyumu, login default şifre kaldırma, user-enumeration kapatma
- [x] ✅ 2026-08-20 `bkmargus-etl` + `bkmargus-risk-model` skill dosyaları (advisor-skills referansları kapandı)
- [x] Ref ekranları ortak düzen
- [x] IrsTip map ekranı sadeleştirme

### Eski TODO maddeleri — 2026-08-20'de kod kanıtıyla doğrulandı

`todo-verification.md` gereği file:line ile kontrol edildi, hipotez olarak kapatılmadı.

- [x] ✅ Personel entegrasyon log sayfası — `Features/Yonetim/Index.cshtml.cs:64,88` (`log.sp_PersonnelSync_Summary`, `_Log_List`)
- [x] ✅ Kullanıcı-Personel bağlantı yönetimi — `Features/Yonetim/Index.cshtml.cs:36,51,99` (List + Close + CloseAll)
- [x] ✅ Footer DB bağlantı durumu — `Features/Shared/_Layout.cshtml:52,57` (`GetDbInfoAsync`, `CanConnectAsync`)
- [x] ✅ Admin/ref ekranları için auth — `Security/Roles.cs` + `Policies.AdminOnly` (commit `7712f74`)
- [x] ✅ AI Worker LM + semantik hafıza — `LmRules.cs:5`, `SemanticMemoryService.cs:9`, DI'da kayıtlı
- [~] Semantik hafıza vektör sync — **kod kapalı, veri açık** → A6'ya taşındı
- [~] LLM queue işleme — **kod kapalı, veri açık** → A7'ye taşındı
