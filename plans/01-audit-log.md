# 01 — Denetim İzi (audit.AuditLog)

**Tier:** 3 · **Durum:** taslak — onay bekliyor
**Tarih:** 2026-08-20 · **TODO:** A1

## Problem

`security-principles.md` denetim izini zorunlu kılıyor. Gerçekte:

| Bulgu | Kanıt |
|---|---|
| `audit.AuditLog` migration zincirinde **yok** | `grep "CREATE TABLE audit.*AuditLog" sql/` → 0 sonuç |
| Hiçbir koddan referans **yok** | `grep -ril auditlog sql/ src/` → yalnız Serilog DLL'i (isim benzerliği) |
| Canlı DB'de tablo **var**, 0 satır | Bir önceki oturumun DB sayımı |
| `audit.Users` de CREATE edilmiyor | `sql/35_migration_auth.sql:24-60` yalnız `ALTER TABLE ... ADD` |

İki ayrı sorun çıktı:

**(a) Hayalet tablo.** `audit.AuditLog` canlı DB'de elle oluşturulmuş, kaynak kontrolünde yok, kimse yazmıyor. CLAUDE.md 10 tablo iddia ediyor, `sql/` 6 tane oluşturuyor.

**(b) Migration zinciri kırık — bloklayıcı.** `sql/35_migration_auth.sql` var olmayan `audit.Users`'a `ALTER TABLE` atıyor. **Temiz kurulumda patlar.** Dev DB'de çalışıyor olması, elle uygulanmış olmasından. `phase-review-gate.md §3.5` tam bu senaryoyu tarif ediyor.

(b) çözülmeden (a) doğrulanamaz — fresh-DB testi zaten 35'te duruyor.

## Kapsam

**Dahil:**
- `audit.Users` + `audit.CorrectiveActions` + `audit.AiAnalyses` için eksik `CREATE TABLE` (idempotent, mevcut DB'yi bozmadan)
- `audit.AuditLog` şema tanımı + `audit.sp_AuditLog_Write` + `audit.sp_AuditLog_List`
- Mevcut iş SP'lerine izin yazımı (denetim finalize, DÖF geçiş, ref değişikliği)
- Web tarafı HTTP-bağlamlı olaylar (login, export, AI skill tetikleme)
- `Policies.AdminOnly` altında görüntüleme ekranı
- Fresh-DB migrate testi (zincirin uçtan uca çalıştığı kanıtı)

**Hariç:**
- G1 (AI çağrı izi alanları — `ai.SkillExecutions`). Aynı tema, farklı tablo, ayrı plan (`02`). Tek migration'a sıkıştırmak review'ı zorlaştırır.
- Log saklama/arşivleme politikası (hacim sorun olunca)
- `log.LoginHistory`'yi değiştirme — dokunulmuyor

## Reddedilen alternatifler

| Alternatif | Neden reddedildi |
|---|---|
| **Her şeyi `log.LoginHistory`'ye yaz** | Auth'a özel şema (`IsSuccess`, `FailureReason`). Genel iş aksiyonu bu şekle sığmaz; zorlarsak kolonların yarısı boş kalır |
| **`audit.AuditLog`'u iptal et, Serilog dosyasına yaz** | Dosya log'u sorgulanamaz, ekranda gösterilemez, silinebilir. Denetim izi **kayıt**tır, log değil |
| **SQL Server Temporal Tables / CDC** | Otomatik ve cazip ama *kim* ve *neden* bilgisini taşımaz — sadece *ne değişti*. Denetim izinin asıl değeri aktör ve niyet. Ayrıca her tabloya uygulanınca hacim patlar |
| **Yalnız C#'tan yaz (tek yerden, basit)** | Rollback olursa iz kalır, olay olmamıştır → **yalan iz**. Bu, izin olmamasından kötü |
| **Yalnız SP'den yaz** | SQL, HTTP bağlamını (IP, user-agent, oturum) göremez. Login/export gibi olaylar dışarıda kalır |

## Tasarım

### Dört soruya karar

**(1) Tek tablo mu, `log.LoginHistory` ayrı mı?**
İkisi de kalır, rolleri ayrılır:
- `log.LoginHistory` → auth adli inceleme detayı (deneme deneme, IP, başarısızlık sebebi). Yüksek hacim, dokunulmuyor.
- `audit.AuditLog` → **tek denetim izi**. Login/logout için de özet satır yazar (`LOGIN_SUCCESS`, `LOGIN_FAIL`, `LOGOUT`) ve `RelatedTable='log.LoginHistory'` ile detaya işaret eder.

Gerekçe: denetçi tek tabloya bakabilmeli. Kullanıcı sayımız onlarca — hacim endişesi teorik.

**(2) SP'den mi, C#'tan mı?**
**Yazma daima `audit.sp_AuditLog_Write` üzerinden; çağıran değişir.**

| Olay tipi | Çağıran | Neden |
|---|---|---|
| Veri değişikliği (finalize, DÖF geçiş, ref update) | **İş SP'sinin içinden**, aynı transaction | Rollback olursa iz de geri alınır. Unutulamaz |
| HTTP bağlamı gerektiren (login, export, AI tetikleme) | **C#**, işlemden sonra | SQL IP/user-agent göremez |

Tek SP, tek şekil, iki çağrı noktası.

**(3) Hangi aksiyonlar** (`security-principles.md` listesi):
`LOGIN_SUCCESS` · `LOGIN_FAIL` · `LOGOUT` · `PASSWORD_CHANGE` · `ACCOUNT_LOCK` · `USER_CREATE/UPDATE/DELETE` · `ROLE_CHANGE` · `AUDIT_FINALIZE` · `DOF_TRANSITION` · `DOF_CLOSE` · `REF_CHANGE` · `ETL_MANUAL_RUN` · `AI_SKILL_EXECUTE` · `AI_INSIGHT_APPROVE/REJECT` · `EXPORT`

Sabitler `BkmArgus.Web.Domain.AuditAction` sınıfında — çıplak string yasak (`architecture.md §9`).

**(4) Eski/yeni değer:**
`OldValues` / `NewValues` `nvarchar(max)`, JSON, **yalnız değişen alanlar**. Tam satır yazmak hem şişirir hem gereksiz PII taşır. UPDATE dışı aksiyonlarda NULL.

### Şema

```sql
-- Idempotent: canli DB'de tablo elle olusturulmus olabilir, sekli bilinmiyor.
-- Once CREATE (yoksa), sonra eksik kolonlari tek tek ekle.
IF OBJECT_ID('audit.AuditLog', 'U') IS NULL
CREATE TABLE audit.AuditLog (
    Id              bigint IDENTITY(1,1) CONSTRAINT PK_AuditLog PRIMARY KEY,
    ActionCode      varchar(30)    NOT NULL,   -- AuditAction sabitleri
    EntityType      varchar(30)    NULL,       -- DENETIM, DOF, KULLANICI, REF, ETL, AI
    EntityId        int            NULL,
    UserId          int            NULL,       -- NULL = sistem/job
    UserName        nvarchar(100)  NULL,       -- kullanici silinse de iz kalsin (denormalize, bilincli)
    Description     nvarchar(500)  NULL,       -- Turkce ozet
    OldValues       nvarchar(max)  NULL,       -- JSON, yalniz degisen alanlar
    NewValues       nvarchar(max)  NULL,
    IpAddress       varchar(45)    NULL,       -- IPv6 icin 45
    UserAgent       nvarchar(300)  NULL,
    RelatedTable    varchar(100)   NULL,       -- detay tablosuna isaret (or. log.LoginHistory)
    RelatedId       bigint         NULL,
    IsSuccess       bit            NOT NULL CONSTRAINT DF_AuditLog_IsSuccess DEFAULT(1),
    CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_AuditLog_CreatedAt DEFAULT(SYSDATETIME())
);
```

`UserName` denormalize — kullanıcı silinirse iz anlamsızlaşmasın. FK yok, bilinçli: denetim izi kaynak kaydın silinmesinden **etkilenmemeli**.

Index: `IX_AuditLog_CreatedAt (CreatedAt DESC)`, `IX_AuditLog_Entity (EntityType, EntityId)`, `IX_AuditLog_User (UserId, CreatedAt DESC)`.

### Dosyalar

| Dosya | İş |
|---|---|
| `sql/56_audit_schema_repair.sql` | **YENİ** — `audit.Users`, `CorrectiveActions`, `AiAnalyses` eksik CREATE'leri (zincir tamiri) |
| `sql/57_audit_log.sql` | **YENİ** — `audit.AuditLog` + index + `sp_AuditLog_Write` + `sp_AuditLog_List` |
| `sql/21_sps_audit.sql` | `sp_Audit_Finalize` içine iz yazımı |
| `sql/38_dof_state_machine.sql` | `sp_Finding_Transition` içine iz yazımı |
| `sql/08_sps_ref.sql` | Ref upsert SP'lerine iz yazımı |
| `src/BkmArgus.Web/Domain/AuditAction.cs` | **YENİ** — sabitler |
| `src/BkmArgus.Web/Services/AuditLogService.cs` | **YENİ** — HTTP bağlamını toplayıp SP'yi çağırır |
| `Services/AuthService.cs` | Login/logout/şifre değişimi izi |
| `Features/Ai/*`, `Program.cs` (`/api/ai/skill/execute`) | AI tetikleme izi |
| `Services/ExcelExportService.cs` çağrı yerleri | Export izi |
| `Features/Yonetim/AuditLog.cshtml(.cs)` | **YENİ** — görüntüleme, `Policies.AdminOnly` |

### Kısıt kontrolü

- [x] SP-first — yazma `sp_AuditLog_Write` üzerinden, Web'de inline SQL yok
- [x] Türkçe SP parametresi ↔ İngilizce kolon (`@AksiyonKodu`, `@VarlikTipi`, `@KullaniciId` …)
- [x] `src.*` dokunulmuyor
- [x] `rpt.*` snapshot etkilenmiyor
- [x] Yeni sayfa `[Authorize(Policy = Policies.AdminOnly)]`
- [x] AI yok — halüsinasyon kapısı ilgisiz
- [x] `datetime2(0)` + `SYSDATETIME()`

## 5 lens

- 🔴 **Contrarian:** İz yazımı iş SP'sinin transaction'ına girerse, iz yazımındaki bir hata **asıl işlemi geri alır**. Denetim finalize, log yüzünden başarısız olmamalı. → İz yazımı `TRY/CATCH` ile sarılıp yutulmalı mı? Hayır — yutmak sessiz başarısızlık olur. Çözüm: `sp_AuditLog_Write` o kadar basit olmalı ki (tek INSERT, FK yok, constraint yok) patlaması pratikte imkânsız olsun. Bu yüzden FK yok.
- 🔵 **First Principles:** Asıl soru "log tutalım mı" değil, **"altı ay sonra 'bu DÖF'ü kim kapattı ve neden' sorusuna cevap verebiliyor muyuz"**. Şema bu soruya göre test edilmeli.
- 🟢 **Expansionist:** Bu iz, G4'ün (alarm yorgunluğu / eşik öğrenmesi) eğitim verisidir. `AI_INSIGHT_APPROVE/REJECT` kayıtları etiket üretir. Şimdi doğru tasarlamak sonra veri madenciliği kazandırır.
- ⚪ **Outsider:** "10 tablo var" diyen bir doküman ile 6 tablo oluşturan bir migration zinciri arasındaki farkı kimse fark etmemiş. Asıl sorun tek tablo değil, **kaynak kontrolü ile canlı DB'nin ayrışmış olması.**
- 🟡 **Executor:** Pazartesi ilk adım — `sql/56` ile zinciri tamir et, fresh-DB testi koş. Yeşil olmadan 57'ye geçme.

## Riskler

| Risk | Etki | Önlem |
|---|---|---|
| Canlı `audit.AuditLog` farklı şekilde | Migration patlar | CREATE + kolon-kolon `IF COL_LENGTH IS NULL ALTER ADD`. **Uygulamadan önce canlı şekli sorgula** |
| `sql/56` canlı `audit.Users`'ı bozar | Veri kaybı | Yalnız `IF OBJECT_ID IS NULL CREATE`. Var olana dokunmaz |
| İz yazımı asıl işlemi geri alır | İşlevsellik kaybı | FK/constraint yok, tek INSERT |
| Hacim büyümesi | Performans | `CreatedAt DESC` index; saklama politikası kapsam dışı, hacim ölçülünce ele alınır |
| `OldValues`/`NewValues` PII taşır | KVKK | Yalnız değişen alan; şifre hash'i **asla** |

## Adımlar

- [ ] **Faz 0** — Canlı `audit.AuditLog` + `audit.Users` şeklini sorgula *(bloklu: sqlcli erişimi gerekli)*
- [ ] **Faz 1** — `sql/56_audit_schema_repair.sql` → fresh-DB migrate testi yeşil
- [ ] **Faz 2** — `sql/57_audit_log.sql` (tablo + 2 SP) → `sql-sp-reviewer`
- [ ] **Faz 3** — İş SP'lerine iz yazımı (finalize, DÖF geçiş, ref)
- [ ] **Faz 4** — C# tarafı: `AuditAction`, `AuditLogService`, çağrı noktaları → `code-reviewer` + `security-reviewer`
- [ ] **Faz 5** — Görüntüleme ekranı
- [ ] **Faz 6** — Smoke: her aksiyon tipi için bir satır üret, çıktıyla göster

Her faz sonunda `phase-review-gate.md` zinciri.

## Bitiş kriteri

- [ ] Fresh DB'de `sql/00 → 57` **0 fail** ile uygulanıyor
- [ ] 15 aksiyon kodunun her biri için `audit.AuditLog`'da en az 1 gerçek satır (SQL çıktısıyla kanıtlanmış)
- [ ] Başarısız login denemesi hem `log.LoginHistory`'ye hem `audit.AuditLog`'a yazıyor
- [ ] DÖF geçişi rollback olursa iz satırı **oluşmuyor** (atomiklik kanıtı)
- [ ] `Yonetim/AuditLog` ekranı DENETCI rolüne 403 veriyor
- [ ] "Bu DÖF'ü kim, ne zaman, hangi statüden hangisine geçirdi" sorusu tek sorguyla cevaplanıyor

## Geri alma

`sql/57` yalnız ekleme yapar (yeni tablo + yeni SP) — geri alma: `DROP TABLE audit.AuditLog`, `DROP PROCEDURE audit.sp_AuditLog_*`.
İş SP'lerindeki iz yazımı `CREATE OR ALTER` ile eklendiğinden, önceki sürüm `git checkout` + yeniden uygulama ile döner.
`sql/56` yalnız eksik tablo oluşturur; canlı DB'de zaten varlarsa hiçbir şey yapmaz — geri alma gerekmez.
