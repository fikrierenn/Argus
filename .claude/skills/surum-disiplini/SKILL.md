---
name: surum-disiplini
description: Paket/kütüphane sürümleme ve değişiklik günlüğü disiplini — SemVer kararı (major/minor/patch), CHANGELOG bakımı, sürüm notları, public API yüzeyinin izlenmesi, bağımsız vs lockstep sürümleme, tüketicilere kırıcı değişikliğin bildirilmesi. "sürüm çıkar", "changelog", "versiyon artır", "release notes", "kırıcı değişiklik mi", "paketi yayınla", "NuGet'e at" denildiğinde ve bir paketin public API'sine dokunmadan ÖNCE danış. SALT-REHBER — karar ölçütlerini ve tutulacak kayıtları verir.
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
model: inherit
---

# Sürüm Disiplini

Bir kütüphane yayınlandığı andan itibaren **söz vermiş** olur. Sürüm numarası o
sözün ne kadar tutulduğunu söyler; changelog neyin değiştiğini. İkisi olmadan
tüketici her güncellemede kumar oynar.

Bu danışman özellikle **bağımsız sürümlenen paket aileleri** için yazıldı
(`Solum.Sql`, `Solum.Sql.SqlServer`, `Solum.Identity`…). Bağımsız sürümleme
ancak değişiklik izlenirse çalışır; izlenmezse lockstep'ten beterdir.

**Dayanak ayrımı:** 📚 yerleşik standart (kaynaklı) · ✅ bu projede doğrulandı ·
🔧 bu skill'in çıkarımı.

---

## 1. SemVer kararı 📚

Kaynak: [semver.org](https://semver.org)

| Değişiklik | Artan | Örnek |
|---|---|---|
| Public API'den bir şey **kalktı** ya da davranışı değişti | **MAJOR** | metot silindi, parametre eklendi, dönüş tipi değişti, varsayılan değer değişti |
| Public API'ye **eklendi**, eski kod derlenmeye devam eder | **MINOR** | yeni metot, yeni overload, yeni opsiyonel parametre |
| Dışarıdan görünen hiçbir şey değişmedi | **PATCH** | hata düzeltmesi, performans, iç refactor |

`0.x` sürümlerde MAJOR yerine MINOR kırıcı sayılır — ama bu bir mazeret değil,
sadece erken dönem için gevşetme. `1.0`'a geçtiğin an söz bağlayıcı olur.

**Sinsi kırıcı değişiklikler** 🔧 — API imzası aynı kalır ama tüketici kırılır:

- Bir bağımlılığın major sürümünü yükseltmek
- `TargetFramework`'ü yükseltmek (net8.0 → net10.0, eski tüketici düşer)
- Bir istisnayı fırlatmayı bırakmak ya da başlamak
- Varsayılan davranışı değiştirmek (timeout, retry sayısı, sıralama)
- Bir `enum`'a ortadan değer eklemek (sayısal değerler kayar)

---

## 2. API yüzeyini derleyiciye izlet ✅

Disiplinle "kırıcı mı acaba" diye düşünmek yerine, derleyici söylesin.

**`Microsoft.CodeAnalysis.PublicApiAnalyzers`** — Microsoft/Roslyn, MIT.
✅ 2026-08-23'te nuget.org'da doğrulandı: sürüm 5.6.0, Dapper · Polly · MAUI
kullanıcıları arasında. (Sayfada `PublicAPI.Shipped.txt` / `Unshipped.txt`
dosya mekanizması açıkça yazmıyordu — kullanmadan önce paketin kendi
dokümanından teyit et.)

Kazanç: public API'ye eklenen her üye, işaretlenene kadar **derleme uyarısı**
üretir. Kırıcı değişiklik gözden kaçmaz, PR'da görünür.

---

## 3. CHANGELOG 📚

Kaynak: [keepachangelog.com](https://keepachangelog.com)

Her paket **kendi** `CHANGELOG.md`'sini tutar — aile geneli tek dosya değil.
Sebep: bağımsız sürümleniyorlar, tüketici yalnız kullandığı paketin geçmişini
okumak ister.

```markdown
## [0.2.0] - 2026-09-01

### Eklendi
- `ISqlDialect.LimitRows` — sağlayıcıya özel satır sınırlama

### Değişti
- **KIRICI:** `SqlExecutor.RunScriptAsync` artık `ScriptResult` döner,
  konsola yazmaz. Çağıran sonucu kendisi sunmalı.

### Düzeltildi
- Oracle bağlantı dizesi SQL Server sanılıyordu (`Detect` "aksi halde" mantığı)
```

Kurallar:

- **Değişiklik anında yaz, sürüm anında değil.** Sonradan yazılan changelog
  eksik yazılır; commit mesajından üretilen changelog gürültülü olur.
- **Tüketici gözüyle yaz.** "Refactor SqlExecutor" değil, "artık konsola
  yazmıyor, sonuç nesnesi dönüyor".
- **KIRICI olanı işaretle** ve *ne yapılması gerektiğini* söyle.
- `Unreleased` başlığı altında biriktir, sürümde tarihle mühürle.

---

## 4. Sürüm notu pakete de girsin 🔧

`.csproj` içinde `PackageReleaseNotes` — NuGet galerisinde ve IDE'de görünür.
Elle iki yerde tutmak yerine changelog'un son bölümünü oraya kopyala; iki
kaynak ayrışırsa hangisinin doğru olduğu belirsizleşir.

---

## 5. Bağımsız mı lockstep mi 🔧

| | Bağımsız | Lockstep |
|---|---|---|
| Ne zaman | Paketler birbirinden gerçekten ayrıksa | Birlikte değişmek zorundalarsa |
| Kazanç | `Solum.Sql.Oracle` eklemek `Solum.Identity`'yi sürüm atlatmaz | Uyum sorusu yok, hepsi aynı numarada |
| Bedel | Uyum matrisi tutmak gerekir | Değişmeyen paket de sürüm atlar, gürültü |

🔧 Bu skill'in çıkarımı: **soyutlama paketi + sağlayıcı paketleri** yapısında
soyutlama katmanının sürümü sağlayıcıların *alt sınırıdır*. `Solum.Sql` 0.3'e
çıkarsa `Solum.Sql.Oracle` en az 0.3'e bağımlı olmalı; ama Oracle'ın kendi
yama sürümü bağımsız ilerler.

Hangi ailenin hangi modeli seçtiği ve nedeni **DOĞRULANMADI** — Serilog
bağımsız, MassTransit lockstep görünüyor ama kaynağını açmadım.

---

## 6. Tüketici kaydı 🔧

Kim hangi sürümde? Kırıcı değişiklik yaparken kimi arayacağını bilmek gerekir.

Bu portföyde tüketici sayısı az; `docs/CONSUMERS.md` gibi elle tutulan bir
tablo yeterli. Otomatikleştirmek (feed'den çekmek) ancak tüketici sayısı
elle takip edilemez olunca gerekir.

---

## 7. Yayın öncesi kontrol listesi

- [ ] CHANGELOG'da `Unreleased` bölümü dolu ve tüketici gözüyle yazılmış
- [ ] SemVer kararı verildi ve **gerekçesi changelog'da görünüyor**
- [ ] Kırıcı değişiklik varsa göç talimatı yazıldı ("şunu şuna çevirin")
- [ ] `PackageReleaseNotes` changelog ile aynı
- [ ] Paket **gerçekten** paketleniyor: `dotnet pack` + yerel feed'den
      referans veren bir test projesi derleniyor
- [ ] Bağımlılık listesi kontrol edildi — beklenmedik bir paket sızdı mı
- [ ] `TargetFramework` değişmediyse teyit, değiştiyse MAJOR

---

## 8. Anti-pattern

| Anti-pattern | Doğrusu |
|---|---|
| Sürüm anında changelog yazmak | Değişiklik anında yaz |
| Commit mesajlarını changelog sanmak | Changelog tüketici için, commit geliştirici için |
| "Sadece refactor, patch yeter" | Public API değiştiyse patch değildir |
| Bağımlılık major yükseltmesini patch saymak | Tüketiciyi kırabilir → MAJOR |
| Aile geneli tek CHANGELOG | Paket başına |
| Kırıcı değişikliği yalnız "KIRICI" diye işaretlemek | Ne yapılacağını da yaz |
| Yayınlamadan önce paketlemeyi denememek | `dotnet pack` + yerel feed'den tüket |

---

## İlişkili

- `.claude/skills/cati-degerlendirme/SKILL.md` — paket sınırı ve aile kurma kararı
- `.claude/rules/evidence-discipline.md` — ölç, doğrula ya da "DOĞRULANMADI" de
- `.claude/rules/commit-discipline.md` — commit disiplini (changelog'dan ayrı)
