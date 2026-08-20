---
name: sql-migration-writer
description: BkmArgus için idempotent SQL migration yazar (sql/NN_<konu>.sql). Numaralı zincir disiplini, CREATE TABLE / ALTER / CREATE OR ALTER PROCEDURE pattern'leri, Türkçe SP parametresi + İngilizce kolon sözleşmesi, datetime2(0)/decimal(18,3)/SYSDATETIME tip kuralları, persisted computed kolon tuzağı, src.* dokunulmazlığı. "migration yaz", "tablo ekle", "kolon ekle", "SP yaz", "şema değişikliği" denildiğinde tetiklenir. Yedek almadan silme YASAK kuralını uygular.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
user-invocable: true
model: inherit
---

# SQL Migration Writer (BkmArgus)

## Ne zaman tetiklenir

- Yeni tablo / kolon / index / constraint
- Yeni veya değişen stored procedure / view
- Veri backfill (mevcut satırların doldurulması)
- Tablo/kolon silme veya yeniden adlandırma

## Adım 0 — ÖNCE OKU (atlanamaz)

1. **Son numarayı bul:**
   ```bash
   ls sql/[0-9]*.sql | sort -V | tail -3
   ```
   Yeni dosya = `sql/<son+1>_<kisa_konu>.sql`. Numara **atlanmaz, tekrarlanmaz**.

2. **Mevcut tanımı oku.** Değiştireceğin tablo/SP hangi dosyada tanımlı? `grep -rn "CREATE TABLE rpt.DailyProductRisk\|sp_Insight_List" sql/`

3. **Var olan migration dosyasını DEĞİŞTİRME.** Uygulanmış olabilir → dev ile prod ayrışır. Düzeltme daima yeni numaralı dosyada.

4. **Canlı şema ile karşılaştır** (erişim varsa): kolon gerçekten yok mu, tip ne? `sqlcli` ile doğrula. Yoksa "canlı doğrulama yapılmadı" diye belirt.

## Dosya İskeleti

```sql
/* =====================================================================
   51_<konu>.sql — <bir cumlelik amac>
   Tarih   : YYYY-MM-DD
   Bagimli : 49_insight_detail_enrichment.sql (varsa)
   Geri al : <rollback notu veya "geri alinamaz — yedek alindi">
   ===================================================================== */

SET NOCOUNT ON;
GO
```

## 1. Tablo Ekleme

```sql
IF OBJECT_ID('dof.Attachments', 'U') IS NULL
BEGIN
    CREATE TABLE dof.Attachments
    (
        Id                int            IDENTITY(1,1) NOT NULL,
        DofId             bigint         NOT NULL,
        FileName          nvarchar(260)  NOT NULL,
        FilePath          nvarchar(500)  NOT NULL,
        FileSize          bigint         NOT NULL,
        IsActive          bit            NOT NULL CONSTRAINT DF_Attachments_IsActive DEFAULT(1),
        -- Zorunlu audit seti (sql-conventions.md 1)
        CreatedAt         datetime2(0)   NOT NULL CONSTRAINT DF_Attachments_CreatedAt DEFAULT(SYSDATETIME()),
        UpdatedAt         datetime2(0)   NULL,
        CreatedByUserId   int            NULL,
        UpdatedByUserId   int            NULL,
        CONSTRAINT PK_Attachments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Attachments_Findings FOREIGN KEY (DofId) REFERENCES dof.Findings(Id)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Attachments_DofId' AND object_id = OBJECT_ID('dof.Attachments'))
    CREATE NONCLUSTERED INDEX IX_Attachments_DofId ON dof.Attachments(DofId) INCLUDE (FileName, FileSize);
GO
```

**Zorunlu:** `CreatedAt`, `UpdatedAt`, `CreatedByUserId`, `UpdatedByUserId` her tabloda.

## 2. Kolon Ekleme

```sql
IF COL_LENGTH('rpt.DailyProductRisk', 'PeriodCode') IS NULL
    ALTER TABLE rpt.DailyProductRisk
        ADD PeriodCode varchar(20) NOT NULL
            CONSTRAINT DF_DailyProductRisk_PeriodCode DEFAULT('Son30Gun');
GO
```

NOT NULL kolon eklerken **DEFAULT zorunlu** (mevcut satırlar için). Backfill gerekiyorsa DEFAULT + ayrı UPDATE.

## 3. Stored Procedure

```sql
CREATE OR ALTER PROCEDURE dof.sp_Attachment_Add
    @DofId        bigint,
    @DosyaAdi     nvarchar(260),
    @DosyaYolu    nvarchar(500),
    @DosyaBoyut   bigint,
    @KullaniciId  int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: kapanmis DOF'a ek eklenemez
        IF EXISTS (SELECT 1 FROM dof.Findings WHERE Id = @DofId AND Status = 'KAPANDI')
            THROW 50010, N'Kapanmis DOF kaydina ek eklenemez.', 1;

        INSERT INTO dof.Attachments (DofId, FileName, FilePath, FileSize, CreatedByUserId)
        VALUES (@DofId, @DosyaAdi, @DosyaYolu, @DosyaBoyut, @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
```

**Kurallar:**
- Parametreler **Türkçe** (`@DosyaAdi`), kolonlar **İngilizce** (`FileName`).
- C# çağrısındaki anonymous object property adı SP parametresiyle **birebir** eşleşmeli — eşleşmezse sessizce null gider.
- `SET NOCOUNT ON; SET XACT_ABORT ON;` + `TRY/CATCH` + açık transaction (yazma varsa).
- İş kuralı hatası `THROW 5xxxx, N'Türkçe mesaj', 1;` — **50000-59999** aralığı.
- `CATCH` içinde çıplak `THROW;` — mesajı ezme.

## 4. Tip Kuralları (ihlal = review'da HIGH)

| Kullanım | Tip |
|---|---|
| Tarih/zaman | `datetime2(0)` — `datetime` YASAK |
| Şimdiki zaman | `SYSDATETIME()` — `GETDATE()` YASAK |
| Miktar/stok | `decimal(18,3)` — `float`/`real` YASAK |
| Para | `decimal(18,4)` |
| Kod/durum | `varchar(20)` (ASCII) |
| Metin | `nvarchar(...)` |
| PK | `int IDENTITY` (veya `bigint` yüksek hacim) |

## 5. YASAKLAR

- **`src.*` view'ı değiştirme** — `ALTER/CREATE OR ALTER/DROP VIEW src.` = mimari ihlali (`architecture.md §4`).
- **`SELECT *`** — kolonları açıkça yaz.
- **Yedeksiz DROP** — aşağıya bak.
- **Var olan migration dosyasını düzenleme.**
- **Persisted computed kolonu doğrudan değiştirme** (`SnapshotDay`, `AuditResults.RiskScore/RiskLevel`) — DROP+ADD zinciri gerekir.

## 6. Silme Protokolü (yedek almadan YASAK)

```sql
-- 1) Kanit: kac satir etkileniyor
SELECT COUNT(*) AS EtkilenenSatir FROM ref.EskiTablo;

-- 2) Yedek (ayni DB, tarihli)
SELECT * INTO ref.EskiTablo_Yedek_20260820 FROM ref.EskiTablo;

-- 3) Bagimliliklari bul (FK, SP, view)
SELECT OBJECT_NAME(referencing_id) FROM sys.sql_expression_dependencies
WHERE referenced_entity_name = 'EskiTablo';

-- 4) Ancak kullanici ONAYINDAN sonra DROP
```

Silme adımı kullanıcı onayı olmadan yazılmaz. Skill silme SQL'ini **yorum satırı olarak** üretir, çalıştırılabilir hâlde bırakmaz.

## 7. Backfill

```sql
-- Toplu UPDATE'i partlara bol (log buyumesi + lock suresi)
WHILE 1 = 1
BEGIN
    UPDATE TOP (5000) rpt.DailyProductRisk
       SET PeriodCode = 'Son30Gun'
     WHERE PeriodCode IS NULL;

    IF @@ROWCOUNT = 0 BREAK;
END
GO
```

## 8. Uygulama ve Doğrulama

```bash
# Uygula (sqlcli — sqlcmd KULLANMA)
SQLCLI_CONN="$BKM_DENETIM_CONN" dotnet run --project D:/Dev/sqlcli -- script sql/51_konu.sql

# Dogrula: obje olustu mu
SQLCLI_CONN="$BKM_DENETIM_CONN" dotnet run --project D:/Dev/sqlcli -- query \
  "SELECT OBJECT_ID('dof.sp_Attachment_Add') AS SpVar, OBJECT_ID('dof.Attachments') AS TabloVar"
```

**İki kez çalıştır** — idempotency kanıtı. İkinci koşuda hata vermemeli, veri değişmemeli.

## Çıktı Kontrol Listesi

- [ ] Dosya adı `sql/NN_<konu>.sql`, numara zincirde tekil
- [ ] Başlıkta amaç + tarih + bağımlılık + geri alma notu
- [ ] Her DDL idempotent sarmalayıcıda (`IF OBJECT_ID` / `IF COL_LENGTH` / `IF NOT EXISTS`)
- [ ] SP `CREATE OR ALTER` + `XACT_ABORT` + `TRY/CATCH` + transaction
- [ ] Parametreler Türkçe, kolonlar İngilizce
- [ ] `THROW` kodu 50000-59999, mesaj Türkçe
- [ ] Tip kuralları (`datetime2(0)`, `decimal(18,3)`, `SYSDATETIME()`)
- [ ] Zorunlu audit kolonları eklendi
- [ ] Index gerekiyorsa eklendi
- [ ] `src.*`'a dokunulmadı
- [ ] Silme varsa: satır sayısı + yedek + onay
- [ ] İki kez çalıştırıldı, sonuç aynı

## İlişkili

- `.claude/rules/sql-conventions.md` — tam standart
- `.claude/rules/etl-discipline.md` — snapshot/idempotency
- `.claude/agents/sql-sp-reviewer.md` — yazdıktan sonra denetim
- `.claude/rules/phase-review-gate.md §3.5` — fresh-DB migrate testi
