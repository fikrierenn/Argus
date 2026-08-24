# Plan 04 — Bkm.* Ortak Katman (kütüphane kümesi, çatı değil)

**Durum:** onay bekliyor
**Tier:** 3 (proje-üstü, yeni pattern, kullanıcı-görünür değil ama geri alınması zor)
**Tarih:** 2026-08-23

---

## Karar ve gerekçe

`D:\Dev` altında 92 klasör, 23 .NET projesi. Soru "ABP'ye taşıyalım mı / ABP gibi
bir çatı yazalım mı" idi. Ölçümle cevaplandı (`cati-degerlendirme` skill'i bu
kararın çerçevesini kalıcılaştırdı).

| Ölçüm | Sonuç | Anlamı |
|---|---|---|
| Yığın | 23 .NET · 22 Node · 11 Python | Tek kod katmanı tek yığını kapsar |
| Ev stili | Dapper 14 / EF Core 7 | ABP (EF-first) uymuyor |
| `SqlExecutor.cs` | MIMBAL~fifo **%100** | Gerçek kopya, paketlenebilir |
| `Db.cs` | en yüksek %24.6 | Aynı kavram, farklı kod |
| `AuthService.cs` | en yüksek **%8.3** | Yalnız ad ortak |

**Karar:** ABP'ye taşıma yok, ABP klonu yok. **Kütüphane kümesi + konvansiyon**,
strangler modeliyle: yeni işler üstünde doğar, eskiler *zaten dokunulduğunda* geçer.

---

## Referans uygulama ölçerek seçildi

Kimlik diliminde **Operax > BkmArgus**:

| | Operax | BkmArgus |
|---|---|---|
| kullanıcı deposu | `DapperUserStore.cs` **332 satır** — ASP.NET Core Identity'nin `IUserStore`/`IUserPasswordStore`/`IUserRoleStore`/`IUserClaimStore` arayüzlerini Dapper üzerinde uygular, `AddIdentity` standart | elle yazılmış `AuthService.cs` 88 satır + BCrypt |
| yetki ekranı | `Admin/Roles/Permissions` 80 satır | yok |
| denetim izi | `Admin/AuditLog/` ekranı var | yok — **A1 açık TODO** |
| KVKK | yok | yok |

Operax'ın yaklaşımı hem daha az kod hem daha güvenli: şifre hash'leme, lockout,
claim, cookie auth Microsoft'ta kalıyor; yalnız depolama bizde.

---

## Sıra

### 1. `Bkm.SqlTools` — tasarım işi yok
sqlcli çekirdeği (`SqlExecutor`, `ConnectionResolver`, `OutputFormatter`,
`ConfigStore`). %100 kopya, MIMBAL ve fifo referans verip kendi kopyalarını siler.
**Done:** 3 kopya → 1 kaynak, üç proje de derleniyor.

### 2. `Bkm.Identity` — Operax'tan genelleştirme
`DapperUserStore` taşınır. Tek genelleştirme noktası: tablo/kolon adları projeye
göre değişiyor → SQL bir sözleşmeden gelsin, gövde sabit kalsın.
**Done:** Operax kendi kopyasını silip pakete referans verir ve çalışmaya devam eder.
Sonra BkmArgus ikinci tüketici olur, `AuthService` emekliye ayrılır.

### 3. `Bkm.Audit` — iki uygulamanın birleşimi
Operax `AuditLog` + BkmArgus `audit.AuditLog`. BkmArgus'ta **A1'i kapatır**.
KVKK erişim kaydı bunun üstüne biner.

### 4. `Bkm.Kvkk` — sıfırdan
Veri envanteri, saklama süresi, rıza, silme talebi, veri sahibi erişimi.
Hiçbir çatının vermediği parça.

---

## Kapsam dışı

- Mevcut projeleri toplu taşıma (strangler — sadece dokunulduğunda)
- Node/Python projeleri
- Çalışma zamanı modül sistemi (ABP tarzı yaşam döngüsü) — tek geliştirici için aşırı
- Multi-tenancy

---

## Riskler

| Risk | Azaltma |
|---|---|
| **Tüketicisiz çatı** (`claude-context-template` böyle öldü: doğru mimari, 0 commit) | İki tüketici bugün var — Operax kaynak, BkmArgus ikinci |
| Erken soyutlama | Kütüphane yakınsamayı izler; %30 altı benzerlikte paketleme yok |
| Merkez bayatlar | Geri akış yolu (`harvest.sh` deseni) baştan kurulur |
| Projeye özel bilgi gövdeye gömülür | Mekanizma / eşleme ayrımı (hook'larda öğrenildi) |

---

## Done kriterleri

- [ ] `Bkm.SqlTools`: 3 projede kopya silindi, hepsi derleniyor
- [ ] `Bkm.Identity`: Operax kopyasını silip pakete geçti, login çalışıyor
- [ ] `Bkm.Audit`: BkmArgus A1 kapandı, denetim izi yazıyor
- [ ] Her paket bağımsız sürümleniyor; birini güncellemek diğerini kırmıyor

---

## İlişkili

- `.claude/skills/cati-degerlendirme/SKILL.md` — karar çerçevesi
- `memory/project_framework_karari.md` — ölçümler ve karar
- `plans/03-argus-uzman-ajanlar.md` — BkmArgus içi ajan katmanı (ayrı iş)
