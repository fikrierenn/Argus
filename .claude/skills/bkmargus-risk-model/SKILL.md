---
name: bkmargus-risk-model
description: BkmArgus risk skorlama modeli danışmanı — risk flag'leri, ağırlıklandırma (ref.RiskScoreWeights), eşikler (ref.RiskParameters), skor normalizasyonu, eskalasyon ve otomatik DÖF tetikleme kuralı, yanlış pozitif/negatif dengesi, geçmişe dönük karşılaştırılabilirlik. "risk skoru", "ağırlık değiştir", "eşik", "flag ekle", "otomatik DÖF açsın", "skor yanlış", "eskalasyon kuralı" denildiğinde ve skorlama mantığına dokunmadan ÖNCE danış. SALT-REHBER — çerçeve verir, kararı sen gerekçeyle verirsin.
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
model: inherit
---

# BkmArgus Risk Modeli — Danışman

Risk skoru bu platformun **para kazandıran/kaybettiren** çıktısıdır: denetçinin nereye gideceğini, hangi DÖF'ün açılacağını belirler. Yanlış model = boşa harcanan denetçi zamanı veya kaçan risk.

Bu skill kod yazmaz. Karar vermeden önce sorulması gereken soruları ve tuzakları verir.

## Mevcut Model

| Bileşen | Yer |
|---|---|
| Flag tanımları | `ref.SemanticDefinitions` (Category = 'risk', TermType = 'flag') |
| Ağırlıklar | `ref.RiskScoreWeights` (10 satır) |
| Eşikler | `ref.RiskParameters` (7 satır) |
| Hesaplanan skor | `rpt.DailyProductRisk.RiskScore` (SQL katmanında) |
| Denetim sonucu skoru | `audit.AuditResults.RiskScore` — **PERSISTED computed** |

Bilinen flag'ler: `FlagDataQuality`, `FlagSalesWithoutEntry` (girişsiz satış), `FlagDeadStock` (ölü stok), `FlagNetAccumulation` (net birikim), `FlagHighReturn` (yüksek iade), sayım düzeltme, hızlı devir.

## 1. Yeni Flag Eklerken

| Soru | Neden |
|---|---|
| Bu flag **gözlemlenebilir bir davranışı** mı yoksa **veri hatasını** mı işaretliyor? | Veri kalitesi sorunu risk değildir; `etl.DataQualityIssues`'a gider, skoru şişirmez |
| Mevcut bir flag'in özel hali mi? | Öyleyse yeni flag değil, mevcut flag'e detay kolonu (footprint-ladder) |
| Yanlış pozitif oranı ne olur? | Tahmini ver. %50 üstü yanlış pozitif üreten flag sisteme olan güveni yıkar |
| Denetçi bunu sahada **doğrulayabilir** mi? | Doğrulanamayan sinyal DÖF'e dönüşemez, sadece gürültü |
| Ağırlığı ne, neden o? | "Hissen" değil; benzer flag'lerle kıyasla gerekçelendir |

Yeni flag = `ref.SemanticDefinitions` kaydı + `ref.RiskScoreWeights` satırı + ETL'de hesap. Üçü birlikte, yoksa flag görünür ama skora girmez (veya tersi).

## 2. Ağırlık Değiştirirken — En Sinsi Tuzak

**Ağırlık değişince geçmiş snapshot'lar yeniden hesaplanmaz.**

Sonuç: 1 Ocak'ta skoru 55 olan ürün, 1 Şubat'ta aynı davranışla 70 çıkar. Dönemler arası trend grafiği **yalan söyler** — davranış değişmedi, ölçek değişti.

Üç seçenek, üçünün de bedeli var:

| Seçenek | Bedel |
|---|---|
| Geçmişi yeniden hesapla | Pahalı; "geçmiş rapor neden değişti" sorusu |
| Ağırlık sürümünü snapshot'a yaz | Şema değişikliği; ama trend dürüst kalır |
| Hiçbiri — sadece belgele | Ucuz; kullanıcı kıyaslarken yanılır |

**Öneri:** en azından `ref.RiskScoreWeights` değişikliğine tarih damgası ve `audit.AuditLog` kaydı düş; rapor başlığında "ağırlıklar X tarihinde değişti" uyarısı göster.

## 3. Normalizasyon Sorusu

Şu anki skor **mekan büyüklüğüne göre normalize değil**.

- Büyük mağazada 60 skor normal olabilir (hacim çok, mutlak sapma büyük)
- Küçük şubede 60 anormaldir

Sorular:
- Skor mutlak mı, akran-grubuna göre yüzdelik mi olmalı?
- Akran grubu ne? (m², ciro, ürün sayısı, mekan tipi — mağaza/kafe)
- Karşılaştırma **mekanlar arası** mı yoksa **mekanın kendi geçmişine göre** mi? (İkincisi genelde daha adil ve daha az tartışma çıkarır.)

Karar verilene kadar rapor/insight çıktısına "skor mekan büyüklüğüne normalize edilmemiştir" notu düşülmeli. `sem.Metrics.risk_skoru` tuzağı bu şekilde kayıtlı.

## 4. Eşik ve Otomatik DÖF

Otomatik DÖF açma eşiği tartışılırken:

| Soru | Not |
|---|---|
| Yanlış pozitif maliyeti? | Denetçi zamanı + sisteme güven kaybı. Güven bir kez kırılırsa geri gelmez |
| Yanlış negatif maliyeti? | Kaçan risk. Ölçülebilir mi (geçmişte kaçan var mı)? |
| Eşik sabit mi, mekan/kategori bazlı mı? | Bkz. normalizasyon |
| Eşik değişince geçmiş yeniden değerlendirilecek mi? | Hayırsa **açıkça söyle** |
| İnsan onayı var mı? | BkmArgus ilkesi: otomasyon **önerir**, insan **onaylar** (`ai-layer.md`) |

**Kural:** otomatik açılan DÖF, elle açılandan **ayırt edilebilir** olmalı (kaynak alanı). Aksi halde model kalitesini ölçemezsin.

## 5. Model Kalitesini Ölçme

Skor modeli varsayım üretir; doğruluğunu ölçmeden iyileştiremezsin.

Minimum ölçüm seti:
- **İsabet:** yüksek skorlu ürünlerin kaçında saha denetimi gerçekten bulgu çıkardı?
- **Kaçak:** saha bulgusu çıkan ürünlerin kaçının ERP skoru düşüktü? (`audit.crosscheck.erp` skill'i bu soruyu soruyor)
- **Flag bazında isabet:** hangi flag işe yarıyor, hangisi gürültü?
- **Zaman içinde:** isabet artıyor mu?

Bu ölçümler yoksa ağırlık tartışması **fikir tartışmasına** döner.

## 6. Eskalasyon

- Eskalasyon bir **bildirim olayıdır**, statü değil. DÖF durumunu değiştirmemeli (`denetim-surec-danismani` ajanı bu ayrımı detaylandırır).
- SLA saati hangi statüde durur? Tanımlanmadıysa metrik güvenilmez (`sem.Metrics.dof_sla_gun` şu an `teyit bekliyor`).
- Kaç kademe, kime? Kademe sayısı arttıkça herkesin sorumlu olduğu, kimsenin sorumlu olmadığı bir yapı doğar.

## 7. Anti-pattern

| Anti-pattern | Doğrusu |
|---|---|
| Skoru LLM'e hesaplatmak | Skor SQL'de; LLM sadece **gerekçe** yazar |
| Ağırlığı kodda sabitlemek | `ref.RiskScoreWeights` |
| Eşiği job kodunda sabitlemek | `AiWorkerOptions` / `ref.RiskParameters` |
| Veri kalitesi sorununu skora katmak | `etl.DataQualityIssues` |
| Yeni flag'i skora bağlamadan eklemek | Flag + ağırlık + ETL hesabı üçü birlikte |
| Ağırlık değişimini sessizce yapmak | Tarih damgası + audit log + rapor uyarısı |
| "Skor yüksek çıktı, eşiği yükseltelim" | Önce isabeti ölç; eşik oynatmak semptomu gizler |

## Çıktı Formatı

```
## Risk Modeli Danışmanlığı — <konu>

### Netleşmesi gereken sorular
1. ...

### Önerilen çerçeve
- <öneri + gerekçe>

### Tuzaklar
- <somut senaryo: "X yaparsan Y bozulur">

### Kod yazıldıktan sonra doğrulanacaklar
- [ ] Ağırlık/eşik config'te mi?
- [ ] Geçmiş karşılaştırılabilirliği bozuluyor mu?
- [ ] Otomatik DÖF'te insan onayı var mı?

### Karar sende
<seçenekler + hangisini neden önerdiğim>
```

## İlişkili

- `.claude/rules/architecture.md §1` — iki veri kanalı
- `.claude/rules/etl-discipline.md` — skorun hesaplandığı yer
- `.claude/rules/ai-layer.md` — halüsinasyon kapısı (LLM skor üretmez)
- `.claude/agents/denetim-surec-danismani.md` — DÖF/SLA modelleme
- `sem.Metrics` — `risk_skoru` ve `dof_sla_gun` tuzakları kayıtlı
