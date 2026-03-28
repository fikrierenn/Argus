using System.Text.Json;

namespace BkmArgus.AiWorker;

public sealed class LmRules
{
    public LmDecision Decide(RiskOzetRow risk)
    {
        var root = ResolveRootCause(risk);
        var plan = ResolveEvidencePlan(risk);
        var llm = risk.RiskSkor >= 90 || risk.FlagVeriKalite || risk.FlagSayimDuzeltmeYuk;

        var features = new
        {
            risk.RiskSkor,
            risk.FlagVeriKalite,
            risk.FlagGirissizSatis,
            risk.FlagOluStok,
            risk.FlagNetBirikim,
            risk.FlagIadeYuksek,
            risk.FlagBozukIadeYuksek,
            risk.FlagSayimDuzeltmeYuk,
            risk.FlagSirketIciYuksek,
            risk.FlagHizliDevir,
            risk.FlagSatisYaslanma
        };

        return new LmDecision
        {
            RootCauseClass = root,
            EvidencePlan = plan,
            LlmGerekliMi = llm,
            OncelikPuan = Math.Clamp(risk.RiskSkor, 0, 100),
            KisaOzet = risk.RiskYorum,
            OzellikJson = JsonSerializer.Serialize(features)
        };
    }

    private static string ResolveRootCause(RiskOzetRow risk)
    {
        if (risk.FlagVeriKalite) return "VERI_KALITE";
        if (risk.FlagGirissizSatis) return "GIRISSIZ_SATIS";
        if (risk.FlagSayimDuzeltmeYuk) return "SAYIM_DUZELTME";
        if (risk.FlagIadeYuksek) return "IADE_SICRAMA";
        if (risk.FlagHizliDevir) return "HIZLI_DEVIR";
        if (risk.FlagSatisYaslanma) return "SATIS_YASLANMA";
        if (risk.FlagOluStok) return "OLU_STOK";
        if (risk.FlagNetBirikim) return "NET_BIRIKIM";
        return "DIGER";
    }

    private static string ResolveEvidencePlan(RiskOzetRow risk)
    {
        if (risk.RiskSkor >= 90)
        {
            return "FULL";
        }

        if (risk.FlagVeriKalite || risk.FlagGirissizSatis || risk.FlagSayimDuzeltmeYuk)
        {
            return "MOVE50";
        }

        return "BASIC";
    }
}
