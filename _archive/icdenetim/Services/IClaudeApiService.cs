namespace BkmArgus.Services;

/// <summary>
/// Claude API ile iletisim arayuzu.
/// Sistem prompt + kullanici mesaji gonderir, yanit alir.
/// </summary>
public interface IClaudeApiService
{
    Task<string> AnalyzeAsync(string systemPrompt, string userMessage);
    Task<string> AnalyzeWithVisionAsync(string systemPrompt, string userMessage, byte[] imageData);
    Task<Stream> StreamAnalyzeAsync(string systemPrompt, string userMessage);
    bool IsConfigured { get; }
}
