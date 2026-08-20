# C# Konvansiyonları (BkmArgus)

net10.0, Razor Pages, Dapper, nullable enable. `paths:` yok.

## Dosya Boyutu Disiplini

**Kural:** Yeni yazılan/düzenlenen C# dosyası **300 satırın altında**. **500 satır kırmızı çizgi** — bir sonraki commit'te split zorunlu.

**Mevcut ihlaller (borç, dokundukça azalt):**
- `Features/Ref/Index.cshtml.cs` (1214) — 8 sekme tek PageModel'de, sekme başına servise bölünecek
- `AiWorker/AiWorkerService.cs` (936)
- `AiWorker/LlmService.cs` (1129) — provider başına partial/dosya

**Split yolu:** PageModel'de SP çağrısı çoksa `Services/<Modül>Service.cs`; DTO çoksa `Models/<Modül>Dtos.cs`; 5+ public helper varsa scope bazlı ayır.

## Razor PageModel

- **Async:** `public async Task<IActionResult> OnPostAsync(...)`
- **Authorize:** Sayfa `.cshtml` başında `@attribute [Authorize]`; yetki gerekiyorsa `@attribute [Authorize(Policy = Policies.AdminOnly)]` (bkz. `security-principles.md §RBAC`)
- **POST handler:** view'da `@Html.AntiForgeryToken()` (Razor Pages otomatik ekler, `<form method="post">` ile), handler `async Task<IActionResult>`
- **Dönüş tipi:** DTO / `record` — DB entity bind etme (mass assignment)

## Dapper (EF YOK)

Tüm erişim `SqlDb` (Web) / `Db` (AiWorker) üzerinden, **stored procedure** ile:

```csharp
var rows = await _db.QueryAsync<RiskRow>("rpt.sp_Risk_List",
    new { MekanId = mekanId, BaslangicTarih = bas, BitisTarih = bit });
```

- SP parametreleri **Türkçe** adlandırılır (DB sözleşmesi) — anonymous object property adı SP parametresiyle birebir eşleşmeli.
- Inline SQL **yasak** (`architecture.md §2`). Yeni sorgu → yeni SP.
- Sync API yok: `QueryAsync` / `QuerySingleAsync` / `ExecuteAsync`.
- Yeni connection açan yol ekleme — `SqlDb`'yi genişlet.

## Exception Handling

Spesifik önce, generic en son. **`ex.Message` kullanıcıya GÖSTERME.**

```csharp
catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
{
    // Is kurali hatasi — SP Turkce yazdi, kullaniciya gosterilebilir
    TempData["Error"] = sqlEx.Message;
    return RedirectToPage();
}
catch (SqlException sqlEx)
{
    _logger.LogError(sqlEx, "DB hatasi: {Op}", nameof(OnPostAsync));
    TempData["Error"] = "Veritabani isleminde hata olustu.";
    return RedirectToPage();
}
```

- **Sessiz `catch {}` yasak** — minimum `_logger.LogWarning`.
- Detay: `.claude/rules/error-handling.md`.

## Nullability

- `<Nullable>enable</Nullable>` aktif — **uyarı bırakma**. `CS8618`/`CS8601`/`CS8603` build'i kirletiyorsa `required` / `= string.Empty` / `?` ile çöz, pragma ile susturma.
- `string?` vs `string` tutarlı; default `string.Empty` tercih.

## Async / await

- Handler → `async Task<IActionResult>`; **`async void` yasak**.
- `CancellationToken ct = default` al ve downstream'e geçir (özellikle AiWorker job'ları — LLM çağrısı uzun sürer).
- `OperationCanceledException` → `ct.IsCancellationRequested` ise rethrow.

## DI + Primary Constructor (C# 12+)

```csharp
public sealed class DofDetailModel(SqlDb db, ILogger<DofDetailModel> log) : PageModel
{
    public async Task OnGetAsync(long id) => ...
}
```

- Property injection **yasak**.
- `new HttpClient()` **yasak** → `IHttpClientFactory` (AiWorker'da named client: `ollama` / `gemini` / `claude`).
- `DateTime.Now` yerine ne? BkmArgus **yerel saat** kullanır (DB `SYSDATETIME()`); C# tarafında da `DateTime.Now` tutarlıdır. **Karışık kullanma** — bir kayıt zinciri boyunca tek kaynak. `DateTime.UtcNow` sadece dış sistem/LLM zaman damgasında.

## Magic String Yasağı

Durum/rol/tip kodu çıplak string yazılmaz — `BkmArgus.Web.Security.Roles`, `BkmArgus.Web.Domain.DofStatus`, `RiskType`, `AiStatus` sabitleri kullanılır (`architecture.md §9`).

## Türkçe Yorum (ZORUNLU)

Tüm `.cs` / `.cshtml.cs` dosyalarında yorumlar **Türkçe**. Metot başı 1-2 satır, iş kuralı noktaları, karmaşık SP çağrıları, guard clause gerekçesi. İngilizce yorum yasak. Detay: `.claude/rules/coding-discipline.md`.

## Modern C# 13 / .NET 10

| Eski | Yeni | Ne zaman |
|---|---|---|
| ctor + `_x = x` | **Primary constructor** | Her DI'lı sınıf |
| `new List<string>{...}` | **Collection expression** `[...]` | Liste/dizi init |
| DTO için class | **`record`** | Düz veri taşıma |

- Default `sealed` ekle.
- `required` / `init` ile geçersiz durumu imkânsız kıl (AiWorker model sınıflarındaki CS8618 uyarılarının doğru çözümü budur).

## Naming

- PascalCase: class/method/property. camelCase: local/parametre. `I` öneki: interface. `Async` soneki: async metot.
- **Yanlış anlam üreten kısaltma yasak:** `SqlException` → `sqlEx` (asla `sex`). Belirsizse açık yaz.

## Ölü Kod

Deneme/debug dosyası prod binary'sine girmez. `TestDebug.cs` / `DbTest.cs` / `DebugTest.cs` / `TestEmbedding.cs` benzeri dosyalar `tests/` altına taşınır veya silinir.

## İlişkili

- `.claude/rules/coding-discipline.md` — Türkçe yorum, 80 satır, guard clause
- `.claude/rules/error-handling.md` — Result pattern + SP THROW köprüsü
- `.claude/rules/sql-conventions.md` — Türkçe SP parametresi
- `.claude/rules/architecture.md` — SP-first, Dapper
