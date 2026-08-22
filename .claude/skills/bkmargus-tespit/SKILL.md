---
name: bkmargus-tespit
description: BkmArgus veri tespit ve bulgu üretimi danışmanı — verideki tutarsızlığı/anomaliyi bulan kural yazımı, "bu bir bulgudur" iddiasının kanıtlanması, yanlış pozitif–yanlış negatif dengesi, "veri yok" ile "sorun yok" ayrımı, kanıt sayısının doğruluğu (mükerrer sayım, DISTINCT), eşik seçimi, bulgunun insana nasıl sunulacağı. "tutarsızlık bul", "anomali tespit", "veri kalitesi kontrolü", "bu bulgu mu", "AI denetçi", "otomatik bulgu üret", "tarama yaz", "kural yaz" denildiğinde ve tespit mantığına dokunmadan ÖNCE danış. SALT-REHBER — çerçeve ve doğrulanacak noktaları verir, kararı sen gerekçeyle verirsin.
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
model: inherit
---

# BkmArgus Tespit Danışmanı

Veriden **iddia** üreten her iş bu danışmanın alanıdır: tutarsızlık taraması, anomali kuralı, veri kalitesi kontrolü, otomatik bulgu üretimi, AI denetçi.

Neden ayrı bir danışman: `bkmargus-etl` veriyi **taşır**, `bkmargus-risk-model` **skorlar**, `denetim-surec-danismani` **süreci** modeller. Hiçbiri "bu veri bir bulguya işaret ediyor mu, ediyorsa nasıl kanıtlarım" sorusunu kapsamıyordu. 2026-08-22'de bu boşluktan dört hata çıktı (aşağıda).

---

## 0. Katman seçimi — LLM son çare

```
Tespit ihtiyaci
  |
  +-- Deterministik kural mi?  -> SQL / LmRules   (0 maliyet)   << once burayi dene
  +-- Gecmis benzer vaka mi?   -> semantik hafiza (yerel)
  +-- Gercekten muhakeme mi?   -> LLM             (ucretli, son care)
```

**Tutarsızlık tespiti neredeyse her zaman bir KURAL işidir.** "İki alan çelişiyor mu", "bu alan boş mu", "sayaç gerçekle uyuşuyor mu" — hepsi SQL. LLM'e sormak hem para yakar hem de deterministik olması gereken bir kararı olasılıklı hale getirir.

LLM'in tespitteki tek meşru rolü: **anlatı**. Sayıyı SQL üretir, gerekçeyi LLM yazar (`ai-layer.md §3`).

---

## 1. "Veri yok" ≠ "Sorun yok" (EN KRİTİK)

Bir alan boşsa üç ayrı ihtimal vardır ve **üçü farklı sonuç doğurur**:

| Durum | Anlamı | AI ne yapmalı |
|---|---|---|
| Alan hiç doldurulmamış | Ölçüm yapılmadı | **Sonuç ÇIKARMA.** "Değerlendirilemez" de |
| Sorgu çalıştı, gerçekten sıfır | Ölçüldü, yok | Sonuç çıkarılabilir |
| Sorgu yanlış / mekanizma bozuk | Bilmiyoruz | Önce mekanizmayı doğrula |

Üçünü aynı şekilde boş geçmek, **yokluğu kanıt saymaktır** — denetimde yapılabilecek en pahalı hata. Bir mağazada kanıt toplanmadığı için "uygunsuzluk yok" demek, denetimin zıddıdır.

Uygulama: bağlamda ayrı işaretler kullan.

```sql
DECLARE @YOK         nvarchar(100) = N'(kayit yok)';
DECLARE @TOPLANMAMIS nvarchar(200) =
    N'(veri toplanmamis — bu alan sistemde hic doldurulmamis, yoklugundan sonuc cikarma)';
```

Kontrol sorusu: *"Bu alanın boş olması, sorunun olmadığını mı gösteriyor, yoksa bakılmadığını mı?"*

---

## 2. Sayının doğruluğu, metnin doğruluğu kadar önemli

Kullanıcı bir tespite bakarken önce **sayıya** güvenir. Yanlış sayı, halüsinasyondan daha az göze batar ve daha çok güven kazanır.

Bugüne kadar çıkan sayım hataları:

```sql
-- YANLIS: ayni varlikta 3 x 5why + 2 x classify calistirmasi = 6 sayilir, oysa 1 bulgu
SELECT COUNT(*) FROM ai.SkillExecutions a JOIN ai.SkillExecutions b ON b.EntityId = a.EntityId ...

-- DOGRU: varlik bazinda tekille
SELECT COUNT(DISTINCT CAST(a.EntityType AS varchar(20)) + ':' + CAST(a.EntityId AS varchar(20))) ...
```

Kontrol listesi:
- [ ] JOIN çapraz çarpım üretiyor mu? `COUNT(*)` mı `COUNT(DISTINCT ...)` mı?
- [ ] Sayılan birim ne — **kayıt** mı, **bulgu** mu, **mekan** mı? Kullanıcıya hangisini söylüyorum?
- [ ] Alt sorgudaki `TOP` sayımı etkiliyor mu?
- [ ] Aynı kavram başka modülde farklı sayılıyor mu? (örn. "açık DÖF": burada `Status <> 'CLOSED'`, `sql/38`'de `NOT IN ('CLOSED','REJECTED')` — **iki tanım = iki gerçek**)

---

## 3. Kırılgan eşleştirme yasağı

Tespit kuralı, verinin **biçimine** değil **anlamına** bağlanmalı.

| Kırılgan | Sağlam |
|---|---|
| `LIKE '%"sistemselMi": true%'` | `JSON_VALUE(OutputJson, '$.sistemselMi') = 'true'` |
| `SourceKey LIKE '%ItemId:%'` | Formatı üreten yerle **aynı** sabitten türet |
| `Status = 'KAPANDI'` | Statü sözlüğünün tek kaynağından (`dof.StatusRules`) |
| Tarih string karşılaştırma | `CAST(... AS date)` + tip uyumu |

Kırılgan eşleşme **hata vermez, sessizce sıfır döner** — "sorun yok" gibi görünür. `audit.sp_Analysis_DofEffectiveness` tam olarak böyle çifte ölüydü: hem `'KAPANDI'` (gerçek değer `'CLOSED'`) hem yanlış `SourceKey` formatı arıyordu.

Kontrol: **kuralı yazdıktan sonra sıfır dönerse, sıfırın gerçek olduğunu kanıtla.** Ters testi çalıştır — eşleşmesi gereken bir kaydı elle bul.

---

## 4. Yanlış pozitif ve yanlış negatif dengesi

İkisi eşit maliyetli değildir ve hangisinin pahalı olduğu **bulgu türüne** göre değişir.

| Tür | Yanlış pozitif maliyeti | Yanlış negatif maliyeti | Eğilim |
|---|---|---|---|
| Veri kalitesi uyarısı | Düşük (gürültü) | Orta | Geniş tut |
| Otomatik DÖF tetikleme | **Yüksek** (boş iş, güven kaybı) | Yüksek | Dar tut, insan onayı |
| Sistemik bulgu iddiası | Orta | **Çok yüksek** (merkezi sorun görülmez) | Geniş tut, "araştır" de |

**Mevcut taramanın kör noktası:** altı sorunun tamamı *var olan kaydın eksiğine* bakıyor; **olmayan kaydı** arayan yok. "Risk skoru 6-8 arasında, birden çok denetimde tekrar etmiş, ama hiç DÖF açılmamış N madde var" — bir tespit sisteminin en değerli sorusu budur ve sorulmuyor.

Kontrol: *"Bu kural neyi kaçırır?"* sorusunu **yazmadan önce** yanıtla.

---

## 5. Yayılım ≠ kök sebebin doğası

İki bağımsız boyut; biri diğerini kısıtlamaz.

- **Yayılım:** bulgu kaç mekanda **görüldü** (`audit.systemic.classify`)
- **Kök sebebin doğası:** sebep yerel bir uygulama hatası mı, merkezi bir süreç/politika/eğitim boşluğu mu (`audit.rootcause.5why`)

Tek mekanda görülen bir bulgunun kök sebebi **merkezi olabilir**. *"Başka mekanda görülmedi"*, *"başka mekanda yok"* demek değildir; çoğu zaman *"başka mekana bakılmadı"* demektir (extent of condition).

**Tek mekan + merkezi kök sebep** en değerli erken uyarıdır. Aksiyonu diğer mekanlarda tarama açmaktır, bulguyu susturmak değil.

2026-08-22'de bu ayrım karıştırıldı ve AI'a *"yayılım TEKİL ise kök sebep sistemsel sayılmasın"* diye **yanlış bir kural öğretildi**. Sonucu: merkezi politika boşluğu tekil sayılır, mağazaya havale edilir, kök sebep durur, üç ay sonra başka mekanda çıkar — ve sistem sistemik bulguyu yapısal olarak göremez hale gelir. Geri alındı (`sql/76`).

---

## 6. Bulguyu insana sunma

**Toplu sor, tek tek değil.** 91 boş not için 91 soru işe yaramaz; bir soru sor, cevap **politika** olsun.

Her tespit şunları taşımalı:
- **Sayı** — SQL'den, LLM'den değil
- **Kanıt örneği** — ilk 5 kayıt, kullanıcı kendi gözüyle doğrulasın
- **Ne anlama geldiği** — ham gözlem değil, sonucu
- **Seçenekler** — ve seçenekler **cevabı belirler**

Son madde en çok atlanan: *şık listesini kuran, cevabı da kurmuş olur.* Yanlış şık = yanlış karar. Şıkları yazdıktan sonra sor: **"doğru cevap bu listede var mı?"** 2026-08-22'deki yanlış domain kuralı tam olarak eksik şıktan doğdu.

---

## 7. Tespit kuralı için idempotency

Tarama tekrar koştuğunda:
- Aynı tutarsızlık **yeni kayıt açmamalı** → imza (`Signature`) bazlı `MERGE`
- Cevaplanmış soru **yeniden açılmamalı**
- Eş zamanlı iki tetikleme yarışmamalı → `MERGE ... WITH (HOLDLOCK)`
- Tespit **artık bulmuyorsa** kapanış gerekçesi dürüst olmalı: *"tarama bulmuyor"* ≠ *"sorun çözüldü"*. Tespit sorgusu değişmiş de olabilir.

---

## 8. Anti-pattern

| Anti-pattern | Doğrusu |
|---|---|
| Tutarsızlığı LLM'e sordurmak | Deterministik SQL, sıfır maliyet |
| Boş alanı boş string geçmek | "veri toplanmamış" / "kayıt yok" ayrımı |
| `COUNT(*)` ile bulgu sayma | `COUNT(DISTINCT varlık)` |
| `LIKE` ile JSON alanı okuma | `JSON_VALUE` |
| Sıfır dönen kuralı doğru saymak | Ters test — eşleşmesi gereken kaydı elle bul |
| Kayıt başına soru | Toplu soru, cevap politika olur |
| Şık listesini gözden geçirmemek | "Doğru cevap listede var mı?" |
| Yalnız var olan kaydın eksiğine bakmak | Olmayan kaydı da ara (yanlış negatif) |
| Eşiği koda gömmek | `ref.RiskParameters` / config |

---

## 9. Doğrulama (tespit kuralı yazdıktan sonra)

1. Kuralı çalıştır — **kaç satır** döndü?
2. Sıfırsa: ters test ile sıfırın gerçek olduğunu kanıtla
3. Sıfır değilse: dönen kayıtlardan **birini elle** aç, gerçekten bulgu mu?
4. Sayıyı ikinci bir yoldan hesapla — tutuyor mu?
5. Kuralı iki kez çalıştır — mükerrer üretmiyor mu?
6. **"Bu kural neyi kaçırır?"** — yanıtı yazıya dök

Kanıtı **çıktıyla** raporla. Doğrulanmadıysa `DOĞRULANMADI` de (`evidence-discipline.md`).

---

## İlişkili

- `.claude/rules/evidence-discipline.md` — uydurma yasak, ölç veya işaretle
- `.claude/rules/ai-layer.md` — kademeli maliyet, halüsinasyon kapısı
- `.claude/skills/bkmargus-risk-model/SKILL.md` — skorlama (tespit değil)
- `.claude/skills/bkmargus-etl/SKILL.md` — veri taşıma (tespit değil)
- `.claude/agents/denetim-surec-danismani.md` — süreç/DÖF modelleme
- `.claude/agents/etl-validator.md` · `sql-sp-reviewer.md` — üretim sonrası denetim
