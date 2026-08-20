---
name: bkmargus-ai-worker
description: BkmArgus AI katmanı uygulama rehberi — kademeli maliyet (LM Rules → Semantic Memory → LLM), sağlayıcı zinciri (Gemini/Claude/Ollama) ve soft-fail, SkillRegistry/SkillExecutor ile prompt yönetimi, context yükleme, halüsinasyon kapısı, insan onayı, job yazımı (BaseAiJob + AiJobScheduler), semantik hafıza. "AI ekle", "LLM çağır", "yeni skill", "prompt", "insight üret", "AI job", "embedding", "Ollama/Gemini/Claude" denildiğinde ve AiWorker kodu yazmadan ÖNCE danış.
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
user-invocable: true
model: inherit
---

# BkmArgus AI Katmanı — Uygulama Rehberi

Kural kaynağı: `.claude/rules/ai-layer.md`. Bu skill nasıl yazılacağını gösterir.

## Adım 0 — Katman Seçimi (kod yazmadan önce)

```
Yeni AI ihtiyaci
  |
  +-- Deterministik kural mi?          -> LmRules.cs  (0 maliyet)      << once burayi dene
  +-- Gecmiste benzeri cozuldu mu?     -> SemanticMemoryService (yerel)
  +-- Gercekten uretken metin/muhakeme -> LlmService (ucretli)         << son care
```

"LLM'e sorayım kolay olsun" **yasak**. Her LLM çağrısı = para + gecikme + belirsizlik.

## 1. Yeni Skill Ekleme

Skill = prompt template + değişken sözleşmesi. **Kodda string olarak yazılmaz.**

```sql
-- sql/NN_yeni_skill.sql
IF NOT EXISTS (SELECT 1 FROM audit.Skills WHERE SkillId = 'risk.explain')
INSERT INTO audit.Skills (SkillId, Name, SystemPromptTemplate, UserPromptTemplate, IsActive, CreatedAt)
VALUES ('risk.explain', N'Risk Gerekcesi',
  N'Sen bir ic denetim analistisin. Turkce, kisa, kanit-temelli yaz. Sayi UYDURMA — sadece verilen verideki sayilari kullan.',
  N'Mekan: {{MekanAdi}}
Urun: {{UrunAdi}}
Risk skoru: {{RiskSkoru}}
Tetiklenen sinyaller: {{Sinyaller}}

Bu urunun neden denetim gerektirdigini 3 maddede acikla.',
  1, SYSDATETIME());
```

Sonra `SkillRegistry` üzerinden çağrılır:

```csharp
var vars = await BuildSkillVariablesAsync(entityType, entityId, ct);   // DB'den doldur
var result = await _executor.ExecuteAsync("risk.explain", vars, ct);
```

**Kritik:** `BuildSkillVariables` **boş sözlük dönerse** LLM bağlamsız üretir → halüsinasyon. Context yüklemesi yoksa skill çalıştırma.

## 2. LLM Çağrısı — Soft-Fail Zinciri

```csharp
var result = await _llm.GenerateAsync(prompt, ct);

if (result.Error is not null)
{
    // Saglayici hatasi ISI DURDURMAZ — logla, sonucu FAILED degil SKIPPED isaretle
    _logger.LogWarning("LLM cagrisi basarisiz: {Error}", result.Error);
    return SkillResult.Fail(result.Error);
}
```

Sağlayıcı davranışı:
- `GeminiEnabled = false` → **sessizce atla**, sıradakine geç. Exception atma.
- API key boş → o sağlayıcı **kapalı sayılır**. Runtime crash **yasak**.
- Hepsi kapalı → iş `LLM_SKIPPED` ile kapanır, kuyruk tıkanmaz.
- Model adı config'ten (`GeminiModel`, `ClaudeModel`, `LlmModel`) — **hardcode etme**.

## 3. Halüsinasyon Kapısı (MUTLAK)

**LLM'in ürettiği sayısal değer DB'ye yazılmaz.**

| Değer | Kaynak |
|---|---|
| Risk skoru, tutar, adet, yüzde, tarih | **SQL / deterministik hesap** |
| Gerekçe metni, özet, öneri, başlık | LLM |

```csharp
// DOGRU: skor SQL'den, anlati LLM'den
var insight = new InsightRow
{
    RiskScore   = row.RiskScore,                    // SP'den geldi
    Explanation = llm.Result?.ExecutiveSummary ?? "",   // LLM yazdi
    Confidence  = llm.Result?.ConfidenceScore ?? 0
};
```

JSON parse başarısız olursa: **soft-fail** — ham metni sakla, uyarı logla, işi başarısız sayma.

## 4. İnsan Onayı (AI önerir, insan karar verir)

AI **hiçbir zaman** kendi başına DÖF açmaz, denetim kapatmaz, durum değiştirmez.

```
AI cikti -> ai.Insights (IsActive=1, onaysiz)
         -> kullanici UI'da gorur
         -> Onayla/Reddet -> ai.sp_Feedback_Upsert
         -> onaylandiysa DOF/aksiyon acilir
```

Geri bildirim sonraki çalıştırmada context'e girer (öğrenme döngüsü).

## 5. Job Yazımı

```csharp
public sealed class YeniJob(Db db, SkillExecutor executor, IOptions<AiWorkerOptions> opt,
                            ILogger<YeniJob> log) : BaseAiJob(db, log)
{
    public override string JobName => "yeni-job";

    protected override async Task<JobResult> RunAsync(CancellationToken ct)
    {
        // Esik degeri CONFIG'ten — kodda sabit sayi YASAK
        var esik = opt.Value.RiskEsik;

        var rows = await Db.QueryAsync<Row>("ai.sp_YeniJob_Kaynak", new { RiskEsik = esik }, ct);

        foreach (var r in rows)
        {
            ct.ThrowIfCancellationRequested();
            // ... skill calistir, sonucu UPSERT ile yaz (idempotency)
        }

        return JobResult.Ok($"{rows.Count} kayit islendi");
    }
}
```

**Job kuralları:**
- `BaseAiJob` türet, `AiJobScheduler`'a kaydet (NCrontab ifadesi config'te)
- **Idempotent:** aynı gün iki kez çalışırsa mükerrer insight üretmemeli → SP tarafında UPSERT
- Eşikler `AiWorkerOptions`'ta — kodda sabit sayı yok
- `CancellationToken` kontrol et
- Sonuç `ai.AgentExecutions`'a yazılır — **sessiz başarısızlık yasak**

## 6. Semantik Hafıza

```csharp
var similar = await _memory.FindSimilarAsync(text, threshold: 0.85, top: 5, ct);
if (similar.Count > 0)
{
    // Gecmis cozum bulundu -> LLM'e gerek yok veya context olarak ver
}
```

- Model: `mxbai-embed-large` (1024 boyut, Ollama yerel)
- Eşik **0.85** — altındaki eşleşme "yok" sayılır
- Sync'i kapatmak için `VectorSyncMinutes = 99999` gibi hack **kullanma** — açık bir bayrak ekle

## 7. Maliyet Gözlemlenebilirliği

Her LLM çağrısı loglanır: sağlayıcı, model, süre, sonuç durumu. `/api/ai/skill/execute` yetkisi `Policies.YonetimVeUstu` — herkes LLM tetikleyemez.

## 8. Kontrol Listesi

- [ ] LM Rules / semantic memory katmanı denendi mi (LLM son çare)
- [ ] Prompt `audit.Skills` tablosunda, kodda değil
- [ ] `BuildSkillVariables` DB'den gerçek context yüklüyor
- [ ] Sağlayıcı kapalıysa sessiz atlama, exception yok
- [ ] Model adı ve eşikler config'te
- [ ] LLM sayısal değer üretip DB'ye yazmıyor
- [ ] JSON parse hatası soft-fail
- [ ] İnsan onayı kapısı var
- [ ] Job idempotent, `CancellationToken` alıyor, `ai.AgentExecutions`'a yazıyor
- [ ] Yetki: maliyetli endpoint `YonetimVeUstu`

Yazdıktan sonra: **`ai-pipeline-reviewer` ajanını çağır** (`work-protocol.md` adım 3).

## İlişkili

- `.claude/rules/ai-layer.md` — tam kural
- `.claude/agents/ai-pipeline-reviewer.md` — denetleyici
- `.claude/rules/architecture.md §7` — katman mimarisi
