# AI Katmanı Disiplini (BkmArgus)

AiWorker, LLM sağlayıcı zinciri, skill registry ve semantik hafıza kuralları. `paths:` yok — AI bu projenin merkezi, kural compact sonrası da geçerli.

## 1. Kademeli Maliyet İlkesi (MUTLAK)

```
LM Rules (deterministik, 0 maliyet)
  → Semantic Memory (Ollama embedding, yerel, ~0 maliyet)
    → LLM (Gemini → Claude → Ollama, ücretli/yavaş)
```

**Kural:** Bir üst katmana ancak alt katman **çözemezse** çıkılır. "LLM'e sorayım kolay olsun" refleksi yasaktır — her çağrı para + gecikme + belirsizlik.

Yeni bir AI ihtiyacı doğduğunda sırayla sor:
1. Bu bir kural mı? → `LmRules` içine deterministik kural
2. Geçmişte benzeri çözüldü mü? → semantic memory eşleşmesi (cosine > 0.85)
3. Gerçekten üretken metin/muhakeme mi gerekiyor? → LLM

## 2. Sağlayıcı Zinciri

- Sıra: **Gemini → Claude → Ollama**. `AiWorkerOptions` içindeki `GeminiEnabled` / `ClaudeEnabled` / `OllamaEnabled` bayrakları.
- **Kapalı sağlayıcı sessizce atlanır**, hata fırlatmaz. Hepsi kapalıysa iş `LLM_SKIPPED` ile kapanır, exception atmaz.
- API key yoksa o sağlayıcı **kapalı sayılır** — key eksikliği runtime crash üretmemeli.
- Timeout: `LlmTimeoutSeconds` (varsayılan 300). LLM çağrısı **daima** `CancellationToken` alır.
- Model adları config'ten gelir (`GeminiModel`, `ClaudeModel`, `LlmModel`) — kod içine gömülmez.

## 3. Prompt ve Skill Disiplini

- Prompt template'leri **kod içine gömülmez** — `ai.Skills` / `SkillRegistry` üzerinden gelir (`Skills/SkillRegistry.cs`).
- Değişken enjeksiyonu `{{Degisken}}` formatı, `SkillExecutor.RenderTemplate`.
- **Skill context DB'den yüklenir** (`BuildSkillVariables`) — boş context ile LLM çağırmak halüsinasyon üretir.
- Yeni skill: önce `ai.Skills` kaydı + `SkillVersions`, sonra kod. Skill versiyonlanır; eski çıktı hangi versiyonla üretildi izlenebilir olmalı.

## 4. Çıktı Doğrulama (Soft Validation)

- LLM JSON döndürmezse **ham metin fallback** kabul edilir, iş `FAILED` olmaz — `RawJson` alanına yazılır.
- JSON parse denemesi zorunlu; başarısızsa log'a **uyarı** (hata değil) + raw sakla.
- **Halüsinasyon kapısı:** LLM'in ürettiği sayısal iddia (risk skoru, tutar, adet) doğrudan DB'ye yazılmaz. Sayısal değerler deterministik katmandan gelir; LLM sadece **anlatı/gerekçe** üretir.
- `ConfidenceScore` düşükse insight `IsActive = 0` ile kaydedilir, kullanıcıya "düşük güven" etiketiyle gösterilir.

## 5. İnsan Onayı (AI yönetilen, AI yöneten değil)

- AI **hiçbir zaman** kendi başına DÖF açmaz, denetim kapatmaz, durum değiştirmez.
- AI çıktısı = **öneri**. Kullanıcı onayı (`ai.sp_Feedback_Upsert`) ile aksiyona dönüşür.
- Onay/red geri bildirimi kaydedilir ve sonraki skill çalıştırmasında context'e girer (öğrenme döngüsü).

## 6. Job Disiplini (`Jobs/`)

- Her job `BaseAiJob` türer; `AiJobScheduler` NCrontab ile tetikler.
- Job içinde **eşik değerleri config'ten** gelir — kodda sabit sayı bırakma (örn. `RiskEsik`, `GunEsik` `AiWorkerOptions`'a taşınmalı).
- Job idempotent olmalı: aynı gün iki kez çalışırsa mükerrer insight üretmez (`ai.sp_Insight_*` upsert davranışı).
- Uzun süren job `CancellationToken` kontrol eder; kapanışta temiz durur.
- Job sonucu `ai.AgentExecutions` tablosuna yazılır — sessiz başarısızlık yasak.

## 7. Semantik Hafıza

- Model: `mxbai-embed-large` (Ollama, yerel, 1024 boyut).
- Benzerlik eşiği: **0.85** cosine. Eşiğin altındaki eşleşme "yok" sayılır.
- Vektörlenen kaynak: kapanmış DÖF kayıtları + denetim notları (`ai.sp_SemanticVector_SourceList`).
- `VectorSyncMinutes` devre dışı bırakmak için devasa değer verme — `0` veya ayrı bir `VectorSyncEnabled` bayrağı kullan.

## 8. Maliyet ve Gözlemlenebilirlik

- Her LLM çağrısı loglanır: sağlayıcı, model, token/süre, sonuç durumu.
- `/api/ai/skill/execute` yetkisi `Policies.YonetimVeUstu` — herkes LLM tetikleyemez.
- Aynı girdi için tekrar çağrı yapılmadan önce `ai.LlmResults` cache/geçmiş kontrol edilir.

## 9. Anti-pattern

| Anti-pattern | Doğrusu |
|---|---|
| Prompt string'i C# içinde | `ai.Skills` template |
| LLM'e "risk skorunu hesapla" | Skoru SQL hesaplar, LLM gerekçe yazar |
| Boş context ile skill çalıştırma | `BuildSkillVariables` DB'den doldurur |
| Sağlayıcı kapalıyken exception | Sessiz atla, sıradakine geç |
| Kodda sabit eşik (`RiskEsik = 60`) | `AiWorkerOptions` |
| AI çıktısını doğrudan DOF'a yazma | Kullanıcı onayı zorunlu |
| Model adı hardcoded | Config |

## İlişkili

- `.claude/rules/architecture.md §7` — AI katman mimarisi
- `.claude/rules/error-handling.md` — soft-fail disiplini
- `.claude/skills/bkmargus-ai-worker/SKILL.md` — uygulama rehberi
- `.claude/agents/ai-pipeline-reviewer.md` — AI hattı denetleyicisi
