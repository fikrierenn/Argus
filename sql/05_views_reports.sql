/* 05_views_reports.sql
   Updated: 2026-03-30
   Views now reference renamed English tables (rpt.DailyProductRisk, rpt.DailyStockBalance)
   but expose Turkish column aliases for backward compatibility with existing SPs.
*/
USE BKMDenetim;
GO

IF OBJECT_ID(N'rpt.vw_RiskUrunOzet_Stok', N'V') IS NOT NULL DROP VIEW rpt.vw_RiskUrunOzet_Stok;
GO
CREATE VIEW rpt.vw_RiskUrunOzet_Stok
AS
SELECT
    KesimTarihi      = r.SnapshotDate,
    KesimGunu        = CONVERT(date, r.SnapshotDate),
    DonemKodu        = r.PeriodCode,
    MekanId          = r.LocationId,
    StokId           = r.ProductId,
    NetAdet          = r.NetQty,
    BrutAdet         = r.GrossQty,
    NetTutar         = r.NetAmount,
    BrutTutar        = r.GrossAmount,
    AlisBrutAdet     = r.PurchaseGrossQty,
    SatisBrutAdet    = r.SalesGrossQty,
    IadeBrutAdet     = r.ReturnGrossQty,
    TransferBrutAdet = r.TransferGrossQty,
    TransferNetAdet  = r.TransferNetQty,
    SayimBrutAdet    = r.CountGrossQty,
    DuzeltmeBrutAdet = r.AdjustmentGrossQty,
    IcKullanimBrutAdet = r.InternalUseGrossQty,
    BozukBrutAdet    = r.DamagedGrossQty,
    AlisBrutTutar    = r.PurchaseGrossAmount,
    SatisBrutTutar   = r.SalesGrossAmount,
    IadeBrutTutar    = r.ReturnGrossAmount,
    TransferBrutTutar = r.TransferGrossAmount,
    TransferNetTutar = r.TransferNetAmount,
    SayimBrutTutar   = r.CountGrossAmount,
    DuzeltmeBrutTutar = r.AdjustmentGrossAmount,
    IcKullanimBrutTutar = r.InternalUseGrossAmount,
    BozukBrutTutar   = r.DamagedGrossAmount,
    SonSatisTarihi   = r.LastSaleDate,
    SatisYasiGun     = r.SaleAgeDays,
    AdetSifirTutarVarSatir = r.ZeroQtyWithAmountRows,
    IadeOraniYuzde   = r.ReturnRatePct,
    FlagVeriKalite       = r.FlagDataQuality,
    FlagGirissizSatis    = r.FlagSalesWithoutEntry,
    FlagOluStok          = r.FlagDeadStock,
    FlagNetBirikim       = r.FlagNetAccumulation,
    FlagIadeYuksek       = r.FlagHighReturn,
    FlagBozukIadeYuksek  = r.FlagHighDamagedReturn,
    FlagSayimDuzeltmeYuk = r.FlagHighCountAdjustment,
    FlagSirketIciYuksek  = r.FlagHighInternalUse,
    FlagHizliDevir       = r.FlagFastTurnover,
    FlagSatisYaslanma    = r.FlagSalesAging,
    RiskSkor         = r.RiskScore,
    RiskYorum        = r.RiskComment,
    StokBakiyeTarihi = s.[Date],
    StokMiktar       = s.StockQty,
    FlagStokKaydiYok = CONVERT(bit, CASE WHEN s.[Date] IS NULL THEN 1 ELSE 0 END),
    FlagStokSifir    = CONVERT(bit, CASE WHEN s.[Date] IS NOT NULL AND s.StockQty=0 THEN 1 ELSE 0 END)
FROM rpt.DailyProductRisk r
OUTER APPLY (
    SELECT TOP (1) b.[Date], b.StockQty
    FROM rpt.DailyStockBalance b
    WHERE b.LocationId=r.LocationId
      AND b.ProductId=r.ProductId
      AND b.[Date] <= DATEADD(day,-1,CONVERT(date, r.SnapshotDate))
    ORDER BY b.[Date] DESC
) s;
GO

/* "Toplam" raporu: DB'de MekanId=0 yok; bu view toplami hesaplar.
   Transfer double olmamasi icin sadece pozitif transfer net bacagi sayilir.
*/
IF OBJECT_ID(N'rpt.vw_RiskUrunOzet_Toplam', N'V') IS NOT NULL DROP VIEW rpt.vw_RiskUrunOzet_Toplam;
GO
CREATE VIEW rpt.vw_RiskUrunOzet_Toplam
AS
SELECT
    KesimGunu        = CONVERT(date, r.SnapshotDate),
    KesimTarihi      = MAX(r.SnapshotDate),
    DonemKodu        = r.PeriodCode,
    MekanId          = 0,
    StokId           = r.ProductId,

    NetAdet  = SUM(r.NetQty),
    BrutAdet = SUM(r.GrossQty),
    NetTutar = SUM(r.NetAmount),
    BrutTutar= SUM(r.GrossAmount),

    -- transfer teki:
    TransferTekAdet  = SUM(CASE WHEN r.TransferNetQty>0 THEN r.TransferNetQty ELSE 0 END),
    TransferTekTutar = SUM(CASE WHEN r.TransferNetAmount>0 THEN r.TransferNetAmount ELSE 0 END),

    RiskSkor = MAX(r.RiskScore),

    FlagVeriKalite       = MAX(CONVERT(int,r.FlagDataQuality)),
    FlagGirissizSatis    = MAX(CONVERT(int,r.FlagSalesWithoutEntry)),
    FlagOluStok          = MAX(CONVERT(int,r.FlagDeadStock)),
    FlagNetBirikim       = MAX(CONVERT(int,r.FlagNetAccumulation)),
    FlagIadeYuksek       = MAX(CONVERT(int,r.FlagHighReturn)),
    FlagBozukIadeYuksek  = MAX(CONVERT(int,r.FlagHighDamagedReturn)),
    FlagSayimDuzeltmeYuk = MAX(CONVERT(int,r.FlagHighCountAdjustment)),
    FlagSirketIciYuksek  = MAX(CONVERT(int,r.FlagHighInternalUse)),
    FlagHizliDevir       = MAX(CONVERT(int,r.FlagFastTurnover)),
    FlagSatisYaslanma    = MAX(CONVERT(int,r.FlagSalesAging))
FROM rpt.DailyProductRisk r
JOIN src.vw_Mekan m ON m.MekanId=r.LocationId
GROUP BY CONVERT(date, r.SnapshotDate), r.PeriodCode, r.ProductId;
GO

IF OBJECT_ID(N'rpt.vw_RiskUrunOzet_Son', N'V') IS NOT NULL DROP VIEW rpt.vw_RiskUrunOzet_Son;
GO
CREATE VIEW rpt.vw_RiskUrunOzet_Son
AS
WITH x AS (
    SELECT
        KesimTarihi      = r.SnapshotDate,
        KesimGunu        = CONVERT(date, r.SnapshotDate),
        DonemKodu        = r.PeriodCode,
        MekanId          = r.LocationId,
        StokId           = r.ProductId,
        NetAdet          = r.NetQty,
        BrutAdet         = r.GrossQty,
        NetTutar         = r.NetAmount,
        BrutTutar        = r.GrossAmount,
        AlisBrutAdet     = r.PurchaseGrossQty,
        SatisBrutAdet    = r.SalesGrossQty,
        IadeBrutAdet     = r.ReturnGrossQty,
        TransferBrutAdet = r.TransferGrossQty,
        TransferNetAdet  = r.TransferNetQty,
        SayimBrutAdet    = r.CountGrossQty,
        DuzeltmeBrutAdet = r.AdjustmentGrossQty,
        IcKullanimBrutAdet = r.InternalUseGrossQty,
        BozukBrutAdet    = r.DamagedGrossQty,
        AlisBrutTutar    = r.PurchaseGrossAmount,
        SatisBrutTutar   = r.SalesGrossAmount,
        IadeBrutTutar    = r.ReturnGrossAmount,
        TransferBrutTutar = r.TransferGrossAmount,
        TransferNetTutar = r.TransferNetAmount,
        SayimBrutTutar   = r.CountGrossAmount,
        DuzeltmeBrutTutar = r.AdjustmentGrossAmount,
        IcKullanimBrutTutar = r.InternalUseGrossAmount,
        BozukBrutTutar   = r.DamagedGrossAmount,
        SonSatisTarihi   = r.LastSaleDate,
        SatisYasiGun     = r.SaleAgeDays,
        AdetSifirTutarVarSatir = r.ZeroQtyWithAmountRows,
        IadeOraniYuzde   = r.ReturnRatePct,
        FlagVeriKalite       = r.FlagDataQuality,
        FlagGirissizSatis    = r.FlagSalesWithoutEntry,
        FlagOluStok          = r.FlagDeadStock,
        FlagNetBirikim       = r.FlagNetAccumulation,
        FlagIadeYuksek       = r.FlagHighReturn,
        FlagBozukIadeYuksek  = r.FlagHighDamagedReturn,
        FlagSayimDuzeltmeYuk = r.FlagHighCountAdjustment,
        FlagSirketIciYuksek  = r.FlagHighInternalUse,
        FlagHizliDevir       = r.FlagFastTurnover,
        FlagSatisYaslanma    = r.FlagSalesAging,
        RiskSkor         = r.RiskScore,
        RiskYorum        = r.RiskComment,
        rn = ROW_NUMBER() OVER (PARTITION BY r.SnapshotDay, r.PeriodCode, r.LocationId, r.ProductId ORDER BY r.SnapshotDate DESC)
    FROM rpt.DailyProductRisk r
)
SELECT * FROM x WHERE rn=1;
GO
