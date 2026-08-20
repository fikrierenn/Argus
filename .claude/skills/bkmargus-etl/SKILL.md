---
name: bkmargus-etl
description: BkmArgus ETL uygulama rehberi — rpt.* günlük snapshot yazımı, idempotency deseni (MERGE / DELETE+INSERT kapsam eşitliği), SnapshotDate gün-seviyesi kuralı, PeriodCode PK bütünlüğü, src.* view üzerinden ERP erişimi ve alias disiplini, ehAltDepo=0 P0 kuralı, etl.DataQualityIssues kapısı, log.*Runs kaydı. "ETL yaz", "snapshot", "gecelik iş", "risk özeti çalıştır", "stok bakiyesi", "veri aktarımı" denildiğinde ve rpt./etl./log.sp_*_Calistir zincirine dokunmadan ÖNCE danış.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
user-invocable: true
model: inherit
---

# BkmArgus ETL — Uygulama Rehberi

Kural kaynağı: `.claude/rules/etl-discipline.md`. Bu skill nasıl yazılacağını gösterir.

## Adım 0 — Kod yazmadan önce üç soru

1. **Bu veri zaten bir snapshot'ta var mı?** Varsa yeni ETL değil, mevcut SP'ye kolon ekle (footprint-ladder basamak 1).
2. **Grain ne?** Bir satır neyi temsil edecek — mekan+ürün+gün+periyot mu, mekan+gün mü? Grain netleşmeden yazma.
3. **İki kez çalışırsa ne olur?** Cevap "aynı sonuç" değilse tasarım yanlış.

## 1. Idempotency Deseni

### Tercih: MERGE

```sql
MERGE rpt.DailyProductRisk AS t
USING (
    SELECT
        CAST(SYSDATETIME() AS date) AS SnapshotDate,   -- GUN seviyesi, saat YOK
        sh.ehMekanId  AS LocationId,                    -- ERP Turkce kolonu alias'lanir
        sh.ehStokId   AS ProductId,
        @PeriyotKodu  AS PeriodCode,
        ...
    FROM   src.vw_StokHareket sh                        -- cross-DB DAIMA view uzerinden
    WHERE  sh.ehAltDepo = 0                             -- P0 kurali
      AND  sh.ehTarih >= @BaslangicTarih
    GROUP BY sh.ehMekanId, sh.ehStokId
) AS s
   ON  t.SnapshotDate = s.SnapshotDate
   AND t.LocationId   = s.LocationId
   AND t.ProductId    = s.ProductId
   AND t.PeriodCode   = s.PeriodCode      -- PK'nin TAM esi; eksik birakirsan periyotlar birbirini ezer
WHEN MATCHED THEN
    UPDATE SET t.RiskScore = s.RiskScore, t.UpdatedAt = SYSDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (...) VALUES (...);
```

### Alternatif: DELETE + INSERT — kapsam eşitliği ŞART

```sql
-- YANLIS: silme kapsami genis, yazma kapsami dar -> veri kaybi
DELETE FROM rpt.DailyProductRisk WHERE SnapshotDate = @Bugun;
INSERT INTO rpt.DailyProductRisk (...) SELECT ... WHERE PeriodCode = 'Son30Gun';
--   ^ Son90Gun satirlari silindi, geri yazilmadi

-- DOGRU: iki tarafta AYNI predikat
DELETE FROM rpt.DailyProductRisk
 WHERE SnapshotDate = @Bugun AND PeriodCode = @PeriyotKodu;
INSERT INTO rpt.DailyProductRisk (...) SELECT ... ;
```

**INSERT-only ETL yasak** — mükerrer satır üretir.

## 2. SnapshotDate Tuzağı

```sql
-- YANLIS: saat bileseni gelir, PK her calistirmada yeni satir uretir
SnapshotDate = SYSDATETIME()

-- DOGRU
SnapshotDate = CAST(SYSDATETIME() AS date)
```

`SnapshotDay` PERSISTED computed'dır — INSERT/UPDATE kolon listesine **koyma**, `SnapshotDate`'ten türer.

## 3. ERP Erişimi

```sql
-- DOGRU
FROM src.vw_StokHareket sh
SELECT sh.ehMekanId AS LocationId, sh.ehStokId AS ProductId, sh.ehMiktar AS Quantity

-- YASAK
FROM DerinSISBkm.dbo.irsHrk        -- cross-DB dogrudan tablo
ALTER VIEW src.vw_StokHareket ...  -- src.* dokunulmaz
```

Alias vermezsen C# mapping sessizce null alır — hata yok, veri yok.

## 4. Veri Kalitesi Kapısı

Kaliteyi bozan kaydı **filtreleyip atma** — raporla:

```sql
-- ehAltDepo <> 0 (P0 ihlali) sessizce atlanmaz
INSERT INTO etl.DataQualityIssues (IssueType, SourceTable, SourceKey, Detail, DetectedAt)
SELECT 'ALT_DEPO_SIFIR_DEGIL', 'src.vw_StokHareket',
       CONCAT(sh.ehMekanId, '-', sh.ehStokId),
       CONCAT(N'ehAltDepo = ', sh.ehAltDepo),
       SYSDATETIME()
FROM   src.vw_StokHareket sh
WHERE  sh.ehAltDepo <> 0
  AND  sh.ehTarih >= @BaslangicTarih;
```

Diğer kapılar: eşleşmeyen mekan/ürün (`ref` karşılığı yok), negatif stok, bilinmeyen hareket tipi (`ref.TransactionTypeMap`), tarih aralığı dışı.

Bunlar ETL'i **durdurmaz** ama görünür olur.

## 5. Çalıştırma Kaydı (sessiz ETL yasak)

```sql
DECLARE @RunId int, @Baslangic datetime2(0) = SYSDATETIME();

INSERT INTO log.RiskEtlRuns (StartedAt, Status) VALUES (@Baslangic, 'CALISIYOR');
SET @RunId = SCOPE_IDENTITY();

BEGIN TRY
    -- ... ETL govdesi ...
    DECLARE @Yazilan int = @@ROWCOUNT;

    UPDATE log.RiskEtlRuns
       SET FinishedAt = SYSDATETIME(), Status = 'BASARILI',
           RowsWritten = @Yazilan,
           DurationMs = DATEDIFF(millisecond, @Baslangic, SYSDATETIME())
     WHERE Id = @RunId;
END TRY
BEGIN CATCH
    UPDATE log.RiskEtlRuns
       SET FinishedAt = SYSDATETIME(), Status = 'HATA', ErrorMessage = ERROR_MESSAGE()
     WHERE Id = @RunId;
    THROW;
END CATCH
```

**Sıfır satır da bir sonuçtur** ve yazılır. "Hata yok demek ki çalıştı" varsayımı yanlış.

## 6. Tip Kuralları

| Kullanım | Tip |
|---|---|
| Miktar/stok | `decimal(18,3)` — `float` YASAK |
| Para | `decimal(18,4)` |
| Tarih | `datetime2(0)`, `SYSDATETIME()` |

## 7. Performans

- `rpt.DailyProductRisk` ~66k satır/gün. Filtre kolonlarında index şart.
- SARGable WHERE: `WHERE YEAR(SnapshotDate) = 2026` index'i bozar.
- Set-based yaz; cursor/satır-satır işleme kullanma.
- Backfill'i partlara böl (`UPDATE TOP (5000)` + döngü) — log büyümesi ve lock süresi.

## 8. Doğrulama (atlanamaz)

"Derlendi / 0 hata" yetmez. Sırayla:

1. Dar tarih aralığında çalıştır
2. Satır sayısını **önce/sonra** karşılaştır
3. Bir mekan+ürün için elle doğrula: kaynak hareket toplamı = snapshot değeri
4. **İki kez çalıştır → sonuç değişmemeli** (idempotency kanıtı)
5. `log.*Runs` kaydında satır sayısı ve süre görünmeli

```bash
SQLCLI_CONN="$BKM_DENETIM_CONN" dotnet run --project D:/Dev/sqlcli -- query \
  "SELECT PeriodCode, COUNT(*) Satir, MAX(SnapshotDate) SonTarih
   FROM rpt.DailyProductRisk GROUP BY PeriodCode"
```

Sonucu **çıktıyla** raporla. Doğrulanmadıysa `DOĞRULANMADI` de.

## 9. Kontrol Listesi

- [ ] Grain tanımlı ve PK ile uyumlu
- [ ] Idempotent (MERGE veya kapsamı eşit DELETE+INSERT)
- [ ] `SnapshotDate` gün seviyesinde
- [ ] `PeriodCode` predikatı silme ve yazmada aynı
- [ ] `SnapshotDay` yazılmıyor (computed)
- [ ] ERP'ye yalnız `src.*` üzerinden, alias'lı
- [ ] `ehAltDepo = 0` + ihlal `etl.DataQualityIssues`'a
- [ ] `log.*Runs` kaydı (sıfır satır dahil)
- [ ] `XACT_ABORT` + `TRY/CATCH` + transaction
- [ ] Tipler `decimal(18,3)` / `datetime2(0)` / `SYSDATETIME()`
- [ ] İki kez çalıştırıldı, sonuç aynı

Yazdıktan sonra: **`etl-validator` ajanını çağır** (`work-protocol.md` adım 3).

## İlişkili

- `.claude/rules/etl-discipline.md` — tam kural
- `.claude/rules/sql-conventions.md` — SP standardı
- `.claude/agents/etl-validator.md` — denetleyici
- `.claude/skills/sql-migration-writer/SKILL.md` — şema değişikliği
