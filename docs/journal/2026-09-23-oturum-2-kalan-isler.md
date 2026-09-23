# Kalan İşler Envanteri — 2026-09-23 (ikinci oturum)

> Companion dosya (`session-handoff` §5 zorunlu). Her açık iş için
> **NE · NEDEN · NEREDE · NASIL KAPANIR · BAĞIMLILIK · ÖNCELİK**.
> Hiçbir madde "hatırlarsın" varsayımı taşımaz.

---

## 1. 🔴 `sql/83_audit_items_butunluk.sql` UYGULANMADI — en kritik

- **NE:** Migration deposunda duruyor, veritabanına koşulmadı.
- **NEDEN:** Bu oturumda DB'ye hiç bağlanılamadı — `BKM_DENETIM_CONN`
  ortam değişkeni tanımsız, `appsettings.Local.json` deny kuralıyla kapalı
  (koruma doğru çalışıyor, kusur değil).
- **NEREDE:** `sql/83_audit_items_butunluk.sql` (7 adım, 2 CHECK constraint
  + 5 `CREATE OR ALTER` SP).
- **NASIL KAPANIR:**
  ```bash
  SQLCLI_CONN="$BKM_DENETIM_CONN" dotnet run --project D:/Dev/sqlcli -- script sql/83_audit_items_butunluk.sql
  ```
  **`migrate` ile DEĞİL** — dosyanın 1. adımındaki veri kapısı "patla ve
  dur" mantığına dayanıyor; toleranslı kip kapıyı geçer, CHECK kurulmaz ama
  SP'ler kurulur ve yarım uygulama sessizce kabul edilmiş olur. Gerekçe
  dosya başında yazılı.
  Sonra **ikinci kez koş** → hata vermemeli (idempotency kanıtı).
- **⚠️ UYGULANMADAN EKRAN ÇALIŞMAZ:** `sp_Item_Insert`/`_Update` yeni
  `@KullaniciId` parametresini tanımıyor, `sp_Item_SetActive` hiç yok.
  Madde ekleme/güncelleme/pasife alma **hata verir**. Liste görünümü
  çalışır (eski SP uyumlu).
- **BAĞIMLILIK:** Bağlantı dizesi. Kullanıcı kararı (2026-09-23): "sen
  uygula".
- **ÖNCELİK:** **1.**

## 2. 🔴 SP smoke'u yapılmadı

- **NE:** `sql/83`'ün ürettiği davranış gerçek kayıtla hiç denenmedi.
- **NEDEN:** Migration uygulanmadı (madde 1).
- **NEREDE:** `/Audit/Items` ekranı + `audit.AuditItems` tablosu.
- **NASIL KAPANIR:** Sırayla, her birinin çıktısıyla:
  1. Madde **ekle** → kayıt oluşuyor mu, `CreatedByUserId` **dolu** mu
  2. Madde **güncelle** → `UpdatedByUserId` + `UpdatedAt` ilerliyor mu
  3. **Pasife al** → listede "Pasif" rozeti, süzgeçte "Yalnız pasif" onu
     getiriyor mu
  4. **Yeni denetim aç** → pasif madde `audit.AuditResults`'a **düşmemeli**
     (bu oturumun CRITICAL bulgusu)
  5. `Impact = 100` POST'u → **50832 ile reddediliyor** mu, kullanıcı Türkçe
     mesaj görüyor mu
  6. Elle `UPDATE audit.AuditItems SET Impact = 100 WHERE Id = <x>` →
     **CHECK ile reddediliyor** mu (SP'yi atlayan yol kapalı mı)
  7. Boş `ItemText` → alan hatası (`<solum-errors>`) görünüyor mu
  8. `FindingType` seç → kaydet → geri aç → **seçim korunuyor** mu
     (bugün "Seçiniz"e düşüyordu)
- **BAĞIMLILIK:** Madde 1.
- **ÖNCELİK:** **1** (madde 1'in hemen ardından).

## 3. Plan 08 commit'lenmedi — 8 dosya uncommitted

- **NE:** Plan 08'in tamamı çalışma ağacında.
- **NEDEN:** Oturum sonunda `code-reviewer` + `security-reviewer` koşuluyordu;
  sonuçları gelmeden commit edilmedi (`phase-review-gate.md`).
- **NEREDE:**
  ```
  M  TODO.md
  M  plans/07-mobil-pwa.md   (Faz 4 kapanışı)
  ?? plans/08-audit-items-solum.md
  ?? sql/83_audit_items_butunluk.sql
  M  src/BkmArgus.Web/Features/Audit/AuditView.cs
  M  src/BkmArgus.Web/Features/Audit/Items.cshtml
  M  src/BkmArgus.Web/Features/Audit/Items.cshtml.cs
  M  src/BkmArgus.Web/wwwroot/css/argus-theme.css
  ?? src/BkmArgus.Web/wwwroot/js/argus-item-risk.js
  ```
- **NASIL KAPANIR:** Denetçi bulguları kapatılır → commit mesajına
  `[reviewed: ...]` (hook zorunlu kılıyor) → push.
- **BAĞIMLILIK:** İki denetçi raporu. `sql-sp-reviewer` **koşuldu**,
  CRITICAL bulgusu commit öncesi kapatıldı.
- **ÖNCELİK:** 2.

## 4. Plan 07 Faz 6 — tam mobil ölçüm

- **NE:** 360 / 390 / 768px genişlikte **her** ekran; yatay kaydırma yok,
  dokunma hedefi ≥44px, pano telefondan durum değiştirebiliyor, tarayıcı
  "yükle" diyor.
- **NEDEN:** Plan 07'nin bitiş ölçütü (8 madde). Faz 1–5 bitti, ölçüm
  fazı kaldı.
- **NEREDE:** `plans/07-mobil-pwa.md` "Done criteria".
- **NASIL KAPANIR:** Her ekran için ölçüm scripti; **dokunma hedefi
  ölçerken tıklanabilir ALANI ölç**, iç elemanı değil (bu oturumda bu hata
  yapıldı: checkbox 22px ama sarmalayan label 44px).
  Ayrıca `beforeinstallprompt` gömülü panelde tetiklenmedi — **gerçek
  cihazda** doğrulanmalı (önceki oturumdan devreden borç).
- **BAĞIMLILIK:** Yok.
- **ÖNCELİK:** 3.

## 5. `/Audit/Create` Solum'a taşınmamış (TODO B17)

- **NE:** Ölçüldü 2026-09-23, 375px: **4 öğe** 44px dokunma hedefinin
  altında; alanlar `mt-1 w-full rounded-lg border…` yani ham Tailwind.
- **NEDEN:** `.solum-input` gölgelemesi bu ekrana ulaşmıyor çünkü ekran
  Solum ilkellerini kullanmıyor. Items ile **aynı sınıf**: plan 05 Dalga 1'de
  atlanmış.
- **NEREDE:** `src/BkmArgus.Web/Features/Audit/Create.cshtml`.
- **NASIL KAPANIR:** Items taşımasının aynısı — `<solum-field>` +
  `<solum-errors>` + `.solum-card`. Items artık **çalışan bir şablon**.
- **BAĞIMLILIK:** Yok (S2/S3 geldi).
- **ÖNCELİK:** 4.

## 6. Denetçi bulguları — kapatılmayan altı madde (TODO B14–B19)

Hepsi `sql-sp-reviewer` turundan, hepsi TODO.md'de kayıtlı:

| TODO | Ne | Neden bu turda kapatılmadı |
|---|---|---|
| **B14** | Katalog izi **alan bazında değil** — yalnız "son dokunan" yazılıyor, `audit.AuditLog`'a satır yok | Ayrı tasarım kararı; `security-principles.md` zorunlu listesinde |
| **B15** | `FindingType` kod kümesine (U/G/I) CHECK yok — tek savunma C# | `sql/83`'ün kendi argümanı bu alana uygulanmadı |
| **B16** | `sql/68_skill_context_build.sql:212,320` pasif maddeleri **AI bağlamına** akıtıyor | CRITICAL bulgunun küçük kardeşi; ayrı migration |
| **B17** | `/Audit/Create` ham Tailwind (yukarıda madde 5) | Kapsam |
| **B18** | `src/BkmArgus.Installer/sql/` aynası **22'de durmuş** — 30–83 arası ~60 dosya yok; kurulumcu yolundan kurulan DB bu düzeltmeleri **almaz** | Sistemik borç, tek başına iş |
| **B19** | `sys.check_constraints` guard'ları şema ile nitelenmemiş; `NOCHECK` durumdaki constraint'i onarmıyor | Düşük etki |

- **ÖNCELİK:** B16 → 4 (AI bağlam doğruluğu), B18 → 4 (kurulum bütünlüğü),
  diğerleri 5.

## 7. Fresh-DB migrate testi — HÂLÂ BORÇ (devreden)

- **NE:** `sql/` zincirini boş bir DB'ye sıfırdan uygulayıp 0 fail + beklenen
  tüm objeleri doğrulamak.
- **NEDEN:** Önceki koşum **geçersizdi** (harness "FAIL: 0" raporladı ama
  test DB'si hiç oluşmamıştı). Artık `sql/83` de zincire girdi, yani borç
  büyüdü.
- **NEREDE:** `.claude/rules/phase-review-gate.md §3.5`.
- **NASIL KAPANIR:** Boş `BKMDenetim_FreshTest` → `sql/[0-9]*.sql` sırayla →
  **her scriptin çıkış kodu** kontrol edilir → `CK_AuditItems_*`,
  `sp_Item_SetActive` dahil beklenen objeler `OBJECT_ID` ile doğrulanır →
  DB düşürülür.
- **BAĞIMLILIK:** Bağlantı dizesi.
- **ÖNCELİK:** 4 — `sql/` altına bir daha dokunulmadan önce **zorunlu**.

## 8. Solum T-serisi — açık, bizi bekletmiyor

- **T2** (`cursor:pointer` kalksın) sıradaki üç adımda, tek satır.
  Geldiğinde bizde **iş yok** (`argus-theme.css:435` kendi cursor'unu
  basıyor), yalnız tıklama smoke'u.
- **T1/T3/T4** — üç-ürün eşiği bkm-magaza tarafından **hiç dolmayacak**
  (o ürün `Solum.Web`i reddetti). Gölge kodumuzu **kalıcı varsay**.
  Bu oturumda T3 gölgelemesinin **yarım** olduğu ortaya çıktı ve
  tamamlandı (`.solum-input`/`.solum-select` eklendi).
- **ÖNCELİK:** pasif takip.

## 9. C9 — `ProjectReference` izolasyonu (bugün İKİ KEZ ısırdı)

- **NE:** `BkmArgus.Web.csproj:23-25` üç `ProjectReference` ile Solum'un
  **canlı çalışma ağacına** bağlı.
- **NEDEN:** Başka bir ekibin yarım yazımı bizim build'imizi durduruyor.
  Dün ~1 saat, bugün iki kez (76 → 16 → 0 hata).
- **NEREDE:** `src/BkmArgus.Web/BkmArgus.Web.csproj:23-25`.
- **NASIL KAPANIR:** Solum NuGet paketi yayınlarsa `PackageReference`'a
  geçiş. Karşı taraf bunu kendi yol haritasında "sürüm sınırı" olarak
  tutuyor ve bizim ölçümümüzü gerekçe olarak kaydetti.
- **BAĞIMLILIK:** Solum'un paket yayınlaması. **Bizim tarafta karar yok.**
- **ÖNCELİK:** 5 — ama her Solum turunda maliyeti tekrar ödüyoruz.

## 10. Küçük borç

- `Features/Dof/Detail.cshtml:39` — CS8321, kullanılmayan `StatusLabel`
  yerel fonksiyonu. **Tek build uyarısı**, iki oturumdur duruyor.
  Faz 3'te temizlenecekti, temizlenmedi.
- `src/BkmArgus.Web/wwwroot/css/argus-theme.css` **680+ satır**. Kurallarda
  CSS için açık eşik yok ama birikiyor (`code-reviewer` not düştü).

---

## 11. 🆕 Merkezî kural deposu göçü — KARAR KULLANICIDA, YAPILMADI

- **NE:** Oturum sonunda üçüncü bir eş oturumdan (`Tek merkez kapı terfi`)
  mesaj geldi: `D:\Dev\claude-context-template` altında 18 kanonik
  `_universal` kural kurulmuş; depoların kendi `.claude/rules/` **kopyalarını**
  bırakıp merkeze **referans** vermesi isteniyor.
- **NEDEN BU OTURUMDA YAPILMADI:** Üç sebep, üçü de bilinçli —
  1. **Bu bir eş oturum talebi, kullanıcı talimatı değil.** `.claude/rules/`
     ve `CLAUDE.md` bu projenin davranış sözleşmesidir; bir peer istedi diye
     değiştirilmez.
  2. İş **Tier 3**: 20+ kural dosyası, `CLAUDE.md` başına işaretçi, hook
     yolları. Plan gerektirir.
  3. Mesajın kendisi *"göç ELLE yapılır ve her sapmanın kararı insana
     aittir"* diyor ve **toplu silmeyi açıkça yasaklıyor**.
- **NEREDE:** `.claude/rules/*.md` (BkmArgus'ta ~20 dosya),
  `CLAUDE.md` kural fihristi, `.claude/hooks/`.
- **NASIL KAPANIR:** Kullanıcı onayıyla:
  1. `bash ../claude-context-template/bin/durum.sh` → BkmArgus satırındaki
     **sapma sayısını ölç** (göç öncesi taban)
  2. Her sapma için `harvest.sh --diff` → üç yoldan biri:
     **bayat** (kopyayı sil, merkeze işaret et) · **bilerek yerel**
     (kalır ama *"bu kural yerel, çünkü…"* gerekçesi dosyanın ilk
     satırlarına yazılır) · **terfi** (merkeze gönder)
  3. `CLAUDE.md`'ye **tek** işaretçi (depo adı `Norma`ya değişecek — yolu
     tek yere yaz, hook'lara gömme)
  4. Göç sonrası `durum.sh` tekrar → sapma düşmeli, model `REFERANS` olmalı.
     **Ölçmediysen göç olmamıştır.**
- **BkmArgus'a özgü dikkat:** Bizim kurallarımızın bir kısmı **ölçülmüş
  yerel gerçek** taşıyor ve merkeze gidemez —
  `sql-conventions.md` (Türkçe SP parametresi ↔ İngilizce kolon sözleşmesi),
  `etl-discipline.md` (`ehAltDepo=0`, snapshot), `ai-layer.md` (kademeli
  maliyet), `turkish-ui.md` (tek dil kararı). Bunlar "bilerek yerel"
  kategorisine girer ve **gerekçesi yazılmalıdır**.
  Buna karşılık `test-discipline.md`, `error-handling.md`,
  `commit-discipline.md`, `todo-verification.md` merkezde ilerlemiş —
  bizimkiler **bayat olabilir**.
- **BAĞIMLILIK:** **Kullanıcı kararı.** Ayrıca merkez tarafında Aşama 2
  (`bootstrap --reference`) henüz YOK.
- **ÖNCELİK:** Kullanıcı belirler. Teknik olarak acil değil — kopya kurallar
  çalışmaya devam ediyor, yalnız merkezdeki iyileştirmeleri almıyoruz.

---

## 12. `FindingType` kod kümesi DOĞRULANMADI — bugünkü commit'te bir varsayım var

- **NE:** `Items.cshtml`'de bulgu tipi seçenekleri **U / G / I** olarak yazıldı
  (`Uygunsuzluk` / `Gozlem` / `Iyilestirme`). Bu kod kümesi **hiçbir yerde
  tanımlı değil** — ben türettim.
- **NEDEN ŞÜPHELİ:** depoda `FindingType` için tek somut değer
  `sql/99_smoke_tests.sql:910,926`'da **`'M'`**. Yani kullanılan gerçek küme
  U/G/I olmayabilir. Kolon `char(1)` (`sql/20_migration_audit.sql:75`) ve
  `audit.AuditResults.FindingType` de öyle.
- **NEREDE:** `src/BkmArgus.Web/Features/Audit/AuditView.cs`
  (`FindingTypeText`, `FindingTypeOptions`), `Features/Audit/Items.cshtml`.
- **BUGÜN EKRAN KIRILMIYOR:** `FindingTypeOptions` tanınmayan kodu listeye
  **ekliyor** ve `FindingTypeText` `"Bilinmeyen kod: M"` yazıyor. Yani veri
  ne olursa olsun düzenleme ekranı açılır ve kullanıcı ne olduğunu görür —
  fail-loud. Bu tasarım kararı bu belirsizlik bilinmeden alınmıştı ve
  şans eseri doğru çıktı.
- **NASIL KAPANIR:** migration smoke'unda tek sorgu —
  ```sql
  SELECT FindingType, COUNT(*) FROM audit.AuditItems GROUP BY FindingType;
  SELECT FindingType, COUNT(*) FROM audit.AuditResults GROUP BY FindingType;
  ```
  Çıkan küme U/G/I ise dokunma; başka bir küme çıkarsa (`M`, `1/2/3`, NULL)
  `AuditView.FindingTypeOptions` o kümeye göre yazılır. Eski ekran uzun
  etiketi (`"Uygunsuzluk"`) gönderip SQL'e sessizce kırptırdığı için
  **geçmiş veri tutarsız olabilir** — sayım bunu da gösterir.
- **BAĞIMLILIK:** DB bağlantısı (§1).
- **ÖNCELİK:** **1** — migration smoke'unun parçası.

## 13. Solum yol harfi — bizi bugün koruyan tutarsızlık

- **NE:** `src/BkmArgus.Web/BkmArgus.Web.csproj:23-25` üç `ProjectReference`
  **küçük harfle** `..\..\..\solum\...` yazıyor; diskteki gerçek ad
  `cmd dir /b` ile ölçüldü: **`Solum`** (büyük S).
- **NEDEN ÖNEMLİ:** Windows dosya sistemi harfe duyarsız olduğu için bugün
  çalışıyor. Solum tarafında ölçülmüş bir ilişki var: **büyük harfli yoldan
  temiz derleme 16 `RS0030` veriyor, küçük harfliden 0/0.** Bizim
  build'imiz yeşil çünkü csproj küçük harfli yolu veriyor.
- **⚠️ MEKANİZMA DOĞRULANMADI:** Solum oturumu ilk açıklamasını
  (`.editorconfig` deseni büyük/küçük harfe duyarlı) **geri çekti** — ölçtüğü
  şey iddiasının kanıtı değilmiş. İlişki duruyor, sebebi **bilinmiyor** ve
  onların tarafında `DOĞRULANMADI` işaretli. Burada da öyle kaydediliyor:
  sebebi bilmiyoruz, sonucu biliyoruz.
- **TUZAK:** csproj'daki yazım diskteki gerçek addan farklı. Biri
  "tutarsızlık var, düzelteyim" diye `Solum` yaparsa — bakımda en makul
  görünen hamle budur — build **sebepsiz** kırılır ve kırılma o kişinin
  değişikliğinden gelmiş gibi görünür. **Bugün bizi koruyan şey, bir sonraki
  kişinin temizlemek isteyeceği şey.**
- **NASIL KAPANIR:** Solum tarafında `[**/SolumFileKey.cs]` düzeltmesi
  geldiğinde kırılganlık kendiliğinden kapanır (desen yola değil dosya adına
  bakar). O gelene kadar **csproj'daki harfe DOKUNMA**.
- **BAĞIMLILIK:** Solum PARK 0. Tetikleyicisine "tüketici csproj'unda harf
  düzeltmesi" satırı eklendi — tetikleyici bizden gelebilir.
- **ÖNCELİK:** dokunma; yalnız bilinsin.
