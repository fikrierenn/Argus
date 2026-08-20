namespace BkmArgus.AiWorker;

/// <summary>
/// Tek bir LLM saglayicisinin yapilandirmasi. Yeni bir AI eklemek kod degil
/// yapilandirma isidir: appsettings icindeki AiWorker:LlmProviders listesine
/// bir kayit eklenir.
///
/// GLM, DeepSeek, Groq, OpenRouter, Together, Mistral, vLLM ve benzerleri ayni
/// OpenAI sohbet-tamamlama sozlesmesini konusur; hepsi Kind = "openai" ile tek
/// jenerik cagri yolunu paylasir. Gemini, Claude ve Ollama kendi sozlesmelerine
/// sahip oldugu icin ayri Kind degerleri tasir.
/// </summary>
public sealed class LlmProviderConfig
{
    /// <summary>Zincirde ve loglarda gorunen benzersiz ad (or. "glm", "deepseek").</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Konusulan protokol: openai | gemini | claude | ollama.</summary>
    public string Kind { get; set; } = LlmProviderKinds.OpenAi;

    public string BaseUrl { get; set; } = string.Empty;

    /// <summary>Kind = openai icin uc yolu. Cogu saglayicida /v1/chat/completions.</summary>
    public string Path { get; set; } = "/v1/chat/completions";

    public string ApiKey { get; set; } = string.Empty;

    public string Model { get; set; } = string.Empty;

    /// <summary>Birincil model basarisiz olursa ayni saglayicida denenecek model.</summary>
    public string? FallbackModel { get; set; }

    /// <summary>
    /// Saglayiciya ozel istek govdesi parametreleri (serbest JSON). Istek govdesine
    /// birlestirilir. Ornek: {"thinking":{"type":"disabled"}} (glm-4.7),
    /// {"reasoning_effort":"low"} (glm-5.3). Boylece yeni bir AI'in kendine has
    /// parametresi kod degisikligi gerektirmez.
    /// </summary>
    public string? ExtraBodyJson { get; set; }

    /// <summary>Bu saglayiciya ozel cikti token siniri. Bos ise global ayar kullanilir.</summary>
    public int? MaxOutputTokens { get; set; }

    /// <summary>Kapali saglayici zincirde sessizce atlanir (ai-layer.md §2).</summary>
    public bool Enabled { get; set; }

    /// <summary>Zincir sirasi — kucuk once denenir. Birincil saglayici her zaman basta.</summary>
    public int Order { get; set; } = 100;

    /// <summary>
    /// Anahtar gerektiren bir saglayici anahtarsizsa kapali sayilir.
    /// Ollama gibi yerel saglayicilar anahtar istemez.
    /// </summary>
    public bool RequiresApiKey { get; set; } = true;

    public bool IsUsable =>
        Enabled
        && !string.IsNullOrWhiteSpace(Name)
        && !string.IsNullOrWhiteSpace(Model)
        && (!RequiresApiKey || !string.IsNullOrWhiteSpace(ApiKey));
}

public static class LlmProviderKinds
{
    public const string OpenAi = "openai";
    public const string Gemini = "gemini";
    public const string Claude = "claude";
    public const string Ollama = "ollama";
}
