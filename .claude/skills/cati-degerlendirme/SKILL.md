---
name: cati-degerlendirme
description: Dış bir çatıyı (ABP, XAF, MediatR yığını, Nx, Django apps…) inceleyip ondan ne alınacağına, kendi ortak katmanını kurmanın değip değmeyeceğine karar verme danışmanı. Kopya ölçümü (aynı ad ≠ aynı kod), çatı ile kütüphane kümesi ayrımı, aktif tüketici koşulu, mekanizma/eşleme ayrımı, göç modeli (strangler), platformun zaten verdiğini kontrol etme. "ABP gibi bir şey yapayım mı", "ortak katman kuralım", "framework yazalım", "bu projeleri birleştirelim", "çatıyı incele" denildiğinde ve ortak kod çıkarmadan ÖNCE danış. SALT-REHBER — ölçülecek şeyleri ve karar eşiklerini verir, kararı sen gerekçeyle verirsin.
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
user-invocable: true
model: inherit
---

# Çatı Değerlendirme Danışmanı

Birden çok projede aynı şeyi yeniden yazdığını fark ettiğinde çıkan soru: *"ABP gibi bir çatı mı kursam?"*

Bu danışman o kararı **ölçüye** bağlar. İçindeki her kural 2026-08-22'de `D:\Dev` üzerinde yapılan gerçek ölçümden çıktı; hiçbiri varsayım değil.

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

```
SqlExecutor.cs          MIMBAL ~ fifo   %100      -> gerçek kopya
ConnectionResolver.cs   MIMBAL ~ fifo   %100      -> gerçek kopya
Db.cs                   en yüksek       %24.6     -> aynı kavram, farklı kod
NotificationService.cs  en yüksek       %13.8     -> aynı kavram, farklı kod
AuthService.cs          en yüksek        %8.3     -> yalnızca ad ortak
```

Eşikler:

- **%80+** → gerçek kopya. Çıkarım = paketleme. Tasarım işi yok, bugün yapılır.
- **%30–80** → yakınsıyor. Bir şekil seçilebilir, ama hangisinin kazanacağı karardır.
- **%30 altı** → **çıkarılacak bir şey yok.** Aynı soruna N ayrı çözümün var. "Ortak kütüphane" yazmak, çözülmüş sorunların üstüne uydurma bir soyutlama koymaktır.

Düşük benzerlik bir başarısızlık değil, **bilgidir**: sorun *"kütüphanem yok"* değil, *"her seferinde yeniden karar veriyorum"*. Bunu kütüphane değil **konvansiyon** (şablon) çözer.

---

## 2. Çatı mı, kütüphane kümesi mi

| | Çatı (framework) | Kütüphane kümesi |
|---|---|---|
| Kontrol | Senin kodun ona takılır | Sen onu çağırırsın |
| Benimseme | Baştan, bütün olarak | Parça parça |
| Çıkış maliyeti | Yüksek | Düşük |
| Bakım | Sürüm/kırıcı değişiklik yönetimi ikinci bir iş | Her paket bağımsız |

Tek geliştiricinin baktığı, alanları birbirinden uzak bir portföyde **kütüphane kümesi neredeyse her zaman kazanır.** Çatı, aynı şekli paylaşan çok sayıda benzer uygulama varsa değer üretir.

**Ortak base kütüphane yapma.** Bir projeye yaptığın değişiklik diğer hepsini riske atar; bu bir bağlanma noktasıdır.

---

## 3. Kütüphane yakınsamayı İZLER, yaratmaz

Sıra bu:

1. Konvansiyon (şablon) → yeni projeler aynı şekilde başlar
2. Şekil oturur, üç projede aynı kalır ve değişmemeye başlar
3. **O zaman** paketle

Ters sırada yaparsan, henüz uzlaşmamış üç şeyi zorla birleştirmiş olursun ve paketin ilk sürümü yanlış soyutlamayı dondurur.

**Kural: bir şey üç projede kullanıldığı KANITLANINCA çıkarılır, önce değil.**

---

## 4. Aktif tüketici koşulu (çatıları asıl öldüren şey)

Ölçülmüş vaka: `claude-context-template` v1.3.0. Mimarisi **doğruydu** — `_universal` / `stacks` / `project` ayrımı yerindeydi, bootstrap çalışıyordu, dokümantasyonu vardı. 11 Haziran'dan itibaren **0 commit**.

Aynı dönemde projeler: pusula 48, Operax 35, reporthub 28 commit.

Sebep göç maliyeti değildi. **Onu çeken aktif bir tüketici yoktu.** İyileştirme işin yapıldığı yerde doğuyor; geri akacak yol yoksa merkez geride kalıyor, geride kalınca "güncelle" komutu projeleri geriye alır hale geliyor ve kimse çalıştırmıyor.

Kontrol listesi:

- [ ] Çatının **bugün** üstünde çalıştığın bir tüketicisi var mı? Gelecekteki proje sayılmaz
- [ ] Merkeze **geri akış** yolu var mı? Yoksa merkez kaçınılmaz olarak bayatlar
- [ ] İlk sürüm gerçek bir işten mi doğuyor, yoksa önden mi tasarlanıyor?

---

## 5. Mekanizma ile eşlemeyi ayır

Bir yeteneği ikinci projeye taşırken kırılan ilk şey, projeye özel bilgiyi gövdeye gömmüş olmandır.

Ölçülmüş vaka: danışman kapısı hook'u BkmArgus'un kendi danışmanlarını `case` içine gömmüştü. Operax'ta o danışmanlar yok — kapı bloklayıp **var olmayan** bir danışmanı işaret edecekti.

```
hooks/*.sh            mekanizma  -> ortak, sync edilir
*-map.conf            eşleme     -> projeye özel, ASLA sync edilmez
```

Genel kural: **taşınabilirlik testi ancak ikinci projede geçilir.** Tek projede yazılmış hiçbir şey taşınabilir sayılmaz.

---

## 6. Göç modeli maliyeti belirler

- **Büyük göç** (hepsini taşı) → pahalı, riskli, genellikle yarım kalır
- **Strangler** (yeni işler çatıda doğar, eskiler *zaten dokunulduğunda* geçer) → maliyet zaten yapılacak işin içine dağılır

Strangler modeli, "N projeyi taşımak pahalı" itirazını ortadan kaldırır. Düşük kod benzerliği de bu modelde sorun olmaktan çıkar: birleştirmiyorsun, **bundan sonrası için bir şekil seçiyorsun**.

---

## 7. Platform zaten veriyor mu

Kendi soyutlamanı yazmadan önce standardın ne verdiğine bak. Yeniden yazmanın meşru sebebi genelde **depolama**dır, davranış değil.

Ölçülmüş vaka: Operax `DapperUserStore` ile ASP.NET Core Identity'nin `IUserStore` / `IUserPasswordStore` / `IUserRoleStore` / `IUserClaimStore` arayüzlerini Dapper üzerinde uyguluyor, `AddIdentity` standart kalıyor.

Sonuç: şifre hash'leme, lockout, claim, cookie auth Microsoft'ta kalıyor; yalnız depolama sende. Elle yazılmış bir `AuthService`'ten hem daha az kod hem daha güvenli.

Soru: *"davranışı mı yeniden yazıyorum, yoksa yalnız depolamayı mı?"* Davranışsa dur.

---

## 8. En olgun uygulamadan çıkar, en tanıdıktan değil

Ölçülmüş vaka: kimlik dilimi için BkmArgus (170 satır, elle yazılmış) tanıdık olandı; Operax (`DapperUserStore` 332 satır, standarda uyumlu, yetki ekranı + denetim izi ekranı var) olgun olandı.

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

## İlişkili

- `.claude/rules/footprint-ladder.md` — en dar basamak; çatı en üst basamaktır
- `.claude/rules/evidence-discipline.md` — ölç, doğrula ya da "DOĞRULANMADI" de
- `.claude/agents/reference-researcher.md` — dış kaynağı gerçeğinden okuyan ajan
- `.claude/agents/code-architect.md` — blueprint üreten ajan
- `.claude/skills/yetenek-uret/SKILL.md` — yeni yetenek üretimi
