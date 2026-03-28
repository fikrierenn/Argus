namespace BkmArgus.Services;

/// <summary>
/// AI servislerinin DI kayit extension metodu.
/// Program.cs icinde builder.Services.AddAiServices() olarak cagrilir.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Claude API, rapor olusturma ve risk tahmin servislerini DI konteynerine ekler.
    /// </summary>
    public static IServiceCollection AddAiServices(this IServiceCollection services)
    {
        services.AddSingleton<IClaudeApiService, ClaudeApiService>();
        services.AddScoped<IReportGeneratorService, ReportGeneratorService>();
        services.AddScoped<IRiskPredictionService, RiskPredictionService>();

        return services;
    }
}
