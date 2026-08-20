# ETL ve Snapshot Disiplini (BkmArgus)

Gecelik ERP ETL'i, `rpt.*` snapshot tabloları ve `etl.*` staging kuralları. `paths:` yok.

## 1. Snapshot Kuralı (MUTLAK)

**Günde bir snapshot, mekan+ürün+periyot başına.** Yeni kayıt eskisini **değiştirir** (replace), üstüne eklemez.

- `rpt.DailyProductRisk` PK: `SnapshotDate` + `LocationId` + `ProductId` + `PeriodCode`
- `PeriodCode` PK'nın parçası — periyot ayrımı korunur (`Son30Gun`, `Son90Gun` vb. aynı gün yan yana durur)
- `SnapshotDate` **gün seviyesinde** yazılır (saat bileşeni yok). Saatli yazmak PK'yı patlatır — 2026-03 ETL bug'ının kök sebebi buydu.
- `SnapshotDay` PERSISTED computed — doğrudan yazılmaz, `SnapshotDate`'ten türer.

## 2. Idempotency

ETL aynı gün iki kez çalıştırılabilir olmalı ve sonuç **aynı** kalmalı.

- Yazma deseni: `MERGE` veya `DELETE + INSERT` tek transaction içinde
- `INSERT`-only ETL yasak — mükerrer satır üretir
- ETL öncesi kısmi silme yaparken kapsamı **tam olarak** yazılacak kapsamla eşleştir (aynı `SnapshotDate` + `PeriodCode`)

## 3. Kaynak Erişimi

- ERP verisine **yalnızca `src.*` view'ları** üzerinden erişilir (`architecture.md §4`)
- SP içinde `DerinSISBkm.dbo.X` doğrudan yazma **yasak**
- ERP Türkçe kolonları SP içinde alias'lanır: `sh.ehMekanId AS LocationId`
- `ehAltDepo = 0` filtresi **P0 kuralı**: sıfır dışı değer sessizce filtrelenmez, `etl.DataQualityIssues`'a alarm yazılır

## 4. Veri Tipleri

- Stok/miktar: `decimal(18,3)` — **float asla**
- Para: `decimal(18,4)`
- Tarih: `datetime2(0)`, `SYSDATETIME()`

## 5. Çalıştırma Kaydı (gözlemlenebilirlik)

Her ETL koşusu `log.RiskEtlRuns` / `log.StockEtlRuns` / `etl.EtlRuns` tablosuna yazar:

- Başlangıç/bitiş zamanı, süre
- Okunan satır / yazılan satır / atlanan satır sayısı
- Durum: `BASARILI` / `HATA` / `KISMI`
- Hata varsa mesaj

**Sessiz ETL yasak.** Sıfır satır yazıldıysa bu da bir sonuçtur ve loglanır — "hata yok demek ki çalıştı" varsayımı yanlıştır.

## 6. Veri Kalitesi Kapısı

`etl.DataQualityIssues` tablosuna yazılacak durumlar:

- Eşleşmeyen mekan/ürün (ref tablosunda karşılığı yok)
- Negatif stok
- `ehAltDepo <> 0`
- Beklenmedik hareket tipi (`ref.TransactionTypeMap`'te yok)
- Tarih aralığı dışı kayıt

Bu kayıtlar ETL'i **durdurmaz** ama raporlanır; Ref ekranından eşleştirme yapılabilir.

## 7. Ana Komutlar

```sql
EXEC log.sp_RiskUrunOzet_Calistir;                       -- gecelik risk ozeti
EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=120;
EXEC log.sp_AylikKapanis_Calistir;                       -- ay sonu
EXEC log.sp_SaglikKontrol_Calistir;                      -- saglik kontrolu
```

## 8. Değişiklik Sonrası Doğrulama (atlanamaz)

ETL SP'sine dokunulduysa "derlendi / 0 hata" **yetmez**:

1. Test kapsamında çalıştır (dar tarih aralığı)
2. Satır sayısını **önce/sonra** karşılaştır
3. Bir mekan/ürün için elle doğrula: kaynak hareket toplamı = snapshot değeri
4. İki kez çalıştır → sonuç değişmemeli (idempotency kanıtı)
5. `log.*Runs` kaydında satır sayısı ve süre görünmeli

Kanıtı **çıktıyla** raporla. Doğrulanmadıysa `DOĞRULANMADI` de (`todo-verification.md`).

## 9. Anti-pattern

| Anti-pattern | Doğrusu |
|---|---|
| `SnapshotDate` saatli yazma | `CAST(... AS date)` gün seviyesi |
| INSERT-only ETL | MERGE / DELETE+INSERT |
| `float` ile miktar | `decimal(18,3)` |
| `GETDATE()` | `SYSDATETIME()` |
| Cross-DB doğrudan tablo | `src.*` view |
| Sıfır satırı sessiz geçme | `log.*Runs`'a yaz + uyar |
| Kalite sorununu filtreleyip atma | `etl.DataQualityIssues`'a yaz |

## İlişkili

- `.claude/rules/sql-conventions.md` — tip ve SP standartları
- `.claude/rules/architecture.md §4, §6` — `src.*` kuralı, snapshot
- `.claude/agents/etl-validator.md` — ETL denetleyicisi
