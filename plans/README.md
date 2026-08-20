# plans/ — Tier 3 İş Planları

`.claude/rules/plan-first.md` gereği **Tier 3** işlerde plan zorunlu. Plan onaylanmadan kod yazılmaz.

## Tier eşiği kısa hatırlatma

| Tier | Ne | Plan? |
|---|---|---|
| 1 Trivial | <30 satır, 1-2 dosya | yok |
| 2 Standard | <5 dosya, mevcut pattern | TODO.md satırı |
| 3 Substantial | 3+ dosya yeni pattern, şema/güvenlik/UX/AI maliyet yüzeyi | **`plans/NN-<slug>.md`** |

BkmArgus'a özgü Tier 3 sinyalleri: `src.*` view'a veya `rpt.*` snapshot şemasına dokunma, yeni `sql/NN_*.sql`, RBAC değişikliği, yeni LLM çağrısı/skill/job.

## Akış

1. Son numarayı bul: `ls plans/[0-9]*.md | sort -V | tail -1`
2. `cp plans/feature-template.md plans/NN-<slug>.md`, doldur
3. Kullanıcı onayı — **onaysız implement yok**
4. Commit mesajında plan referansı: `feat(dof): SLA eskalasyon (plan: 01)`
5. Bitince `git mv plans/NN-*.md plans/archive/`

## Stale disiplini

14 gün dokunulmamış aktif plan: ya yeniden ısıt ya arşivle. `session-start` hook'u uyarır.
