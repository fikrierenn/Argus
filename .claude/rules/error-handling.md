# Hata Yönetimi (Result Pattern + Exception Disiplini)

## Temel Ayrım

**Beklenen sonuç (business outcome)** ≠ **gerçek exception (system failure)**.

| Durum | Tip | Mekanizma |
|---|---|---|
| "Belge bulunamadı", "yetki yok", "stok yetersiz" | Beklenen | **Result pattern** (`OpResult<T>` / null + audit) |
| DB connection loss, network timeout, JSON parse, file I/O fail | Gerçek exception | `try/catch` + log + generic kullanıcı mesajı |
| Bug / impossible state (null check fail, off-by-one) | Programming error | Fırlat, üst handler yakalasın |

**Anti-pattern:** Beklenen iş sonucu için `throw new Exception("Bulunamadı")` → exception flow control = expensive + okunabilirlik düşer.

## Result Pattern (BkmArgus)

BkmArgus'ta konum: `src/BkmArgus.Web/Models/OpResult.cs` (yazılacak — şu an PageModel'lerde inline `TempData`/`BadRequest`):

```csharp
public record OpResult<T>(bool IsSuccess, T? Value, string? Error)
{
    public static OpResult<T> Ok(T value)        => new(true, value, null);
    public static OpResult<T> Fail(string error) => new(false, default, error);
}
```

### Kullanım — service / handler

```csharp
public async Task<OpResult<int>> CreateDofAsync(DofCreateDto dto, int userId, CancellationToken ct = default)
{
    // Beklenen is sonucu -> Result, exception degil
    if (string.IsNullOrWhiteSpace(dto.Title))
        return OpResult<int>.Fail("Bulgu basligi zorunlu.");

    var row = await _db.QuerySingleAsync<NewIdRow>("dof.sp_Finding_Create", new
    {
        Baslik      = dto.Title,
        MekanId     = dto.LocationId,
        KullaniciId = userId
    });

    return row is null
        ? OpResult<int>.Fail("Bulgu olusturulamadi.")
        : OpResult<int>.Ok(row.Id);
}
```

### PageModel — Result tüketme

```csharp
public async Task<IActionResult> OnPostAsync(DofCreateDto dto, CancellationToken ct)
{
    var r = await _service.CreateDofAsync(dto, CurrentUserId, ct);
    if (!r.IsSuccess)
    {
        TempData["Error"] = r.Error;
        return Page();
    }
    TempData["Success"] = "Bulgu olusturuldu.";
    return RedirectToPage("Detail", new { id = r.Value });
}
```

## Exception Handling (gerçek arızalar)

```csharp
catch (SqlException sqlEx)
{
    _logger.LogError(sqlEx, "DB error: {Op}", "DofCreate");
    return BadRequest("Veritabanı işleminde hata oluştu.");
}
catch (OperationCanceledException) when (ct.IsCancellationRequested)
{
    throw; // propagate, clean shutdown
}
catch (Exception ex)
{
    _logger.LogError(ex, "Unexpected: {Op}", "DofCreate");
    return StatusCode(500, "Beklenmedik bir hata. Sistem yöneticisine bildirin.");
}
```

### Mutlak Kurallar

1. **Boş catch yasak.** `catch {}` veya `catch { _ = ex; }` → silent failure. Minimum `_logger.LogWarning(ex, ...)`.
2. **`ex.Message` kullanıcıya gösterme.** SqlException → connection string sızar. Generic Türkçe mesaj. Detay log'a.
3. **`Exception` yakalamadan önce spesifik.** `SqlException`, `JsonException`, `HttpRequestException` ayrı catch.
4. **`OperationCanceledException` rethrow** when `ct.IsCancellationRequested`.
5. **Async + CancellationToken.** Tüm `async Task` method'lar `CancellationToken ct = default` alır + downstream'e geçir.

## SP'lerden Gelen THROW

BkmArgus SP'leri Türkçe hata mesajı fırlatır (`THROW 5xxxx`) (`THROW 50001, N'Belge bulunamadı.', 1`). PageModel bunu yakalar ve kullanıcıya gösterir:

```csharp
try
{
    await _db.ExecuteAsync("audit.sp_Audit_Finalize", new { DenetimId = id, KullaniciId = userId });
}
catch (SqlException sqlEx) when (sqlEx.Number >= 50000 && sqlEx.Number < 60000)
{
    // İş kuralı hatası — kullanıcıya gösterilebilir (SP Türkçe yazdı)
    TempData["Error"] = sqlEx.Message;
    return RedirectToPage();
}
catch (SqlException sqlEx)
{
    // Sistem hatası — log'a, generic mesaj
    _logger.LogError(sqlEx, "Audit_Finalize SQL hatasi. DenetimId={Id}", id);
    TempData["Error"] = "Veritabanı hatası.";
    return RedirectToPage();
}
```

## Anti-pattern Listesi

| Anti-pattern | Doğrusu |
|---|---|
| `throw new Exception("Not found")` business case | `return OpResult.Fail("Bulunamadı")` |
| `catch (Exception) { return null; }` | Spesifik catch + log + result |
| `catch { /* sessiz */ }` | Minimum `_logger.LogWarning` |
| `TempData["Error"] = ex.Message` | Generic + log detayı |
| Result + Exception karışık | Tek strateji, layer tutarlı |

## İlişkili

- `.claude/rules/csharp-conventions.md` Exception Handling bölümü
- `.claude/rules/security-principles.md` `ex.Message` gizleme
- `.claude/rules/sql-conventions.md` SP THROW pattern
