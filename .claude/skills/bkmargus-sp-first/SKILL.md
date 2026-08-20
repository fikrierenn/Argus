---
name: bkmargus-sp-first
description: BkmArgus SP-first veri erişim standardı — Web/AiWorker'dan SP çağırma, Türkçe parametre ↔ İngilizce kolon sözleşmesi, SqlDb kullanımı, SP THROW ↔ C# catch köprüsü, IDOR/kapsam kontrolü, DTO record eşlemesi. "veriyi çek", "yeni sorgu", "SP çağır", "listeyi getir", "kaydet/güncelle/sil", "Dapper" gibi veri erişimi işlerinde ve yeni PageModel/Job yazarken danış. Inline SQL yazmayı engeller.
allowed-tools: Read, Grep, Glob, Edit, Write
user-invocable: true
model: inherit
---

# BkmArgus SP-First Veri Erişimi

## Temel Kural

**Web katmanında inline SQL YASAK.** Tüm veri erişimi stored procedure üzerinden. Tek istisna: `SqlDb.GetDbInfoAsync` ping sorgusu.

Yeni bir veri ihtiyacı varsa sırasıyla sor (footprint-ladder):
1. Mevcut bir SP genişletilebilir mi? (yeni opsiyonel parametre) → **tercih**
2. Mevcut SP'nin dönüş kolonu eklenebilir mi?
3. Yeni SP gerekli mi? → `sql-migration-writer` ile yaz

## 1. Okuma (liste)

```csharp
// SP parametreleri TURKCE — anonymous object property adi birebir eslesmeli
public sealed class RiskModel(SqlDb db) : PageModel
{
    public IReadOnlyList<RiskRow> Rows { get; private set; } = [];

    public async Task OnGetAsync(int? mekanId, DateTime? bas, DateTime? bit)
    {
        // Risk gezgini listesi — rpt.DailyProductRisk uzerinden
        Rows = await db.QueryAsync<RiskRow>("rpt.sp_Risk_List", new
        {
            MekanId        = mekanId,
            BaslangicTarih = bas,
            BitisTarih     = bit
        });
    }
}

// DTO record — DB satir sinifi degil
public sealed record RiskRow(int LocationId, string LocationName, int ProductId, decimal RiskScore);
```

**En sık hata:** SP parametresi `@MekanId` iken C#'ta `LocationId = ...` yazmak. Dapper eşleşmeyeni **sessizce atlar** → SP varsayılanı devreye girer → yanlış sonuç, hata yok. Yeni SP çağrısı yazdıktan sonra **daima** SP tanımındaki parametre adlarıyla karşılaştır:

```bash
grep -n "@" sql/*.sql | grep -A20 "sp_Risk_List"
```

## 2. Tekil kayıt

```csharp
var audit = await db.QuerySingleAsync<AuditRow>("audit.sp_Audit_Get", new { DenetimId = id });
if (audit is null) return NotFound();   // guard clause — erken donus
```

## 3. Yazma + hata köprüsü

```csharp
public async Task<IActionResult> OnPostFinalizeAsync(int id, CancellationToken ct)
{
    try
    {
        // Denetimi kesinlestir — is mantigi SP icinde, tek transaction
        await db.ExecuteAsync("audit.sp_Audit_Finalize", new { DenetimId = id, KullaniciId = CurrentUserId });
        TempData["StatusMessage"] = "Denetim tamamlandi.";
    }
    catch (SqlException sqlEx) when (sqlEx.Number is >= 50000 and < 60000)
    {
        // SP'nin Turkce is kurali mesaji — kullaniciya gosterilebilir
        TempData["Error"] = sqlEx.Message;
    }
    catch (SqlException sqlEx)
    {
        // Sistem hatasi — detay log'a, kullaniciya generic
        _logger.LogError(sqlEx, "Audit_Finalize hatasi. DenetimId={Id}", id);
        TempData["Error"] = "Veritabani isleminde hata olustu.";
    }

    return RedirectToPage(new { id });
}
```

**THROW aralığı sözleşmesi:** SP `50000-59999` fırlattıysa mesaj kullanıcıya gider. Bu aralık dışı = sistem hatası, gizlenir. SP yazarken bu aralığı kullanmayı unutma, yoksa iş kuralı mesajın kaybolur.

## 4. IDOR / kapsam kontrolü

URL'den gelen `id` yeterli değil — kaydın çağıran kullanıcıya **görünür** olduğu doğrulanmalı.

```csharp
// Kullanici kapsami SP'ye gecirilir; filtre SP icinde uygulanir
var dof = await db.QuerySingleAsync<DofRow>("dof.sp_Finding_Get", new
{
    DofId       = id,
    KullaniciId = CurrentUserId,
    RolKodu     = CurrentRole      // SP rol/mekan kapsamini uygular
});
if (dof is null) return NotFound();   // yetkisiz -> "yok" gibi davran (bilgi sizdirma)
```

Yetkisiz erişimde `Forbid()` yerine `NotFound()` tercih — kaydın varlığını sızdırmaz.

## 5. AiWorker tarafı

```csharp
// src/BkmArgus.AiWorker/Db.cs — ayni sozlesme
var pending = await _db.QueryAsync<QueueRow>("ai.sp_AnalysisQueue_Take", new { Adet = batchSize }, ct);
```

Job'larda `CancellationToken` **daima** geçirilir.

## 6. Performans

- `SqlDb` 500 ms üzeri SP çağrılarını `[SLOW SP]` uyarısıyla loglar. Bu uyarıyı görmezden gelme — index veya SP sorgusu problemi işaretidir.
- Sayfalama SP içinde (`OFFSET/FETCH`), C# tarafında `.Skip().Take()` **yapma** (tüm satır çekilir).
- Aynı sayfada 5+ SP çağrısı varsa `QueryMultiple` ile tek round-trip düşün veya SP'yi birleştir.

## 7. Kontrol Listesi

- [ ] Inline SQL yok, SP çağrısı var
- [ ] SP parametre adları Türkçe ve SP tanımıyla birebir eşleşiyor
- [ ] Dönüş tipi `record` DTO
- [ ] Guard clause ile erken dönüş (null → NotFound)
- [ ] `SqlException` 50000-59999 ayrımı yapılmış
- [ ] `ex.Message` kullanıcıya gitmiyor (iş kuralı mesajı hariç)
- [ ] IDOR: kullanıcı kapsamı SP'ye geçiyor
- [ ] `CancellationToken` (AiWorker / uzun işlem)
- [ ] Türkçe yorum: metot başı + iş kuralı noktaları

## İlişkili

- `.claude/rules/architecture.md §2, §3` — SP-first, Dapper
- `.claude/rules/sql-conventions.md` — SP standardı
- `.claude/rules/error-handling.md` — Result + exception ayrımı
- `.claude/skills/sql-migration-writer/SKILL.md` — yeni SP yazımı
