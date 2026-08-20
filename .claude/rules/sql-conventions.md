# SQL ve Veritabanı Standartları (BkmArgus)

BKMDenetim şeması, T-SQL standartları, SP kuralları ve migration disiplini. `paths:` yok.

---

## 1. İsimlendirme (KRİTİK — karma dil)

BkmArgus'ta **tablo/kolon İngilizce, SP parametresi Türkçe**. Bu bilinçli bir karardır (FAZ 1-2 migration), tutarlılık zorunludur.

| Öğe | Kural | Örnek |
|---|---|---|
| Tablo | İngilizce PascalCase | `DailyProductRisk`, `AnalysisQueue` |
| Kolon | İngilizce PascalCase | `LocationId`, `RiskScore`, `IsActive` |
| Boolean kolon | `Is` öneki | `IsActive`, `IsCritical`, `IsSystemic` |
| Tarih kolonu | `At` veya `Date` soneki | `CreatedAt`, `SnapshotDate`, `DueDate` |
| FK kolonu | `Id` soneki | `LocationId`, `CreatedByUserId` |
| SP adı | `schema.sp_Entity_Action` | `audit.sp_Audit_List`, `dof.sp_Finding_Create` |
| **SP parametresi** | **Türkçe**, `@` önekli | `@MekanId`, `@BaslangicTarih`, `@DenetimId` |
| View | `schema.vw_Name` | `rpt.vw_RiskDashboard` |
| Index | `IX_Table_Columns` | `IX_DailyProductRisk_SnapshotDate` |
| PK / FK | `PK_Table` / `FK_Child_Parent` | `PK_DailyProductRisk`, `FK_Actions_Findings` |
| `src.*` view | **YENİDEN ADLANDIRILMAZ** | ERP Türkçe kolonları, SP'de alias |

**Zorunlu audit kolonları** (her tabloda): `CreatedAt`, `UpdatedAt`, `CreatedByUserId`, `UpdatedByUserId`.

---

## 2. Tip Kuralları

*   **`datetime2(0)` zorunlu.** `datetime` **YASAK**.
*   **`SYSDATETIME()`** kullanılır — `GETDATE()` **YASAK**. (Yerel saat kararı; UTC'ye geçilirse tüm zincir birlikte değişir.)
*   **Stok/miktar: `decimal(18,3)`** — `float`/`real` **YASAK**.
*   **Para: `decimal(18,4)`** — float yasak.
*   PK: `int IDENTITY` veya doğal anahtar; GUID PK bu projede kullanılmaz.

---

## 3. T-SQL Sorgu Kuralları

1.  **Parametreli sorgu zorunlu.** SQL içinde string birleştirme (`+`, `QUOTENAME` dışı dinamik SQL) **YASAK**. Dinamik SQL kaçınılmazsa `sp_executesql` + parametre.
2.  **SARGable WHERE.** Index'i bozan fonksiyon kullanma:
    *   Yanlış: `WHERE YEAR(SnapshotDate) = 2026`
    *   Doğru: `WHERE SnapshotDate >= '20260101' AND SnapshotDate < '20270101'`
3.  **`SELECT *` yasak** — kolonları açıkça yaz.
4.  Alt sorgu yerine JOIN / CTE tercih; büyük agregasyonda `OPTION (RECOMPILE)` gerekiyorsa gerekçeyi yorumla belirt.
5.  **Cross-DB** (`DerinSISBkm`) erişimi yalnızca `src.*` view'ları üzerinden; SP içinde doğrudan `DerinSISBkm.dbo.X` yazma.

---

## 4. Stored Procedure Standartları

Her SP şu iskeleti taşır:

```sql
CREATE OR ALTER PROCEDURE audit.sp_Audit_Finalize
    @DenetimId int,
    @KullaniciId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- hata durumunda otomatik rollback

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: sadece TASLAK denetim finalize edilir
        IF NOT EXISTS (SELECT 1 FROM audit.Audits WHERE Id = @DenetimId AND Status = 'TASLAK')
            THROW 50001, N'Denetim bulunamadi veya zaten tamamlanmis.', 1;

        UPDATE audit.Audits
           SET Status = 'TAMAMLANDI', UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
         WHERE Id = @DenetimId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
```

Kurallar:
*   `SET NOCOUNT ON;` + `SET XACT_ABORT ON;` başta.
*   `BEGIN TRY / BEGIN CATCH` **zorunlu** (CLAUDE.md kuralı).
*   Yazma yapan SP'de açık `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`.
*   İş kuralı hatası: `THROW 5xxxx, N'Türkçe mesaj', 1;` — **50000-59999** aralığı (C# bunu kullanıcıya gösterilebilir sayar, bkz. `error-handling.md`).
*   Sistem hatası: `CATCH` içinde çıplak `THROW;` — mesajı ezme.
*   Parametre adları **Türkçe**; kolon adları İngilizce. Bu ikisini karıştırma.

---

## 5. Migration Disiplini

*   Konum: `sql/NN_<konu>.sql` — numara **artan ve tekil**. Son numarayı `ls sql/ | sort -n | tail -1` ile bul.
*   **Idempotent zorunlu:**
    ```sql
    IF OBJECT_ID('dof.Attachments', 'U') IS NULL
        CREATE TABLE dof.Attachments (...);

    IF COL_LENGTH('rpt.DailyProductRisk', 'PeriodCode') IS NULL
        ALTER TABLE rpt.DailyProductRisk ADD PeriodCode varchar(20) NOT NULL CONSTRAINT DF_... DEFAULT('Son30Gun');
    ```
*   SP'ler daima `CREATE OR ALTER`.
*   **Yedek almadan DROP YASAK.** Tablo/kolon silmeden önce: satır sayısı + `SELECT INTO` yedek + kullanıcı onayı.
*   Var olan migration dosyası **düzenlenmez** — uygulanmış olabilir. Düzeltme yeni numaralı dosyada.
*   Uygulama: `sqlcli` (`D:\Dev\sqlcli`) — `script` komutu. `sqlcmd` kullanma.

---

## 6. Persisted Computed Kolon Tuzağı

Şu kolonlar PERSISTED computed'dır, doğrudan rename/update edilemez:

*   `rpt.DailyProductRisk.SnapshotDay` (kaynak: `SnapshotDate`)
*   `audit.AuditResults.RiskScore`, `audit.AuditResults.RiskLevel`

Değiştirmek gerekirse: bağımlı index/constraint DROP → kolon DROP → yeni tanımla ADD → index geri. Tek migration içinde, transaction'lı.

---

## 7. Silme Davranışı

*   `audit.AuditResults` → `audit.Audits`'ten **ON DELETE CASCADE**. Denetim silmek sonuçları da siler — UI'da açık uyarı zorunlu.
*   Diğer yerlerde hard delete yerine **soft delete** (`IsActive = 0`) tercih.

---

## İlişkili

- `.claude/rules/architecture.md` — SP-first, şema sorumlulukları, `src.*` kuralı
- `.claude/rules/etl-discipline.md` — snapshot ve ETL kuralları
- `.claude/rules/error-handling.md` — SP THROW ↔ C# catch köprüsü
- `.claude/skills/sql-migration-writer/SKILL.md` — migration üretici
