# 05 — BkmArgus'un tamamını Solum'a taşıma

**Tier:** 3 · **Durum:** taslak (onay bekliyor)
**Tarih:** 2026-08-25 · **Sahip:** Fikri
**Öncesi:** `plans/04-solum-dashboard.md` (Faz 1-4 tamam — kabuk + Dashboard pilotu)

## Problem

Plan 04 kabuğu ortaklaştırdı ve Dashboard'ı Solum ilkelleriyle yeniden yazdı; **kalan 25 ekran**
hâlâ elle örülü Tailwind. Sonuç bugün melez: kabuk `solum-*`, içerik iki dilde. Kullanıcı kararı
(2026-08-25): **tamamı taşınacak**, eksikler Solum oturumuyla birlikte geliştirilecek.

## Ölçüm (26 ekran, `grep -c`, 2026-08-25)

| Ekran | Satır | Ekran | Satır |
|---|---|---|---|
| `Ref/Index` | **1145** | `Ai/Index` | 422 |
| `Dof/Detail` | 363 | `Risk/Index` | 303 |
| `Dashboard/Index` | 292 ✅ | `Audit/Reports` | 279 |
| `Ai/Providers` | 262 | `Ayarlar/Index` | 242 |
| `Audit/Edit` | 237 | `Audit/Items` | 236 |
| `Audit/Detail` | 224 | `Urun/Index` | 193 |
| `Dof/Index` · `Audit/Index` | 182 | `Ai/Ogrenme` | 173 |
| `Correlation/Index` | 163 | `Yonetim/Index` | 139 |
| `Ai/SkillResult` | 131 | `Account/Login` | 129 |
| `Ai/Detay` | 74 | `Dof/Create` | 66 |
| `Index` · `Audit/Create` | 61 | `Error` · `AccessDenied` · `Logout` | 5-23 |
| `Account/ChangePassword` | 83 | | |

İlkel kullanımı (dosya / geçiş): `<form` **17/53** · `<input` **16/171** · `asp-for` **6/130** ·
`asp-validation` **4/35** · `<select` 8/22 · `<textarea` 4/5 · `<table` **11/26** · `<svg` 10/20 ·
`type="file"` 1/1 · `modal` 1/11 · `kanban`+`draggable` 1/1 · `data-combobox` **0** ·
sayfalama **0** · chart kütüphanesi **0**.

## Kapsam

**Dahil:** 25 ekranın içeriği Solum ilkellerine (`.solum-card` · `.solum-row` · `SolumTable` ·
`KpiCard` · `FieldRenderer` · `_SolumEmpty` · `.solum-pager`) taşınır. Her ekran ayrı commit.
Tailwind CDN, son ekran taşındığında `_Layout`'tan **kaldırılır** (bugün 25 ekran ona bağlı).

**Hariç (bilerek):**
- Kanban sürükle-bırak (`Dof/Index`), modal (`Audit/Items`), dosya yükleme (denetim fotoğrafı) —
  alan-özel, Solum'a verilmedi; `argus-*` kalır.
- `Solum.EntityFrameworkCore` + `Solum.Identity` — SP-first + Dapper kararı değişmiyor.
- SP/şema değişikliği yok. Bu plan tamamen sunum katmanı.

## Solum bağımlılıkları — taşıma sırasını bunlar belirliyor

| # | Solum'da gereken | Kim | Bizde bekleyen |
|---|---|---|---|
| S1 | **`Pages/_ViewImports.cshtml` + `addTagHelper`** — bugün 10 `<partial>` çağrısı ölü, kabuk parçaları birbirini çağıramıyor (ölçüldü) | Solum | gruplu menü + Solum kabuk parçalarını kullanma seçeneği |
| S2 | **`asp-for` / `ModelExpression` köprüsü** — `FieldRenderer` string tabanlı, formlarımız model-bağlı | Solum | **17 dosya / 53 form / 130 `asp-for`** |
| S3 | **`ModelState` → alan hatası sözleşmesi** | Solum | 4 dosya / 35 `asp-validation` |
| S4 | `AddSolumWeb()` | Solum | 7 elle DI kaydı |
| S5 | Tipli kabuk taşıyıcısı + yuva | Solum | 26 ekran kabuğu kullanıyor |
| S6 | Combobox kararı (uzun `<select>`) | Solum/bizde | 8 dosya / 22 `<select>` |
| S7 | Sekme şeridi kararı | Solum/bizde | 4 ekran (Ref 8 sekme, Dashboard 3, Ai, Audit/Reports) |
| S8 | `@Html.SolumKpiGrid` simetrisi | Solum | KPI'lı her ekran |

## Taşıma sırası (bağımlılığa göre — form köprüsü beklemeyenler önce)

- [ ] **Dalga 1 — tablo/liste ağırlıklı (Solum'u beklemez).** `Risk/Index` · `Dof/Index` ·
      `Audit/Index` · `Correlation/Index` · `Urun/Index` · `Index` (Genel Bakış).

      ⚠ **ÖLÇÜLDÜ — sayfalama sözleşmesi eksik, bu bizim tarafın işi:**
      · `rpt.sp_RiskList` sayfalamayı **destekliyor**: `@Page` · `@PageSize` · `@Search` ·
        `@OrderBy` + `@OrderDir` (beyaz listeli sıralama anahtarı, `sql/12_sps_risk.sql:52-70`).
        Solum `TableModel`'in `Search`/`Sort` sözleşmesiyle birebir örtüşüyor.
      · **AMA toplam satır sayısı dönmüyor** (`grep TotalCount|COUNT(*)` → 0).
        `PagedResult<T>` sayfa sayısını `TotalCount`'tan hesaplıyor; onsuz `.solum-pager`
        çizilemez.
      · C# tarafı bugün `Top = 500` gönderiyor, `Page`/`PageSize` **kullanılmıyor**
        (`Features/Risk/Index.cshtml.cs:99`).
      · Diğer Dalga 1 listelerinde sayfalama **hiç yok** (`audit.sp_Audit_List @Top`,
        Dof, Correlation, Urun → TOP-N).

      **Karar gerekiyor (kullanıcı):**
      (a) **TOP-N kal** — `SolumTable` alınır, pager kullanılmaz. Dalga 1 saf sunum işi,
          SQL'e dokunulmaz. Solum'un sayfalama dalı doğrulanmadan kalır.
      (b) **Sayfalama sözleşmesini kur** — liste SP'lerine `@Sayfa`/`@SayfaBoyutu` +
          toplam sayı eklenir. Bu **SQL işi**: `bkmargus-sp-first` + `sql-migration-writer`
          danışmanı, `sql-sp-reviewer` denetimi, yeni `sql/NN_*.sql`. Kapsam Dalga 1'i
          büyütür ama `.solum-pager` ilk gerçek kullanımını ve gerçek performans kazancını
          getirir (bugün Risk ekranı 500 satır çekiyor).
- [ ] **Dalga 2 — detay/rapor ekranları.** `Dof/Detail` · `Audit/Detail` · `Audit/Reports` ·
      `Ai/Index` · `Ai/Detay` · `Ai/SkillResult` · `Ai/Ogrenme` · `Yonetim/Index`.
- [ ] **Dalga 3 — form ağırlıklı (S2+S3 ZORUNLU).** `Audit/Create` · `Audit/Edit` ·
      `Audit/Items` · `Dof/Create` · `Ayarlar/Index` · `Ai/Providers` ·
      `Account/ChangePassword`.
- [ ] **Dalga 4 — `Ref/Index` (1145 satır, 8 sekme).** Tek başına dalga: S7 (sekme) + S2 (form) +
      `csharp-conventions` 500 satır kırmızı çizgisi (TODO C1 ile birleşir) — sekme başına partial.
- [ ] **Dalga 5 — kapanış.** Tailwind CDN kaldır · `app.css` sadeleştir · yerel Tailwind build
      kararı (TODO C11) · tam regresyon smoke (26 ekran) · `phase-review-gate` zinciri.

## Reddedilen alternatifler

| Alternatif | Neden reddedildi |
|---|---|
| Hepsini tek dalgada taşı | 26 ekran tek commit = geri alınamaz; 15 dosya eşiği ve faz kapanış kapısı anlamsızlaşır |
| Tailwind'i hemen kaldır | 25 ekran ona bağlı; taşınmadan kaldırmak hepsini bozar |
| Form köprüsünü (S2) bizde yaz | 17 dosyada tekrar edecek; Solum'un `FieldRenderer`'ı zaten yarısını taşıyor — ikinci bir gerçek doğar |
| Solum kabuk parçalarını kullanmaya geç | S1 kırığı (ölü `<partial>`) düzelmeden imkânsız — ölçüldü |
| Ekran taşırken SP/şema iyileştir | Kapsam patlar; bu plan sunum katmanı, veri katmanı ayrı |

## Riskler

| Risk | Etki | Önlem |
|---|---|---|
| Melez dönem uzar (yarısı Solum, yarısı Tailwind) | Orta | Dalga sonu ölçüm: kaç ekran taşındı / kaç `rounded-xl` kaldı; sayı her dalgada raporlanır |
| Solum bağımlılıkları (S1-S3) gecikir | **Yüksek** | Dalga 1-2 onları beklemez; Dalga 3-4 bekler. Gecikirse sıra değişmez, iş durur — kısmi taşıma yapılmaz |
| Form davranışı sessizce bozulur (bağlama/doğrulama kaybı) | **Yüksek** | Her form ekranı için "kaydet → DB'de satır" smoke'u; `asp-for` kaybı derleme hatası vermez |
| Solum çalışma ağacına bağlılık (TODO C9) | Orta | Her dalga sonunda doğrulanan Solum hash'i commit gövdesine yazılır |
| Yetki kapısı olmayan ekran (bkz. `/Urun/Index`) | **Yüksek** | Dalga 1'de TODO C10 (`FallbackPolicy`) birlikte kapatılır |

## Bitiş kriteri (kanıtlanabilir)

- [ ] `grep -rc "rounded-xl\|bg-white p-" Features/` = **0** (Tailwind kart kabı kalmadı)
- [ ] `_Layout.cshtml`'de `cdn.tailwindcss.com` yok
- [ ] Hiçbir `.cshtml` 500 satırı aşmıyor (`Ref/Index` 1145 → sekme başına partial)
- [ ] 26 ekranın hepsi kimlikli smoke'ta 200 (dev oturum atlama ile ölçülebilir)
- [ ] Form ekranlarında kaydet→DB satırı kanıtı
- [ ] `dotnet test` yeşil; her dalga en az 1 davranış testi ekler
- [ ] Solum tarafına akan kanıt: `.solum-pager` ilk kullanım · `FieldRenderer` gerçek formda ·
      gruplu menü · 26 ekran ölçeğinde kabuk

## Geri alma

Şema değişikliği yok → tamamen kod. Ekran başına tek commit; bozulan ekran `git revert <hash>`
ile eski Tailwind hâline döner (kabuk ortak olduğu için kabukta değişiklik gerekmez).
