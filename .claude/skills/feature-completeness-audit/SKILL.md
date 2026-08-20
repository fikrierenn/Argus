---
name: feature-completeness-audit
description: Bir feature/modülün GERÇEKTEN çalışıp çalışmadığını belirle — statik okuma+happy-path DEĞİL, 4-katman trace (UI↔persist↔client-render↔server-render) + edge-state ÇALIŞTIRARAK doğrulama. "feature denetimi", "tamlık", "dead-end var mı", "bu modülde ne kaldı", "hepsi çalışıyor mu" tetikler. Her feature'ı TAM/KISMİ/DEAD-END sınıflar. Kod YAZMAZ (opsiyonel: bulguları TODO'ya işler).
---

# Feature Completeness Audit — Exercise-Driven

Bu skill'in varlık sebebi: 2026-07-22'de kullanıcı üst üste 5 bug'ı elle tıklayarak buldu ("çalışıyor" demiştim). Kök sebep: "derleniyor + ilk rapor default-param preview render oldu → tamam" dedim. **Statik okuma + happy-path denetim değildir.** Detay: `memory/feedback_exercise_driven_audit.md`.

## Ne zaman

Modül/feature "tamam mı, ne kaldı, hepsi çalışıyor mu" sorulduğunda. "TAM" iddiası VERMEDEN önce bu prosedürden geç.

## Prosedür

### 1. Feature yüzeyini ENUMERE et (say)
Config şeması / model / options'ı oku → tüm ayarlanabilir özellikleri LİSTELE (örn. DashboardConfig'in her alanı). "Kullanılan" değil, "tanımlı olan hepsi". Şema alanı ≠ çalışan feature.

### 2. Her özellik için 4 KATMAN trace (paralel — code-explorer agent ideal)
| Katman | Soru | Nerede |
|---|---|---|
| **UI** | Kullanıcı bunu ayarlayacak kontrol var mı? | view/partial + builder JS setter |
| **Persist** | Config'e (JSON/DB) yazılıyor mu? | syncConfig / model binding |
| **Client render** | İstemci önizleme uyguluyor mu? | client render JS |
| **Server render** | Production/gerçek çıktı uyguluyor mu? | Services/Rendering + Razor |

Her katman **file:line** ile. Consumer'da **gerçekten OKUNDUĞUNU** doğrula — sadece config'de tanımlı/serialize olması TAM demek DEĞİL (ölü JSON tuzağı).

### 3. Sınıfla
- **TAM** = 4 katman tutarlı (UI + persist + her iki render).
- **KISMİ** = bir render var diğeri yok (client↔server parite eksik) VEYA UI kısmi.
- **DEAD-END** = (a) UI yok ama render var (yetenek erişilemiyor) · (b) render var UI yok · (c) config alanı var hiçbir consumer okumuyor (tam ölü JSON) · (d) orphan fonksiyon (tanımlı, çağrılmıyor, çağrılsa şekil-uyumsuz).

### 4. EDGE-STATE çalıştır (kritik — happy-path yetmez)
Preview/DB ile GERÇEK koştur, her feature için:
- boş / 0-satır / null girdi
- named-contract vs indeks (data-variant)
- çok-değer / cross-firma
- iki render-path'i (client vs server) **byte-karşılaştır** (parite)
- yeni-vs-mevcut kullanıcı state (guard/backfill yan-etkisi)
- kendi eklediğin config/satırın etkilediği akışı user rolüyle uçtan uca

### 5. Tekrarlanan mantığı GREP + assignment↔consumer çapraz-kontrol
- Bir dönüşüm/eşleme birden çok yerde mi? `grep` TÜM call-site → formül tutarlı mı (span×3 dört-yer dersi).
- State'e yazılan değerler okunanların kabul kümesinde mi? (`x='veri'` ama consumer `x==='setup'/'style'` → stale).

### 6. Çıktı: tablo + özet
`| Özellik | UI(file:line) | Persist | Client | Server | Durum | Not |` + TAM/KISMİ/DEAD-END sayısı + "ortak kalıp". İstenirse TODO'ya actionable (file:line'lı) işle.

## Guardrails
- ❌ "Derleniyor / happy-path render oldu → TAM" — YASAK.
- ❌ Bir katmanı okuyup genelleme (span×3 dersi).
- ❌ Config'de alan var → feature var varsayımı (dead JSON).
- ✅ code-explorer agent ile 4-katman haritala (token verimli), sonra edge-state ÇALIŞTIR.
- ✅ Bu skill kod YAZMAZ — denetler. Düzeltme ayrı iş (plan + implement).

## İlişkili
- `memory/feedback_exercise_driven_audit.md` — kök sebep + prensip.
- `.claude/rules/todo-verification.md` — claim=hipotez (kardeş: TODO için o, feature için bu).
- `.claude/rules/advisor-skills.md` faz-döngüsü "KONTROL — test + PREVIEW" → preview'i edge-state ile yap.
- `.claude/agents/code-explorer.md` — 4-katman haritalama motoru.
