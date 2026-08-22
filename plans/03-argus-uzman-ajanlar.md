# Plan 03 — Argus İçi Uzman Ajanlar + Kademeli Özerklik

**Durum:** onay bekliyor
**Tier:** 3 (yeni pattern + şema + AI maliyet yüzeyi + kullanıcı-görünür)
**Tarih:** 2026-08-22

---

## Problem

BkmArgus'ta AI şu an **tepkisel**: bir kayıt için elle kuyruğa atılır, skill çalışır, sonuç döner. Sürekli çalışan, kendi alanına bakan, kendiliğinden aday bulgu üreten bir katman yok.

`ai.AgentConfig` / `ai.AgentExecutions` / `ai.AgentPipelines` tabloları **tam da bunun için tasarlanmış** — `SpecialtyArea`, `ExecutionOrder`, `SystemPrompt`, `AgentType` kolonları var. Üçü de **0 satır**. Bu, bu projede tekrar eden desenin bir örneği: kuruldu, bağlanmadı, "yapıldı" sayıldı.

**Bu planın birinci kuralı:** yeni boş tablo eklemeyeceğiz. Ajan = çalışan parçaların zamanlanmış birleşimi.

---

## Engelleyici bulgu (plandan önce çözülmeli)

Altı SP, `dof.Findings`'te **hiç bulunmayan** `'KAPANDI'` statüsünü arıyor. Gerçek dağılım:

```
DRAFT 67 · IN_PROGRESS 5 · OPEN 5 · PENDING_VALIDATION 5 · CLOSED 2
```

| SP | Sessizce bozulan |
|---|---|
| `rpt.sp_DashboardOverview_Kpi` | "açık DÖF" KPI — kapalı olanlar da açık sayılıyor |
| `rpt.sp_Dashboard_Kpi` | aynı |
| `dof.sp_Dashboard_Dof_List` | DÖF liste filtresi |
| `ai.sp_SemanticVector_SourceList` | semantik hafıza kaynağı — kapanmış DÖF hiç gelmiyor (**TODO A6'nın açıklaması**) |
| `audit.sp_Analysis_DofEffectiveness` | etkinlik ölçümü — ayrıca `SourceKey LIKE '%ItemId:%'` bekliyor, gerçek format `AUDIT_2_RESULT_94` (**çifte ölü**) |

Hiçbiri hata vermiyor; hepsi sıfır dönüyor ve "sorun yok" gibi görünüyor. **Ajan 4 (Kapanış Etkinliği) bu mekanizmanın üzerine kurulacak** — önce onarılmalı.

İkinci bulgu: 84 DÖF'ün **67'si DRAFT**. "82 gecikmiş DÖF" aslında "67 DÖF kimse eline almamış". SLA saati DRAFT'ta işliyor — `sql/43`'te `SlaDueDate = CreatedAt + n gün`, DRAFT→OPEN ise insan eylemi.

---

## Kapsam

### Faz 0 — Onarım (ajanlardan ÖNCE)
- `'KAPANDI'` → `'CLOSED'` tekilleştirmesi, 5 SP
- `sp_Analysis_DofEffectiveness` SourceKey eşleştirmesi `AUDIT_{AuditId}_RESULT_{ResultId}` formatına
- **Done kriteri:** düzeltme sonrası "açık DÖF" KPI'ı ve etkinlik sayısı **DEĞİŞMELİ**. Değişmiyorsa düzeltme uygulanmamıştır.

### Faz 1 — Ajan kayıt katmanı
- `ai.AgentConfig`'e özerklik kolonları: `AutonomyLevel` (`ONERI` | `OTOMATIK`), `PromotionThreshold`, `MinSampleSize`, `EvaluationWindowDays`
- `ai.AgentExecutions`'a her koşum: bulunan/önerilen/onaylanan sayısı, süre, hata
- `ai.sp_Agent_Register` / `_List` / `_SetAutonomy`

### Faz 2 — Beş uzman ajan

| # | Ajan | Katman | Veri |
|---|---|---|---|
| 1 | Veri Kalitesi Müfettişi | deterministik SQL | mevcut `sp_Consistency_Scan` — sadece kaydedilecek |
| 2 | Sistemik Bulgu Avcısı | deterministik + LLM anlatı | 91 sonuç, `ItemText` eşleşmesi |
| 3 | ERP–Saha Çapraz Denetçisi | deterministik | 65.960 risk satırı + saha bulguları |
| 4 | Kapanış Etkinliği Denetçisi | deterministik | Faz 0'a bağımlı |
| 5 | Eşik Bekçisi (yanlış negatif) | deterministik | eşik altı tekrar eden, DÖF açılmamış |

Hepsi: sayı SQL'den, anlatı LLM'den (`ai-layer.md §3` halüsinasyon kapısı).

### Faz 3 — Kademeli özerklik
- Başlangıç: **hepsi `ONERI`** — insan onayından geçer
- Terfi: ölçülmüş isabet oranı eşiği aşarsa `OTOMATIK` önerilir; **terfiyi insan onaylar**, ajan kendini terfi ettiremez
- Geri düşme: isabet düşerse otomatik `ONERI`'ye iner
- Detay `denetim-surec-danismani` çıktısına göre kesinleşecek (eşik değeri, örneklem, pencere, hangi ajan asla otomatikleşmemeli)

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
