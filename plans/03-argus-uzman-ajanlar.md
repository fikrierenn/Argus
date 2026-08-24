# Plan 03 — Argus İçi Uzman Ajanlar + Kademeli Özerklik

**Durum:** Faz 0 ✅ tamam (2026-08-22) · Faz 1 devam
**Tier:** 3 (yeni pattern + şema + AI maliyet yüzeyi + kullanıcı-görünür)
**Tarih:** 2026-08-22

---

## Problem

BkmArgus'ta AI şu an **tepkisel**: bir kayıt için elle kuyruğa atılır, skill çalışır, sonuç döner. Sürekli çalışan, kendi alanına bakan, kendiliğinden aday bulgu üreten bir katman yok.

`ai.AgentConfig` / `ai.AgentExecutions` / `ai.AgentPipelines` tabloları **tam da bunun için tasarlanmış** — `SpecialtyArea`, `ExecutionOrder`, `SystemPrompt`, `AgentType` kolonları var. Üçü de **0 satır**. Bu, bu projede tekrar eden desenin bir örneği: kuruldu, bağlanmadı, "yapıldı" sayıldı.

**Bu planın birinci kuralı:** yeni boş tablo eklemeyeceğiz. Ajan = çalışan parçaların zamanlanmış birleşimi.

---

## Engelleyici bulgu (plandan önce çözülmeli)

Beşi gerçekten bozuk olmak üzere altı SP, `dof.Findings`'te **hiç bulunmayan** `'KAPANDI'` statüsünü arıyor. Gerçek dağılım:

```
DRAFT 67 · IN_PROGRESS 5 · OPEN 5 · PENDING_VALIDATION 5 · CLOSED 2
```

| SP | Sessizce bozulan |
|---|---|
| `rpt.sp_DashboardOverview_Kpi` | "açık DÖF" KPI — kapalı olanlar da açık sayılıyor |
| `rpt.sp_Dashboard_Kpi` | aynı |
| `dof.sp_Dashboard_Dof_List` | DÖF liste filtresi |
| `ai.sp_SemanticVector_SourceList` | **bozuk DEĞİLDİ** — `IN ('CLOSED','KAPANDI')` yazıyordu, CLOSED'u yakalıyordu. Yalnız ölü değer temizlendi. (Önce bunu A6'nın açıklaması sandım, yanlıştı.) |
| `audit.sp_Analysis_DofEffectiveness` | etkinlik ölçümü — ayrıca `SourceKey LIKE '%ItemId:%'` bekliyor, gerçek format `AUDIT_2_RESULT_94` (**çifte ölü**) |

Hiçbiri hata vermiyor; hepsi sıfır dönüyor ve "sorun yok" gibi görünüyor. **Ajan 4 (Kapanış Etkinliği) bu mekanizmanın üzerine kurulacak** — önce onarılmalı.

İkinci bulgu: 84 DÖF'ün **67'si DRAFT**. "82 gecikmiş DÖF" aslında "67 DÖF kimse eline almamış". SLA saati DRAFT'ta işliyor — `sql/43`'te `SlaDueDate = CreatedAt + n gün`, DRAFT→OPEN ise insan eylemi.

---

## Kapsam

### Faz 0 — Onarım ✅ TAMAM (`sql/77`, 2026-08-22)
- `'KAPANDI'` → `'CLOSED'` tekilleştirmesi, 5 SP
- `sp_Analysis_DofEffectiveness` SourceKey eşleştirmesi gerçek formata (`AUDIT_{AuditId}_RESULT_{ResultId}`)
- **Kanıt:** `BEKLEYEN_DOF` 84 → **82** · etkinlik SP'si eşleşen kapalı DÖF 0 → **2**
- Yöntem: gövdeler canlı tanımdan alınıp yalnız ilgili satırlar değiştirildi (gövde uzunlukları arttı, budanma yok)
- Kalan: `sql/55` semantik katmana `'KAPANDI'/'IPTAL'` içeren golden sorgu yazmış — AI'a yanlış statü öğretiyor, Faz 1'de düzeltilecek

### Faz 1 — Ölçülebilirlik ve onay mimarisi (ajanlardan ÖNCE)

Danışman bulgusu: **terfi eşiği bugün ölçülemez.** `ai.ProactiveInsights.IsActioned`
onayı ve reddi aynı bayrakta topluyor — isabetin **paydası yok**. Bu düzelmeden
hiçbir kademe kararı anlamlı değil. Bu yüzden Faz 1 artık ajan kaydıyla değil,
ölçülebilirlikle başlıyor.

1. **Onay/red ayrımı** — `ai.ProactiveInsights`'a karar boyutu: `ONAYLANDI` /
   `REDDEDILDI` / `BEKLIYOR` + gerekçe + karar veren + karar zamanı
2. **Üç dik boyut** (tek kolona sıkıştırmak yasak — kombinatoryal patlama):

   | Boyut | Ne cevaplar | Değerler |
   |---|---|---|
   | Kanal | hangi veri yolu | `ERP` / `SAHA` / `IHBAR` (mevcut `SourceSystemCode`) |
   | **Üretim yöntemi** | nasıl doğdu | `INSAN` / `KURAL` / `AI_ONERI` |
   | **Onay yolu** | hangi kapıdan geçti | `VAKA_ONAYI` / `KURAL_ONAYI` / `SESSIZ_ONAY` / `OTOMATIK` |

   Bugün otomatik açılan DÖF `CreatedByUserId=1`, adı `'Sistem'` — makine üretimi
   bir kayıt, "Sistem" adlı birinin elle açtığından **ayırt edilemiyor**.
3. **Eşik ve kural versiyonu dondurma** — bulgu anındaki eşik kayda yazılır.
   Eşik sonradan değişirse eski bulgu kendi eşiğiyle savunulur.
4. `sql/55` golden sorgusundaki yanlış statü değerleri düzeltilir

### Faz 2 — Uzman ajanlar (revize)

Danışman kapsam düzeltmeleri:
- **#1 Veri Kalitesi** hedefi DÖF **değil** — `etl.DataQualityIssues` / öğrenme
  kuyruğu. Veri kalitesi sorunu denetim bulgusu değil sistem arızasıdır; DÖF'e
  çevirmek havuzu kirletir ve "açık DÖF" metriğini anlamsızlaştırır
- **#4 ve #5 birleşiyor** → tek "Tekrar Zinciri Denetçisi", iki çıktı dalı
  (DÖF açılmış-kapanmış-tekrarladı / hiç DÖF açılmamış-tekrarlıyor)
- **#4 yeni DÖF açmaz** — eskinin `IsEffective` alanını işaretler, yeniden açılmayı
  önerir. Yeni DÖF tekrar zincirini koparır, kök sebep izini kaybettirir
- **#2 sistemik** mevcut `sp_Analysis_DetectSystemic` ile çakışıyor — ajan tespiti
  değil tespitin **yorumunu** üretir
- **YENİ #6 Kapsam/Örtüşme Denetçisi** — en büyük boşluk buydu: hangi mekan/kontrol
  maddesi ne zamandır hiç denetlenmedi. #3 yalnız ERP sinyali *olan* yere bakıyor;
  sinyali de olmayan denetlenmemiş yer tamamen kör
- **YENİ #7 Kapanış Kalitesi Denetçisi** — kapanış anındaki kanıt yeterliliği.
  Altı ay tekrar beklemeye gerek yok, kanıt bugün belli. Otomatikleşmeye **en uygun
  aday budur**, listedeki beşi değil

### Faz 3 — Kademeli özerklik (revize)

**Otonomi ekseni isabet oranı DEĞİL, kararın türü.** Onay vakadan kurala taşınır:
isimli yönetici, versiyonlu ve **sona erme tarihli** olarak "şu koşulda DÖF açılır"
kuralını önceden onaylar. İsabet oranı bir ön koşul, terfi sebebi değil.

Neden isabet oranı tek başına yetmez:
- Onaylayan ajanın önerisini görerek karar veriyor → çıpalama; oran zamanla
  ajanın iyileştiğini değil onaylayanın yorulduğunu ölçer
- **Yanlış negatif hiç ölçülmüyor** — ajanın hiç bahsetmediği vaka metriğe girmez,
  yani dar kapsam ödüllendirilir
- Aynı kök sebepten doğan 40 bulgu 40 kanıt değildir (kümelenme)

Ölçüm mekanizmaları:
- **Kör doğrulama örneklemi** — bulguların bir kısmı, ajanın önerisi gizlenerek
  bağımsız denetçiye verilir; **yalnız bu alt küme terfi ölçütüdür**. Çıpalamayı
  kıran tek mekanizma
- **Yanlış negatif tahmini** — ajanın "temiz" dediklerinden rastgele örnek, elle inceleme
- **`REJECTED` oranı** — reddi başka kişi, sonradan, gerçek maliyet görülünce verir
- Eşik nokta tahmini değil **tek taraflı alt güven sınırı** üzerinden → küçük
  örneklemi kendiliğinden cezalandırır

Kademe merdiveni:

| # | Kademe | Ne olur |
|---|---|---|
| 0 | **Gölge** | Üretir, kimse görmez, sadece ölçülür. En çok atlanan basamak |
| 1 | Öneri | İnsan tek tek onaylar |
| 2 | Toplu onay | Verim artar, dikkat düşer → kör örneklem burada zorunlu |
| 3 | **Sessiz onay** | `DRAFT` açar, X iş günü itiraz gelmezse `OPEN`. **TAVAN BU** |
| 4 | Otomatik | Doğrudan `OPEN`. Şimdilik hiçbir ajan aday değil |

**Terfi ajana değil `ai.SkillVersions` sürümüne bağlanır** — prompt değişince
otonomi sıfırlanır. Kayan pencere, kümülatif değil. Geri düşme asimetrik:
tek ağır yanlış (yanlış isnat, dışarı gitmiş rapor) oranı ne olursa olsun sıfırlar.
Otonominin **sona erme tarihi** vardır, sessiz yenileme yok.

**Asla otomatikleşmeyecekler:** kök sebep/kasıt/ihmal ima eden · personel
performansına dokunan · suistimal şüphesi · sistemik nitelendirme · kanıtı
*yokluk* üzerine kurulu · eşiğin kendisini tartışan bulgular.

Beş ajandan **hiçbiri** bugün otomatik DÖF açmaya uygun değil.

### Faz 3.5 — Hile sinyali ayrımı (yeni)

ERP–saha uyuşmazlığı klasik hile göstergesidir. Normal DÖF akışına düşerse
**şüpheliye haber verilmiş olur**. Hile şüphesi tetiklendiğinde akış ayrılmalı,
görünürlük kısıtlanmalı.

### Faz 4 — Ekran
- Ajan panosu: her ajanın alanı, son koşum, ürettiği/onaylanan sayısı, isabet oranı, özerklik seviyesi
- Aday bulgular öğrenme ekranındaki insan kapısından geçer

---

## Kapsam dışı

- Yeni LLM sağlayıcı
- `AiJobScheduler`'ı diriltmek (Program.cs'e kayıtlı değil — ayrı iş; ajanlar mevcut worker döngüsüne bağlanacak)
- Gerçek zamanlı tetikleme (periyodik yeterli)

---

## Alternatifler (reddedilen)

**A. Her ajan ayrı BackgroundService.** Reddedildi: 5 yeni servis, 5 ayrı yaşam döngüsü, 5 ayrı hata yolu. Mevcut worker döngüsü zaten periyodik iş çalıştırıyor (`ScanConsistencyIfNeededAsync`, `SyncVectorsIfNeededAsync`) — genişletmek footprint-ladder 1. basamak.

**B. Ajanları LLM ajanı yapmak (her biri kendi LLM döngüsü).** Reddedildi: tespit deterministik bir iştir (`bkmargus-tespit`). LLM ajanı hem pahalı hem de tespit kararını olasılıklı yapar. LLM yalnız anlatı yazar.

**C. Özerkliği baştan vermek.** Reddedildi: yanlış pozitif doğrudan boş iş ve güven kaybı üretir. Özerklik ölçülmüş isabetle hak edilir.

---

## Riskler

| Risk | Etki | Azaltma |
|---|---|---|
| Beşinci boş tablo seti | Yüksek | Faz 1 bitmeden Faz 2'ye geçilmez; her ajan uçtan uca kanıtlanır |
| Ajan gürültüsü (çok aday bulgu) | Orta | Toplu soru ilkesi; eşik `ref.RiskParameters`'ta |
| Ajanlar çelişir (bugün 5why vs classify yaşandı) | Orta | Çelişki bir tespit türü — Veri Kalitesi Müfettişi'nin kapsamında |
| Kolay bulgularla isabet biriktirip zor alanda otomatikleşme | Yüksek | Terfi ölçütü alan bazlı; danışman çıktısına göre kesinleşecek |
| LLM maliyeti | Orta | Yalnız anlatı; deterministik katman ücretsiz |
| Yanlış mağazaya isnat | **Yüksek** | Korelasyon `LocationName LIKE '%MekanAd%'` bulanık (`sql/40:67`); otomatik DÖF öncesi kesin eşleştirme şart |
| Hile şüphelisine ihbar | **Yüksek** | Faz 3.5 — ayrı akış, kısıtlı görünürlük |
| DÖF havuzunun boğulması | Yüksek | Kaynak ayrımı boyutu **önceden** eklenir, yoksa geçmişe dönük ayrıştırma imkânsız |
| Terfi kaçağı (prompt değişti, otonomi kaldı) | Yüksek | Terfi `SkillVersions` sürümüne bağlı |

---

## Done kriterleri

- [ ] Faz 0: 5 SP onarıldı, KPI **değişti** (kanıt: önce/sonra sayı)
- [ ] `ai.AgentConfig` 5 satır, `ai.AgentExecutions` her koşumda yazıyor
- [ ] Her ajan gerçek veriyle en az bir aday bulgu üretti (çıktıyla)
- [ ] Aday bulgu insan onayından geçip DÖF'e dönüştü (uçtan uca)
- [ ] Özerklik seviyesi ekrandan görülüyor ve değiştirilebiliyor
- [ ] `sql-sp-reviewer` + `security-reviewer` + `ai-pipeline-reviewer` temiz
- [ ] Fresh-DB migrate testi (`phase-review-gate §3.5`) — bu oturumda hiç koşulmadı

---

## Rollback

- Ajanlar `IsActive=0` ile susturulur (şema kalır)
- Faz 0 onarımı geri alınmaz — o bir hata düzeltmesidir, ajanlardan bağımsız değerlidir

---

## 5 Lens

- 🔴 **Contrarian:** Fatal kusur, ajanların yine bağlanmaması. Bu yüzden Faz 1 bitmeden Faz 2 yok ve her ajanın done kriteri "gerçek veriyle çıktı üretti".
- 🔵 **First Principles:** Asıl soru "AI ajanı ekleyelim mi" değil, "denetçinin kaçırdığı neyi sürekli izlemeliyiz". Beş ajan bu sorudan türedi, teknolojiden değil.
- 🟢 **Expansionist:** Terfi mekanizması kurulunca, ajan performansı denetim programının kendisine girdi olur — hangi alan sürekli bulgu üretiyor, denetim sıklığı oraya kayar.
- ⚪ **Outsider:** Yabancı biri "84 DÖF'ün 67'si taslakta bekliyorsa, yeni bulgu üretmenin ne anlamı var?" derdi. Haklı — Faz 0 bunu görünür kılıyor.
- 🟡 **Executor:** Pazartesi sabahı: `'KAPANDI'` → `'CLOSED'` migration'ı ve önce/sonra KPI karşılaştırması.

---

## İlişkili

- `.claude/skills/bkmargus-tespit/SKILL.md` — tespit kuralı disiplini
- `.claude/rules/ai-layer.md` — kademeli maliyet, insan onayı, halüsinasyon kapısı
- `.claude/agents/denetim-surec-danismani.md` — özerklik yönetişimi (danışıldı)
- `sql/70-76` — öğrenme döngüsü (insan kapısı buradan geliyor)
