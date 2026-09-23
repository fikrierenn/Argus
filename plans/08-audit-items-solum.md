# 08 — `/Audit/Items` Solum'a taşıma + katalog bütünlüğü

**Tier:** 3 · **Durum:** taslak
**Tarih:** 2026-09-23 · **Sahip:** oturum

## Problem

`/Audit/Items` master denetim maddesi kataloğunu yönetiyor (87 kayıt, ölçüldü)
ve plan 05'in Dalga 1'inde **atlanmış** tek liste ekranı. Dört kusur, hepsi
ölçüldü:

| # | Kusur | Ölçüm |
|---|---|---|
| 1 | Mobilde kullanılamıyor | 375px'te yatay taşma **44px**; 3 sayısal alanın hiçbirinde `inputmode` yok; **8 alan** 44px dokunma hedefinin altında; düzen 3 kolon. Taşmanın suçlusu `xl:grid-cols-[1fr_380px]` ızgara öğesinin `min-width: auto` olması |
| 2 | Yetki kapısı yok | `Items.cshtml:3` yalnız `@attribute [Authorize]` — giriş yapmış **her** kullanıcı (DENETCI dahil) katalogu değiştirebiliyor. Ekran `ArgusMenu.cs`'de **yok** ama menüden gizlemek yetki değil (`security-principles.md §4`) |
| 3 | Sunucu doğrulaması yok | `Items.cshtml.cs` — `ItemInput`'ta **0** doğrulama niteliği, PageModel'de **0** `ModelState` kontrolü. Boş `ItemText` kaydedilebiliyor |
| 4 | 1–5 sınırı hiçbir katmanda yok | HTML'de `min/max` var; C#'ta yok; `sql/21_sps_audit.sql:376` `@Probability tinyint` (0–255). `RiskScore = Probability × Impact` ve rozet eşikleri 15/9 (5×5=25 ölçeğine göre) — `100×100` girilse madde **10000** skorla kaydolur ve her eşiği ezer |

### Danışman turu sonrası bulunan, DOĞRULANMIŞ üç kusur daha

| # | Kusur | Kanıt (kendi doğrulamam) |
|---|---|---|
| 5 | **`FindingType` sessizce kırpılıyor** | Ekran `<option value="Uygunsuzluk">` (11 karakter) gönderiyor; `sp_Item_Insert`/`_Update` parametresi `@FindingType char(1)` (`sql/21_sps_audit.sql:375`, `422`) ve tablo kolonu da `char(1)` (`sql/20_migration_audit.sql:75`). SQL Server parametre atamasında **sessizce ilk karaktere kırpar** → DB'ye `"U"` yazılır. Düzenleme ekranında hiçbir seçenek eşleşmiyor — canlı ölçüm: `eslesenVarMi: false`, `seciliDeger: ""`. Kullanıcı seçimini yapar, kaydeder, geri döndüğünde **"Seçiniz" görür** |
| 6 | **Değişiklik izi yok** | `audit.AuditItems`'ta `CreatedByUserId`/`UpdatedByUserId` kolonları **var** (`sql/20_migration_audit.sql:86-87`) ama `sp_Item_Insert` INSERT kolon listesinde **yok** (`sql/21_sps_audit.sql:384-397`). "Bu maddenin etkisini kim 5'ten 1'e düşürdü" sorusunun cevabı bugün **yok**. `security-principles.md` "Referans tanım değişikliği" zaten zorunlu audit listesinde |
| 7 | **Rozet eşiği DB ile çakışıyor** | DB `audit.AuditResults.RiskLevel` PERSISTED computed: `<=8 Low`, `<=15 Medium`, else `High` (`sql/20_migration_audit.sql:145-149`). Ekran rozeti: `>=15 kırmızı`, `>=9 amber` (`Items.cshtml:8-13`). Skor **tam 15**'te DB "Medium" der, ekran "yüksek" gösterir |
| 8 | Soft delete bağlanmamış | `sp_Item_List` `@IsActive bit = NULL` parametresini **alıyor**, `WHERE`'de **kullanmıyor** (`sql/21_sps_audit.sql:287`, `308-309`) |

**Eşik yönü kararı:** ekran DB'ye uydurulur (`>15 kırmızı`), tersi değil.
Gerekçe: `RiskLevel` **PERSISTED computed** kolondur; tanımını değiştirmek
SQL Server'a tüm geçmiş satırları yeniden hesaplatır ve **geçmiş raporlar
değişir** (`sql-conventions.md §6` tuzağı). Ekranı değiştirmek geçmişi bozmaz.

Ayrıca ekran ham Tailwind: 236 satır, elle yazılmış 6 kolonlu tablo, iki
sınıf-üretici Razor fonksiyonu (`RiskBadge`, `Truncate`), **satır içi
`oninput=` olay işleyicisi** (CSP borcu, TODO C11 — depoda 27 tanesi zaten
temizlenmişti, bunlar kalmış).

**Geriye dönük veri riski yok:** 87 maddenin tamamı 2–5 aralığında
(`enKucukP=2, enBuyukP=5, enKucukI=2, enBuyukI=5`, sınır dışı **0**).
Sınır eklemek mevcut kaydı geçersiz kılmıyor.

## Kapsam

**Dahil:** Ekranın Solum ilkellerine taşınması · yetki policy'si · sunucu
tarafı doğrulama (`[Required]`/`[Range]` + `ModelState` + `<solum-errors>`) ·
satır içi olay işleyicisinin kaldırılması · mobil düzen.

**Hariç:**
- Madde **silme** (bugün de yok). `IsActive` bağlanınca pasife alma gelir,
  sert silme gelmez.
- `audit.Skills` bağlantısı (`SkillId` bugün sabit `null` gönderiliyor).
- `audit.AuditResults` tarafındaki aynı kusurlar (`Probability`/`Impact`
  orada da CHECK'siz, `FindingType` orada da `char(1)`). Sonuç tablosu ayrı
  bir yazma yolundan besleniyor — ayrı iş, TODO'ya.

### KAPSAM GENİŞLEDİ — 2026-09-23 kullanıcı kararı

Plan ilk yazıldığında SP'ye dokunmamayı seçmişti. Danışman (`denetim-surec-danismani`)
ve kendi ölçümlerim **üç kusur daha** çıkardı ve ikisi yalnız SQL katmanında
kapanıyor. Kullanıcı kararı: **migration da yazılacak.**

Danışmanın gerekçesi aynen geçerli ve kaydedilmiştir: *"CHECK olmadan diğer
üç katman teatral"* — `tinyint` 0–255 kabul ediyor, SP dışı her yol (elle
`UPDATE`, ileride yazılacak ikinci SP, veri aktarımı) açık kalırdı.

## Reddedilen alternatifler

| Alternatif | Neden reddedildi |
|---|---|
| Tek satır CSS ile taşmayı kapat, gerisini bırak | Taşma kapanır, 8 dokunma hedefi ve masaüstü düzeni kalır. "Kapandı" sanılan yarım düzeltme bu depoda kayıtlı bir hata sınıfı (`docs/journal/2026-09-23-kalan-isler.md` §0d, "yarım yakalayan kapı"). Kullanıcı kararı 2026-09-23: taşıma |
| Plan 05'in Dalga sırasını bekle (Items Dalga 3'te) | Dalga 3'ün ön koşulu S2 (`asp-for`/`ModelExpression` köprüsü) + S3 (`ModelState` sözleşmesi) idi. **Ölçüldü: ikisi de geldi** — `Solum.Web/Components/SolumFieldTagHelper.cs:90` (`ModelExpression? For`) ve `SolumErrorsTagHelper.cs:73` (`<solum-errors>`). Engel kalkmış; ekranın mobil kusuru plan 07 Faz 6'nın bitiş ölçütünü bloke ediyor |
| Doğrulamayı yalnız istemcide bırak (HTML `min`/`max`) | İstemci doğrulaması bir kolaylıktır, kapı değildir. `curl` ile POST atan biri `min/max`'ı hiç görmez |
| Sınırı SP'de `THROW` ile zorla | Doğru nihai yer ama bu planın kapsamını SQL denetçi zinciri + migration + fresh-DB testine genişletir. Ayrı iş olarak kaydedildi |

## Tasarım

**Dokunulacak:**
- `src/BkmArgus.Web/Features/Audit/Items.cshtml` — 236 satır → Solum ilkelleri
- `src/BkmArgus.Web/Features/Audit/Items.cshtml.cs` — 118 satır → doğrulama + primary ctor
- `src/BkmArgus.Web/Features/Audit/AuditView.cs` — `RiskBadge` sunum haritasına
- `src/BkmArgus.Web/wwwroot/js/` — risk önizlemesi satır içinden olay devrine

**Kalıplar (Dalga 1'de kurulanlar, yeniden kullanılacak):**
- Süzgeç: `argus-filter-panel` katlanır `<details>` + etkin ölçüt rozeti (Faz 4, bugün)
- Liste: `.solum-row` — `SolumTable` **değil**, çünkü satırda aksiyon var ve
  Solum'un `TableModel`'inde aksiyon hücresi sözleşmesi yok (`Audit/Index.cshtml`
  başındaki gerekçe aynen geçerli)
- Form: `<solum-field asp-for>` + `<solum-errors>`
- Rozet: `ArgusBadge.ForThreshold(skor, 15, 9, yuksekKotu: true)`

**BkmArgus kısıtları:**
- [x] SP-first — yeni inline SQL yok, mevcut üç SP aynen çağrılıyor
- [x] Türkçe SP parametresi ↔ İngilizce kolon — dokunulmuyor
- [x] `src.*` view'a dokunulmuyor
- [x] `rpt.*` snapshot — ilgisiz
- [ ] `[Authorize]` + policy — **bu planın 2. kusuru**; hangi policy domain kararı
- [x] AI yok

## 5 lens

- 🔴 **Contrarian:** Yetkiyi `AdminOnly`'ye çekmek sahadaki denetçinin eksik madde eklemesini engeller — katalog donar ve denetim gerçeği yakalayamaz. Yanlış policy, kapatılan açıktan daha pahalı olabilir.
- 🔵 **First Principles:** Asıl soru "bu ekran güzel mi" değil, **"denetim kontrol listesinin şablonunu kim değiştirebilmeli ve değişiklik iz bırakıyor mu"**. Bugün iz de yok — `audit.AuditLog`'a madde değişikliği yazılmıyor.
- 🟢 **Expansionist:** Katalog sürümlenirse (madde değişti, eski denetimler hangi sürümle yapıldı) geçmiş denetimler karşılaştırılabilir kalır. Bugün madde metni değişince eski denetim sonucu sessizce yeniden yorumlanıyor.
- ⚪ **Outsider:** Bir denetim yazılımında "risk skoru" üreten iki alanın hiçbir katmanda sınırı olmaması garip — ve 87 kaydın hepsinin kurallı olması sınırın **tesadüfen** tutulduğunu gösteriyor, zorlandığını değil.
- 🟡 **Executor:** Önce `ItemInput`'a nitelikler + `ModelState` kapısı (tek dosya, hemen ölçülebilir), sonra görünüm.

## Riskler

| Risk | Etki | Önlem |
|---|---|---|
| Yanlış policy seçimi katalogu dondurur | **Yüksek** | `denetim-surec-danismani` çerçevesi + kullanıcı kararı; kararın gerekçesi koda yorum olarak yazılır |
| `<solum-field>` `int` alanda `asp-for` davranışı bilinmiyor | Orta | Faz 4'te `MinSkor`/`MaxSkor` (`int?`) ile ölçüldü, çalışıyor; `int` (non-null) ilk kez — smoke'ta doğrula |
| SP sınırı zorlamadığı için savunma tek katman | Orta | Planda açıkça yazılı; ayrı iş olarak TODO'ya |
| 87 kayıtlı canlı ekran bozulursa denetim şablonu erişilemez | Orta | Geri alma tek commit revert; şema değişmiyor |

## Adımlar

- [x] Faz 1 — Doğrulama: `ItemInput` nitelikleri + `ModelState` kapısı ✅ 2026-09-23
- [ ] Faz 2 — Migration (`sql/NN_*.sql`): `Probability`/`Impact` CHECK (1-5) ·
      `sp_Item_Insert`/`_Update` audit kolonlarını yazar · `sp_Item_List` `@IsActive`
      `WHERE`'e bağlanır. **CHECK eklemeden önce sınır dışı kayıt taranır** —
      varsa migration durur, `WITH NOCHECK` ile sessizce geçilmez
- [ ] Faz 3 — Görünüm: `Policies.AdminOnly` · Solum ilkelleri · katlanır süzgeç ·
      `.solum-row` liste · `<solum-field>` + `<solum-errors>` form · `FindingType`
      seçenek değerleri `char(1)` ile hizalanır · rozet eşiği DB'ye uydurulur
- [ ] Faz 4 — Satır içi `oninput` → olay devri (CSP)
- [ ] Faz 5 — Ölçüm + denetçi zinciri (`sql-sp-reviewer` dahil) + **fresh-DB migrate testi**

Her faz sonunda `phase-review-gate.md` zinciri.

## Denetçi turu — `sql-sp-reviewer` (2026-09-23)

Migration yazıldıktan **sonra** koşuldu ve bir **CRITICAL** bulgu çıkardı;
commit öncesi kapatıldı.

| # | Bulgu | Durum |
|---|---|---|
| **CRITICAL** | `sp_Result_StartAudit` (`audit.AuditResults`'a yazan **tek** yer) `IsActive` filtrelemiyordu → pasife alınan madde her yeni denetime kopyalanmaya devam ederdi. **Ekran ise kullanıcıya "yeni açılan denetimlere artık eklenmeyecek" diye söz veriyordu.** Kapatmaya çalıştığımız hatanın (sözleşmenin bir ucu yazılmış) tam olarak kendisi, bir katman ötede | ✅ migration'a 7. adım olarak eklendi |
| HIGH | Geri alma talimatı 4 SP'yi sessizce geriye atıyordu | ✅ düzeltildi (yukarı bak) |
| HIGH | Veri kapısının "dur" garantisi yalnız `sqlcli script` kipinde geçerli; `migrate` toleranslı koşar ve kapıyı geçer | ✅ dosya başına çalıştırma notu |
| MEDIUM | `RAISERROR` gerekçem **tersti**: mesaj metinli `RAISERROR` 50000 üretir, yani aralığın *içinde* — eski kalıp fail-closed değil **fail-open**'dı ve ham SQL hata metnini kullanıcıya gösteriyordu | ✅ yorum düzeltildi |
| MEDIUM | `sp_Item_Get` çağrısı hata köprüsünün dışındaydı → olmayan `EditId` ile işlenmemiş 500 | ✅ try/catch + Türkçe mesaj |
| MEDIUM | "Değişiklik izi" iddiam fazla güçlü: yazılan şey **son dokunan**, alan-alan geçmiş değil; `audit.AuditLog`'a satır da yazılmıyor | ⬜ TODO'ya |
| MEDIUM | `FindingType` için izin verilen kod kümesine (U/G/I) CHECK yok — tek savunma C# | ⬜ TODO'ya |
| MEDIUM | `sql/68_skill_context_build.sql:212,320` pasif maddeleri **AI bağlamına** akıtmaya devam ediyor | ⬜ TODO'ya |
| LOW | `sys.check_constraints WHERE name` şema ile nitelenmemiş · `audit.AuditResults`'taki olası sınır dışı geçmiş sessiz geçiliyor · `src/BkmArgus.Installer/sql/` aynası 22'de durmuş (kurulum yolu bu düzeltmeleri almaz) | ⬜ TODO'ya |

**Temiz doğrulananlar:** transaction disiplini · THROW aralığı (50830-50836) ·
`SCOPE_IDENTITY()` konumu · idempotency · **5 SP'nin 41 parametresinde sıfır
ad uyuşmazlığı** (C# anonymous object ile birebir) · Dapper'ın yeni kolonlarla
kırılmaması · tip kuralları · `src.*` dokunulmazlığı.

## Bitiş kriteri (kanıtlanabilir)

- [ ] 375px: yatay taşma **0** (bugün 44px)
- [ ] 375px: 44px altı dokunma hedefi **0** (bugün 8)
- [ ] 3 sayısal alanın üçünde de `inputmode` DOM'da görünüyor (bugün 0/3)
- [ ] `curl` ile `Probability=100` POST'u **reddediliyor** ve alan hatası dönüyor
- [ ] Boş `ItemText` POST'u **reddediliyor**
- [ ] Yetkisiz rol sayfayı açamıyor — iki farklı rolle denendi, biri 403/AccessDenied
- [ ] Satır içi olay işleyicisi sayısı **0** (bugün 2 `oninput`)
- [ ] Sınıf-üretici Razor fonksiyonu **0** (bugün 2)
- [ ] 87 madde listede aynen görünüyor, düzenleme ve ekleme çalışıyor (veri kaybı yok)
- [ ] `FindingType` seçimi kaydedilip geri açıldığında **aynen görünüyor** (bugün "Seçiniz"e düşüyor)
- [ ] Skor 15 olan bir maddede rozet ile DB `RiskLevel` **aynı seviyeyi** söylüyor
- [ ] Yeni/güncellenen maddede `CreatedByUserId`/`UpdatedByUserId` **dolu** (bugün NULL)
- [ ] Elle `UPDATE audit.AuditItems SET Impact = 100` **CHECK ile reddediliyor**
- [ ] Fresh-DB migrate: `sql/[0-9]*.sql` zinciri boş DB'de 0 fail, beklenen objeler `OBJECT_ID` ile doğrulandı

## Geri alma

Migration **var** (2 CHECK constraint + 5 `CREATE OR ALTER` SP). Geri alma:
`ALTER TABLE ... DROP CONSTRAINT CK_AuditItems_*` + **yalnız o beş SP'nin**
eski tanımını geri koyan ayrı bir betik.

> ⚠️ **"`sql/21_sps_audit.sql`'i yeniden koş" DEMEYİN.** İlk yazılışta geri
> alma notu bunu diyordu; `sql-sp-reviewer` yakaladı (confidence 95). O dosya
> 18 SP tanımlar ve **dördü sonradan düzeltilmiştir**: `sp_Audit_Delete`
> (sql/79, sql/82) · `sp_Audit_List` (sql/79, sql/81) ·
> `sp_Analysis_DofEffectiveness` (sql/77) · `sp_Analysis_FullPipeline`
> (sql/43). Dosyayı yeniden koşmak silme kapsamı ve durum sözlüğü
> düzeltmelerini de **sessizce geri alır**.

Tablo verisi değişmiyor, kolon eklenmiyor, kolon silinmiyor. Kod tarafı tek
commit `git revert`.

**Bir veri daralması yolu VARDI ve kapatıldı** (ilk yazılışta "veri kaybı
yolu yok" denmişti, yanlıştı): `sp_Item_Update` `LocationType`'ı `COALESCE`
ile yazıyor ve C# her düzenlemede sabit `"Store"` gönderiyordu. `'Both'` ya
da `'Cafe'` bir madde ekrandan düzenlenseydi sessizce `'Store'`'a daralır ve
`sp_Result_StartAudit`'in `LocationType` süzgeci yüzünden Kafe
denetimlerinden düşerdi — kullanıcı yalnız metnini düzeltip maddeyi
kaybederdi. Artık `null` gönderiliyor, yani "bu alanı değiştirme". Yetki policy'si geri
alınırsa ekran yine herkese açılır — o yüzden policy kararı commit mesajında
gerekçesiyle yazılır.
