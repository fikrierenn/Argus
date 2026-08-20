# Danışman Skill'lere Danışma Kuralı (ZORUNLU)

BkmArgus'ta belirli iş türlerine dokunmadan **ÖNCE** ilgili **danışman (advisor) skill**'e danışılır — kod/ekran/SP yazmadan, hangi kural/pattern/eşik geçerli netleşsin diye. Danışman skill'ler **SALT-REHBER**: kendileri kod yazmaz, doğrulanacak noktaları + kaynakları verir. `paths:` yok.

## Temel İlke

> **"Kod doğru görünüyor" yetmez.** İş aşağıdaki bir alana giriyorsa üretmeden önce eşleşen skill'e danışılır; danışılmadan yazılan risk/ETL/AI/denetim işi **eksik kabul edilir**.

## Danışman Kataloğu (iş türü → skill, kod-ÖNCESİ danış)

| İş türü / tetik | Skill | Detay kuralı |
|---|---|---|
| SP yazma/değiştirme, Türkçe parametre, transaction, THROW aralığı | **`bkmargus-sp-first`** | `sql-conventions.md` |
| Yeni migration, şema değişikliği, kolon ekleme/silme, idempotency | **`sql-migration-writer`** | `sql-conventions.md §5` |
| ETL, `rpt.*` snapshot, `src.*` alias, veri kalitesi, idempotency kanıtı | **`bkmargus-etl`** | `etl-discipline.md` |
| AI katmanı: prompt, skill registry, sağlayıcı zinciri, semantik hafıza, maliyet | **`bkmargus-ai-worker`** | `ai-layer.md` |
| Risk skorlama, eşik/ağırlık, eskalasyon, DÖF tetikleme kuralı | **`bkmargus-risk-model`** | `architecture.md §1` |
| Ekran etkileşimi: form akışı, otomatik doldurma, boş durum, hata geri bildirimi | **`screen-ux-standard`** | `razor-conventions.md` |
| BKM kurumsal DB keşfi (DerinSIS*, BKMDATA, EncoreMerkez) — tablo/kolon/SP bulma | **`bkm-db-explorer`** | cross-DB kaynak |
| Kod yazarken yaygın hata önleme (yazım sırasında, son doğrulama değil) | **`code-quality-checklist`** | her kod dokunuşunda |
| Modül gerçekten çalışıyor mu — 4 katman trace, dead-end avı | **`feature-completeness-audit`** | "tamlık", "çalışıyor mu" |
| Yüksek belirsizlik + yüksek maliyet karar (mimari/yön) | **`llm-council`** | "council this", "pressure-test" |

### Modelleme kararı → AJAN (skill değil)

Denetim süreci / DÖF yaşam döngüsü / statü kümesi / SLA modelleme kararı → **`denetim-surec-danismani`** ajanı (salt-okuma domain danışmanı, opus).

Kod-uyum review → `code-reviewer` · güvenlik → `security-reviewer` · SP iş-doğruluğu → `sql-sp-reviewer` · AI hattı → `ai-pipeline-reviewer` · ETL → `etl-validator`.

## Eylem Skill'leri (danışman DEĞİL — doğrudan üretir)

Tetiklenince işi yapar: `sql-migration-writer` · `impl-spec` · `plan-tracker` · `session-handoff` · `yetenek-uret` · `bkm-sunum`.

## Kural

1. İş bir danışman alanına giriyorsa → **önce skill, sonra kod.**
2. Danışman skill yoksa ve tekrarlayan ihtiyaçsa → `yetenek-uret` ile üret (footprint-ladder).
3. Skill çıktısı rehberdir, dayatmaz — kararı sen verirsin **ama gerekçeyle**.
4. Yeni skill üretilince bu kataloğa satır ekle.

## İlişkili

- `.claude/rules/work-protocol.md` — Danış → Yap → Kontrol Ettir → Smoke (bu katalog = adım 1 + 3a kaynağı)
- `.claude/rules/coding-discipline.md §5` — domain danışmanı detayı
- `.claude/rules/agent-usage.md` — ajan seçimi ve model katmanı
- `.claude/rules/footprint-ladder.md` — yeni skill/agent en dar basamakta
