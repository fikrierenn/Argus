using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace BkmArgus.AiWorker.Skills;

public partial class SkillExecutor
{
    private readonly SkillRegistry _registry;
    private readonly LlmService _llm;
    private readonly ILogger<SkillExecutor> _logger;

    public SkillExecutor(SkillRegistry registry, LlmService llm, ILogger<SkillExecutor> logger)
    {
        _registry = registry;
        _llm = llm;
        _logger = logger;
    }

    public async Task<SkillResult> ExecuteAsync(
        string skillId,
        Dictionary<string, string> variables,
        CancellationToken cancellationToken = default)
    {
        // DB'deki prompt surumlerini tazele (10 dk'da bir; soft-fail — DB yoksa kod tanimlari kullanilir)
        await _registry.ReloadFromDbAsync(zorla: false, ct: cancellationToken);

        var skill = _registry.Get(skillId);
        if (skill is null)
            return SkillResult.Fail($"Skill bulunamadi: {skillId}");

        // Build prompts from templates
        var systemPrompt = RenderTemplate(skill.SystemPromptTemplate, variables);
        var userPrompt = RenderTemplate(skill.UserPromptTemplate, variables);

        var fullPrompt = $"<|system|>{systemPrompt}<|/system|>\n\n{userPrompt}";

        _logger.LogInformation("Executing skill {SkillId} with {VarCount} variables", skillId, variables.Count);

        try
        {
            var result = await _llm.GenerateAsync(fullPrompt, cancellationToken);

            if (result.Error is not null)
                return SkillResult.Fail(result.Error);

            var cikti = result.Result?.RawJson ?? result.Result?.ExecutiveSummary ?? "";

            return new SkillResult
            {
                Success = true,
                SkillId = skillId,
                SkillVersionNo = skill.VersionNo,
                Output = cikti,
                ModelName = result.Result?.ModelName ?? "unknown",
                ConfidenceScore = result.Result?.ConfidenceScore ?? GuvenSkoruOku(cikti),
                ExecutedAt = DateTime.UtcNow
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Skill execution failed: {SkillId}", skillId);
            return SkillResult.Fail(ex.Message);
        }
    }

    /// <summary>
    /// Skill ciktisindaki "guvenSkoru" alanini okur ve 0-100 olcegine cevirir.
    ///
    /// Iki ayri hata vardi: alan hic parse edilmiyordu VE olcek uyusmuyordu —
    /// model 0-1 arasi ondalik yaziyor (0.95), kolon int, yani parse edilse
    /// bile 0.95 sifira yuvarlanacakti. Olculdu: model 0.1 / 0.4 / 0.6 / 0.95
    /// gibi anlamli degerler uretiyor, DB'de hepsi 0 duruyordu.
    ///
    /// Bu deger halusinasyon kapisinin girdisi (ai-layer.md): dusuk guvenli
    /// cikti kullaniciya "dusuk guven" etiketiyle gosterilir. Hepsi 0 ise
    /// kapi anlamsizdir.
    ///
    /// Okunamazsa null doner — 0 DEGIL. Sifir "model emin degil" demek;
    /// null "olculemedi" demek. Ikisi karistirilmaz.
    /// </summary>
    private static int? GuvenSkoruOku(string cikti)
    {
        if (string.IsNullOrWhiteSpace(cikti))
        {
            return null;
        }

        var eslesme = GuvenDeseni().Match(cikti);

        if (!eslesme.Success ||
            !double.TryParse(eslesme.Groups[1].Value, NumberStyles.Float,
                             CultureInfo.InvariantCulture, out var ham))
        {
            return null;
        }

        // Model bazen 0-1, bazen 0-100 yaziyor; 1'in ustu zaten yuzdedir.
        //
        // TAM 1 BELIRSIZ: hem 1.0 (=%100) hem "100 uzerinden 1" (=%1) olabilir
        // ve degerin kendisinden ayirt edilemez. Bu prompt kumesinin urettigi
        // degerler olculdu (0.1 / 0.4 / 0.6 / 0.95 / 1) — hepsi 0-1 olceginde,
        // bu yuzden 1 = %100 kabul ediliyor. Prompt'lar olcegi acikca
        // soyleyecek sekilde revize edilirse bu heuristik kaldirilmalidir.
        var yuzde = ham <= 1.0 ? ham * 100.0 : ham;

        return (int)Math.Round(Math.Clamp(yuzde, 0, 100));
    }

    [GeneratedRegex("""\"guvenSkoru\"\s*:\s*([0-9]*\.?[0-9]+)""", RegexOptions.IgnoreCase)]
    private static partial Regex GuvenDeseni();

    /// <summary>
    /// Prompt sablonundaki {{Degisken}} yer tutucularini doldurur.
    ///
    /// Sozlukte KARSILIGI OLMAYAN yer tutucu prompt'ta ham kalirdi: model
    /// literal "{{OgrenilenBilgi}}" metnini gorurdu ve ustundeki "bunlara UY"
    /// talimatiyla birlikte anlamsiz bir blok olusurdu. Kalanlar acik bir
    /// isaretle degistiriliyor ve SAYILIYOR — hangi degiskenin hic dolmadigi
    /// boylece olculebilir, sessizce kaybolmaz.
    /// </summary>
    private string RenderTemplate(string template, Dictionary<string, string> variables)
    {
        var result = template;

        foreach (var (key, value) in variables)
        {
            result = result.Replace($"{{{{{key}}}}}", value ?? "");
        }

        var kalanlar = KalanYerTutucu().Matches(result);

        if (kalanlar.Count > 0)
        {
            _logger.LogInformation(
                "Prompt'ta {Adet} yer tutucu dolmadi: {Adlar}",
                kalanlar.Count,
                string.Join(", ", kalanlar.Select(m => m.Groups[1].Value).Distinct()));

            result = KalanYerTutucu().Replace(result, "(bu bilgi mevcut degil)");
        }

        return result;
    }

    [GeneratedRegex(@"\{\{([A-Za-z0-9_]+)\}\}")]
    private static partial Regex KalanYerTutucu();
}

public class SkillResult
{
    public bool Success { get; init; }
    public string? Error { get; init; }
    public string SkillId { get; init; } = "";
    public int SkillVersionNo { get; init; } = 1;   // hangi prompt surumuyle uretildi
    public string Output { get; init; } = "";
    public string ModelName { get; init; } = "";
    public int? ConfidenceScore { get; init; }
    public DateTime ExecutedAt { get; init; }

    public static SkillResult Fail(string error) => new() { Success = false, Error = error };
}
