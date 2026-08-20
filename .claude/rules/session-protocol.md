# Oturum Protokolü (BkmArgus)

Her oturumun başı, ortası ve sonu ritüelleri. `paths:` yok.

---

## 1. Oturum Başlangıcı (ilk yanıttan ÖNCE, sessizce)

0. **SessionStart hook'unu KOŞULSUZ çalıştır:** `bash .claude/hooks/session-start.sh` — bağlamda hook çıktısı görünse **bile** tekrar çalıştır. "Gördüm, atlarım" varsayımı yasak: bağlam stale olabilir.
1. **Son 2 journal:** `docs/journal/YYYY-MM-DD.md` — dün ne bitti, ne yarım kaldı, hangi hata notu var.
2. **TODO + plan:** `TODO.md` ve `plans/` altındaki aktif maddeler.
3. **Commit durumu:** `git status --porcelain | wc -l`. **15 dosya eşiği** aşıldıysa yeni işe başlamadan commit-split (`commit-discipline.md`).
4. **Auto-memory:** `C:\Users\fikri.eren\.claude\projects\D--Dev-BkmArgus\memory\MEMORY.md` — proje durumu ve geri bildirimler.

---

## 2. Oturum Ortası Disiplini

1. **3 paralel iş sınırı.** Aynı anda en fazla 3 açık dal/görev; biri bitmeden dördüncüye geçilmez.
2. **Kural konuşmada kalmaz.** Oturumda alınan yeni karar/kural anında `.claude/rules/` altındaki ilgili dosyaya yazılır. Konuşma geçmişi hafıza değildir.
3. **Yeni öğrenilen proje gerçeği memory'ye yazılır** (`memory/` dizini) — kod yapısından türetilemeyen bilgiler için.
4. **Spec → Plan → Execute:** 3+ dosyayı etkileyen iş için önce kapsam, sonra `plans/NN-<slug>.md`, sonra kod (`plan-first.md`).
5. **Danış → Yap → Kontrol Ettir → Smoke** döngüsü her substantive işte (`work-protocol.md`).

---

## 3. Oturum Sonu (Handoff)

Kullanıcı "kapatabiliriz", "iyi geceler", "/handoff", "devam edeceğiz" derse:

1. **Journal yaz:** `docs/journal/YYYY-MM-DD.md`
   - Ana konu
   - Tamamlananlar (dosya:satır referanslı)
   - Build durumu (`dotnet build` çıktısı — hata/uyarı sayısı)
   - Commit'ler + uncommitted dosya listesi
   - Yarım kalan işler ve nerede kalındığı
   - Yarına 1-3 somut başlangıç adımı
2. **TODO/plan güncelle:** kapanan maddeler `[x] ✅ <tarih> (commit <hash>)`.
3. **Memory güncelle:** proje durumu değiştiyse `memory/project_current_state.md`.
4. **CLAUDE.md korunumu:** CLAUDE.md'ye oturum notu/tarihli günlük **yazılmaz**. CLAUDE.md sadece statik kimlik + kural fihristidir.

---

## 4. Bilgi Katmanları (aynı bilgi tek yerde)

| Katman | Nerede | Ne |
|---|---|---|
| Kimlik | `CLAUDE.md` | Proje tanımı, stack, kural indeksi, hızlı referans |
| Kurallar | `.claude/rules/*.md` | Davranış, kodlama, SQL, UI, AI kuralları |
| Süreç | `TODO.md`, `plans/`, `docs/journal/` | Plan, açık iş, günlük |
| Kalıcı hafıza | `memory/*.md` | Oturumlar arası proje gerçeği, kullanıcı tercihi |

Aynı bilgi iki dosyada yaşayamaz.

## İlişkili

- `.claude/rules/session-memory.md` — compact/clear disiplini
- `.claude/rules/commit-discipline.md` — 15 dosya eşiği
- `.claude/rules/work-protocol.md` — 4 adımlı iş döngüsü
- `.claude/skills/session-handoff/SKILL.md` — handoff üretici
