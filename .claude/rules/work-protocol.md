# Çalışma Protokolü — Danış → Yap → Kontrol Ettir → Smoke

**Her substantive iş bu 4 adımlı döngüden geçer.** Kod, SP, şema, ekran, ETL, AI hattı, migration — istisnasız. `paths:` yok — compact sonrası da geçerli. Tier 1 trivial (typo/label) hariç.

> **Bu protokol artık hook'la zorlanıyor** (2026-08-22). `pre-edit-advisor-gate.sh`
> adım 1'i, `pre-commit-review-gate.sh` adım 3'ü bloklar. Sebep: protokol
> metin olarak vardı ve atlandı; atlanan denetimler sonradan koşulduğunda bir
> sır sızdırma yolu ve iki kritik SQL hatası buldu.

## 1. ÖNCE DANIŞ (üretimden ÖNCE)

İş bir danışman alanına giriyorsa, üretmeden önce eşleşen danışmana danış (`advisor-skills.md` kataloğu):

- SP / migration / şema → **`bkmargus-sp-first`** · **`sql-migration-writer`**
- ETL / `rpt.*` snapshot / veri kalitesi → **`bkmargus-etl`**
- AI katmanı: prompt, skill, sağlayıcı zinciri, maliyet → **`bkmargus-ai-worker`**
- Risk skorlama / eşik / eskalasyon → **`bkmargus-risk-model`**
- Denetim süreci / DÖF yaşam döngüsü / SLA modelleme → **`denetim-surec-danismani`** (agent)
- Veri tutarsızlığı/anomali tespiti, bulgu üretimi, AI denetçi → **`bkmargus-tespit`**
- Ekran akışı / UX / boş durum / hata geri bildirimi → **`screen-ux-standard`**
- BKM kurumsal DB keşfi (DerinSIS*, BKMDATA) → **`bkm-db-explorer`**
- Yeni mimari/yön kararı, yüksek belirsizlik → **`llm-council`** · **`code-architect`** (agent)

Danışman çıktısı = çerçeve/ölçüt (dayatmaz); kararı **gerekçeyle** sen verirsin. Danışılmadan yapılan ETL/AI/risk/denetim işi **eksik** sayılır.

## 2. YAP

Uygula — ilgili disipline uy (`coding-discipline`, `csharp-conventions`, `sql-conventions`, `razor-conventions`, `etl-discipline`, `ai-layer`, `security-principles`). Yargı kararı verdiğin her noktayı **işaretle** (adım 3'te sınanacak).

## 3. KONTROL ETTİR — bağımsız + adversarial (üretimden SONRA)

**Öz-onay YOK** (yapan ≠ onaylayan). İki katman:

**(a) Kod/SP/güvenlik review** — `phase-review-gate.md` zinciri:
`build-validator` → `code-reviewer` → `sql-sp-reviewer` (SP/şema varsa) → `security-reviewer` (yeni sayfa/endpoint varsa) → `etl-validator` (ETL varsa) → `ai-pipeline-reviewer` (AI hattı varsa). Bağımsız, salt-okuma.

**(b) DOMAIN-ADVERSARIAL geri-götür (protokolün özü):** ürettiğin işi **danışmana GERİ götür**:

> *"Yaptım. Kurala uygun mu? Verdiğim yargı kararı (eşik değeri, snapshot kapsamı, prompt context'i, yetki sınırı) doğru mu? Mükerrer kayıt / veri kaybı / sessiz başarısızlık riski var mı? Karşılıklı tutarlılık bozuldu mu?"*

- **Adversarial:** "doğru" varsayma; kırmaya çalış.
- Confidence + kanıt (dosya:satır) iste; emin değilse **DOĞRULANMADI** (`todo-verification.md`).

## 4. SMOKE TEST

"Derlendi / 0 hata" YETMEZ — **gerçekten çalışıyor mu** kanıtla (`phase-review-gate §5`):

| Dokunulan | Kanıt |
|---|---|
| SP / migration | Gerçek veriyle `EXEC` → dönen satır/değer çıktısı |
| ETL | Dar aralıkta çalıştır + **iki kez çalıştır, sonuç değişmesin** |
| Razor ekran | `preview_*` boot + HTTP 200 + etkileşim + 0 konsol hatası |
| RBAC | İki farklı rolle dene — yetkisiz 403/AccessDenied almalı |
| AI job/skill | Gerçek kayıtta çalıştır → `ai.AgentExecutions` satırını göster |

Sonucu **çıktıyla** raporla (yeşil/kırmızı). Kırmızıysa söyle, gizleme.

## Atlanırsa

1. Kabul et (mazeret yok). 2. Dön, eksik adımı tamamla. 3. "Derlendi = bitti" / "yaptım = doğru" varsayımı **YASAK**.

## İlişkili

- `.claude/rules/advisor-skills.md` — iş türü → danışman kataloğu (adım 1 + 3a kaynağı)
- `.claude/rules/phase-review-gate.md` — review + smoke zinciri
- `.claude/rules/agent-usage.md` — bağımsız reviewer seçimi + model katmanı
- `.claude/rules/todo-verification.md` — kanıt disiplini / DOĞRULANMADI
