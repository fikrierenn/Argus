# Plan 07 — Tam Mobil Uyum + Kurulabilir PWA

**Durum:** Aktif · **Tier:** 3 · **Açıldı:** 2026-09-22
**Kullanıcı kararı:** kurulabilir PWA + tam mobil, **çevrimdışı çalışma YOK**.
Öncelik: dört ekran grubunun hepsi (Saha Denetim · DÖF · Risk/Ürün · Anasayfa/Dashboard).

---

## Problem — ölçülen durum

| Konu | Ölçüm (2026-09-22) |
|---|---|
| `viewport` meta | **var** (`_Layout.cshtml:14`) |
| `manifest.json` / service worker | **yok** — PWA sıfırdan |
| Solum'un gerçek yerleşim kırılma noktası | **3** (`solum.css:588` 1100px · `:1064` 860px · `:593` 600px KPI ızgarası) |
| `solum-table` için mobil kural | **sıfır** — tablo telefonda yatay kaydırmaya düşüyor |
| `<td>`'de hücre etiketi | **yok** (`TableRenderer.cs:278` düz `<td>` basıyor) |
| Dokunma hedefi | `.solum-btn` `padding: 7px 13px` → ~31px yükseklik (WCAG 2.5.5 hedefi 44px) |
| Tailwind CDN | hâlâ `_Layout`'ta (8 taşınmamış ekran ona bağlı) |
| DÖF panosunda dokunmatik | **`touchstart`/`pointerdown` sayısı 0** — HTML5 sürükle-bırak dokunmatikte tetiklenmez |
| Uygulama ikonu | yalnız `favicon.ico` + `assets/bkmkitap-logo.png` |

**En sert iki nokta:**

1. **Tablolar.** Risk gezgini 8 kolon, denetim listesi 11 kolon. Telefonda
   yatay kaydırma demek, denetçinin sahada veriyi **göremediği** anlamına gelir.
2. **DÖF panosu telefonda kullanılamaz.** Sürükle-bırak HTML5 DnD ile yazıldı;
   dokunmatikte `dragstart` hiç tetiklenmez. Klavye yolu (Alt+←/→) masaüstü
   içindi. Yani panonun telefonda **hiçbir** durum değiştirme yolu yok.

---

## Kapsam

### İÇİNDE

| # | İş | Katman |
|---|---|---|
| M1 | Kabuk: yan menü telefonda gizlenir/çekmece, başlık sadeleşir | CSS + Solum değişkeni |
| M2 | Dokunma hedefleri ≥ 44px (buton, onay kutusu, menü öğesi, tablo satırı) | CSS |
| M3 | Tablo → **kart düzeni** (≤ 640px), hücre etiketleri JS ile | JS + CSS |
| M4 | DÖF panosu: tek kolon + **dokunmatik durum değiştirme** (kart → durum seçici) | JS + Razor |
| M5 | Süzgeç kenar çubuğu → katlanır/alt sayfa (Risk, Denetim) | Razor + CSS |
| M6 | Form akışı tek kolon, `inputmode`/`autocomplete`, tarih girdisi native | Razor |
| M7 | PWA: `manifest.json` + ikon seti + service worker + kurulum istemi | wwwroot + Razor |
| M8 | Ölçüm: 360/390/768 genişlikte smoke + kurulabilirlik kanıtı | — |

### DIŞINDA (bilinçli)

- **Çevrimdışı veri.** Kullanıcı kararı. Service worker **yalnız statik varlık**
  önbellekler; HTML ve `/api/*` **asla**.
- **Ayrı mobil uygulama / ayrı mobil site.** Tek kod tabanı, responsive.
- **Fotoğraf kuyruğu, arka plan senkronu, push bildirim.** Çevrimdışı kapsam dışı
  olduğu için hepsi dışarıda.
- **Taşınmamış 8 ekranın Solum'a taşınması** (plan 05 Dalga 2) — bu plan onlara
  yalnız *responsive* dokunur, ilkel değişimi yapmaz.

---

## Fazlar

### Faz 1 — Kabuk ve dokunma (M1, M2)
Yan menü ≤ 860px'te çekmeceye (Solum'un `solum.js` mobil menüsü var, ölçülecek:
gerçekten çalışıyor mu). Dokunma hedefleri: `.solum-btn`, `.solum-checkbox`,
menü öğesi, tıklanabilir tablo satırı ≥ 44px. `argus-theme.css` üzerinden
(rung 1 — Solum'un değişkenini ezmek, sınıfını gölgelemek değil).

### Faz 2 — Tablo kart düzeni (M3)
`<td>`'de etiket olmadığı ölçüldü, yani CSS-only çözüm **imkânsız**.
`argus-table-mobile.js`: her `.solum-table` için `<th>` metinlerini okuyup
`td.dataset.label` yazar; CSS ≤ 640px'te `display:block` + `::before{content:attr(data-label)}`.
Sayısal hücreler sağa yaslı kalır. **Solum'a bildirilecek:** `<td>`'ye
`data-solum-label` basmak mekanizma tarafına aittir; ikinci tüketici olduğumuzda
JS'i silip onların çıktısına geçeriz.

### Faz 3 — DÖF panosu dokunmatik (M4) ⚠ en riskli
Pano telefonda tek kolon + durum sekmesi. Durum değiştirme: karta dokun →
**durum seçici sayfa/alt sayfa** (sürükleme taklidi YOK — `pointer` olaylarıyla
sürükleme yazmak dokunmatikte kaydırma ile çakışır ve denetçi listeyi
kaydıramaz). Aynı `ArgusApi.post` yolundan geçer, aynı iz yazılır.

### Faz 4 — Süzgeç ve form (M5, M6)
Risk/Denetim süzgeç kenar çubuğu ≤ 860px'te katlanır panele iner; "Süzgeç (3)"
rozetiyle kaç ölçütün etkin olduğu görünür. Formlar tek kolon; sayısal alanlara
`inputmode="numeric"`, tarih alanları zaten `type="date"`.

### Faz 5 — PWA (M7)
- `manifest.json`: ad, kısa ad, `display: standalone`, tema/arka plan rengi
  (`--bkm-red`), `start_url: /`, `scope: /`.
- İkonlar: `assets/bkmkitap-logo.png`'den 192/512 maskable üretilecek.
- Service worker: **cache-first yalnız** `/css`, `/js`, `/assets`,
  `/_content/Solum.Web`; **HTML ve `/api/*` için network-only**.
  Gerekçe aşağıda (Riskler).
- `beforeinstallprompt` yakalanır, "Uygulamayı yükle" düğmesi kabukta görünür.

### Faz 6 — Ölçüm (M8)
360px (küçük Android), 390px (iPhone), 768px (tablet) genişliklerinde her ekran;
yatay kaydırma **yok**, dokunma hedefi ≥ 44px, pano telefonda durum değiştirebiliyor,
tarayıcı "yükle" diyor.

---

## Alternatifler (reddedilen)

**A. Ayrı mobil site / ayrı Razor alanı.** Reddedildi: iki ekran gerçeği doğar,
biri güncellenir öteki bayatlar — bu depoda aynı hatanın iki örneği zaten var
(`_Layout`'ta rol etiketi kopyası, `TrCulture` beş kopya).

**B. Tabloyu yatay kaydırmaya bırakmak.** Reddedildi: 8-11 kolonlu tabloda
denetçi sahada veriyi göremez; "çalışıyor ama kullanılamıyor" bu projede
kabul edilmiş bir sonuç değil.

**C. HTML'i de önbellekleyen service worker.** Reddedildi ve bu bir **güvenlik**
kararı: kimlik doğrulanmış sayfayı önbelleğe almak, çıkış yapmış ya da yetkisi
düşürülmüş kullanıcıya eski içeriği gösterir. Denetim yazılımında bu, yetki
kapısını delen bir önbellektir.

**D. Sürüklemeyi `pointer` olaylarıyla dokunmatiğe taşımak.** Reddedildi:
dokunmatikte sürükleme sayfa kaydırmasıyla çakışır; denetçi listeyi kaydırmaya
çalışırken kart taşır. Dokun → seç akışı hem erişilebilir hem kazasız.

---

## Riskler

| Risk | Azaltma |
|---|---|
| Service worker eski sürümü servis eder, kullanıcı güncellemeyi görmez | Sürümlü önbellek adı + `activate`'te eski önbellek temizliği; HTML zaten network-only |
| SW kimlik doğrulanmış içeriği önbelleğe alır | Yalnız statik yol beyaz listesi; `/api/*` ve HTML hiç dokunulmaz (Alternatif C) |
| Tailwind CDN'e bağlı 8 ekran PWA kabuğunda stilsiz kalır | Çevrimdışı kapsam dışı; CDN network-only kalır. CSP/Tailwind borcu ayrı (TODO C11) |
| Tablo JS etiketleyici Solum çıktısı değişince kırılır | Etiket yoksa kart düzeni yerine yatay kaydırmaya **düşer** (bozulmaz); Solum'a bildirilecek |
| Pano dokunmatik akışı masaüstü sürüklemeyi bozar | İki yol ayrı: sürükleme ve klavye aynen kalır, dokunmatik üçüncü yol |
| 44px hedef, yoğun tabloda satır sayısını azaltır | Kabul: okunabilirlik > yoğunluk, mobilde |

---

## Done criteria

- [ ] 360/390/768 genişlikte **hiçbir ekranda yatay kaydırma yok** (ölçüm: `scrollWidth <= clientWidth`)
- [ ] Risk, Denetim, DÖF listeleri telefonda kart düzeninde ve **her alan etiketli**
- [ ] DÖF panosunda telefondan durum değiştirilebiliyor + `audit.AuditLog`'a iz düşüyor
- [ ] Dokunma hedefleri ≥ 44px (ölçüm: `getBoundingClientRect().height`)
- [ ] Tarayıcı uygulamayı **yüklenebilir** sayıyor; ana ekrandan tam ekran açılıyor
- [ ] Service worker `/api/*` ve HTML'i önbelleğe **almıyor** (ölçüm: `caches.keys()` + içerik denetimi)
- [ ] Çıkış yapıp geri dönünce eski oturumun sayfası **gösterilmiyor**
- [ ] Build 0 hata · test 64/64 · `code-reviewer` + `security-reviewer` yeşil

## Rollback

Her faz ayrı commit. PWA fazı geri alınacaksa: `manifest.json` bağlantısı
`_Layout`'tan çıkarılır ve service worker `unregister` eden bir sürüm
yayımlanır — **dosyayı silmek yetmez**, kayıtlı SW tarayıcıda kalır. Bu,
"geri alma" adımı olarak faz 5'in içinde yazılacak.

---

## 5 Lens

- 🔴 **Contrarian:** Fatal kusur adayı service worker. Yanlış yazılmış bir SW, kimlik doğrulanmış sayfayı önbelleğe alıp yetki kapısını deler ve bunu **kimse fark etmez** — çünkü ekranda doğru görünür. Bu yüzden HTML hiç önbelleklenmiyor ve done criteria'da açıkça ölçülüyor.
- 🔵 **First Principles:** Asıl soru "responsive mi" değil; **denetçi mağazada telefonla denetim yapabiliyor mu**. Bu soruyu tablo genişliği değil, DÖF panosunun dokunmatikte hiç çalışmaması belirliyor — ölçüm onu gösterdi, tasarım sezgisi değil.
- 🟢 **Expansionist:** Kart düzeni + dokun-seç akışı, çevrimdışı istendiğinde (bugün hayır) gereken istemci-taraflı form altyapısının yarısını zaten kurar. Bugün yapmıyoruz ama kapıyı kapatmıyoruz.
- ⚪ **Outsider:** Saha denetim yazılımının telefonda kullanılamaması, yabancı birinin ilk dakikada soracağı şey: "denetçi bunu masaüstünde mi dolduruyor?"
- 🟡 **Executor:** Pazartesi sabahı Faz 1: `argus-theme.css`'e mobil kırılma noktaları + 44px hedefler; yarım gün, hiçbir şeyi bozmaz, her ekranda görünür kazanç.

---

## Faz Durumu (güncel: 2026-09-23)

| Faz | Durum | Kanıt / not |
|---|---|---|
| Faz 1 — kabuk ve dokunma | ✅ **bitti** | commit `f546ece`; üst çubuk 37px taşma → 0; yan menü ölçümü düzeltildi (`left=-256`, Solum'un kabuğu çalışıyor) |
| Faz 2 — tablo kart düzeni | ✅ **bitti** | commit `91b983e`; `/Risk` 375px 137px → **0**, 350/350 hücre etiketli, 0/17 hedef 44px altında; altı ekran 0 taşma. Ayrıca ölü `RowUrl` kancası 4 çağrı yerinde gerçek `<a>`'ya çevrildi |
| Faz 3 — DÖF panosu dokunmatik | ✅ **bitti** | `argus-sheet.js` (alt sayfa ilkeli, Solum'da yok) + kart → sarmalayıcı/`<a>`/durum düğmesi. Üç giriş yolu da ölçüldü: sürükleme, Alt+Ok, dokun→seç. İz `audit.AuditLog` Id 12 `DOF_GECIS`. 375px: taşma 0, **0/208** hedef 44px altında |
| Faz 4 — süzgeç ve form | ⬜ **sırada** | `argus-sheet` **hazır** (Faz 3'te yazıldı, yeniden kullanılacak); `<solum-field>` çoklu seçim **alınmadı** → `argus-checkgroup` kalıcı |
| Faz 5 — PWA | ✅ **bitti** | `manifest.webmanifest` + 3 ikon + `sw.js` (**yalnız statik**) + kurulum düğmesi. Ölçüldü: HTML ve `/api/*` önbelleğe **girmiyor**; geri alma yolu **denendi** |
| Faz 6 — ölçüm | ⬜ | 3/4/5'e bağlı |

### Solum talepleri (T0–T6) — cevap geldi 2026-09-23

Altısı da onların deposunda ölçüldü, altı iddia da doğrulandı; **hiçbiri
bugün uygulanmıyor** (aktif başlıkları K4). Tam metin ve ölçümler:
`docs/journal/2026-09-23-kalan-isler.md` §0 ve §0b.

- **T1** (`data-solum-label`) kabul edilebilir bulundu → geldiği gün
  `wwwroot/js/argus-table-mobile.js` **silinir**, davranış değişmez
- **T2** dar öneriye döndü: yalnız `cursor:pointer` kalkacak, kanca kalacak →
  **bizde iş yok**
- **T3 / T4** emsalli ama üç-ürün eşiği **1/3**; gelirse
  `argus-theme.css:325-340` ve `:446-470` blokları silinir
- **T5 / T6** alınmadı → `argus-sheet` ve `argus-checkgroup` bizde kalıcı
- **🔴 `Solum.Core` + `Solum.EntityFrameworkCore` kırıcı değişikliği
  duyuruldu, kod yazılmadı** — geldiğinde altıncı uyarlama turu

### Faz 3 ölçümü (2026-09-23)

| Ne | Ölçüm |
|---|---|
| Kart / gövde / durum düğmesi | 84 / 84 / 84 |
| İç içe etkileşimli öğe (`a button`) | **0** — düğme `<a>`'nın yanında, içinde değil |
| Dokun → seç → sunucu | DRAFT 65→64, OPEN 6→7, kart taşındı, `audit.AuditLog` Id **12** `DOF_GECIS` |
| Sürükleme (masaüstü regresyonu) | `dragstart` iç `<a>`'dan doğuyor, işleyici sarmalayıcıyı buluyor → OPEN→IN_PROGRESS ✅ |
| Klavye (regresyon) | Alt+← → IN_PROGRESS→OPEN ✅ |
| Durum düğmesi masaüstünde | `display: none` (`any-pointer: coarse` false) |
| 375px taşma | **0** |
| 44px altı dokunma hedefi | **0 / 208** |
| Konsol hatası | **0** |

**Faz 1'den düzeltilen hata:** `@media (pointer: coarse)` bloğundaki
`.solum-nav-item` seçicisi **hiçbir şeyle eşleşmiyormuş** (ölçüldü: sayfada 0).
Solum'un menüsü `nav.solum-nav > ul > li > a`, sınıfsız. Menü öğeleri 37px
kalmıştı — telefonda **en çok dokunulan** hedefler. `.solum-nav a` yapınca
12/208 → 0/208. Faz 1 ölçümüm içerik alanını saymış, çekmeceyi saymamıştı.

**Kaldırılan iki ölü CSS kuralı** (canlı DOM'a karşı tarandı, kaynakta 0 referans):
`.argus-tabs-panel` ve `.argus-cards .solum-table tr[data-solum-href]` —
ikincisi Faz 2'de `Linked()`e geçince karşılıksız kalmıştı ve Solum'un
CHANGELOG gerekçesinde adı geçen "tek tüketici kullanımı" tam olarak buydu.

### Faz 5 ölçümü (2026-09-23)

| Ne | Ölçüm |
|---|---|
| `manifest.webmanifest` | 200, `application/manifest+json`, `display: standalone`, 3 ikon, tema `#e30622` |
| İkonlar | 192 / 512 / 512-maskable, hepsi 200 + `image/png`; maskable içerik oranı 0.60 (güvenli alan) |
| Servis çalışanı kaydı | `argus-pwa.js` sayfa yüklenince kaydediyor → kayıt 1, durum `activated`, kontrolcü var |
| **HTML önbelleğe girdi mi** | **HAYIR** — `/` ve `/Dof` istendi, `CacheStorage` içeriği yalnız `/css/argus-theme.css` + `/icons/argus-192.png` |
| **`/api/*` önbelleğe girdi mi** | **HAYIR** |
| Çapraz kaynak (CDN) | önbellekte yok |
| Beyaz listede 404 | `/js/olmayan-dosya.js` → 404, önbelleğe **girmedi** (`yanit.ok` kapısı) |
| **Geri alma** | **denendi**: geçici `unregister` sürümü yayımlandı → `registration.update()` → önbellek `["argus-statik-v1"]` → `[]`, kayıt 1 → 0 |
| `/sw.js` `Cache-Control` | `no-cache` (tek değer) |
| Kurulum düğmesi 375px | "Yükle" 69×44, erişilebilir ad "Uygulamayı yükle" korunuyor, taşma 0 |

**Ölçüm sırasında bulunan gerçek risk:** `/sw.js` ve `/manifest.webmanifest`
hiç `Cache-Control` taşımıyordu → tarayıcı **sezgisel** önbellekleme
uyguluyor. Bedeli oturumda yaşandı: geri alma testinden sonra gerçek servis
çalışanı geri konduğunda tarayıcı **eski betiği HTTP önbelleğinden** servis
etti ve yeni SW hiçbir şeyi önbelleklemedi. Üretimde bu, **geri almayı
sessizce etkisiz kılar**. `Program.cs`'e `OnStarting` ile `no-cache` garantisi
eklendi.

> İlk denemede başlık doğrudan atandı ve `"no-cache, no-cache"` çıktı —
> `MapStaticAssets` parmak izsiz varlıklara zaten `no-cache` basıyormuş.
> Yani ara katman **hiçbir şey eklemiyordu**; bu oturum boyunca avladığımız
> "yazıldı ama bir şeye değmiyor" sınıfının bir örneği daha. `OnStarting`
> ile üzerine yazacak hale getirildi: tek değer + işleyici değişse bile garanti.

**DOĞRULANMADI:** tarayıcının kurulum istemi (`beforeinstallprompt`) bu
gömülü panelde **tetiklenmedi**, dolayısıyla "tarayıcı uygulamayı yüklenebilir
sayıyor" ölçütü **gözlemlenmedi**. Manifest + SW + ikon + güvenli bağlam
koşulları sağlanıyor ama istemin kendisi görülmedi → gerçek Chrome/Android'de
doğrulanmalı (Faz 6).

### 🔴 Faz 5 — `security-reviewer` bulgusu ve düzeltmesi (aynı gün)

Denetçi **confidence 90** ile gerçek bir kusur buldu (IMP-1):
**cache-first + parmak izsiz adres = istemci kodu kalıcı donar.**

Sunucu `/_content/Solum.Web/solum.js` için `Cache-Control: no-cache` beyan
ediyor (ölçüm: `staticwebassets.endpoints.json`). Cache-first bunu görmezden
gelir; `ONBELLEK` sabiti elle yükseltilene kadar eski kopya servis edilir.
Solum paylaşılan katman ve aktif geliştirmede — oraya bir **güvenlik
düzeltmesi** girdiği gün, önbelleğe bir kez girmiş her tarayıcı düzeltmeyi
**hiç almaz** ve ekranda her şey doğru görünür.

**Düzeltme:** önbellek artık **parmak izi zorunlu** kılıyor. Yalnız içeriğini
adresinde taşıyan varlık (`ad.<parmakizi>.uzanti` veya `?v=`) önbelleğe
girer; içerik değişince adres değişir, bayat kopya **imkânsız**. Ayrıca
uzantı beyaz listesi eklendi ve `/manifest.webmanifest` listeden çıkarıldı
(IMP-2 · IMP-3).

| Ölçüm (düzeltme sonrası) | Sonuç |
|---|---|
| Önbellekteki 9 anahtarın hepsi parmak izli mi | **evet** |
| İçerik | `app.nk7guychm1.css` · `argus-theme.03hxjw3dor.css` · `solum.vofa6q873o.css` · `solum.ep1l6wu3e4.js` · `argus-shell/table-mobile/pwa` · `tailwind.config` · `logo` |
| Parmak izsiz `/css/argus-theme.css` | önbelleğe **girmiyor** |
| `/icons/*.png`, `/manifest.webmanifest` | önbelleğe **girmiyor** (küçük dosya, kazancı yok riski var) |
| **Yedi negatif yol** (parmak izsiz css/ikon/manifest, 404, `..%2F` traversal, navigate-olmayan HTML, `/api/*` GET) | önbellek anahtar sayısı **9 → 9, değişmedi** |

**DOĞRULANMADI (denetçinin istediği, yapılmayan):** varlık tazeliği testi
(bir dosyayı değiştirip depolamayı temizlemeden yeniden yükleme) · iki rolle
paylaşımlı cihaz turu · iOS Safari üzerinde `mode === "navigate"` ve
`apple-touch-icon` teyidi. Üçü de Faz 6'ya.
