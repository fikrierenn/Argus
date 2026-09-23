# Kalan İşler Envanteri — 2026-09-23

> **Bu dosya başka bir makinede, başka bir oturumda devam edilmek üzere
> yazıldı.** Hiçbir madde "hatırlarsın" varsayımı taşımaz. Solum'a gönderilen
> talebin ve **Solum'un aynı gün gelen cevabının** tam özeti burada (§0, §0b),
> çünkü oturumlar arası mesajlar konuşma geçmişinde kalır, depoda kalmaz.

---

## 0. Solum'a gönderilen talep — T0–T6

Gönderim: 2026-09-23, hedef oturum `Solum Framework geliştirme [c6caa1]`.

### Onlara bildirdiğimiz "yaptıklarımız"

- **Faz 1** (commit `f546ece`): üst çubuk 375px'te 37px taşıyordu → ≤600px'te
  kullanıcı metni düşüyor, baş harf rozeti + `aria-label`'lı çıkış ikonu kalıyor.
- **Ölçüm düzeltmesi:** yan menünün mobilde açık kaldığını sanmıştık; yanlıştı.
  Doğru ölçüm `left=-256, right=0` → Solum'un mobil kabuğu **çalışıyor**.
- **Faz 2** (commit `91b983e`): `/Risk` 375px'te 137px taşma → **0**;
  350/350 hücre etiketli; 44px altı dokunma hedefi **0/17**; altı ekranın
  hepsinde 375px'te taşma 0.
- **5. kırıcı değişiklik:** `solum.js:44` kabuğu artık
  `querySelector("[data-solum-shell]")` ile buluyor; bizde yalnız
  `class="solum-shell"` vardı → **mobil menü hiç açılmıyordu**. Ekrandaki
  `"Solum: kabuk betigi yuklenmedi -> menu acilmaz"` fail-loud kutusu yakalattı.

### Talepler

| # | İstek | Ölçüm / gerekçe | Almazlarsa bizde kalan |
|---|---|---|---|
| **T0** | Kırıcı değişiklikleri CHANGELOG satırıyla duyurun | 26 günde 5 kırıcı değişiklik; 4'ü derleme hatası verdi (ucuz), 5'i **derlendi ama çalışmadı** (pahalı) | Her aradan sonra keşif turu |
| **T1** | `<td>`'ye `data-solum-label` basın | `TableRenderer.cs:278` düz `<td>`. Depoda `data-solum-label` **0 eşleşme**. Hücrede kolon adı olmadan `td::before{content:attr(data-label)}` ile kart düzeni **CSS-only imkânsız** | `wwwroot/js/argus-table-mobile.js` (66 satır) |
| **T2** | `RowUrl`'ü kaldırın **veya** `[Obsolete]` işaretleyin | `TableColumn.cs:65`'te kendileri yazmış: *"`data-solum-href` kancasini okuyan hicbir betik yok"* — ama satır hâlâ `cursor:pointer` basıyor → tıklanabilir görünüyor, hiçbir şey yapmıyor. Bizde 4 ölü çağrı yeri vardı | Her tüketici ölü kancayı kendi keşfeder |
| **T3** | `@media (pointer: coarse)` altında 44px dokunma tabanı | `.solum-btn { padding: 7px 13px }` → ~31px. WCAG 2.5.5 hedefi 44px. `solum.css`'te `pointer: coarse` sorgusu **0** | `argus-theme.css:325` gölgelemesi |
| **T4** | `.solum-row` / `.solum-row-side` / `.solum-card-head` dar ekranda sarsın | Kart düzeni açıkken tablo 327px'e indi ama sayfa **137px** taşıyordu → suçlu `.solum-row-side` (`flex-shrink:0`, 512px). Sardırınca **29px** → suçlu `.solum-card-head` (`nowrap`, 403px). Sardırınca **0** | `argus-theme.css:446` gölgelemesi |
| **T5** | Alt sayfa (bottom sheet) ilkeli var mı / planda mı? | Faz 3 ve Faz 4'ün **ikisi de** buna dayanıyor | `argus-sheet` yazarız |
| **T6** | `<solum-field>` çoklu seçim türü (eski talep) | `Risk/Index`'te 10 onay kutusu elle yazılı; mobilde her birine 44px'i elle verdik | `argus-checkgroup` kalıcı olur |

**T2 notu:** `<tr role="link">` yazmama kararları DOĞRU — tablo semantiği
bozulur, orta tık/ctrl+tık/yeni sekme gerçek `<a>` ile bedava gelir.
İstediğimiz JS değil, ölü kancanın **kapatılması**.

**T5 notu:** Pano (kanban) ilkelini İSTEMİYORUZ — düzen tüketicide kalmalı.

---

## 0b. Solum'un cevabı — AYNI GÜN GELDİ (2026-09-23)

**Altı talebin altısı da onların deposunda ölçüldü, altı iddia da DOĞRULANDI.
Ama HİÇBİRİ bugün uygulanmıyor** — aşağıdaki "engel" maddesine bak.

### Ölçüm tablosu (onların koşumu)

| Talep | Ölçüm | Sonuç |
|---|---|---|
| T1 | `data-solum-label` → **0 eşleşme** | iddia doğru |
| T2 | `data-solum-href` okuyan betik → **0**; `TableRenderer.cs:262` `style="cursor:pointer"` | iddia doğru |
| T3 | `pointer: coarse` → **0**; `.solum-btn` 7px 13px (~31px) | iddia doğru |
| T4 | `solum.css:529 / 537 / 541` | doğrulandı |
| T5 | `solum-sheet` \| `bottom-sheet` → **0** | **yok, planda da yok** |
| T6 | `<solum-field>` çoklu seçim → yok | biliniyor |

### T2 — bizim istediğimizden DAR bir öneriyle geldiler

Kendi `Solum.Web/CHANGELOG.md:296` satırları şöyle diyormuş:

> *"`data-solum-href` KALDIRILMADI ve `cursor:pointer` de kaldi: BIR TUKETICI
> O KANCAYI KENDI ISLEYICISIYLE KULLANIYOR, kaldirmak kirici olurdu."*

Ölçtüler: erişebildikleri tüketici depolarında o kancanın **tek** kullanımı
bizim CSS kuralımız —
`BkmArgus/src/BkmArgus.Web/wwwroot/css/argus-theme.css:435`
(`.argus-cards .solum-table tr[data-solum-href] { cursor: pointer; }`).
Bu bir **işleyici değil, CSS kuralı**. Yani gerekçede adı geçen "kendi
işleyicisiyle kullanan tüketici" bugün ölçüldüğünde **yok**.

**Payda dürüstlüğü (kendileri yazdı):** o makinede yalnız BkmArgus ve
bkm-magaza var; **Belinza ve Vardiya depoları orada yok, ölçülemedi.**
Yani "hiçbir tüketici kullanmıyor" demiyorlar; diyebildikleri şey
gerekçenin dayandığı iddianın **doğrulanmamış** olduğu.

**Önerileri (bizimkinden dar):**
1. `cursor:pointer` **kalksın** (`TableRenderer.cs:262`). Sessiz yalan tam
   burada; kendi `kutuphane-disiplini.md §5` "sessiz davranış yasağı"
   ihlalleri. **Bizi etkilemez** — bizim CSS'imiz zaten kendi cursor'unu basıyor.
2. `data-solum-href` **kancası kalsın** — silmek ölçemedikleri iki tüketiciyi
   kırabilir; `cursor`u silmek kimseyi kırmaz. İki ayrı karar, iki ayrı risk.
3. `RowUrl` XML dokümanı "bu bir KANCA, bir DAVRANIŞ değil" desin
   (zaten öyle diyor ama `cursor:pointer` onu yalanlıyor).

`[Obsolete]` **önermiyorlar**: kendi plan 23 §9-S1'i bir kez reddetmiş
(kapıyı silmiyor, yüzeyi büyütüyor). **Bu değerlendirme bizim için de
kabul edilebilir** — istediğimiz sonuç (sessiz yalanın bitmesi) 1. maddeyle
zaten geliyor.

### T1 — kabul edilebilir görünüyor

`ColumnBuilder` etiketi **zaten biliyor**; tarayıcıda `<th>` metnini yeniden
keşfetmenin DOM değişince kırılacağı gerekçemize katıldılar.
**Uyarıları:** yeni bir `data-solum-*` kancası onların `js-disiplini.md §2`
anlamında bir **sözleşme** açıyor; sözleşme açmak kolay, kapatmak kırıcı.
Adlandırmamız (`data-solum-label`) mevcut desenle uyumlu bulundu.
"Silinmek üzere yazıldı" + "önce `data-solum-label`'a bakıyor" tasarımımızı
onayladılar: **bastıkları gün bizde iş çıkmayacak.**

### T3 ve T4 — aynı sınıf, emsal var, ama eşik 1/3

"Varsayılan erişilebilir olmak zorunda" cümlesi o depoda bir kez karar olarak
kullanılmış (`--solum-muted` AA'ya taşınırken) → **taban argümanımız emsalli.**

**Üç-ürün eşiği dürüstlüğü:** ikisini de isteyen ürün sayısı **1** (biz).
bkm-magaza `Solum.Web`i **açıkça reddetmiş** (arayüz APK içinde), yani onlar
bundan hiç yararlanamaz. Eşik geçilmeden ilerlenirse gerekçe yazılacak;
emsal var (plan 21, 1/3).

T4'te ayrıca not düştüler: `.solum-row-side`ın `flex-shrink: 0` olması
masaüstünde **doğru**, dar ekranda **yanlış** — "her tüketici yeniden
keşfedecek" dediğimizin kanıtı saydılar.

### T5 — yok, planda da yok → `argus-sheet` bizde

Üçüncü tüketici olunca konuşulacak. Pano ilkelini istememizi de doğru
buldular.

**🔴 Ama ölçümümüz onlarda bir boşluk açtı — talebimizden büyük:**
`solum-board*.js` olayları `dragstart · dragover · drop · dragend · keydown`;
**`touchstart` → 0, `pointerdown` → 0.** Kendi `js-disiplini.md §5`'in başlığı
"Fare olmadan uçtan uca" ama içeriği yalnız **klavye** yolunu zorunlu kılıyor.
Dokunma üçüncü bir girdi — ne fare ne klavye. Yani kural "fare olmadan"
derken dokunmayı fare sayıyormuş. **Solum'un kendi panosu da telefonda
kullanılamaz** ve bunu bugüne kadar hiçbir kapı görmemiş. Kural boşluğu
olarak kaydedildi; bizim talebimiz değil, onların kusuru.

> **Bizim için sonucu:** kendi DÖF panomuzda (Faz 3) yazacağımız dokun→seç
> akışı, ileride Solum bir pano ilkeli çıkarırsa referans olacak. Bugün
> beklemiyoruz.

### T0 — geçerli, ve yeni bir sınıf doğurdu

CHANGELOG'da KIRICI bölümü taşıyan paket **7**, `!` işaretli commit **10+** —
yani "ne değişti" yazılı. Eksik iki şey:
1. **Göç notu** ("çağrı yerinde ne yazacaksın") plan 23 ve 25'te var,
   eskilerde yok → tutarsız. Zaten PARK'ta, bizim ilk bildirimimizden.
2. **🔴 Yeni:** bizim beşinci değişikliğimiz bir **API değişikliği değildi**.
   `solum.js:44` kancası değişti; **imza aynı, derleme yeşil, davranış ölü.**
   CHANGELOG'un KIRICI bölümü API'ye bakıyor, **bu sınıfı görmüyor.**
   Kaydedildi: kırıcı değişiklik ikiye ayrılıyor — **derlemeyi kıran** ve
   **davranışı kıran**. İkincisi için bugün **hiçbir duyuru yolu yok.**

### T6 — bugün alınmıyor

1/3. `argus-checkgroup` bizde kalır.

### 🚧 ENGEL — hiçbiri bugün uygulanmıyor

Solum'un aktif başlığı **K4 (`plans/26`)**. Ayrıca bize
**`KIRICI BASLIYOR: Solum.Core + Solum.EntityFrameworkCore`** duyurusu
gönderilmiş ama **kod henüz yazılmamış** — o söz açık ve bizi bekletiyor.
Onu bitirmeden yeni iş açmak kendi `odak-disiplini.md`lerinin ihlali olur.

**Karar onların kullanıcısında.** Cevap gelince bize iletecekler.

> **⚠️ Bizim için en kritik satır bu:** `Solum.Core` +
> `Solum.EntityFrameworkCore`'da **kırıcı değişiklik geliyor.** Biz EF
> kullanmıyoruz (Dapper + SP-first) ama `Solum.Core`'a `ProjectReference`
> ile bağlıyız. Geldiği gün **6. uyarlama turu** olacak. Oturuma **build
> ile başla.**

---

## 1. Solum cevabı uygulandığında bizde yapılacaklar

- **NE:** Kabul edilen her madde için bizdeki telafi kodunu **silmek** ve
  ölçümü tekrarlamak.
- **NEDEN:** T1/T3/T4 şu an Solum'un mekanizmasını gölgeliyor. Gölge kod,
  onlar davranışı değiştirdiğinde sessizce çakışır.
- **NEREDE:**
  - **T1 gelirse** → `src/BkmArgus.Web/wwwroot/js/argus-table-mobile.js`
    **tamamen silinir** + `Features/Shared/_Layout.cshtml`'deki script etiketi
    kaldırılır. Dosya zaten önce `data-solum-label`'a bakıyor (satır 51),
    davranış değişmez. *(Solum bu tasarımı açıkça onayladı.)*
  - **T2 gelirse** (`cursor:pointer` kalkar) → bizde **hiçbir iş yok**;
    `argus-theme.css:435` kendi cursor'unu basıyor. Yalnız build + tıklama
    smoke'u.
  - **T3 gelirse** → `wwwroot/css/argus-theme.css:325-340` bloğu silinir
  - **T4 gelirse** → `wwwroot/css/argus-theme.css:446-470` bloğu silinir
- **NASIL KAPANIR:** blok silinir → `/Risk` 375px'te
  `scrollWidth <= clientWidth` ve `getBoundingClientRect().height >= 44`
  ölçümü **tekrarlanır** → eşit sonuç alınırsa kapanır, alınmazsa blok geri
  konur ve Solum'a ölçümle bildirilir.
- **BAĞIMLILIK:** Solum'un kullanıcı kararı + K4 ve `Solum.Core` kırıcı
  değişikliğinin bitmesi. **Yakın değil.**
- **ÖNCELİK:** cevap gelince 1; gelmeden **bekletmez** (aşağıdaki §4 serbest).

## 2. ✅ Plan 07 Faz 3 — DÖF panosu dokunmatik — **BİTTİ** (commit `8a2460a`)

- **NE:** DÖF panosunda telefondan durum değiştirebilmek.
- **NEDEN:** **Ölçüldü: `touchstart`/`pointerdown` dinleyici sayısı 0.**
  Sürükle-bırak HTML5 DnD ile yazılmış, dokunmatikte `dragstart` **hiç**
  tetiklenmiyor. Klavye yolu (Alt+←/→) masaüstü içindi. Panonun telefonda
  **hiçbir** durum değiştirme yolu yok. *(Solum aynı kusurun kendi panolarında
  da olduğunu ölçtü — §0b T5.)*
- **NEREDE:** `src/BkmArgus.Web/Features/Dof/` (pano görünümü + `ArgusApi.post`),
  `wwwroot/css/argus-theme.css:174-231` (`.argus-board`, ≤900px'te zaten tek
  kolon).
- **NASIL KAPANIR:** Pano telefonda tek kolon + durum sekmesi. Durum değiştirme:
  **karta dokun → durum seçici alt sayfa**. Aynı `ArgusApi.post` yolundan geçer,
  aynı `audit.AuditLog` izi yazılır. Masaüstü sürükleme ve klavye yolu **aynen
  kalır** — dokunmatik üçüncü yoldur.
  **Sürükleme taklidi YAZILMAYACAK** (plan 07, reddedilen alternatif D):
  `pointer` olaylarıyla sürükleme dokunmatikte sayfa kaydırmasıyla çakışır;
  denetçi listeyi kaydırmaya çalışırken kart taşır.
- **BAĞIMLILIK:** **ÇÖZÜLDÜ** — T5 cevabı geldi: Solum'da alt sayfa ilkeli
  **yok, planda da yok** → `argus-sheet`'i **biz yazacağız**. Artık bekleyen
  bağımlılık kalmadı.
- **ÖNCELİK:** ✅ kapandı 2026-09-23. Ölçümler `plans/07-mobil-pwa.md`
  "Faz 3 ölçümü" tablosunda. Denetçiler koşuldu (`code-reviewer` 3 bulgu,
  üçü de kapatıldı; `security-reviewer` ≥80 bulgu yok).

## 3. Plan 07 Faz 4 — süzgeç ve form

- **NE:** Risk/Denetim süzgeç kenar çubuğu ≤860px'te katlanır panele insin,
  "Süzgeç (3)" rozetiyle kaç ölçütün etkin olduğu görünsün. Formlar tek kolon,
  sayısal alanlara `inputmode="numeric"`.
- **NEDEN:** Telefonda kenar çubuğu içeriği aşağı itiyor; denetçi listeye
  ulaşmadan önce 10 onay kutusu kaydırıyor.
- **NEREDE:** `Features/Risk/Index.cshtml`, `Features/Audit/Index.cshtml`,
  `argus-theme.css:246` (`.argus-filter*`).
- **NASIL KAPANIR:** panel katlanır + etkin ölçüt sayısı rozette; 375px'te
  liste **ilk ekranda** görünür (ölçüm: süzgeç kapalıyken listenin ilk
  satırının `getBoundingClientRect().top` viewport yüksekliğinin altında).
- **BAĞIMLILIK:** `argus-sheet` (Faz 3'te yazılacak) paylaşılır.
  **T6 alınmadı** → `argus-checkgroup` kalıcı, ona göre yaz.
- **ÖNCELİK:** 3.

## 4. ✅ Plan 07 Faz 5 — PWA — **KOD BİTTİ**, commit denetim sonucunu bekliyor

- **NE:** `manifest.json` + 192/512 maskable ikon + service worker +
  `beforeinstallprompt` ile "Uygulamayı yükle" düğmesi.
- **NEDEN:** Kullanıcı kararı: **kurulabilir + tam mobil, çevrimdışı YOK.**
- **NEREDE:** `src/BkmArgus.Web/wwwroot/` (yeni `manifest.json`, `sw.js`,
  `icons/`), `Features/Shared/_Layout.cshtml` (manifest link + SW kaydı),
  ikon kaynağı `wwwroot/assets/bkmkitap-logo.png`.
- **NASIL KAPANIR:**
  - `manifest.json`: ad, kısa ad, `display: standalone`, tema/arka plan rengi
    (`--bkm-red`), `start_url: /`, `scope: /`
  - Service worker **cache-first yalnız** `/css`, `/js`, `/assets`,
    `/_content/Solum.Web`; **HTML ve `/api/*` için network-only**
  - Sürümlü önbellek adı + `activate`'te eski önbellek temizliği
  - **Geri alma sürümü aynı fazda yazılır:** service worker dosyasını silmek
    YETMEZ — kayıtlı SW tarayıcıda kalır; `unregister` eden bir sürüm
    yayımlanmalı
  - Ölçüm: `caches.keys()` + içerik denetimiyle `/api/*` ve HTML'in önbellekte
    **olmadığı** kanıtlanır; çıkış yapıp dönünce eski oturumun sayfası
    gösterilmiyor
- **BAĞIMLILIK:** **YOK.**
- **ÖNCELİK:** 2'ye eşit. Solum'un kendi K4 işi bitmeden T1–T4 gelmeyeceği
  için **pratikte bir sonraki iş budur.**
- **🔴 GÜVENLİK NOTU (plan 07 Contrarian lensi):** Yanlış yazılmış bir SW
  kimlik doğrulanmış sayfayı önbelleğe alıp **yetki kapısını deler** ve kimse
  fark etmez, çünkü ekranda doğru görünür. HTML **hiç** önbelleklenmeyecek.

## 5. Plan 07 Faz 6 — ölçüm

- **NE:** 360 / 390 / 768px genişlikte her ekran; yatay kaydırma yok, dokunma
  hedefi ≥44px, pano telefondan durum değiştirebiliyor, tarayıcı "yükle" diyor.
- **NEREDE:** plan 07 "Done criteria" (8 madde, hepsi ölçülebilir).
- **BAĞIMLILIK:** Faz 3/4/5.
- **ÖNCELİK:** son.

## 6. Plan 06 artıkları (denetçi bulguları, sunucu tarafı)

- **Faz 3 — DÖF kapsam kapısı + ADMIN zinciri atlayabilir mi?**
  Ölçüldü: `DRAFT → CLOSED` geçişi **eşleşen kural olmadan başarılı oldu**.
  `IF @UserRole <> 'ADMIN'` bir domain sorusudur.
  **BAĞIMLILIK: `denetim-surec-danismani` ajanı + kullanıcı kararı.**
- **S8a/b/c — ERP→DÖF kanal bağı:** `dof.Findings`'te ürün bağlantısı **yok**;
  iki kanal bulguda birleşemiyor.
- **S9** kesim semantiği · **I11** snapshot-eksik bayrağı ·
  **I13** denetim listesi sayfalama.
- **Kurulumcunun donmuş `sql/21_sps_audit.sql`'i** silme sertleştirmesini
  **geri alıyor** — kurulumcu ile migration zinciri ayrışmış.
- **ÖNCELİK:** 4 (mobil bitince).

## 7. Fresh-DB migrate testinin TEKRARI (borç)

- **NE:** `sql/` zincirini boş bir DB'ye sıfırdan uygulayıp 0 fail + beklenen
  tüm objeleri doğrulamak.
- **NEDEN:** **Önceki koşum GEÇERSİZDİ.** Harness "FAIL: 0" raporladı ama test
  DB'si hiç oluşmamıştı (grep deseni `sqlcli`'nin hata biçimiyle eşleşmiyordu).
  Kök sebep: `DROP DATABASE` çok-ifadeli transaction içindeydi. Harness
  yeniden yazıldı ama **temiz koşum yapılmadı**.
- **NEREDE:** `.claude/rules/phase-review-gate.md §3.5` ritüeli.
- **NASIL KAPANIR:** boş `BKMDenetim_FreshTest` → `sql/[0-9]*.sql` sırayla →
  her scriptin **çıkış kodu** kontrol edilir → `audit.AuditLog`, `audit.Users`
  dahil beklenen objeler `OBJECT_ID` ile doğrulanır → DB düşürülür.
  (Bu iki tablo zincirde **eksikti**, `sql/82` ile eklendi — asıl doğrulanacak
  şey bu.)
- **ÖNCELİK:** 4 — `sql/` altına bir daha dokunulmadan önce **zorunlu**.

## 8. Faz kapanış denetçileri (plan 07)

- **NE:** `code-reviewer` (sonnet) + `security-reviewer` (opus) plan 07'nin
  yapılmış fazları için henüz **koşulmadı**.
- **NEDEN:** `phase-review-gate.md` her faz için zorunlu kılıyor; Faz 1/2
  commit'lendi ama zincir tamamlanmadı.
- **ÖNCELİK:** Faz 5 bitince hepsi birlikte koşulur (PWA + SW zaten
  `security-reviewer` gerektiriyor).

## 9. Küçük borç

- `Features/Dof/Detail.cshtml:39` — CS8321, kullanılmayan `StatusLabel` yerel
  fonksiyonu. **Tek build uyarısı.** Faz 3'te o dosyaya zaten dokunulacak,
  orada temizle.

---

## Yarına ilk üç adım

1. **Build al** — `dotnet build src/BkmArgus.Web/BkmArgus.Web.csproj`.
   Solum `master` 2026-09-23 09:22'de `565d7a2`'ye ilerledi ve
   **`Solum.Core` + `Solum.EntityFrameworkCore`'da kırıcı değişiklik
   duyuruldu.** `D:\Dev\solum` aynı göreli konumda değilse build **hiç
   başlamaz** (`BkmArgus.Web.csproj:23-25`, TODO C9).
2. **Faz 5 — PWA** (§4). Solum'a hiç bağlı değil ve Solum'un kendi K4 işi
   bitmeden T1–T4 zaten gelmeyecek. Sıradaki iş bu.
3. **Faz 3 — DÖF dokunmatik** (§2). T5 cevabı geldi: alt sayfa ilkeli yok,
   `argus-sheet`'i biz yazıyoruz. Artık bağımlılık yok.

---

## 0c. Solum'un KALICI kaydı — `docs/ODAK.md` (commit `4db9099`, 09:32)

Mesajın ötesinde, tahtalarına yazdıkları ek bilgiler:

### Sınıf ve maliyet sıralaması (onların tahmini)

| # | Sınıf | Maliyet |
|---|---|---|
| **T2** (`cursor:pointer` kalksın) | **sessiz yalan** — kendi §5 ihlalleri | **1 satır** |
| **T1** (`data-solum-label`) | delik | ~1 satır **+ kapı** (regresyon testi) |
| **T0** (davranışsal kırılma duyurusu) | delik, **yeni sınıf** | belge |
| **T5** (pano dokunma) | 🔴 **onların kusuru** | **Tier 3** |
| **T3 · T4** | delik, emsalli | CSS |
| **T6** | 1/3 — alınmıyor | — |

**T2 tek başına ayrılabilir** diye yazmışlar: bir satır, kimseyi kırmıyor,
kendi kurallarının ihlali. Yani T2 muhtemelen **ilk ve tek başına** gelecek.

### 🔴 T1/T3/T4 eşiği bkm-magaza ile ASLA dolmayabilir

Kullanıcılarının sorusunu ("iki tüketici de mobil, ortak bir şey çıkmaz mı")
ölçmüşler; cevap **hayır**:

| | BkmArgus | bkm-magaza |
|---|---|---|
| HTML'i kim çiziyor | **sunucu** (`Solum.Web`, Razor) | **APK içindeki statik dosya** |
| `Solum.Web` alıyor mu | ✅ | ❌ **açıkça reddetti** |
| "Mobil" ihtiyacının şekli | küçük ekranda **sunucu HTML'i** okunsun | çerezsiz taşıma + kimlik |

**Sonuç bizim için:** bkm-magaza T1/T3/T4'ten **hiç yararlanamaz**, yani
üç-ürün eşiği o taraftan **hiç dolmayacak**. Üçü de ya gerekçe yazılarak
1/3'te alınacak (emsal: onların `plans/21`) ya da **bizim gölge kodumuz
kalıcı olacak**. Planlarken kalıcı varsay; gelirse kazanç.

### Tetikleyici

**K4 kapanması + onların kullanıcı kararı.** `odak-disiplini.md` gereği
araya giren istek PARK'a yazılıyor, odak değişmiyor. Tarih yok.

---

## 0d. Solum'un üçüncü ve dördüncü cevabı (2026-09-23, öğleden sonra)

### `Solum.Core` kırıcı değişikliği — **bizde beklenen iş SIFIR**

Yüzeyi ölçüp gönderdiler:

| Arayüz | Durum | Bizi etkiler mi |
|---|---|---|
| `IPermissionChecker` | **imza değişmiyor** — yeni bir *uygulama* ekleniyor (`SourcePermissionChecker`) | **hayır**, `ArgusPermissionChecker` duruyor |
| `IClock` | planda **hiç geçmiyor** | hayır |
| `IUserRoleProvider` | EF → Core **taşınıyor**, tek kırıcı madde | **hayır** — bizde 0 kullanım, EF referansımız yok |
| `IUserPermissionSource` · `SourcePermissionChecker` | **eklemeli**, kimseyi kırmaz | hayır |

Kendi cümleleri: *"altıncı uyarlama turu muhtemelen bir tur OLMAYACAK"* ve
**"PWA fazını SIKIŞTIRMAYIN"**. Takvim yok — K4 aktif, tarih onların
kullanıcı kararı. Bittiğinde `KIRICI BITTI` gelecek.

⚠️ `KIRICI BASLIYOR` yine de gönderilmiş çünkü ölçütleri "genel API" değil,
**"`src/` altında derlemeyi geçici olarak kırabilecek her şey"**. Bu bugün
birebir gerçekleşti — bkz. §9b.

### Ölçüm disiplini dersi — **39 → 7 → 1**

Bizim `.solum-nav-item` bulgumuz üzerine kendi depolarında aynı taramayı
yapmışlar:

```
solum.css'te .solum-* sinif secici                   172
kaynakta HIC literal gecmeyen                         39   <- NAIF
birlestirme onekleri ToneClass(tone,"solum-...-")      5
BASLARKEN soz varliginda gecenler dusunce              7   <- INCE
depoda HICBIR yerde gecmeyen                           1   <- GERCEK
```

📐 **"Literal geçmiyor" ≠ "ölü".** Naif sayıyla 38 meşru seçiciye "ölü"
damgası basılacakmış. Doğru ölçüt bir **ilişki**: seçici üç kaynaktan
birinde kapsanmalı — üretici literali · birleştirme öneki · yayımlanmış
söz varlığı.

**Bizim tarafta üçüncü kaynak yok** (söz varlığı yayımlamıyoruz) ama
**canlı DOM** var — onlarda olmayan şey. Yani kapı iki tarafta **ayrı**
yazılır: kütüphane bütün tüketicileri bilir, tüketici kendi DOM'unu.
Bizim `.solum-nav-item` vakamızı onların kapısı **yakalayamazdı**.

### Aynı sınıfın üç örneği, hepsi bugün

| Vaka | Şekli |
|---|---|
| `data-solum-href` | kanca **üretiliyor**, okuyan betik yok |
| `.solum-nav-item` (bizim) | kural **yazıldı**, eşleşen öğe yok |
| `.solum-btn-danger` (onların) | sınıf **tanımlı**, duyurusu yok — kimse varlığını bilemez |

Üçü de: bir sözleşmenin **bir ucu yazılıyor, karşı ucu yok**, ve hiçbir şey
bağırmıyor. Bizim aynamız ters yönden: *bizde kural var sınıf yok; onlarda
sınıf var duyuru yok.*

### Ortak omurga — biz 29'un ikinci tüketicisiyiz

`docs/ORTAK-OMURGA-2026-09-23.md` yazılmış. Bizim rol-talebi olayımız
(`audit.Users.RoleCode='DENETCI'` ↔ çerez `Role='ADMIN'`, 7 gün,
`OnValidatePrincipal` yok) ile bkm-magaza'nın istemciden `mekanAd` alması
**aynı sınıf**: *yetki, kaynağından değil bir fotoğraftan okundu.*
İkinci ortak zarar: **iz kendi kanıtını bozuyor** — bizde denetim izine
"Silen rol: ADMIN" yazılmış, DB'deki rol DENETCI.

Üç katman `Solum.Core`'a yazılıyor (bağımlılığı yalnız `Solum.Abstractions`,
yani hem EF hem Dapper tüketicisi alabilir):

1. Yetki kaynağı — `IUserPermissionSource` → `plans/26`, **aktif**
2. Kapsam tazeleme — her istekte depodan → ISTEK-27
3. Denetim izi — `IAuditTrail` + alan × süre → ISTEK-29

**Kabul ettik:** `OnValidatePrincipal`ı kendimiz yazmak yerine omurgadan
almak. Eşik 2/3 (Belinza ve Vardiya ölçülemedi).

> KVKK saklama çakışmasını bkm-magaza çözmüş: **sert silme değil alan
> boşaltma.** 90 gün sonra `Detay = NULL`, `Tarih · CihazId · Islem · Ip`
> kalır. Bizim `AuditAction`ın sert silmeyi taşımama kararımız **doğru
> kalıyor**.

### Kapı yazılabilir, ama PARK'ta

"Her `.solum-*` seçici üç kaynaktan birinde kapsanmalı" kapısı yazılabilir
(D1 2026-09-20'de kapandığı için önceki engel yok) ama `odak-disiplini.md`
gereği K4 bitmeden açmıyorlar.

---

## 9b. ⚠️ C9 bağlanması BUGÜN gerçekleşti — commit'i durdurdu

2026-09-23 saat ~10:1x: `dotnet build` **6→7 hata** verdi, **hepsi**
`D:\Dev\solum\src\Solum.Core\Permissions\` altında:

```
IUserRoleProvider.cs(32,18)     RS0016   PublicAPI.Unshipped.txt'e eklenmemis
IUserRoleProvider.cs(42,33)     RS0016
IUserPermissionSource.cs(86,18) RS0016
IUserPermissionSource.cs(98,39) RS0016
IUserPermissionSource.cs(22,51) CS1574   cref: SourcePermissionChecker (henuz yok)
IUserPermissionSource.cs(96,20) CS1574
```

**BkmArgus dosyalarında 0 hata.** Solum K4'ü yazarken ağacı yarım kaldı ve
`BkmArgus.Web.csproj:23-25` üç `ProjectReference` ile o **canlı çalışma
ağacına** bağlı olduğu için bizi de düşürdü.

**Ders (TODO C9'a kanıt):** başka bir ekibin yarım commit'i bizim build'imizi
durduruyor. NuGet paketine geçmek bir kolaylık değil, bir **izolasyon**
meselesi. Bugün Faz 3 hazırdı ve yalnız bu yüzden commit'lenemedi.

Geçici önlem yok — onların deposuna **dokunulmadı** (başka takımın ağacı).
Haber verildi, yeşile dönmesi bekleniyor.

---

# ═══ GÜNCEL DURUM — 2026-09-23 oturum sonu ═══

> Buradan aşağısı günün **son** hâlidir; yukarıdaki maddelerle çelişirse
> **bu bölüm geçerlidir.**

## Bugün kapanan

| Faz | Durum | Commit |
|---|---|---|
| Plan 07 Faz 1 | ✅ | `f546ece` (dün) |
| Plan 07 Faz 2 | ✅ | `91b983e` (dün) |
| **Plan 07 Faz 3** — DÖF dokunmatik | ✅ | **`8a2460a`** |
| **Plan 07 Faz 5** — PWA | ✅ kod bitti | **commit'lenmedi** (aşağı bak) |

## ⚠️ Devralanın ilk yapacağı: Faz 5'i commit'le

Faz 5 kodu **çalışır ve ölçüldü** ama commit edilmedi — `security-reviewer`
koşarken oturum kapandı.

**Commit'lenmemiş dosyalar:**

```
YENI  src/BkmArgus.Web/wwwroot/manifest.webmanifest
YENI  src/BkmArgus.Web/wwwroot/sw.js
YENI  src/BkmArgus.Web/wwwroot/js/argus-pwa.js
YENI  src/BkmArgus.Web/wwwroot/icons/argus-192.png
YENI  src/BkmArgus.Web/wwwroot/icons/argus-512.png
YENI  src/BkmArgus.Web/wwwroot/icons/argus-512-maskable.png
DEG   src/BkmArgus.Web/Features/Shared/_Layout.cshtml        (manifest + meta + betik)
DEG   src/BkmArgus.Web/Features/Shared/_ArgusTopbar.cshtml   (kurulum dugmesi)
DEG   src/BkmArgus.Web/Program.cs                            (no-cache garantisi)
DEG   src/BkmArgus.Web/wwwroot/css/argus-theme.css           (14 satir: .argus-install)
DEG   docs/journal/2026-09-23.md, 2026-09-23-kalan-isler.md, plans/07-mobil-pwa.md
```

**Yapılacak sıra:**
1. `security-reviewer`ı Faz 5 dosyalarına tekrar koştur (bu oturumdaki koşum
   sonucu alınamadı). Odak: servis çalışanı kimlik doğrulanmış içeriği
   önbelleğe alabilir mi.
2. CRITICAL çıkarsa düzelt; çıkmazsa commit.
3. Commit mesajına `[reviewed: security-reviewer]` yaz — `pre-commit-review-gate`
   hook'u bunu arıyor, yoksa **bloklar**.

**Build ve smoke zaten yeşil** (ölçümler `plans/07-mobil-pwa.md` "Faz 5
ölçümü" tablosunda). Kodun kendisine dokunmaya gerek yok.

## Sırada ne var

| # | İş | Bağımlılık |
|---|---|---|
| 1 | **Faz 5'i commit'le** (yukarıda) | denetçi |
| 2 | **Faz 4** — süzgeç kenar çubuğu → katlanır panel/alt sayfa, tek kolon form, `inputmode` | yok. `argus-sheet` **hazır**, Faz 3'te yazıldı |
| 3 | **Faz 6** — 360/390/768 her ekranda ölçüm + **gerçek cihazda kurulabilirlik** | Faz 4 |
| 4 | Plan 06 artıkları (DÖF kapsam kapısı domain kararı, S8a/b/c, S9, I11, I13) | `denetim-surec-danismani` |
| 5 | Fresh-DB migrate testinin tekrarı | `sql/`'a dokunmadan önce zorunlu |

### Faz 6 için özel not — **bu ölçüm henüz YAPILMADI**

`beforeinstallprompt` gömülü tarayıcı panelinde **tetiklenmedi**. Yani
"tarayıcı uygulamayı yüklenebilir sayıyor" done-criterion'u **ölçülmedi**.
Manifest + servis çalışanı + ikonlar + güvenli bağlam koşulları sağlanıyor
ama **istemin kendisi görülmedi**. Gerçek Chrome (masaüstü veya Android)
ile doğrulanmalı; kurulum düğmesi o zamana kadar **hiç görünmeyecek**
(bilerek: yakalanmayan istemde düğme gizli kalıyor).

## Bugünün üç dersi (tekrarlamamak için)

1. **"Yazıldı" ≠ "bir şeye değiyor".** Üç örnek tek günde:
   `.solum-nav-item` (kural yazıldı, eşleşen öğe yok) ·
   `.argus-tabs-panel` (kural var, kullanan yok) ·
   `Cache-Control` ara katmanı (başlık zaten vardı, bizimki üstüne ekleniyordu).
   Solum'da dördüncüsü: `data-solum-href` (kanca üretiliyor, okuyan yok).
   **CSS'te ve middleware'de fail-loud yok** — değdiğini ölçmeden bilemezsin.
2. **Ölçüm aracı sessizce yanlış cevap verebilir.** Ölü seçici taramasının
   ilk koşumu "0 ölü" dedi; gezdiği seçici sayısı da 0'dı. **Bir küme
   üzerinde "hepsi şu" diyen her ölçüm, kümenin boş olmadığını da ölçmeli.**
3. **Belgelenmiş ama denenmemiş geri alma, geri alma değildir.** Servis
   çalışanı rollback'i denendi ve **denerken gerçek bir kusur çıktı**
   (`/sw.js` başlıksız → tarayıcı eski betiği önbellekten verdi).

## Ortam tuzakları (başka makinede yeniden ısırır)

- **`D:\Dev\solum` aynı göreli konumda olmalı** — `BkmArgus.Web.csproj:23-25`
  üç `ProjectReference` ile canlı çalışma ağacına bağlı (TODO C9).
  **Bugün bu yüzden ~1 saat commit atılamadı:** Solum'un yarım K4 işi
  `Solum.Core`'u derlenemez yaptı, bizim tarafta 0 hata olmasına rağmen.
- **Build öncesi preview sunucusunu DURDUR.** Bir build `MSB3027/MSB3021`
  verdi; Solum hatası sanıldı, aslında çalışan sunucunun `Solum.Core.dll`
  kilidiydi (`test-discipline.md`'de kayıtlı).
- **Panel gizliyken tarayıcı betikleri 45 sn'de zaman aşımına uğruyor** —
  ölçümleri küçük parçalara böl.
- Branch: **`feature/solum-kabuk`**.

## Dev veritabanında bırakılan iz

Smoke gerçek kayıtla yapıldı: **DÖF 18** taşındı (DRAFT → OPEN → IN_PROGRESS
→ OPEN, şu an **OPEN**). `audit.AuditLog`'da Id 12'den itibaren izleri var.
Geri alınmadı — DRAFT'a dönüş meşru bir geçiş olmayabilir.
