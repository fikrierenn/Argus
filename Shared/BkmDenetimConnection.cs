using Microsoft.Extensions.Configuration;

namespace BkmArgus.Infrastructure;

/// <summary>
/// BKMDenetim bağlantı dizesi çözümlemesi: iki kaynak (icdenetim / RiskAnaliz) birleşirken
/// appsettings'te hem "BkmDenetim" hem "BkmArgus" anahtarı kullanılabilmişti; tek API ile ikisi de desteklenir.
/// Öncelik: ortam değişkeni BKM_DENETIM_CONN, sonra ConnectionStrings:BkmDenetim, sonra ConnectionStrings:BkmArgus.
/// </summary>
public static class BkmDenetimConnection
{
    public static string Resolve(IConfiguration configuration)
    {
        var env = configuration["BKM_DENETIM_CONN"];
        if (!string.IsNullOrWhiteSpace(env))
            return env;

        var app = configuration.GetConnectionString("BkmDenetim")
            ?? configuration.GetConnectionString("BkmArgus");
        if (!string.IsNullOrWhiteSpace(app))
            return app;

        throw new InvalidOperationException(
            "BKM_DENETIM_CONN veya ConnectionStrings:BkmDenetim / BkmArgus tanimli degil.");
    }
}
