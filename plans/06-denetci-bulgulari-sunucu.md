# Plan 06 — Denetçi Bulguları: Sunucu Kapıları ve Veri Doğruluğu

**Durum:** Aktif · **Tier:** 3 · **Açıldı:** 2026-08-26
**Kaynak:** Dalga 1 kapanış denetimi (`code-reviewer` · `security-reviewer` · `silent-failure-hunter`)

---

## Problem

Plan 05 Dalga 1 altı ekranı Solum ilkellerine taşıdı. Kapanış denetimi **taşımanın
ürettiği** yeni açık bulmadı; ama taşınan ekranların **dayandığı sunucu katmanında**
önceden var olan yedi eksik doğruladı. İkisi kritik:

1. **Panonun dayandığı geçiş endpoint'i kapsamsız.** `dof.sp_Finding_Transition`
   kaydın çağıran kullanıcının kapsamında olduğunu doğrulamıyor. Yeni klavye
   kısayolu bu kapıya ikinci bir tetik ekledi — açığı biz açmadık ama
   erişilebilirliğini artırdık.
2. **Ürün ekranı olmayan veriyi "yok" diye sunuyor.** `Doflar` koleksiyonu
   hiçbir yerde doldurulmuyor; ekran "bu ürün için açılmış düzeltici faaliyet
   bulunmuyor" yazıyor. Denetçi mükerrer DÖF açar. `evidence-discipline.md`
   ile doğrudan çelişiyor.

Kalan beşi: CSRF savunmasının yalnız `SameSite=Lax`'e dayanması, denetim
silmede kapsam+iz+hata köprüsü eksikliği, `audit.AuditLog`'a **hiç** satır
yazılmaması (TODO A1 ile aynı kök), Risk listesinde gerçek toplamın hiç
bilinmemesi, denetim listesinin bitiş tarihinde aynı günü düşürmesi.

**Neden ayrı plan:** Hepsi SP/şema değişikliği veya yetki yüzeyi. Dalga 1'in
sunum commit'lerine karıştırılırsa geri alınamaz hale gelir ve
`sql-sp-reviewer` kapısı sunum diff'i içinde boğulur.

---

## Kapsam

### İÇİNDE

| # | Bulgu | Kaynak | Katman |
|---|---|---|---|
| S1 | `audit.AuditLog` yazan tek yol yok (A1) | önceden açık | Yeni SP + servis |
| S2 | Denetim silme: kapsam + `try/catch` + iz + cascade uyarısı | IMP-3 / 5.x | SP + PageModel + UI |
| S3 | DÖF geçişinde kullanıcı-kapsam kapısı | IMP-1 **YÜKSEK** | SP (domain kararı) |
| S4 | `sp_Finding_List` kapsamsız — pano herkese her DÖF'ü gösteriyor | IMP-1 | SP |
| S5 | 3 `/api/*` endpoint'inde antiforgery yok, parametre sorgu dizesinde | IMP-2 | Program.cs + JS |
| S6 | Risk listesinde `TotalCount` yok → boş sayfa "kayıt yok" diyor | 3.4 | SP + PageModel |
| S7 | Denetim `EndDate` gün sonu değil gece yarısı | 6.3 | SP |
| S8 | Ürün DÖF geçmişi veri yolu yok | 5.1 **CRITICAL** | Yeni SP + PageModel |
| S9 | Kesim "başlangıç/bitiş" bir aralık değil, aralığın son günü | 1.2 | Semantik karar + SP/UI |
| S10 | Excel dışa aktarım izsiz | bilgi | S1'e bağlı |

### DIŞINDA

- Dalga 1'in sunum/sessiz-hata bulguları → aynı gün, plan 05 kapanış commit'i (Tier 2).
- CSP başlıkları (TODO C11) — kapsam dışı 8 ekranda satır içi işleyici sürdüğü için hâlâ yazılamaz.
- Risk eşiklerinin `ref.RiskParameters`'a taşınması (TODO B11) — ayrı iş.
- Skor hesabı, ağırlık, ETL. **Hiçbir risk formülüne dokunulmaz.**

---

## Fazlar

### Faz 1 — Denetim izi (S1, S2 kısmen, S10)
`audit.sp_AuditLog_Write` (@KullaniciId, @Eylem, @Varlik, @VarlikId, @Detay) +
`Services/AuditTrail.cs`. Bağlanacak ilk noktalar: denetim silme, denetim
finalize, DÖF geçişi, Excel dışa aktarım, AI skill çalıştırma.
`security-principles.md §Audit Log Kapsamı` listesi ölçüt.

### Faz 2 — Denetim silme sertleştirme (S2)
Kapsam kontrolü SP'de · `THROW 5xxxx` Türkçe mesaj · PageModel'de
`catch (SqlException) when (Number 50000..59999)` köprüsü · onay metnine
cascade sayıları ("45 madde ve 30 fotoğraf da silinecek").

### Faz 3 — DÖF kapsam kapısı (S3, S4) ⚠ domain kararı gerekiyor
**Karar gerektiren:** DÖF'ü kim taşıyabilir?
- (a) Atanan + oluşturan + YONETICI/ADMIN
- (b) Mekan kapsamı (kullanıcı ↔ mekan eşlemesi üzerinden)
- (c) İkisi birlikte

`denetim-surec-danismani` ajanına danışılacak, sonra `ref.UserPersonnelMap` /
`ref.LocationSettings` üzerinden kapsam çözümü. Okuma tarafı (`sp_Finding_List`)
aynı kapsamla filtrelenecek — yoksa kullanıcı taşıyamadığı kartı görmeye devam eder.

### Faz 4 — CSRF (S5)
`/api/dof/transition`, `/api/notifications/mark-read`, `/api/notifications/mark-all-read`:
parametreler JSON gövdeye, `IAntiforgery` doğrulaması, JS tarafında token başlığı.
Tek bir yardımcıya bağlanacak — üç endpoint'te üç ayrı desen yasak.

### Faz 5 — Veri doğruluğu (S6, S7, S8, S9)
- S6: `COUNT(*) OVER()` ile gerçek toplam; `PagedResult` doğru beslenir; boş sayfa "kayıt yok" demez.
- S7: `a.AuditDate < DATEADD(day, 1, CONVERT(date, @Bitis))`.
- S8: ürün bazlı DÖF listesi SP'si; gelene kadar ekranda "yok" DEMEYEN metin (Tier 2 tarafında bugün yapılıyor).
- S9: kesim alanı tek "kesim günü"ne mi inecek yoksa gerçek aralık mı olacak — `bkmargus-etl` danışmanına sorulacak, snapshot semantiği etkiliyor.

---

## Alternatifler (reddedilen)

**A. Dalga 1 kapanışına katmak.** Reddedildi: sunum taşıması geri alınabilir,
şema/yetki değişikliği değil. Aynı commit'te olursa panoyu geri almak için
güvenlik düzeltmesini de geri almak gerekir.

**B. Kapsam kontrolünü yalnız C#'ta yapmak.** Reddedildi: SP'ler AiWorker ve
CLI'dan da çağrılıyor; kapı tek boğazda olmalı (`architecture.md §2`). C#
kontrolü ikinci savunma hattı olarak kalabilir, birincisi değil.

**C. Hepsini tek büyük migration.** Reddedildi: S3 domain kararı bekliyor,
diğerleri beklemesin.

---

## Riskler

| Risk | Azaltma |
|---|---|
| Kapsam kapısı meşru kullanıcıyı kilitler | Önce ölç: kaç DÖF kaç kullanıcı için erişilemez olur (SELECT ile kuru koşum), sonra uygula |
| `sp_Finding_List` filtresi panoyu boşaltır | ADMIN/YONETICI kapsamı geniş kalır; DENETCI için önce sayım |
| Antiforgery JS'i kırar | Üç endpoint tek yardımcıya bağlı, smoke ile her biri tıklanır |
| `TotalCount` sorguyu yavaşlatır | `COUNT(*) OVER()` aynı taramada; öncesi/sonrası süre ölçülür |

---

## Done criteria

- [ ] `audit.AuditLog` en az 5 eylem tipinde satır üretiyor (SELECT ile kanıt)
- [ ] Silme: yetkisiz kullanıcı `THROW` mesajı alıyor, hata sayfası GÖRMÜYOR
- [ ] DÖF geçişi: kapsam dışı `dofId` ile deneme reddediliyor (iki rolle kanıt)
- [ ] Pano yalnız kapsamdaki DÖF'leri gösteriyor
- [ ] Üç `/api/*` token'sız POST'u reddediyor, tarayıcıdan çalışıyor
- [ ] Risk listesi gerçek toplamı gösteriyor; boş sayfa "kayıt yok" demiyor
- [ ] Bugün kaydedilmiş denetim, bitiş=bugün süzgecinde GÖRÜNÜYOR
- [ ] Ürün DÖF sekmesi gerçek veri gösteriyor ya da hiç iddia etmiyor
- [ ] `sql-sp-reviewer` + `security-reviewer` yeşil

## Rollback

Her faz kendi migration numarasında (`sql/5N_*.sql`), her biri idempotent.
Kapsam kapısı geri alınacaksa: SP'yi önceki tanıma `CREATE OR ALTER` ile döndür
(veri kaybı yok, yalnız kontrol kalkar). Faz 4 geri alınacaksa JS + endpoint
birlikte döner — yarısı yasak.

---

## 5 Lens

- 🔴 **Contrarian:** Kapsam kapısını yanlış modelleyip denetçileri kendi işlerinden kilitlemek, açığı bırakmaktan daha pahalıya gelebilir. Bu yüzden Faz 3 domain danışmanı olmadan başlamıyor ve önce kuru koşumla ölçülüyor.
- 🔵 **First Principles:** Gerçek soru "CSRF token'ı nereye koyalım" değil; **"bu kullanıcı bu kaydı görebilir mi"** sorusunun sistemde tek bir cevap yeri olmaması. S3/S4/S2/S8 aynı boşluğun dört yüzü.
- 🟢 **Expansionist:** `audit.AuditLog` yazan tek yol kurulunca A1 kapanır, AI maliyet izi ve Excel izi de aynı yola bağlanır — üç TODO bir altyapıyla düşer.
- ⚪ **Outsider:** Denetim yazılımının kendi eylemlerini loglamaması ve "DÖF yok" diye yanlış bilgi vermesi, yabancı bir denetçinin ilk sayfada bulacağı iki şey.
- 🟡 **Executor:** Pazartesi sabahı: `audit.sp_AuditLog_Write` + `AuditTrail` servisi + silme akışına bağla. Yarım gün, domain kararı beklemiyor.

---

## Faz 1 KAPANDI — 2026-08-26 (ölçümlerle)

`sql/78_audit_trail.sql` uygulandı (iki kez → idempotent, `tamam:5 uyarı:0 hata:0`).
`audit.sp_AuditLog_Write` + `audit.sp_AuditLog_List` canlıda, `CreatedAt`
varsayılanı `GETDATE()` → `SYSDATETIME()` oldu ve kısıt adlandırıldı
(`DF_AuditLog_CreatedAt`). `Services/AuditTrail.cs` beş noktaya bağlandı:
denetim silme · denetim kesinleştirme · DÖF geçişi · Excel dışa aktarım ·
AI skill çalıştırma. Eylem kodları `Domain/AuditAction.cs`.

**Kanıt:** Excel dışa aktarım tetiklendi → `audit.AuditLog` Id 4 yazıldı:
`DISA_AKTARIM · rpt.DailyProductRisk · UserId 1 · "Excel · 0 satir ·
kirpildi=False · suzgec: ... skor=95..—"`. Tablo 3 satırdan 4'e çıktı.

Düzeltme: TODO'da `audit.AuditLog` "boş" yazıyordu — **yanlıştı**. 3 satır
vardı ve hepsi `OGRENME_CEVAP` (2026-08-21, `sql/74`/`sql/76` içindeki satır
içi INSERT'lerden). Web katmanında yazan yer yoktu, tablo boş değildi.

---

## Faz 1 ölçümü sırasında ÇIKAN İKİ YENİ BULGU

### S11 — ADMIN durum makinesini TAMAMEN atlıyor (canlı SP'de ölçüldü)

`dof.sp_Finding_Transition` canlı tanımı:

```sql
-- ADMIN bypasses all rules
IF @UserRole <> 'ADMIN'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dof.StatusRules WHERE ...) ...
END
```

**Ölçüm:** ADMIN oturumuyla `POST /api/dof/transition?dofId=92&newStatus=CLOSED`
→ `{"success":true}`. DÖF 92 **DRAFT'tan doğrudan CLOSED'a** geçti. Oysa
`dof.StatusRules`'da yedi kural var ve `DRAFT → CLOSED` **YOK**:

| From | To | RequiredRole |
|---|---|---|
| `*` | DRAFT | ADMIN |
| DRAFT | OPEN | DENETCI |
| OPEN | IN_PROGRESS | NULL |
| IN_PROGRESS | PENDING_VALIDATION | NULL |
| PENDING_VALIDATION | CLOSED | YONETICI |
| PENDING_VALIDATION | REJECTED | YONETICI |
| REJECTED | IN_PROGRESS | NULL |

Yani onay zinciri (IN_PROGRESS → PENDING_VALIDATION → YONETICI onayı) ADMIN
için hiç yok; tek istekle kapatılabiliyor ve `StatusHistory` bunu meşru bir
geçiş gibi kaydediyor. **Bu bir karar sorusu, kod hatası değil:** ADMIN'in
süreci atlaması istenen davranış mı? İç denetimde "onaylayan ≠ yapan"
ilkesiyle çelişiyor. `denetim-surec-danismani` ile Faz 3'te birlikte
karara bağlanacak — kapsam kapısıyla aynı dokunuş.

**Not:** bu ölçüm dev DB'de DÖF 92'yi CLOSED, 93'ü OPEN yaptı. Geri
alınmadı — elle UPDATE `StatusHistory`'ye YANLIŞ bir geçmiş yazardı; kayıt
gerçekten olan şeyi gösteriyor.

### S12 — `sql/38` ile canlı SP AYRIŞMIŞ (dev-DB drift)

| | Mesaj |
|---|---|
| `sql/38_dof_state_machine.sql:328,345` | `Finding is already in status %s` · `Invalid transition: ...` (İngilizce) |
| Canlı `dof.sp_Finding_Transition` | `Zaten bu durumda: %s` · `Gecersiz gecis: X -> Y (rol: Z)` (Türkçe) |

Canlı sürümde ayrıca `SET XACT_ABORT ON` yok ve `RAISERROR` sonrası ölü
`RETURN` satırları var.

Bunu **ölçüm yakaladı, dosya okumak yakalamadı**: mesaj eşlemesini önce
denetçinin bildirdiği İngilizce kalıplara yazdım, canlıda hiç tutmadı ve
gerçek sebep jeneriğe düşüyordu. Ölçüm olmasaydı "düzelttim" diyecektim.
Şimdi iki dil de tanınıyor, tanınmayan mesaj ham hâliyle geçiyor (kendi
SP'mizin iş kuralı metni, 50000-59999 sözleşmesi gereği gösterilebilir).

`phase-review-gate §3.5` fresh-DB kapısı tam bu ayrışma için var ve bu
plandaki her SQL fazında koşturulacak.

### S13 — Marka ezmesi erişilebilirliği düşürüyordu (KAPANDI)

`argus-theme.css` `--solum-bad`'i `#E30613`, `--solum-good`'u `#10B981`
yapıyordu. Yumuşak zemin üzerinde ölçülen kontrast: **3,97** ve **2,15** —
ikincisi büyük metin eşiğini (3,0) bile geçmiyordu. Solum'un erişilebilir
varsayılanları aynı bağlamda 6,20 / 6,46. Ezme kaldırıldı; marka kırmızısı
`--solum-accent` olarak kaldı (üzerinde beyaz metin). Ölçüm sonrası altı
sınıfın hepsi AA: 4,53 – 16,70.

---

## Faz 4 KAPANDI — 2026-08-26 (CSRF)

`Security/ApiGuard.cs` — tek kapı: token doğrulama + JSON gövde okuma.
`AddAntiforgery(o => o.HeaderName = "RequestVerificationToken")`. Dört uç nokta
bağlandı: `dof/transition` · `notifications/mark-read` · `mark-all-read` ·
**`ai/skill/execute`** (denetim raporunda üçlüye dahil değildi ama aynı sınıfta —
LLM maliyeti üretiyor, CSRF ile tetiklenmesi para harcatır).

Parametreler sorgu dizesinden **gövdeye** taşındı (`NotifIdRequest`,
`DofTransitionRequest`): sorgu dizesi tarayıcı geçmişine, erişim loguna ve
`Referer` başlığına yazılıyor.

İstemci tarafı tek yol: `window.ArgusApi.post(url, gövde)` (`argus-shell.js`).
Token **üretilmiyor**, `_Layout`'taki `@Html.AntiForgeryToken()` alanından
**okunuyor**. Pano da bu yoldan geçiyor; `argus-board.js` içindeki elle
sorgu-dizesi kurulumu silindi.

### Ölçüm — iki yön de kanıtlandı

| Test | Sonuç |
|---|---|
| Token**suz** POST, eski usul sorgu dizesi | **403** + "Oturum doğrulaması başarısız…" |
| Tokensuz POST, JSON gövde | **403** |
| `notifications/mark-all-read` tokensuz | **403** |
| `ai/skill/execute` tokensuz | **403** |
| **Geçerli token** ile POST | 403 **DEĞİL** → iş mantığına ulaştı (400, DB erişilemediği için jenerik hata) |

Yani kapı hem reddediyor hem meşru isteği geçiriyor. Reddetme **DB'ye
dokunmadan** oluyor.

**DOĞRULANMADI:** tarayıcıdan uçtan uca pano sürükleme (token okuma + başarılı
geçiş) ölçülemedi — `192.168.40.201` erişilemiyor (ping %100 kayıp, 1433 kapalı),
her sayfa 500 veriyor. Token'ı `/Account/Login` sayfasından aldım (o sayfa DB'siz
render oluyor). DB dönünce tarayıcı smoke'u koşulacak.

### Faz 2 BLOKLANDI

Denetim silme sertleştirmesi canlı şema ölçümü, migration uygulaması ve smoke
gerektiriyor; DB erişilemediği için başlanmadı. `sql/38` ile canlı SP'nin
ayrıştığı ölçüldüğü için (S12) **şemayı dosyadan varsaymak yasak** —
`before-major-change.md §5`.
