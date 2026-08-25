# 04 — Dashboard'ı Solum çatısı üzerine oturtma

**Tier:** 3 · **Durum:** uygulanıyor (onay: 2026-08-25, Fikri)
**Tarih:** 2026-08-25 · **Sahip:** Fikri

> **Solum tarafı mutabakatı (solum-8d oturumu, 2026-08-25):** raporladığımız 6 boşluğun
> tamamı kabul edildi — (1) `--solum-sidebar-bg/fg` eklenecek, (2) switch-company
> BASLARKEN+CHANGELOG'a zorunlu adım, (3) tipli kabuk taşıyıcısı (Tier 3, plan yazılıyor),
> (4) `AddSolumWeb()`, (5) `ClaimsPermissionChecker`, (6) Razor Pages kilidi YOL-HARITASI'na.
> **Karar değişikliği:** `.solum-card` / `.solum-kpi` **CSS'i** pakete giriyor (ReportHub
> şeklinden); C# `KpiModel` sözleşmesi girmiyor (gerçek KPI tüketicisi 2, eşik 3). Yani
> Faz 3'te `argus-kpi` yerine `solum-kpi` kullanılabilir — CSS hazır olduğunda kontrol et.
> Ayrıca Solum master'da bugün iki ölçülmüş sessiz veri kaybı düzeltildi (onay kutusu
> `false` bağlanması + `ReadOnly` etkisizliği) — referans bugünkü master'a çekilir.

## Problem

**Kanıtlanmış üç bulgu:**

1. **Kabuk elde örülü ve büyük.** `src/BkmArgus.Web/Features/Shared/_Layout.cshtml` = **406 satır**;
   yan menünün 20+ bağlantısı satır içi SVG + `NavClass()` yardımcısıyla tek dosyada.
   `csharp-conventions.md` 300/500 satır sınırının üstünde.
2. **Dashboard tekrar üretiyor.** `Features/Dashboard/Index.cshtml` = **504 satır**;
   KPI kartı, rozet ve tablo işaretlemesi elle (`TabClass`, `DofBadge`, `HealthBadge`,
   `ComplianceBadgeClass`, `ComplianceTextClass` — 5 ayrı sınıf-üretici fonksiyon,
   satır 6-36). Grafik alanı boş `<div class="mt-4 h-44">` + `TrendPoints` polyline.
3. **Solum'un tüketicisi yok.** `D:\Dev\solum` CLAUDE.md: *"Solum'un bugün hiç
   tüketicisi yok… docs/PLAN.md risk tablosunun ilk satırı 'tüketicisiz çatı'"*.
   `grep -rn "Solum" src/ Directory.*.props` → **0 sonuç**: BkmArgus henüz Solum'a
   hiç dokunmamış.

Bu iş ikisini birden kapatır: BkmArgus tekrar + dosya-boyutu borcunu düşürür,
Solum ilk gerçek tüketicisini kazanır.

## Kapsam

**Dahil:**
- `Solum.Abstractions` + `Solum.Core` + `Solum.Web` → `BkmArgus.Web` proje referansı
- Bağlam adaptörleri (BkmArgus kimliği → Solum sözleşmesi): `ICurrentUser`, `IClock`,
  `ICurrentCompany` (tek şirket), `IPermissionChecker` (rol/policy köprüsü)
- Menü: `_Layout` içindeki 20+ elle yazılmış bağlantı → tek `IMenuContributor`
- Kabuk: `_Layout.cshtml` → Solum kabuk parçaları + `:root` değişken ezmesiyle BKM paleti
- `Features/Dashboard/Index.cshtml` yeniden tasarım: Solum tablo/rozet/boş-durum +
  uygulama-yerel KPI/panel/sekme/grafik ilkelleri

**Hariç (bilerek):**
- **Diğer ~20 ekran** (Risk, DOF, Audit, Ai, Ref, Yonetim…) — Dashboard pilot; kabuk
  ortak olduğu için görünüm zaten akar, içerik dönüşümü ayrı faz.
- **`Solum.EntityFrameworkCore` + `Solum.Identity`** — BkmArgus `architecture.md`
  gereği **SP-first + Dapper**; Solum'un CRUD/EF yarısı buraya uymaz, alınmaz.
  Solum'un kendi sınırı da bunu söylüyor: *"CRUD → EF Core. Raporlama, toplu işlem,
  çok tablolu birleştirme → SQL."* Dashboard tamamen raporlama tarafı.
- **Solum paketine kod eklemek** — KPI kartı, panel, sekme ve grafik Solum'da **YOK**
  (`solum.css` 255 satır tarandı: shell·nav·table·pager·toolbar·btn·field·badge·alert·empty
  var; card·kpi·tab·chart yok). Bunlar BkmArgus'ta `argus-*` olarak kalır — Solum'un
  **üç ürün eşiği** ("bir yetenek üç üründe kanıtlanmadan paketlenmez") tek tüketiciyle
  karşılanmaz.
- **NuGet paketleme** (`VersionPrefix 0.1.0`, yayınlanmış besleme yok).
- **Kiracılık** — BkmArgus tek kiracı; `ICurrentTenant` gerekmedikçe bağlanmaz.

## Reddedilen alternatifler

| Alternatif | Neden reddedildi |
|---|---|
| Kabuk elde kalsın, yalnız Dashboard'a kozmetik dokunuş | İki borcun hiçbirini kapatmaz: 406 satırlık düzen ve 20 elle-yazılmış menü bağlantısı yerinde kalır, Solum tüketicisiz kalır |
| Koyu yan menüyü korumak için `_SolumSidebar` gölgelemek | **Ölçülmüş sonuç:** gölgelenen dosya güncelleme almayı bırakır (Solum değiştirme merdiveni 5. basamak). Kabuk tam bu yüzden 11 parçaya bölünmüş |
| BkmArgus'u Solum EF/CRUD yığınına taşımak | `architecture.md` SP-first'i ihlal eder; Dashboard SP'lerden besleniyor (`rpt.sp_Dashboard_Kpi`, `dof.sp_Dashboard_Dof_List`, `audit.sp_Dashboard_*`) — EF'e çevirmenin veri-doğruluğu getirisi yok |
| Solum'u NuGet paketi olarak almak | Yayınlanmış besleme yok, sürüm `0.1.0` lockstep, iki depo eşzamanlı gelişiyor; proje referansı iterasyonu hızlandırır |
| KPI/panel/sekme/grafik ilkellerini Solum'a eklemek | Üç-ürün eşiği; tek tüketiciden paket API'si çıkarmak "ileride lazım olur" soyutlamasıdır (Solum CLAUDE.md'nin açıkça reddettiği şey) |

## Tasarım

### Dokunulan / yeni dosyalar

| Dosya | İşlem |
|---|---|
| `src/BkmArgus.Web/BkmArgus.Web.csproj` | 3 `ProjectReference` (`..\..\..\solum\src\Solum.{Abstractions,Core,Web}`) |
| `BkmArgus.sln` | Solum projeleri çözüme eklenir (derleme zinciri görünür olsun) |
| `src/BkmArgus.Web/Security/SolumContext.cs` | **YENİ** — `ArgusCurrentUser : ICurrentUser`, `SystemClock : IClock`, `SingleCompany : ICurrentCompany` |
| `src/BkmArgus.Web/Security/ArgusPermissionChecker.cs` | **YENİ** — `IPermissionChecker`; izin adı → BkmArgus policy (`Policies.AdminOnly`, `Policies.YonetimVeUstu`) |
| `src/BkmArgus.Web/Features/ArgusMenu.cs` | **YENİ** — `IMenuContributor`; menü ağacı + `RequiredPermission` |
| `src/BkmArgus.Web/Program.cs` | DI kayıtları (`IMenuBuilder`→`MenuBuilder`, adaptörler, `ITableRenderer`) |
| `src/BkmArgus.Web/Features/Shared/_Layout.cshtml` | 406 → ince kabuk; Solum parçalarını çağırır, BkmArgus'a özgü olan (bildirim çanı, DB durum göstergesi) **kendi parçasına** çıkar |
| `src/BkmArgus.Web/wwwroot/css/argus-theme.css` | **YENİ** — `:root` Solum değişken ezmesi (BKM paleti) + `argus-kpi` / `argus-panel` / `argus-tabs` |
| `src/BkmArgus.Web/Features/Dashboard/Index.cshtml` | 504 → ≤300; Solum tablo/rozet/boş-durum + yerel KPI/panel/sekme |
| `src/BkmArgus.Web/Features/Dashboard/Index.cshtml.cs` | `TableModel<T>` sütun tanımları; SP çağrıları **değişmez** |

### Tema — değişken ezmesi (merdiven 1. basamak)

```css
:root {
  --solum-accent:      #E30613;   /* bkm-red — tailwind.config.js ile aynı değer */
  --solum-accent-ink:  #ffffff;
  --solum-bg:          #F3F4F6;   /* bkm-canvas */
  --solum-font:        Inter, ui-sans-serif, system-ui, sans-serif;
  --solum-bad:         #E30613;
  --solum-good:        #10B981;   /* bkm-safe */
}
```

**Bilinen sınır (dürüstçe):** bugünkü koyu yan menü (`bkm-dark #2D2D2D`) bu yolla
**birebir korunamaz** — Solum'da `--solum-sidebar-bg` değişkeni yok; yan menü
`--solum-surface`'ı kart ve üst çubukla paylaşıyor. Faz 2 Solum'un açık yan menüsüyle
çıkar (marka vurgusu kırmızı). Koyu menü şart ise doğru yol **Solum'a değişken
eklemek** (1. basamak, her tüketiciye yarar) — ayrı iş, ayrı oturum: *"Solum üzerinde
çalışılacaksa oturum Solum'da başlar"* (Solum CLAUDE.md; kapılar aksi hâlde yüklenmiyor).

### İki CSS bir arada

`solum.css` yalnız `.solum-*` seçicileriyle çalışır ve kendi dosyasında bunu söylüyor:
*"Uygulama sayfaların kendi yardımcı-sınıf düzenini kullanmaya devam eder; ikisi
çakışmaz."* Tailwind CDN (`cdn.tailwindcss.com`) kalır — dönüştürülmemiş 20 ekran hâlâ
ona bağlı. Faz 4'te preflight sıfırlamasının Solum kabuğunu bozmadığı doğrulanır.

### BkmArgus kısıtları

- [x] SP-first — inline SQL eklenmiyor; mevcut `sp_Dashboard_*` çağrıları korunuyor
- [x] Türkçe SP parametresi ↔ İngilizce kolon — SP'ye dokunulmuyor
- [x] `src.*` view'a dokunulmuyor
- [x] `rpt.*` snapshot idempotency — okuma tarafı, yazma yok
- [x] `[Authorize]` — `Index.cshtml` attribute'u korunur; menü gizlemesi **yetki değil**
      (iki deponun kuralı aynı: asıl kapı sayfa attribute'u)
- [x] AI — bu işte yeni LLM çağrısı yok
- [x] `@Html.Raw` — Solum tablo üreticisi hücreleri kaçırır; menü ikonu geliştirici
      yazımı satır içi SVG (kullanıcı verisi değil)

## 5 lens

- 🔴 **Contrarian:** Fatal hata = iki tasarım dili yarı yolda kalır; 21 ekranın 1'i
  Solum, 20'si Tailwind → tutarsız ürün. Önlem: kabuk **hepsi için ortak** değişir
  (menü/üst çubuk), yalnız içerik pilotu Dashboard'da kalır.
- 🔵 **First Principles:** Doğru soru "dashboard nasıl görünsün" değil, *"bu tekrar
  neden var"* — cevap: paylaşılan kabuk yokluğu. Solum tam bunu çözüyor.
- 🟢 **Expansionist:** Kabuk ortaklaşınca 20 ekranın menü/başlık/boş-durum tekrarı da
  tek yere iner; asıl kazanç Dashboard'dan büyük.
- ⚪ **Outsider:** Yabancı biri "aynı repoda iki CSS sistemi neden" diye sorar — gerekçe
  yazılı olmalı (`argus-theme.css` başına yorum).
- 🟡 **Executor:** Pazartesi ilk adım = Faz 1: 3 proje referansı + 4 adaptör, **hiç
  görsel değişiklik yok**, derleme yeşil. Geri alması tek commit.

### Faz 3 öncesi Solum durumu (doğrulandı — Solum `9c27533`)

Ölçülmüş ihtiyaç listemizin **dördü de** pakete girdi; `solum.css` içinde satır satır teyit edildi:

| İhtiyaç | Karşılığı | Satır |
|---|---|---|
| Panel kabı + başlık şeridi (24 tekrar) | `.solum-card` + `-head`/`-title`/`-sub`/`-foot`, head zaten `space-between` | 166, 190-196 |
| Sağa yaslı eylem grubu | `.solum-row-side` | 186 |
| Liste satırı (4 tekrar) | `.solum-row` + `-main`(`min-width:0`)/`-label`/`-desc` | 178-183 |
| KPI 6 kolon | `--solum-kpi-cols` (değişken; kırılmada yarıya düşer 6→3→1) | 212-224 |
| Grafik rengi (2 çıplak hex) | `.solum-spark` (`currentColor` + `--solum-accent`), `-base`, `-area` | 310 |
| KPI durum/yargı | `.solum-kpi-good/bad/flat-judge` + ton kenarı + `-missing`/`-hint` | 269-323 |

**Sonuç:** `argus-theme.css`'te planlanan `argus-kpi` / `argus-panel` **yazılmayacak** — hepsi `solum-*` karşılığından gelecek. **Yerel kalan tek şey: sekme şeridi** (`argus-tabs`) — tek kullanım, üç-ürün eşiğine takılır, Solum bilerek almadı.

Faz 3'te Solum'a geri dönecek 4 kanıt: `UrlGuard` meşru drill adreslerini reddetmiyor · gruplu menü (boş-grup dalı + alt öğe tam-yol çağrısı) · `_SolumEmpty` tablo içinde · `KpiDelta`/`Judge()` canlı veriyle.

## Riskler

| Risk | Etki | Önlem |
|---|---|---|
| Depo-arası `ProjectReference` (`D:\Dev\solum`) makinede yoksa derleme kırılır | Yüksek | Yol göreli (`..\..\..\solum`); `deploy.ps1` publish denemesi **Faz 1 bitiş kanıtı**. Kırılırsa plan B: yerel besleme + `.nupkg` |
| Tailwind CDN preflight'ı Solum kabuğunu bozar | Orta | Faz 4 smoke: kabuk + tablo + rozet ekran görüntüsü; bozulursa `argus-theme.css`'te hedefli düzeltme (dosya gölgeleme değil) |
| Koyu menü kaybı kullanıcıya sürpriz olur | Orta | Planda açık yazıldı; onay bu bilgiyle alınır. Koyu menü isteniyorsa Solum değişkeni ayrı iş |
| İki yetki gerçeği (`IPermissionChecker` vs `Policies`) | **Yüksek** | Adaptör **yalnız** BkmArgus policy'sini okur, kendi kuralını taşımaz. Menü gizlemesi güvenlik sayılmaz |
| `CrudPageModel`'e özenip Dashboard'ı CRUD sayfası sanmak | Düşük | Dashboard rapor ekranı; `CrudPageModel` kullanılmıyor (`Page()` gizlenme tuzağı da bu yüzden geçersiz) |

## Adımlar

- [x] **Faz 1 — Bağlam + referans (görsel değişiklik yok).** ✅ 2026-08-25
      3 proje referansı + 4 adaptör (`Security/SolumContext.cs`, `Security/ArgusPermissionChecker.cs`)
      + 7 DI kaydı (`Program.cs`). Kanıt:
      · `dotnet build BkmArgus.sln` → **0 hata**, 32 uyarı (hepsi önceden var olan borç: AiWorker CS8618/CS8603, `Dof/Detail.cshtml:39` CS8321 — Faz 1'den gelen yeni uyarı yok)
      · `dotnet publish` → yeşil; RCL statik varlığı `wwwroot/_content/Solum.Web/solum.css` publish çıktısında **doğrulandı** (Faz 2 buna link verecek)
      · Boot smoke: yayınlanmış çıktı Production → `GET /Account/Login` **HTTP 200**; Development → **HTTP 200** (Development'ta `ValidateOnBuild` açık, yani 7 Solum kaydının bağımlılık grafiği başlangıçta doğrulandı)
      · **Uyarı — henüz kanıtlanmayan:** kayıtların gerçekten TÜKETİLDİĞİ yol yok (hiçbir sayfa `IMenuBuilder`/`ITableRenderer` çağırmıyor). Uçtan uca kanıt Faz 2'de `_SolumSidebar` ile gelir.
      · `deploy.ps1` **çalıştırılmadı** — sunucuya kopyalama içerebilir, dış-etkili; yerine `dotnet publish` kullanıldı.
      · Yan etki: `dotnet sln add` Solum.Sql'i de çözüme ekledi (aşağıdaki bulgu 7).

> **Faz 1'de çıkan yeni bulgu (Solum'a raporlandı — 7.):** `Solum.Core.csproj:9`
> `Solum.Sql`'e ProjectReference veriyor ama Core içinde **tek satır kullanımı yok**
> (`grep -rn "Solum\.Sql" src/Solum.Core/` → 0). Sonuç: Core alan herkes Solum.Sql'i de
> taşıyor. Publish çıktımızda `Solum.Sql.dll` **var** — biz istemedik, bağımlılık grafiği
> getirdi. README/BASLARKEN §0 "Core → yalnız Abstractions" diyor; gerçek bu değil.
- [x] **Faz 2 — Kabuk.** ✅ 2026-08-25 · **açık yan menü** (kullanıcı kararı; koyu menü
      Solum değişkeni gelince iki satırla döner)
      Yeni: `Features/ArgusMenu.cs` (IMenuContributor + `RoleLabel`) ·
      `Features/Shared/_ArgusSidebar|_ArgusTopbar|_ArgusFooter|_ArgusNotifications.cshtml` ·
      `wwwroot/css/argus-theme.css` · `wwwroot/js/argus-shell.js`. Kanıt:
      · `_Layout.cshtml` **406 → 56 satır** (hedef ≤80 ✔); `grep -c asp-page _Layout` = **0**
      · Menü tek kaynakta: elle yazılmış ~24 anchor (13 sidebar + 12 mobil kopya) → 12 `MenuItem`
      · Build 0 hata (1 önceden var olan uyarı)
      · `/Error` (anonim, kabuklu) **HTTP 200**; DOM: `solum-shell`/`solum-sidebar`/`solum-topbar`/`solum-nav`/`solum-main`/`solum-footer` **var**
      · Tema ezmesi ölçüldü: `--solum-accent` = `#E30613`, `--solum-bg` = `#F3F4F6`, font Inter, grid `256px 1024px`, yatay kaydırma **yok**
      · Varlıklar 200: `_content/Solum.Web/solum.css` · `argus-theme.css` · `solum.js` · `argus-shell.js` (.NET 10 fingerprint'li)
      · Mobil çekmece: `data-solum-menu-toggle` tıklaması `data-solum-menu` `open`↔`closed` (solum.js çalışıyor) — 12 kopya mobil anchor kaldırıldı, yerine çekmece
      · İzin süzmesi: anonim kullanıcıda 5 menü öğesi (AI/Korelasyon/Tanımlar/Yönetim/Ayarlar **gizli**); korumalı 7 rota **302 → login**, `/Account/Login` 200
      · **DOĞRULANMADI:** oturum açmış kabuk (kullanıcı kartuşu, bildirim çanı, ADMIN/YÖNETİCİ menü öğeleri) — kimlik bilgisi yok, elle giriş gerekiyor.
      · **Önceden var olan 3 kırık** (eski `_Layout`'tan taşındı, düzeltilmedi): `assets/bkmkitap-logo.png` **404** (dosya repoda hiç yok) · `js/tailwind.config.js` CDN'den ÖNCE yükleniyor → `tailwind is not defined` (özel renkler aslında `app.css`'ten geliyor) · bildirim panelindeki `/Bildirimler` linki **404**
      · **Kaldırılan (onay bekliyor):** ust cubuktaki tarih + arama girdileri — `form`/`name`/JS bağı yoktu, işlevsizdi.
- [x] **Faz 3 — Dashboard yeniden tasarım.** ✅ 2026-08-25 · Solum `0411b67`+ (çalışma ağacı)
      Yeni: `Features/Dashboard/DashboardView.cs` (sunum haritası, 266 satır) ·
      `tests/BkmArgus.Tests/DashboardViewTests.cs` (17 test) · `argus-tabs`/`argus-split`/`argus-kpi-6` CSS.
      Ölçüm: `Index.cshtml` **504 → 292** · sınıf-üretici fonksiyon **7 → 0** · çıplak hex **2 → 0** ·
      inline style 0 · Tailwind kart kabı **24 → 0** (`.solum-card`) · 4 tablo `SolumTable` ·
      5 boş durum `_SolumEmpty` · 14 KPI `KpiCard` (`--solum-kpi-cols: 6` denetim sekmesinde).
      **Test: 17/17 geçti** (`dotnet test --filter DashboardViewTests`). Kapsam:
      polarite matrisi tüketici tarafında (`Decrease + LowerIsBetter = Good`) · delta yokluğunda
      uydurma yok (seri <2 nokta → null) · `UrlGuard` drill adresini reddetmiyor ·
      `solum-empty` + HTML kaçırma · rozet haritası · bilinmeyen durum kırmızı değil.
      **DOĞRULANMADI:** tarayıcı görünümü — Dashboard `[Authorize]`, şifre girmek yasak (B9).
      Not: `tests` projesine `BkmArgus.Web` referansı + `Microsoft.Data.SqlClient` 6.0.1→6.1.3
      (NU1605 downgrade hatası). C9 riski gerçekleşti: Solum çalışma ağacı bir ara derlenmedi
      (`RS0026` `ICrossCompanyScope.RunAsync`), test o yüzden gecikti — kendileri düzeltti.
- [ ] **Faz 4 — Denetim + smoke.** `phase-review-gate.md` zinciri: build →
      `code-reviewer` → `security-reviewer` → tarayıcı smoke (3 sekme, boş durum, mobil
      menü, koyu tema). Solum tarafına dokunulduysa `solum-denetci` (Solum oturumunda).

## Bitiş kriteri (kanıtlanabilir)

- [ ] `wc -l Features/Shared/_Layout.cshtml` ≤ 80 (bugün 406)
- [ ] `wc -l Features/Dashboard/Index.cshtml` ≤ 300 (bugün 504)
- [ ] `grep -c "asp-page" Features/Shared/_Layout.cshtml` = 0 → menü tek `IMenuContributor`'da
- [ ] `grep -rn "style=\"" Features/Dashboard/` = 0
- [ ] `dotnet build BkmArgus.sln` 0 hata · Solum testleri 187/187 geçer
- [ ] 3 sekme + boş durum + 860px altı mobil menü tarayıcıda doğrulandı (ekran görüntüsü)
- [ ] Solum `docs/PLAN.md` "tüketicisiz çatı" riski artık bir tüketiciye işaret ediyor

## Geri alma

Şema/migration **yok** → geri alma tamamen kod. Faz başına tek commit:
`git revert <faz-commit>`. Faz 1 geri alınırsa `.csproj`'dan 3 referans ve
`Security/SolumContext.cs` düşer, kabuk eski hâline döner. Solum deposunda bu planla
**hiç değişiklik yapılmaz** (koyu menü değişkeni ayrı iş).
