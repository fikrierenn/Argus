namespace BkmArgus.AiWorker;

public sealed class AiWorkerOptions
{
    public string ConnectionString { get; set; } = string.Empty;
    public int PollSeconds { get; set; } = 15;

    // Gunluk risk ETL'i sonrasi otomatik AI kuyruklama. Esik kodda sabit
    // birakilmaz (ai-layer.md §6) — maliyeti dogrudan bu deger belirler.
    // Yerel embedding modeli. Ollama'ya bagimlilik kalkti: model surec icinde
    // ONNX ile calisir, boylece metin makineden cikmaz (KVKK) ve 16 GB'lik bir
    // makinede ayri servis ayakta tutmak gerekmez.
    public string EmbeddingModelPath { get; set; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                     "BkmArgus", "models", "multilingual-e5-base");
    public int  EmbeddingMaxTokens { get; set; } = 512;
    public int  VectorSyncBatchSize { get; set; } = 200;

    // Cross-encoder yeniden siralama. Olcumde HitRate@1 0,800 -> 0,967 ama
    // aday basina ~130 ms. Bu yuzden varsayilan KAPALI; LLM'e kanit hazirlanan
    // yolda acilir, her aramada degil (ai-layer.md kademeli maliyet).
    // Tutarsizlik taramasi: deterministik, LLM'siz, sifir maliyet.
    // Sik kosmasinin zarari yok ama soru kumesi gunde birkac kez degisir.
    public bool ConsistencyScanEnabled { get; set; } = true;
    public int  ConsistencyScanMinutes { get; set; } = 360;

    // Semantik baglam: sem.* katmanindan skill prompt'una tasinan sema bilgisi.
    // Ust sinir prompt butcesini korur — baglam buyudukce asil veriye yer kalmaz.
    public int SemanticContextTopPerSection { get; set; } = 8;
    public int SemanticContextMaxChars { get; set; } = 6000;

    public bool   RerankerEnabled { get; set; }
    public string RerankerModel { get; set; } = "seroe/mmarco-mMiniLMv2-L12-turkish";
    public string RerankerModelPath { get; set; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                     "BkmArgus", "models", "turkish-reranker");
    // XLM-R tabanli modellerde "xlmr", BERT tabanlilarda "bert".
    // Yanlis deger hata vermez, sessizce bozuk skor uretir.
    public string RerankerTokenStyle { get; set; } = "xlmr";
    public int    RerankerTopN { get; set; } = 10;
    public int    RerankerMaxTokens { get; set; } = 512;
    public bool SemanticMemoryEnabled { get; set; } = true;

    public bool PostRiskEtlTriggerEnabled { get; set; } = true;
    public int  PostRiskEtlRiskEsik { get; set; } = 85;
    public int BatchSize { get; set; } = 20;
    public int SemanticTop { get; set; } = 500;
    // MUTLAK esik artik kabul karari vermez — bkz. SemanticMemoryService.
    // Geriye uyumluluk icin duruyor; yeni kod SimilarityFloor + SimilarityMargin kullanir.
    public double SimilarityThreshold { get; set; } = 0.85;

    // Taban: bunun altindaki benzerlik "eslesme yok" sayilir.
    // Bu korpusta kosinus 0,75-0,90 arasinda sikisiyor (olculdu: ciftler arasi
    // ortalama 0,8803); 0,85 gibi bir taban neredeyse her seyi reddederdi.
    public double SimilarityFloor { get; set; } = 0.80;

    // Marj: en iyi eslesme ikinciyi bu kadar gecmezse karar verilmez.
    // Olcumde yanlis sonuc getirilen bir vakada aradaki fark 0,0003'tu —
    // marj kurali orada "emin degilim" diyerek dogru davranir.
    public double SimilarityMargin { get; set; } = 0.02;

    // RRF sabiti. 30 sorgulu olcumde k=10 ve k=15 esit (HitRate@1 0,767),
    // k=60 biraz onde (0,800) — ama reranker devredeyken fark kayboluyor
    // (0,967). Korpus buyudukce yeniden olculmeli.
    public int RrfK { get; set; } = 60;

    // Arsiv bellek onbellegi. 189 kayit x 768 boyut = 581 KB.
    public int CorpusCacheMinutes { get; set; } = 10;
    public string OllamaBaseUrl { get; set; } = "http://localhost:11434";
    public string EmbeddingModel { get; set; } = "multilingual-e5-base";
    public int EmbeddingTimeoutSeconds { get; set; } = 30;
    public string LlmProvider { get; set; } = "ollama";
    public string LlmModel { get; set; } = "mistral:7b-instruct-v0.3-q4_1";
    public string? LlmModelLowRam { get; set; } = "gemma2:9b-instruct-q4_1";
    public int LlmTimeoutSeconds { get; set; } = 120;
    public string GeminiBaseUrl { get; set; } = "https://generativelanguage.googleapis.com";
    public string GeminiApiKey { get; set; } = string.Empty;
    public string GeminiModel { get; set; } = "gemini-2.0-flash";
    public string? GeminiModelFallback { get; set; } = "gemini-3.0-flash";
    public string ClaudeBaseUrl { get; set; } = "https://api.anthropic.com";
    public string ClaudeApiKey { get; set; } = string.Empty;
    public string ClaudeModel { get; set; } = "claude-sonnet-4-20250514";
    public string? ClaudeModelFallback { get; set; }
    public bool LlmEnabled { get; set; } = true;
    public bool GeminiEnabled { get; set; } = true;
    public bool ClaudeEnabled { get; set; } = false;

    // GLM (Z.AI) — OpenAI uyumlu sohbet tamamlama ucu.
    // Anahtar appsettings.Local.json veya GLM_API_KEY ortam degiskeninden gelir;
    // takipli appsettings.json'a asla yazilmaz (security-principles.md §5).
    public string  GlmBaseUrl { get; set; } = "https://api.z.ai";
    public string  GlmApiKey { get; set; } = string.Empty;
    public string  GlmModel { get; set; } = "glm-4.6";
    public string? GlmModelFallback { get; set; }
    public bool    GlmEnabled { get; set; } = false;
    public bool OllamaEnabled { get; set; } = false;
    public bool DocsEnabled { get; set; } = true;
    public string DocsPath { get; set; } = "docs";
    public int DocsMaxChars { get; set; } = 4000;
    public int DocsSnippetChars { get; set; } = 500;
    public int VectorSyncMinutes { get; set; } = 60;
    
    // Yeni eklenen LLM parametreleri
    public double Temperature { get; set; } = 0.1;
    public double TopP { get; set; } = 0.9;
    public double RepeatPenalty { get; set; } = 1.1;
    public int MaxTokens { get; set; } = 2048;
    public int Seed { get; set; } = 42;
    public string[]? StopTokens { get; set; } = new[] { "}", "<|end|>" };
}
