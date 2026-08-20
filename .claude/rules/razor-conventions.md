# Razor Pages Konvansiyonları (BkmArgus)

`RootDirectory = "/Features"`, feature-folder yapısı, Tailwind. `paths:` yok.

## Sayfa Yapısı

Her `.cshtml` şu sırayla başlar:

```cshtml
@page
@model BkmArgus.Web.Features.<Modül>.IndexModel
@attribute [Authorize]                        @* veya [Authorize(Policy = Policies.AdminOnly)] *@
@{
    ViewData["Title"] = "Ekran Adi";
}
```

- `@using BkmArgus.Web.Security` gerekmez — `Features/_ViewImports.cshtml`'de tanımlı.
- Model tipi **DTO/record** olmalı; DB satır sınıfını doğrudan bind etme (mass assignment).
- `ViewData`/`ViewBag` minimum — Model property tercih.

## Yetkilendirme (ZORUNLU)

Her yeni sayfa `@attribute [Authorize]` ile başlar. Yönetimsel/maliyetli ekranda policy zorunlu:

| Ekran türü | Attribute |
|---|---|
| Genel (Dashboard, Risk, DOF, Audit) | `[Authorize]` |
| AI, Korelasyon (LLM maliyeti) | `[Authorize(Policy = Policies.YonetimVeUstu)]` |
| Ref, Yonetim, Ayarlar | `[Authorize(Policy = Policies.AdminOnly)]` |

Menüden gizlemek yetki değildir — sayfa attribute'u asıl kapıdır (`security-principles.md §4`).

## Form Kuralları

- POST handler: `OnPostAsync()` veya `OnPost<Aksiyon>Async()`, dönüş `Task<IActionResult>`
- Razor Pages `<form method="post">` için antiforgery token'ı otomatik üretir — token'ı kaldırma, `IgnoreAntiforgeryToken` kullanma
- Validasyon: `<span asp-validation-for="Field" class="text-xs text-red-600"></span>` + üstte özet
- Anahtar alanlar düzenleme modunda `readonly`
- Kaydet / Güncelle / Vazgeç butonları tüm ekranlarda **aynı** görünür ve aynı sırada

## Güvenlik

- **`@Html.Raw` YASAK** kullanıcı verisi için. JSON gömerken:
  ```cshtml
  <script type="application/json" id="chart-data">@Json.Serialize(Model.ChartData)</script>
  ```
  ve JS tarafında `JSON.parse(document.getElementById('chart-data').textContent)`.
- Kritik alanlar `[BindNever]`.
- Redirect: `LocalRedirect` kullan, ham `Redirect(returnUrl)` yazma.

## Mesaj Gösterimi

```cshtml
@if (TempData["StatusMessage"] is string msg)
{
    <div class="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-2 text-sm text-emerald-700">@msg</div>
}
@if (TempData["Error"] is string err)
{
    <div class="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">@err</div>
}
```

Anahtar adları tutarlı: başarı `StatusMessage`, hata `Error`.

## CSS / Tailwind

- BkmArgus Tailwind kullanır (`wwwroot/js/tailwind.config.js`, marka rengi `bkm-red`).
- **Tekrar eden bileşen → partial + ortak class.** Aynı 12 utility'yi üçüncü kez yazıyorsan partial'a çıkar.
- **Inline `style="..."` yasak** renk/font/border için — Tailwind class kullan. Tek seferlik grid/ölçü hesabı istisna, yorumla gerekçelendir.
- Marka rengi `bkm-red` — çıplak `#E30622` yazma.

## Icon

Inline SVG (CDN bağımlılığı yok):
```cshtml
<svg class="h-4 w-4 text-current" viewBox="0 0 24 24" fill="none" aria-hidden="true">
    <path d="..." stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
</svg>
```

## JavaScript

- **Server-rendered Razor Pages. SPA (React/Vue/Angular) yasak.**
- Etkileşim: **vanilla JS**. `data-*` attribute + `onclick="fn(this)"` + `wwwroot/js/` içinde IIFE-wrapped fonksiyon.
- jQuery genişletme yasak.
- `fetch` ile `/api/...` çağrısı: `credentials: 'same-origin'`, hata durumunda kullanıcıya Türkçe mesaj.

## Partial

- Tekrar eden UI → `Features/Shared/_AdName.cshtml`
- Kullanım: `<partial name="_SkillPanel" model="model" />`
- Mevcut ortak partial'lar: `_Layout`, `_SkillPanel`

## Türkçe UI

- Tüm kullanıcı-görünür metin Türkçe. Kod/DB İngilizce, arayüz Türkçe — karıştırma.
- Detay: `.claude/rules/turkish-ui.md`

## Dosya Boyutu

`.cshtml` **500 satırı** aşmamalı. `Ref/Index.cshtml` (1145) borç — sekme başına partial'a bölünecek.

## İlişkili

- `.claude/rules/security-principles.md` — XSS, CSRF, RBAC
- `.claude/rules/turkish-ui.md`
- `.claude/rules/csharp-conventions.md` — PageModel disiplini
