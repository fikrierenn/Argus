namespace BkmArgus.AiWorker;

public sealed record AiIstekRow
{
    public long? IstekId { get; init; }
    public DateTime? KesimTarihi { get; init; }
    public string DonemKodu { get; init; } = string.Empty;
    public int MekanId { get; init; }
    public int StokId { get; init; }
    public string? MekanAd { get; init; }
    public string? UrunKod { get; init; }
    public string? UrunAd { get; init; }
    public int? RiskSkor { get; init; }
    public int Oncelik { get; init; }
    public string Durum { get; init; } = string.Empty;
    public string? EvidencePlan { get; init; }
    public string? LmNot { get; init; }
    public DateTime? OlusturmaTarihi { get; init; }
    public DateTime? GuncellemeTarihi { get; init; }
    public string? HataMesaji { get; init; }
}

public sealed record AiLlmIstekRow
{
    public long IstekId { get; init; }
    public DateTime? KesimTarihi { get; init; }
    public string DonemKodu { get; init; } = string.Empty;
    public int MekanId { get; init; }
    public int StokId { get; init; }
    public string? EvidencePlan { get; init; }
    public string? EvidenceJson { get; init; }
    public string? LmNot { get; init; }
}

public sealed record RiskOzetRow
{
    public DateTime? KesimTarihi { get; init; }
    public string DonemKodu { get; init; } = string.Empty;
    public int MekanId { get; init; }
    public string MekanAd { get; init; } = string.Empty;
    public int StokId { get; init; }
    public string UrunKod { get; init; } = string.Empty;
    public string UrunAd { get; init; } = string.Empty;
    public int RiskSkor { get; init; }
    public string? RiskYorum { get; init; }
    public bool FlagVeriKalite { get; init; }
    public bool FlagGirissizSatis { get; init; }
    public bool FlagOluStok { get; init; }
    public bool FlagNetBirikim { get; init; }
    public bool FlagIadeYuksek { get; init; }
    public bool FlagBozukIadeYuksek { get; init; }
    public bool FlagSayimDuzeltmeYuk { get; init; }
    public bool FlagSirketIciYuksek { get; init; }
    public bool FlagHizliDevir { get; init; }
    public bool FlagSatisYaslanma { get; init; }
}

public sealed record LmDecision
{
    public string RootCauseClass { get; init; } = "DIGER";
    public string EvidencePlan { get; init; } = "BASIC";
    public bool LlmGerekliMi { get; init; }
    public int OncelikPuan { get; init; }
    public string? KisaOzet { get; init; }
    public string? OzellikJson { get; init; }
    public string? SemanticNot { get; init; }
}

public sealed record LlmResult
{
    public string Model { get; init; } = string.Empty;
    public string PromptVersiyon { get; init; } = "v1";
    public string? KokNedenHipotezleri { get; init; }
    public string? DogrulamaAdimlari { get; init; }
    public string? OnerilenAksiyonlar { get; init; }
    public string? DofTaslakJson { get; init; }
    public string? YoneticiOzeti { get; init; }
    public int? GuvenSkoru { get; init; }
    public string RawJson { get; init; } = string.Empty;
    public string? ParseError { get; init; }
}

public sealed record LlmCallResult
{
    public LlmResult? Result { get; init; }
    public string? Error { get; init; }
    public bool Success => Result is not null;
}

public sealed record VectorRow
{
    public long VektorId { get; init; }
    public long RiskId { get; init; }
    public long? DofId { get; init; }
    public string? Baslik { get; init; }
    public string? OzetMetin { get; init; }
    public bool KritikMi { get; init; }
    public string VektorJson { get; init; } = string.Empty;
}

public sealed record SemanticMatch
{
    public long RiskId { get; init; }
    public long? DofId { get; init; }
    public string Baslik { get; init; } = "Gecmis kayit";
    public double Similarity { get; init; }
    public bool KritikMi { get; init; }
}

public sealed record DofKayitRow
{
    public long DofId { get; init; }
    public string? DofImza { get; init; }
    public string Baslik { get; init; } = string.Empty;
    public string? Aciklama { get; init; }
    public string? KaynakAnahtar { get; init; }
    public int RiskSeviyesi { get; init; }
    public string Durum { get; init; } = string.Empty;
}
