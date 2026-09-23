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

- [ ] **A1. `audit.AuditLog` hiç yazılmıyor** *(plan 06 I4 olarak ele alınıyor)* — `security-principles.md` denetim izi zorunlu kılıyor.
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

- [x] ✅ 2026-08-21 (commit 2b1ebfb, 5e21147) **B1. Semantik katmanı AI context'ine bağla** — `BuildSkillVariablesAsync` içinden `sem.sp_Context_Build` çağrılsın. Şu an semantik katman dolu ama LLM'e ulaşmıyor.
- [x] ✅ 2026-08-21 (commit 5e21147) **B2. 10 denetim skill'ini uçtan uca koş** — her biri için gerçek kayıtla bir çalıştırma + çıktı kalitesi değerlendirmesi. Zayıf çıktı veren prompt'u revize et (`ai.sp_Skill_Upsert` yeni sürüm üretir).
- [ ] **B4. `sem.vw_Stale` curator akışı** — `session-handoff` sırasında 7 günde bir bayat kayıt taraması.
- [x] ✅ 2026-08-25 **B6. Solum ortak katmanına bağlan (Faz 1)** — `Solum.Abstractions/Core/Web` proje referansı + 4 bağlam adaptörü (`Security/SolumContext.cs`, `Security/ArgusPermissionChecker.cs`). Kanıt: build 0 hata, publish yeşil, Development boot `ValidateOnBuild` geçti. `plans/04-solum-dashboard.md`
- [x] ✅ 2026-08-25 **B7. Kabuk Solum'a taşındı (Faz 2)** — `_Layout` 406→56 satır, ~24 elle yazılmış menü anchor'ı → 12 `MenuItem` (`Features/ArgusMenu.cs`). Açık yan menü (kullanıcı kararı). Kanıt: `/Error` 200, `--solum-accent`=#E30613, mobil çekmece çalışıyor, izin süzmesi 12→5, konsol 0 hata. `plans/04-solum-dashboard.md`
- [x] ✅ 2026-08-25 (commit 91287b4) **B8. Faz 3 — Dashboard Solum ilkelleriyle yeniden yazıldı** — `Index.cshtml` 504→292, 7 sınıf-üretici fonksiyon→0, çıplak hex 2→0, 24 Tailwind kart kabı→`.solum-card`, 4 tablo `SolumTable`, 14 KPI `KpiCard`. Test 17/17. `plans/04-solum-dashboard.md`
- [x] ✅ 2026-08-26 **B9. Oturum açmış kabuk smoke'u** — dev oturum atlama ile yapıldı: ADMIN'de 12/12 menü öğesi, `aria-current` pozitif dalı doğru öğede, gruplu menü alt öğeleri çiziliyor, DENETCI'de grup tamamen gizleniyor.
- [x] ✅ 2026-08-26 **B10. Dalga 1 — 6 ekran Solum ilkellerine taşındı** — sınıf-üretici fonksiyon 23→0, Tailwind kart kabı 30→0, satır içi olay işleyicisi 27→0. `plans/05-solum-tam-tasima.md`
- [ ] **B11. Risk sunum eşiklerini `ref.RiskParameters`'tan oku** — `RiskView.cs` 90/70 sunum eşiği taşıyor; semantik katmanda `KritikSkorEsik` tanımı var (`sql/47:91`). Danışman kuralı "eşiği kodda sabitleme". Skor hesabına DOKUNULMAZ, yalnız rozet rengi.
- [ ] **B12. `<solum-field>` çoklu seçim türü yok** — `Risk/Index`'te mekan/tip onay kutusu grupları elle yazılı (10 kutu). Solum'a bildirildi, üç-ürün eşiğine takılıyor; Solum almazsa `argus-checkgroup` kalıcı olur.
  - **2026-09-23 KARAR: Solum ALMIYOR** (eşik 1/3; bkm-magaza `Solum.Web`i açıkça reddetti, yani o taraftan eşik hiç dolmayacak). `argus-checkgroup` **kalıcı**. Mobilde her kutuya 44px elle verildi (`argus-theme.css` `.argus-checkitem`).
- [ ] **B14. Katalog denetim izi ALAN BAZINDA değil** — `sql/83` yalnız `UpdatedByUserId` + `UpdatedAt` yazıyor, yani **son dokunan**. İkinci düzenleme birincinin failini üzerine yazar; hangi alanın neyden neye gittiği hiçbir yerde yok ve `audit.AuditLog`'a satır da yazılmıyor. `security-principles.md` "Referans tanım değişikliği"ni zorunlu audit listesinde sayıyor. (sql-sp-reviewer, confidence 92)
- [ ] **B15. `audit.AuditItems.FindingType` için kod kümesi CHECK'i yok** — izin verilen küme U/G/I ama tek savunma C#'taki `[StringLength(1)]`. SP'yi doğrudan çağıran ikinci bir yol doğduğunda sessiz kırpma geri gelir. `sql/83`'ün kendi argümanı ("CHECK tek gerçek kapı") bu alana uygulanmadı. (sql-sp-reviewer, confidence 85)
- [ ] **B16. Pasif maddeler AI bağlamına akıyor** — `sql/68_skill_context_build.sql:212,320` `FROM audit.AuditItems` diyor, `IsActive` süzgeci yok. Emekliye ayrılan madde LLM context'inde canlıymış gibi durur. `sql/83`'ün CRITICAL bulgusunun (denetim seed'i) küçük kardeşi. (sql-sp-reviewer, confidence 90)
- [ ] **B17. `/Audit/Create` Solum'a taşınmamış** — ölçüldü 2026-09-23, 375px: 4 öğe 44px dokunma hedefinin altında, alanlar `mt-1 w-full rounded-lg border…` yani ham Tailwind. `.solum-input` gölgelemesi bu ekrana ulaşmıyor. Plan 05 Dalga 3 kalemi; Items ile aynı sınıf.
- [ ] **B18. `src/BkmArgus.Installer/sql/` aynası 22'de durmuş** — 30–83 arası ~60 migration dosyası orada **yok**. Kurulumcu yolundan kurulan bir DB ne CHECK constraint'leri ne yeni SP'leri alır; `sql/83`'ün "SP dışı her yol buradan geçer" vaadi o kurulumda geçersiz. Sistemik borç. (sql-sp-reviewer, confidence 95)
- [ ] **B19. `sys.check_constraints` guard'ları şema ile nitelenmemiş** — `sql/83:87,92` `WHERE name = 'CK_AuditItems_*'`; constraint adları yalnız şema içinde tekil. `IF OBJECT_ID(N'audit.CK_…', N'C') IS NULL` daha kesin. Ayrıca guard, constraint `NOCHECK` (untrusted) durumdaysa onarmaz. (sql-sp-reviewer, confidence 85)
- [ ] **B13. `/Audit/Items` Solum'a taşı** — ⚠️ **KOD BİTTİ, MIGRATION UYGULANMADI** (2026-09-23, plan 08). Ekran taşındı ve ölçüldü (taşma 44px→0, dokunma hedefi 8→0/191, `inputmode` 0/3→3/3, satır içi olay 2→0); `sql/83_audit_items_butunluk.sql` yazıldı ama **DB'ye koşulmadı** — bağlantı dizesine erişilemedi. Uygulanana kadar madde ekleme/güncelleme **hata verir** (SP'ler `@KullaniciId` tanımıyor). Kapanış: migration + SP smoke'u (`docs/journal/2026-09-23-oturum-2-kalan-isler.md` §1-2). Özgün tespit: — plan 05 Dalga 1'de atlanmış tek liste ekranı; 236 satır ham Tailwind, elle yazılmış 6 kolonlu tablo. **Ölçüldü 2026-09-23, 375px:** yatay taşma **44px**, 3 sayısal alanın hiçbirinde `inputmode` yok, **8 alan** 44px dokunma hedefinin altında, düzen 3 kolon. Taşmanın doğrudan suçlusu `xl:grid-cols-[1fr_380px]` ızgara öğesinin `min-width: auto` olması. Tek satır CSS taşmayı kapatır ama diğer ikisi kalır — kullanıcı kararı (2026-09-23): **yarım düzeltme değil, taşıma**. Hedef: `<solum-field>` · `.solum-card` · `SolumTable` veya `.solum-row` (satırda aksiyon var, `Audit/Index`'teki gerekçeye bak).
- [ ] **B5. Skill yönetim ekranı** — `ai.Skills`/`SkillVersions` için Razor sayfası (prompt görüntüle, sürüm geçmişi, aktif/pasif). Şu an sadece SQL'den yönetilebiliyor. `Policies.AdminOnly`.

---

## FAZ C — Teknik Borç

- [ ] **C1. `Features/Ref/Index` böl** — 1214 satır PageModel + 1145 satır Razor, 8 sekme tek dosyada. Sekme başına partial + `RefService`. `csharp-conventions.md` 500 satır kırmızı çizgisi.
- [ ] **C2. `LlmService.cs` (1129) ve `AiWorkerService.cs` (936) böl** — sağlayıcı başına dosya.
- [ ] **C3. 62 build uyarısını sıfırla** — çoğu nullable (CS8618/8601/8603). Doğru çözüm `required`/`init`, pragma değil.
- [ ] **C4. Ölü dosyaları kaldır** — `TestDebug.cs` (ikinci `Main`, CS7022), `DbTest.cs`, `DebugTest.cs`, `TestEmbedding.cs` prod binary'sine giriyor.
- [ ] **C5. `AiWorkerService.cs:726` inline SQL** — `log.Notifications` INSERT'i SP'ye taşı (kendi SP-first kuralımızın ihlali).
- [ ] **C6. Kullanılmayan `timeoutMinutes`** — `AgentPipelineMonitorJob` ve `RiskPredictionJob`'da atanıp kullanılmıyor; timeout mantığı hiç yazılmamış.
- [x] ✅ 2026-08-25 **C8. Solum kabuk commit'lerinde denetçi koşumu borcu** — Faz 4'te koşuldu: kural-uyum (sonnet) + güvenlik (opus). Bulgular kapatıldı ya da aşağıya madde olarak taşındı. Not: BkmArgus'un kendi `code-reviewer`/`security-reviewer` ajanları yüklü değildi (oturum başka repo kökünde açıldı); aynı kural dosyaları + görev tanımı verilen genel denetçilerle koşuldu.
- [ ] **C10. `FallbackPolicy` ile varsayılan `[Authorize]`** — güvenlik denetimi (2026-08-25) `/Urun/Index`'i yetki kapısı olmadan buldu (kapatıldı). Mekanik çözüm: `Program.cs`'te `options.FallbackPolicy = RequireAuthenticatedUser()` + `Login`/`Logout`/`AccessDenied`/`Error`'a `[AllowAnonymous]`. Böylece attribute yazmayı unutmak bir daha açık üretmez. Auth yüzeyi → Tier 3, plan gerekir.
- [ ] **C11. Güvenlik başlıkları yok** — `Content-Security-Policy` / `X-Content-Type-Options` / `Referrer-Policy` / `X-Frame-Options` repoda hiç yok (grep temiz). CSP yazılacağı gün `_ArgusNotifications`'taki 3 inline `onclick` `unsafe-inline` gerektirecek → önce onları `addEventListener`'a taşı. Prod için Tailwind CDN yerine yerel build.
- [ ] **C12. `NU1903` yüksek önem dereceli paket açığı** — `SQLitePCLRaw.lib.e_sqlite3 2.1.11` (AiWorker üzerinden, testlere de sızıyor). Sürüm yükseltme veya bağımlılığı kaldırma.
- [ ] **C13. Uygulama `sa` ile bağlanıyor** — `appsettings.Local.json` (gitignore'lu) `User Id=sa`. `security-principles.md §14` "uygulama `sa` ile bağlanmaz" diyor; kısıtlı login + yalnız gerekli şemalarda `EXECUTE`.
- [ ] **C14. `SqlDb.cs:34,48` çıplak `catch { }`** — footer DB hatasını sessizce "bağlantı yok"a çeviriyor. Sızıntı değil ama sessiz yutma (`error-handling.md`). Minimum `LogWarning`.
- [ ] **C15. `DashboardView.RozetSinifi` magic string yığını** — ~13 çıplak durum kodu. `csharp-conventions.md §Magic String` sabit sınıfı istiyor ama `DofStatus`/`RiskType`/`AiStatus` projede **tanımlı değil** (denetçi grep ile doğruladı). Ya `Domain/StatusCodes.cs` yazılır (DÖF/AI/denetim ekranlarını da kapsar, ayrı iş) ya `DashboardView` içinde iyi/orta/kötü dizilerine gruplanır.
- [ ] **C16. Türkçe metot adları vs `turkish-ui.md`** — `DashboardView` public metotları Türkçe (`RozetSinifi`, `TrendDeltasi`…); kural "C# tanımlayıcıları İNGİLİZCE" diyor ve mevcut BkmArgus kodu İngilizce. Yeniden adlandır (Faz 4 kalanı) veya kuralı netleştir.
- [ ] **C17. Kabuk parçalarında layout amaçlı inline `style`** — `_ArgusTopbar:39`, `_ArgusNotifications:64,68,70`, `_ArgusFooter:24`. Kuralın harfi yalnız renk/font/border'ı yasaklıyor ama gerekçe yorumu yok; `argus-theme.css`'e sınıf çıkar.
- [ ] **C18. Dev oturum atlama — yayın uyarısı** — `appsettings.Local.json` publish çıktısına KOPYALANIYOR (csproj `CopyToOutputDirectory`). Bayrak makinede açıkken publish edilirse üretimde uygulama açılışta hata verir (kanıtlandı, fail-loud). Yayın öncesi bayrağı kaldır ya da bayrağı ortam değişkenine taşı.
- [ ] **C9. Solum referansı commit'siz çalışma ağacına bağlı** — `ProjectReference` `D:\Dev\solum` kaynağını derliyor; o repoda commit'lenmemiş bir değişiklik BkmArgus build'ini kırabilir ve BkmArgus commit'i "hangi Solum hâline karşı derlendi" bilgisini taşımıyor. Faz 1+2 doğrulaması Solum `0411b67`'ye karşı yapıldı. Kalıcı çözüm: yerel besleme/`.nupkg` veya submodule (kullanıcı kararı).
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

---

## FAZ G — Pazar Boşluğu (2026-08-20 rakip araştırması)

20+ ticari ürün + GitHub taraması. **Konumlanma doğrulandı:** ERP sürekli denetim + saha denetimini tek üründe birleştiren yalnızca MetricStream (\$75K+/yıl, enterprise-only), **Diligent One** (medyan \$23.8K, giriş \$5K) ve **Agilence** (perakendeye özel) var. Açık kaynak muadili yok. En yakın açık kaynak (`cockpit-labs/CockpitCE`, perakende mağaza denetimi) 2022'de ölmüş, 3 yıldız.

Mimari referans: **Diligent One** — ACL Robotics "P2P Analysis for SAP ERP" = bizim ETL kanalımız, Projects mobil fotoğraf/ses kanıtı = saha kanalımız. İkinci referans **Agilence** (exception-based reporting + case management + store audit üçlüsü).

### Doğrulanan tercihlerimiz

- **LLM sayı üretmez** — Optro "deterministic ML + retrieval + LLM harmanı", MindBridge LLM'i **hiç kullanmıyor**, Workiva izlenebilir çıktı. Hiçbir ticari ürün LLM'i sayısal hesaplama/skorlama için kullanmıyor. `ai-layer.md` halüsinasyon kapımız sektör standardıyla aynı.
- **Versiyonlu prompt kütüphanesi** — IIA-NL GenAI olgunluk modelinde **Seviye 2**; `ai.Skills`/`SkillVersions` ile zaten oradayız.
- **Kademeli maliyet** — rakiplerden disiplinli.

### G1. AI denetim izi eksik alanları — AB AI Act Art. 12/19

`ai.SkillExecutions`'a ekle: `PromptHash` (SHA-256), `ResponseHash`, **tam model versiyonu** (`ModelName` yetersiz — patch dahil), `Temperature`, `TopP`, `InputTokens`, `OutputTokens`, `ProviderUsed`, `FallbackChain`, `LatencyMs`.
Not: **temperature 0 tekrarlanabilirlik garanti etmez** — savunma bit-exact çıktıya değil hash izine dayanmalı. Art. 19: min 6 ay saklama.

### G2. Halüsinasyon kapısını koda indir

Kural olarak yazdık ama **programatik kontrol yok**. LLM çıktısındaki her sayıyı context'teki sayılarla eşleştir; eşleşmeyen sayı içeren çıktıyı **reddet**, uyarıyla sakla.

### G3. Onayı kontrole yükselt + gate koy

`ai.Feedback` şu an memnuniyet oyu. CAQ kriteri: onaylayan **completeness + accuracy + relevancy** kontrolünü işaretlemeli, sistem onaylayanın rol/yetkinliğini kaydetmeli.
Ayrıca **kapı**: AI çıktısı onaylanmadan DÖF/aksiyon tetikleyemesin. HITL'i **seçici** yap — her çıktıya onay hem ölçeklenmez hem *automation bias* üretir.

### G4. Alarm yorgunluğu — eşik tabanlı önceliklendirme

Svanberg vd. (2025, *ISAF* 32/4): CA sistemleri 30 yıldır aynı yerde takılı — **çok fazla istisna üretip terk ediliyorlar**. Kural tabanlı tasarımın çıktı hacmini öngörülebilir kontrol mekanizması yok.
Bizim `ai.Feedback` onay/ret verisi **zaten etiket üretiyor**. 1.000+ etikete ulaşınca: XGBoost + olasılık eşiği + SHAP açıklaması; denetçi eşiği günlük kapasitesine göre ayarlasın. Ön koşul: hata oranı ≥%1, kararlı veri yapısı.
*(Bu, mevcut geri bildirim döngümüzün doğal devamı — yeni mimari değil.)*

### G5. Fotoğrafa vision AI — saha kanalının en görünür açığı

`src/BkmArgus.AiWorker/` içinde **hiç görüntü işleme yok**; fotoğraflar yalnızca diskte duruyor. Rakiplerin hepsinde var: Mitti (fotoğraftan otomatik issue), Crunchtime Photo Intelligence, FieldPie raf/fiyat/etiket tanıma, Wooqer SensEye.
Kitapçı/kafe için: raf düzeni, fiyat etiketi tutarlılığı, temizlik/hijyen, teşhir uyumu.

### G6. Kanıt zinciri

`audit.AuditResultPhotos` şu an `FilePath + Remark + CreatedAt`. Ekle: **SHA-256 hash, EXIF çekim zamanı, yükleyen kullanıcı, GPS**. Üstüne mobil offline (PWA + service worker + IndexedDB) ve check-in GPS doğrulaması.
MetricStream, FieldPie, PEAKUP'ta standart. Türkiye'de satışa çıkarsak ilk sorulacak şey.

### G7. Denetim yönetimi katmanı — en büyük fonksiyonel açık

Klasik iç denetim yazılımının standardı, bizde **hiç yok**:

| Eksik | Not |
|---|---|
| **Denetim evreni** | Mağaza/kafe/süreç envanteri + son denetim tarihi + son bulgu |
| **Risk-bazlı yıllık plan** | Ağırlıklı skor → frekans. **ERP risk sinyallerimiz bu skoru otomatik besleyebilir — kimse bunu yapmıyor.** Farklılaşma noktası |
| **Görev yaşam döngüsü** | `audit.Audits`'te sadece `IsFinalized` bit'i. Planning → Fieldwork → Reporting → Closure fazı, kapsam/amaç, saha tarih aralığı yok |
| **Çalışma kağıdı** | Prosedür → test → kanıt → sonuç zinciri |
| **Hazırlayan/gözden geçiren imzası** | Tek `IsFinalized` var, ikinci göz yok |
| **Örnekleme** | İstatistiksel + yargısal, MUS, örneklem büyüklüğü |
| **Komite raporlaması** | Çeyreklik paket: bulgu özeti, plan gerçekleşme %, açık DÖF yaşlandırma |

### G8. DÖF olgunluğu

Mevcut state machine iyi bir temel (`DRAFT → OPEN → IN_PROGRESS → PENDING_VALIDATION → CLOSED/REJECTED`, rol bazlı geçiş, `EffectivenessScore`). Eksikler:
- **Gecikmeli etkinlik doğrulaması** — ISO 9001 md.10.2.1.d: kapanıştan N gün sonra tekrar kontrol. Şu an kapanışta tek seferlik skor. *(`dof.effectiveness.review` skill'i bu soruyu soruyor ama tetikleyici yok.)*
- **Düzeltme ≠ düzeltici ≠ önleyici ayrımı** — ISO 9001 10.2.1.a/b/c. Şu an tek "aksiyon" kavramı; anlık düzeltme ile sistemik önlem ayrışmıyor.
- **Yapılandırılmış kök neden** — tek `CorrectRootCause varchar(100)`. 5 Neden/Ishikawa alanları yok. *(`audit.rootcause.5why` skill'i var, veri modeli yok.)*
- **Tekrarlama tespiti** — aynı mekan + aynı bulgu tipi X ay içinde tekrar ederse otomatik "sistemik".

### G9. KVKK — yurt dışına aktarım riski

Gemini/Claude'a giden prompt'lar **mekan adı, personel adı, ürün/stok verisi** içeriyor. Bu KVKK açısından yurt dışına aktarım sorusudur.
Seçenekler: PII tokenizasyonu (prompt öncesi maskeleme), yerel Ollama'ya yönlendirme (kişisel veri içeren skill'ler için), veya açık rıza/aktarım dayanağı.
IBM 2025: AI modeli içeren ihlal bildiren kuruluşların **%97'si yetersiz AI erişim kontrolüne** işaret etmiş.

### G10. ISO 21378:2019 — `src.*` katmanını standarda hizala

ERP-bağımsız modüler audit veri standardı (Base/GL/AR/Sales/AP/Purchase/Inventory/PPE). Tam olarak `src.*` soyutlama katmanımızın çözmeye çalıştığı problemi standartlaştırıyor.
Kazanç: yeni ERP'ye geçişte eşleme maliyeti düşer, dış denetçiye veri teslimi standart olur, **"ISO 21378 uyumlu veri çıkarıyoruz" satılabilir bir iddia** olur. Tamamlayıcı: AICPA Audit Data Standards + Audit Data API.

### Referans kaynaklar

- IIA GTAG *Continuous Auditing* 2nd ed. — CA'in gücü CM ile **koordine edildiğinde** ortaya çıkar
- IIA *AI Auditing Framework* (Eyl 2024) — "Desirable Attributes for AI" doğrudan denetim kriteri; iç denetim AI'a **yalnızca sınırlı güvence** verebilir
- CAQ *Auditing in the Age of Generative AI* (Nis 2024) — automation bias, explainability vs interpretability, "çıktı bağımsız yeniden üretilebiliyor mu" kriteri
- IIA-NL *Internal Audit in the Age of GenAI* (2025) — 5 seviyeli olgunluk modeli (biz Seviye 2'deyiz, hedef 4/RAG)
- Vasarhelyi MCL mimarisi — bizim `src.* → ETL → rpt.* → LM Rules → ai.* → DÖF` zincirinin akademik karşılığı

**Not:** "AI kanıt olamaz" kategorik olarak yanlış. Doğru formülasyon: AI çıktısı **tek başına yeterli ve uygun denetim kanıtı değildir**; üreten süreç üzerindeki kontroller test edilebilir ve çıktı bağımsız doğrulanabilir olmalıdır. IAASB ISA 500 revizyonu henüz yayımlanmadı, PCAOB'un bağlayıcı AI kuralı yok (2026 ortası).

---

## FAZ H — Semantik Hafıza (2026-08-21 ölçümleri)

Vektör hafızası kuruldu ve **ölçüldü**. Kararlar tahmine değil sayıya dayanıyor.

### Yapıldı

- [x] ✅ Yerel ONNX embedding (`multilingual-e5-base`, 768 boyut, 74 ms/kayıt) — Ollama bağımlılığı kalktı, veri makineden çıkmıyor (G9/KVKK kapandı)
- [x] ✅ Kaynak havuzu 2 → **189** (DÖF + saha denetimi + AI analizi, ağırlıklı)
- [x] ✅ Hibrit arama: vektör + C# BM25, RRF ile birleştirme (k=15) — **6/6** (tek başına vektör 5/6, BM25 5/6)
- [x] ✅ Ağırlık çarpan olmaktan çıktı — `ham × ağırlık` sıralaması içeriği eziyordu
- [x] ✅ Şablon öneki gömme metninden çıkarıldı
- [x] ✅ `sp_SemanticVector_UpsertGolden` onarıldı (parametre adları + `EmbeddingModel`)

### Ölçülüp REDDEDİLENLER — tekrar denemeden önce oku

| Deneme | Sonuç | Karar |
|---|---|---|
| **Cross-encoder reranker** (`mmarco-mMiniLMv2-L12`, 113 MB) | Top-1 **7/8 → 5/8**, 533 ms/sorgu. Skorlar çoğunlukla negatif — mMARCO'nun 14 dilinde **Türkçe yok**, model bu görevde Türkçe görmemiş | **Eklenmedi** |
| **Ortalama merkezleme** (anizotropi çaresi) | Her sorguyu tek kayda çöktürdü, marj sıfırlandı | **Uygulanmadı** |
| **Vektör DB / ANN indeksi** | 189 × 768 float = 581 KB; ölçülen tarama süresi 28 ms. Bu boyutta ANN indeksi eğitilemez | **Gereksiz** |
| **Chunking** | Metinler ortalama 170 karakter, 512 token limitinin onda biri | **Gereksiz** |

Yeniden değerlendirme eşiği: ANN için ~50.000 kayıt. Reranker için Türkçe eğitilmiş bir cross-encoder çıkarsa.

### Açık

- [x] ✅ 2026-08-21 **H1. Ölçüm seti kuruldu** — `ai.RetrievalEvalSet` (30 elle yazılmış Türkçe sorgu) + `ai.RetrievalEvalRuns` + `RetrievalEvalTests`. Ground truth kaynak kayıt ID'si, karar deterministik.
- [ ] **H2. RRF k'sını ölç** — 15 seçildi (60 bu boyutta sıraları düzleştirir) ama ölçülmedi. H1 hazır olunca k=10/15/20/60 karşılaştır.
- [ ] **H3. Yinelenen kayıt** — 189 vektörün yalnız 95'i tekil. Aynı checklist maddesi farklı denetimlerde tekrar ediyor; arama sonucunda tekilleştir.
- [ ] **H4. Semantik hafızayı skill context'ine bağla** — B1 ile aynı iş; hafıza dolu ama LLM'e ulaşmıyor.
- [ ] **H5. Geri bildirim döngüsü** — `ai.Feedback` hâlâ 0 satır. Onaylanan çıktı GOLDEN vektöre dönüşüyor (hat artık çalışıyor) ama besleyen yok.

### ⚠️ Asıl darboğaz: veri yok

| Alan | Dolu |
|---|---|
| `AuditResults.Remark` (denetçi gözlemi) | **0 / 91** |
| `Findings.EffectivenessNote` ("nasıl çözüldü") | **0 / 84** |
| `Findings.Description` | 84/84 ama ortalama 75 karakter, otomatik iskelet |

Arşivin tamamı **checklist sorusu**. "Benzer durumda geçmişte ne yapıldı" sorusunun kaynağı sistemde yok. Çiftler arası benzerlik ortalaması **0.8803** — 189 tane "X yapılıyor mu?" gerçekten birbirine benziyor.

Hiçbir retrieval mimarisi bunu çözmez. Çözüm veri yakalamada:

- [ ] **H6. Denetim ekranı** — madde "HAYIR" işaretlenince `Remark` zorunlu
- [ ] **H7. DÖF kapanışı** — `EffectivenessNote` zorunlu (ne yapıldı, sonuç ne)
- [ ] **H8. DÖF açılışı** — otomatik iskeletin yanına serbest metin alanı

---

## FAZ I — Dalga 1 kapanış denetimi borçları (2026-08-26)

Üç denetçi (`code-reviewer` · `security-reviewer` · `silent-failure-hunter`) Dalga 1
kapanışında koştu. Sunum/sessiz-hata bulgularının **tamamı aynı gün kapatıldı**
(commit gövdesinde ölçümler). Aşağıdakiler SQL/şema/yetki gerektirdiği için
**plan 06**'ya taşındı; buradaki satırlar o planın izidir.

### Plan 06 — sunucu kapıları (SQL + yetki)

- [ ] **I1. DÖF geçişinde kullanıcı-kapsam kapısı** — `dof.sp_Finding_Transition`
      kaydın çağıranın kapsamında olduğunu doğrulamıyor; `OPEN→IN_PROGRESS` ve
      `IN_PROGRESS→PENDING_VALIDATION` rol istemediği için DENETCI `dofId`
      döngüsüyle kendisine atanmamış tüm açık DÖF'leri taşıyabiliyor.
      **YÜKSEK** (`security-reviewer` conf 95). Domain kararı gerekiyor
      (`denetim-surec-danismani`): atanan+oluşturan+yönetici mi, mekan kapsamı mı.
- [ ] **I2. `dof.sp_Finding_List` kapsamsız** — pano herkese her DÖF'ü gösteriyor.
      I1 ile aynı kapsam çözümüne bağlanmalı; yoksa kullanıcı taşıyamadığı kartı
      görmeye devam eder.
- [ ] **I3. `/api/*` üçlüsünde antiforgery yok** — `dof/transition`,
      `notifications/mark-read`, `mark-all-read`. Savunma yalnız `SameSite=Lax`;
      parametreler sorgu dizesinde. Aynı-site alt alan adı senaryosu açık.
      Parametreler JSON gövdeye + tek yardımcıya bağlı token doğrulaması.
- [ ] **I4. `audit.AuditLog`'a yazan tek yol yok** (= eski A1) — silme, finalize,
      DÖF geçişi, Excel dışa aktarım, AI skill çalıştırma izsiz. `audit.sp_AuditLog_Write`
      + `Services/AuditTrail.cs`, sonra beş noktaya bağla.
- [ ] **I5. Denetim silmede kapsam kontrolü SP'de yok** — herhangi bir DENETCI
      başka mekanın taslak denetimini silebiliyor; `AuditResults` + `AuditResultPhotos`
      CASCADE ile gidiyor. C# tarafı bugün kapandı (try/catch + THROW köprüsü +
      onay metninde madde sayısı), **kapsam kapısı SP'de duruyor**.
- [ ] **I6. Risk listesinde gerçek toplam yok** — `PagedResult` yalnız o sayfanın
      satır sayısını taşıyor, Solum'un sayfalayıcısı hiç çizilmiyor. SP'ye
      `COUNT(*) OVER()` eklenecek. Bugün C# tarafında yalnız "bu sayfa boş" ile
      "kayıt yok" ayrıldı.
- [ ] **I7. `rpt.sp_RiskList` dışa aktarım kipi** — SP `@PageSize`'ı 200'e kırpıyor;
      dışa aktarım şu an 25 çağrılık **sayfa döngüsüyle** 5000 satır topluyor
      (ölçüldü: 28 sn). `@Export bit` ile tek çağrıda alınmalı.
- [ ] **I8. Kesim aralığı semantiği** — SP iki tarihi aralık olarak KULLANMIYOR,
      aralıktaki `MAX(SnapshotDate)` gününü listeliyor. Bugün ekran gerçeği
      yazıyor; karar (`bkmargus-etl`): tek "kesim günü" alanına inmek mi, gerçek
      aralık desteği mi.
- [ ] **I9. Ürün DÖF geçmişi veri yolu** — `Doflar` koleksiyonu hiç doldurulmuyordu
      ve ekran "DÖF kaydı yok" diyordu (**CRITICAL**, mükerrer DÖF riski). Bugün
      ekran iddiayı bıraktı; ürün bazlı DÖF listesi SP'si yazılacak.
- [ ] **I10. Denetim listesi bitiş tarihi SP'de** — `AuditDate <= @Bitis` aynı günü
      düşürüyor. C# şimdilik gün sonuna çekiyor; doğrusu SP'de
      `AuditDate < DATEADD(day, 1, CONVERT(date, @Bitis))`.
- [ ] **I11. `rpt.sp_RiskList` snapshot yok bayrağı** — ETL koşmamışsa SP
      `RETURN` ile hiç sonuç kümesi döndürmüyor; ekran "süzgeci genişletin"
      diyor ve kullanıcı ETL'in çalışmadığını asla öğrenmiyor.
- [ ] **I12. DÖF SP mesajları İngilizce** — `Invalid transition: ...`,
      `already in status ...`. `turkish-ui.md` ihlali. C# tarafında iki kalıp
      Türkçeye eşlendi (fallback sızdırmıyor), doğrusu SP'de Türkçe yazmak.
- [ ] **I13. Denetim listesinde sayfalama yok** — en yeni 100 kayıt. Bugün kırpma
      uyarısı basılıyor; Risk ekranındaki sayfalama deseni buraya da gelecek.
- [ ] **I14. DÖF panosu kolon başına sayfalama** — pano en yeni 100 bulguyla
      sınırlı ve gecikmişler tanım gereği eski olduğu için kırpılan dilime
      düşüyor. Bugün uyarı basılıyor; doğrusu kolon başına yükleme + sunucu sayacı.

### Solum'a bildirilenler (bu dalgadan)

- [ ] **I15. `.solum-alert-warn` yok** — Solum'da `-good` / `-bad` var, uyarı tonu
      yok (ölçüldü: `solum.css:403-405`). Üç ekranda kırpma/uyarı bandı gerekti;
      şimdilik `argus-alert-warn` (footprint-ladder 1. basamak, `solum-*` adı
      gölgelenmedi). İkinci tüketicide pakete girmeli.
- [ ] **I16. `Dof/Detail` hâlâ Tailwind + çıplak durum dizesi** — altı durum kodu
      ve Türkçe etiket eşlemesi üç ayrı `switch`te tekrarlıyor. `Domain/DofStatus`
      sabit sınıfı bugün yazıldı ve `Dof/Index` ona bağlandı; `Detail` Dalga 2'de.

---

## Tamamlananlar

- [x] ✅ 2026-08-20 Sır temizliği — 4 API key + 2 DB şifresi tüm geçmişten kaldırıldı (`git filter-repo`)
- [x] ✅ 2026-08-20 RBAC — `Roles`/`Policies`, sayfa politikaları, AccessDenied, nav filtresi (`7712f74`)
- [x] ✅ 2026-08-20 `.claude` yığını — 23 kural, 15 ajan, 12 skill, 5 hook (`41f2946`)
- [x] ✅ 2026-08-20 DB tabanlı skill registry + 10 denetim skill'i + semantik katman (`48a5bc4`)
- [x] ✅ 2026-08-20 Cookie/HTTPS dev uyumu, login default şifre kaldırma, user-enumeration kapatma
- [x] ✅ 2026-08-20 `bkmargus-etl` + `bkmargus-risk-model` skill dosyaları (advisor-skills referansları kapandı)
- [x] ✅ 2026-08-21 F5 kök dizin temizliği — 23 dosya kaldırıldı; kaynağı bulundu (RiskAnaliz'den kopyalanmış)
- [x] ✅ 2026-08-21 `D:\Dev\RiskAnaliz` + `D:\Dev\icdenetim` → `D:\Dev\_archive\` (git'siz snapshot'lardı, içerikleri BkmArgus'ta doğrulandı)
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
