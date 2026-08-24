---
name: cati-degerlendirme
description: Dış bir çatıyı (ABP, XAF, MediatR yığını, Nx, Django apps…) inceleyip ondan ne alınacağına, kendi ortak katmanını kurmanın değip değmeyeceğine karar verme danışmanı. Kopya ölçümü (aynı ad ≠ aynı kod), çatı ile kütüphane kümesi ayrımı, aktif tüketici koşulu, mekanizma/eşleme ayrımı, göç modeli (strangler), platformun zaten verdiğini kontrol etme. "ABP gibi bir şey yapayım mı", "ortak katman kuralım", "framework yazalım", "bu projeleri birleştirelim", "çatıyı incele" denildiğinde ve ortak kod çıkarmadan ÖNCE danış. SALT-REHBER — ölçülecek şeyleri ve karar eşiklerini verir, kararı sen gerekçeyle verirsin.
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
user-invocable: true
model: inherit
---

# Çatı Değerlendirme Danışmanı

Birden çok projede aynı şeyi yeniden yazdığını fark ettiğinde çıkan soru: *"ABP gibi bir çatı mı kursam?"*

Bu danışman o kararı **ölçüye** bağlar.

**Dayanak ayrımı — okurken buna dikkat et:**

| İşaret | Anlamı |
|---|---|
| 📐 **ÖLÇÜM** | Gerçek bir portföyde ölçülmüş **örnek vaka**. Yöntem senin için geçerli, sayılar değil — kendi portföyünde yeniden ölç |
| 🔧 **SEZGİ** | Bu skill'in yazarının çıkarımı. Makul ama **doğrulanmadı**, eşikler tartışmaya açık |
| 📚 **YERLEŞİK** | Sektörde bilinen desen, kaynağı belirtildi |

Bu ayrım olmadan yazılan ilk sürümde ölçülmüş sayılarla uydurulmuş eşikler
aynı güvenle yan yana duruyordu — `evidence-discipline.md`'nin tam da
yasakladığı şey.

**Örnek vakalar 2026-08 tarihli bir .NET portföyünden (92 klasör, 23 .NET
projesi) alındı.** Onları kanıt değil **yöntem gösterimi** olarak oku: aynı
ölçümü kendi portföyünde yaptığında sayılar farklı çıkacak, karar da farklı
olabilir.

---

## 0. Önce ölç, sonra karar ver

Karar vermeden önce dört sayı gerekir. Hiçbiri tahminle doldurulamaz.

| Ölçüm | Nasıl | Neden belirleyici |
|---|---|---|
| Yığın dağılımı | proje başına `*.csproj` / `package.json` / `*.py` | Tek kod kütüphanesi tek yığını kapsar. 23 .NET + 22 Node + 11 Python ise "tek çatı" baştan imkânsız |
| Paket tekrarı | `csproj` içindeki `PackageReference` sayımı | Ev stilini gösterir. Dapper 14 / EF 7 çıkarsa EF-temelli bir çatı (ABP) sana uymaz |
| **Kod benzerliği** | aynı adlı dosyaları çift çift `difflib` ile karşılaştır | **En kritik ölçüm.** Aşağıya bak |
| Aktif tüketici | çatıyı bugün kullanacak canlı proje var mı | Yoksa çatı ölür (§4) |

---

## 1. Aynı ad ≠ aynı kod (en çok atlanan ölçüm)

Aynı adlı dosyaların **var olması** ortak kod olduğunu göstermez. Ölçüm:

📐 **ÖLÇÜM** — `difflib.SequenceMatcher`, aynı adlı dosyalar çift çift:

```
SqlExecutor.cs          MIMBAL ~ fifo   %100      -> gerçek kopya
ConnectionResolver.cs   MIMBAL ~ fifo   %100      -> gerçek kopya
Db.cs                   en yüksek       %24.6     -> aynı kavram, farklı kod
NotificationService.cs  en yüksek       %13.8     -> aynı kavram, farklı kod
AuthService.cs          en yüksek        %8.3     -> yalnızca ad ortak
```

Eşikler — 🔧 **SEZGİ**, ölçülmedi:

Aşağıdaki yüzdeler bu skill'in yazarının koyduğu ayrım noktalarıdır; bir
literatüre ya da ölçüme dayanmıyor. Gözlenen dağılım iki uçta kümelendiği için
(%100 ve %8-25) arada geniş bir boşluk vardı ve eşik oraya kondu. Kendi
verinde farklı bir dağılım görürsen eşiği taşı.

- **%80+** → gerçek kopya. Çıkarım = paketleme. Tasarım işi yok, bugün yapılır.
- **%30–80** → yakınsıyor. Bir şekil seçilebilir, ama hangisinin kazanacağı karardır.
- **%30 altı** → **çıkarılacak bir şey yok.** Aynı soruna N ayrı çözümün var. "Ortak kütüphane" yazmak, çözülmüş sorunların üstüne uydurma bir soyutlama koymaktır.

Düşük benzerlik bir başarısızlık değil, **bilgidir**: sorun *"kütüphanem yok"* değil, *"her seferinde yeniden karar veriyorum"*. Bunu kütüphane değil **konvansiyon** (şablon) çözer.

---

## 2. Çatı mı, kütüphane kümesi mi  🔧 SEZGİ

| | Çatı (framework) | Kütüphane kümesi |
|---|---|---|
| Kontrol | Senin kodun ona takılır | Sen onu çağırırsın |
| Benimseme | Baştan, bütün olarak | Parça parça |
| Çıkış maliyeti | Yüksek | Düşük |
| Bakım | Sürüm/kırıcı değişiklik yönetimi ikinci bir iş | Her paket bağımsız |

Tek geliştiricinin baktığı, alanları birbirinden uzak bir portföyde **kütüphane kümesi neredeyse her zaman kazanır.** Çatı, aynı şekli paylaşan çok sayıda benzer uygulama varsa değer üretir.

**Ortak base kütüphane yapma.** Bir projeye yaptığın değişiklik diğer hepsini riske atar; bu bir bağlanma noktasıdır.

---

## 3. Kütüphane yakınsamayı İZLER, yaratmaz  🔧 SEZGİ + 📚 YERLEŞİK

Sıra bu:

1. Konvansiyon (şablon) → yeni projeler aynı şekilde başlar
2. Şekil oturur, üç projede aynı kalır ve değişmemeye başlar
3. **O zaman** paketle

Ters sırada yaparsan, henüz uzlaşmamış üç şeyi zorla birleştirmiş olursun ve paketin ilk sürümü yanlış soyutlamayı dondurur.

**Kural: bir şey üç projede kullanıldığı KANITLANINCA çıkarılır, önce değil.**

📚 Bu "rule of three" adıyla bilinen yerleşik bir kural (Martin Fowler,
*Refactoring*; ayrıca WET/DRY tartışmasında yaygın). Sıralamanın kendisi
("önce konvansiyon, sonra paket") 🔧 bu skill'in çıkarımı.

---

## 4. Aktif tüketici koşulu (ortak katmanları asıl öldüren şey)

**Yöntem — her portföyde uygulanır:**

Merkezî bir katmanın canlı olup olmadığı, mimarisinden değil **commit akışından**
anlaşılır. Ölç: merkez deposu ile onu kullanan projelerin aynı dönemdeki commit
sayıları. Merkez belirgin şekilde geriden geliyorsa katman fiilen ölüdür —
"güncelle" komutu artık projeleri geriye alacağı için kimse çalıştırmaz.

```
merkez_commit / donem   vs   proje_commit / donem
```

**Örnek vaka** 📐 (bu portföyde ölçüldü, senin sayıların farklı olacak):
`claude-context-template` v1.3.0. Mimarisi **doğruydu** — `_universal` / `stacks` / `project` ayrımı yerindeydi, bootstrap çalışıyordu, dokümantasyonu vardı. 11 Haziran'dan itibaren **0 commit**.

Aynı dönemde projeler: pusula 48, Operax 35, reporthub 28 commit.

Sebep göç maliyeti değildi. **Onu çeken aktif bir tüketici yoktu.** İyileştirme işin yapıldığı yerde doğuyor; geri akacak yol yoksa merkez geride kalıyor, geride kalınca "güncelle" komutu projeleri geriye alır hale geliyor ve kimse çalıştırmıyor.

Kontrol listesi:

- [ ] Çatının **bugün** üstünde çalıştığın bir tüketicisi var mı? Gelecekteki proje sayılmaz
- [ ] Merkeze **geri akış** yolu var mı? Yoksa merkez kaçınılmaz olarak bayatlar
- [ ] İlk sürüm gerçek bir işten mi doğuyor, yoksa önden mi tasarlanıyor?

---

## 5. Mekanizma ile eşlemeyi ayır

**Yöntem:** Bir yeteneği ikinci projeye taşırken kırılan ilk şey, projeye özel
bilgiyi gövdeye gömmüş olmandır. Ayrım şu soruyla bulunur: *"bu satır her
projede aynı mı kalır, yoksa projeye göre mi değişir?"* Değişenler gövdeden
çıkıp bir yapılandırma dosyasına iner.

**Örnek vaka** 📐: danışman kapısı hook'u BkmArgus'un kendi danışmanlarını `case` içine gömmüştü. Operax'ta o danışmanlar yok — kapı bloklayıp **var olmayan** bir danışmanı işaret edecekti.

```
hooks/*.sh            mekanizma  -> ortak, sync edilir
*-map.conf            eşleme     -> projeye özel, ASLA sync edilmez
```

Genel kural: **taşınabilirlik testi ancak ikinci projede geçilir.** Tek projede yazılmış hiçbir şey taşınabilir sayılmaz.

---

## 6. Göç modeli maliyeti belirler  📚 YERLEŞİK

- **Büyük göç** (hepsini taşı) → pahalı, riskli, genellikle yarım kalır
- **Strangler** (yeni işler çatıda doğar, eskiler *zaten dokunulduğunda* geçer) → maliyet zaten yapılacak işin içine dağılır

📚 Strangler Fig deseni Martin Fowler'a ait
(martinfowler.com/bliki/StranglerFigApplication.html). Portföy ölçeğine
uygulanması 🔧 bu skill'in çıkarımı.

Strangler modeli, "N projeyi taşımak pahalı" itirazını ortadan kaldırır. Düşük kod benzerliği de bu modelde sorun olmaktan çıkar: birleştirmiyorsun, **bundan sonrası için bir şekil seçiyorsun**.

---

## 7. Platform zaten veriyor mu

**Yöntem:** Kendi soyutlamanı yazmadan önce standardın ne verdiğine bak. Yeniden yazmanın meşru sebebi genelde **depolama**dır, davranış değil.

**Örnek vaka** 📐: Operax `DapperUserStore` ile ASP.NET Core Identity'nin `IUserStore` / `IUserPasswordStore` / `IUserRoleStore` / `IUserClaimStore` arayüzlerini Dapper üzerinde uyguluyor, `AddIdentity` standart kalıyor.

Sonuç: şifre hash'leme, lockout, claim, cookie auth Microsoft'ta kalıyor; yalnız depolama sende. Elle yazılmış bir `AuthService`'ten hem daha az kod hem daha güvenli.

Soru: *"davranışı mı yeniden yazıyorum, yoksa yalnız depolamayı mı?"* Davranışsa dur.

---

## 8. En olgun uygulamadan çıkar, en tanıdıktan değil

**Yöntem:** Aynı dilimin birden çok uygulaması varsa referansı **ölçerek** seç:
satır sayısı, uyguladığı standart arayüz sayısı, çevresindeki ekran/araç
varlığı. En çok zaman geçirdiğin proje en iyi çözüme sahip olan olmayabilir.

**Örnek vaka** 📐: kimlik dilimi için BkmArgus (170 satır, elle yazılmış) tanıdık olandı; Operax (`DapperUserStore` 332 satır, standarda uyumlu, yetki ekranı + denetim izi ekranı var) olgun olandı.

Referans uygulamayı **ölçerek** seç. En çok zaman geçirdiğin proje en iyi çözüme sahip olan olmayabilir.

---

## 9. Anti-pattern

| Anti-pattern | Doğrusu |
|---|---|
| Ölçmeden "ortak kütüphane yazalım" | Önce kod benzerliği ölç |
| Aynı ad = aynı kod varsaymak | Çift çift karşılaştır |
| Tüketicisiz çatı kurmak | Gerçek, bugünkü bir işten doğsun |
| Tek yönlü akış (merkez → proje) | Geri akış (hasat) olmadan merkez bayatlar |
| Projeye özel bilgiyi gövdeye gömmek | Mekanizma / eşleme ayrımı |
| Kütüphaneyle yakınsama yaratmaya çalışmak | Önce konvansiyon, yakınsayınca paketle |
| Platformun verdiğini yeniden yazmak | Yalnız depolamayı değiştir |
| Tanıdık projeyi referans almak | En olgun olanı ölçerek seç |
| Büyük göç planlamak | Strangler |

---

## 10. Çıktı biçimi

Bu danışmana danışıldığında şu üçü **sayıyla** cevaplanmalı:

1. **Ne kopya?** (%80+ benzerlik) → bugün paketlenir
2. **Ne yakınsıyor?** (%30-80) → şablona referans uygulama
3. **Ne ayrışmış?** (<%30) → dokunma, konvansiyonla yakınsat

Ve bir de: **ilk tüketici kim, bugün.**

---

## Manzara — nereye bakılır

Bir ortak katman kurmadan önce **aynı sorunu çözmüş olanlara** bakılır. ABP ve
XAF akla ilk gelenler olabilir ama manzarayı daraltmasınlar:

| Tür | Örnekler | Ne öğretir |
|---|---|---|
| Uygulama çatısı | ABP, Orchard Core, XAF, Umbraco | Modül sınırı, yaşam döngüsü, eklenti ekosistemi |
| **Şablon** (çatı değil) | Ardalis CleanArchitecture, Jason Taylor CleanArchitecture | Neyin şablonda kalıp neyin pakete gireceği — **çoğu portföy için doğru cevap budur** |
| Kompozisyon | .NET Aspire (`ServiceDefaults`) | "Her projede aynı log/health/telemetry kurulumu" sorununun güncel cevabı |
| Tek-amaçlı paket ailesi | Serilog, MassTransit, Polly, FluentValidation, `Microsoft.Extensions.*` | Paket sınırı, sürümleme, `AddXxx()` konvansiyonu |
| Ekosistem dışı | Spring Boot **starter**, Django apps, Rails engines, Laravel service providers | Bir paketin hem bağımlılığı hem varsayılan yapılandırmayı getirmesi |
| Monorepo aracı | Nx, Turborepo, changesets | Paket sınırı ve sürüm otomasyonu |

**Ölmüş olanlara da bak.** SharpArchitecture, NLayerApp gibi bir zamanlar
yaygın .NET çatılarının neden terk edildiği, yaşayanların neden yaşadığından
daha öğretici olabilir.

## Eksik — doldurulacak

Bu skill'in ilk sürümü **dış kaynak araştırması yapılmadan** yazıldı; içeriğin
yarısı bugünkü ölçüm, yarısı yazarın sentezi. `reference-researcher` ile ABP,
XAF ve çok-paketli .NET kütüphane aileleri (Serilog, MassTransit, Polly,
Microsoft.Extensions.*) incelendiğinde şu başlıklar **kaynaklı** hale gelmeli:

- Paket sınırı nasıl çizilir, bağımlılık yönü kuralları
- Bağımsız vs lockstep sürümleme — tek geliştirici için hangisi
- DI kayıt konvansiyonu (`AddXxx`), Options pattern, `ValidateOnStart`
- Şema/tablo adlarını ayarlanabilir yapma desenleri
- Aileleri batıran somut hatalar (aşırı paket bölme, sürüm cehennemi)

## İlişkili

- `.claude/rules/footprint-ladder.md` — en dar basamak; çatı en üst basamaktır
- `.claude/rules/evidence-discipline.md` — ölç, doğrula ya da "DOĞRULANMADI" de
- `.claude/agents/reference-researcher.md` — dış kaynağı gerçeğinden okuyan ajan
- `.claude/agents/code-architect.md` — blueprint üreten ajan
- `.claude/skills/yetenek-uret/SKILL.md` — yeni yetenek üretimi
