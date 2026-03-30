namespace BkmArgus.AiWorker;

public sealed class AiWorkerOptions
{
    public string ConnectionString { get; set; } = string.Empty;
    public int PollSeconds { get; set; } = 15;
    public int BatchSize { get; set; } = 20;
    public int SemanticTop { get; set; } = 500;
    public double SimilarityThreshold { get; set; } = 0.85;
    public string OllamaBaseUrl { get; set; } = "http://localhost:11434";
    public string EmbeddingModel { get; set; } = "mxbai-embed-large";
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
