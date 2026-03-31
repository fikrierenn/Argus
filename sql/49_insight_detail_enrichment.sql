/* 49_insight_detail_enrichment.sql
   - sp_Insight_DenetimPlanla: lower @RiskEsik default to 10, add flag counts to description
   - sp_Insight_List: ensure EntityName column exposed
   2026-03-31
*/
USE BKMDenetim;
GO

-- ===========================================================================
-- ai.sp_Insight_DenetimPlanla — enriched with flag counts in description
-- ===========================================================================
IF OBJECT_ID('ai.sp_Insight_DenetimPlanla', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_DenetimPlanla;
GO
CREATE PROCEDURE ai.sp_Insight_DenetimPlanla
    @GunEsik    int = 30,   -- days since last audit
    @RiskEsik   int = 10    -- min avg ERP risk score (lowered from 60 to 10)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Find high-risk locations from ERP that may need audit attention
        ;WITH LatestSnap AS (
            SELECT MAX(CONVERT(date, SnapshotDate)) AS MaxDate
            FROM rpt.DailyProductRisk
        ),
        LocationRisk AS (
            SELECT
                r.LocationId,
                AVG(r.RiskScore)                                              AS AvgRisk,
                COUNT(*)                                                      AS ProductCount,
                SUM(CASE WHEN r.FlagSalesWithoutEntry = 1 THEN 1 ELSE 0 END) AS FlagGirissizSatis,
                SUM(CASE WHEN r.FlagDeadStock = 1 THEN 1 ELSE 0 END)         AS FlagOluStok,
                SUM(CASE WHEN r.FlagNetAccumulation = 1 THEN 1 ELSE 0 END)   AS FlagNetBirikim,
                SUM(CASE WHEN r.FlagHighReturn = 1 THEN 1 ELSE 0 END)        AS FlagIadeYuksek,
                SUM(CASE WHEN r.FlagHighCountAdjustment = 1 THEN 1 ELSE 0 END) AS FlagSayimDuzeltme
            FROM rpt.DailyProductRisk r
            CROSS JOIN LatestSnap ls
            WHERE CONVERT(date, r.SnapshotDate) = ls.MaxDate
              AND r.PeriodCode = 'Son30Gun'
            GROUP BY r.LocationId
            HAVING AVG(r.RiskScore) >= @RiskEsik
        ),
        LocationName AS (
            SELECT MekanId, MekanAd FROM src.vw_Mekan
        )
        INSERT INTO ai.ProactiveInsights (InsightType, Severity, Title, Description, EntityType, EntityId, MetricValue, ThresholdValue)
        SELECT
            'DENETIM_PLANLA',
            CASE WHEN lr.AvgRisk >= 80 THEN 'KRITIK' WHEN lr.AvgRisk >= 50 THEN 'YUKSEK' ELSE 'ORTA' END,
            N'Yuksek Riskli Mekan: ' + ISNULL(ln.MekanAd, N'Mekan #' + CAST(lr.LocationId AS nvarchar(10))),
            N'Ort. risk skoru: ' + CAST(CAST(lr.AvgRisk AS int) AS nvarchar(10)) +
                N'/100 (' + CAST(lr.ProductCount AS nvarchar(10)) + N' urun). ' +
                CASE WHEN lr.FlagGirissizSatis > 0 THEN CAST(lr.FlagGirissizSatis AS nvarchar(10)) + N' GirissizSatis, ' ELSE N'' END +
                CASE WHEN lr.FlagNetBirikim > 0 THEN CAST(lr.FlagNetBirikim AS nvarchar(10)) + N' NetBirikim, ' ELSE N'' END +
                CASE WHEN lr.FlagIadeYuksek > 0 THEN CAST(lr.FlagIadeYuksek AS nvarchar(10)) + N' IadeYuksek, ' ELSE N'' END +
                CASE WHEN lr.FlagSayimDuzeltme > 0 THEN CAST(lr.FlagSayimDuzeltme AS nvarchar(10)) + N' SayimDuzeltme, ' ELSE N'' END +
                N'Denetim planlanmasi onerilir.',
            'MEKAN',
            lr.LocationId,
            lr.AvgRisk,
            @RiskEsik
        FROM LocationRisk lr
        LEFT JOIN LocationName ln ON ln.MekanId = lr.LocationId
        WHERE NOT EXISTS (
            SELECT 1 FROM ai.ProactiveInsights p
            WHERE p.InsightType = 'DENETIM_PLANLA'
              AND p.EntityType = 'MEKAN'
              AND p.EntityId = lr.LocationId
              AND p.CreatedAt >= DATEADD(hour, -24, SYSDATETIME())
        );

        SELECT @@ROWCOUNT AS InsertedCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Also update the existing stale insight description for FSM (EntityId=1)
-- so the user sees better info immediately
UPDATE ai.ProactiveInsights
SET Description = (
    SELECT
        N'Ort. risk skoru: ' + CAST(CAST(AVG(r.RiskScore) AS int) AS nvarchar(10)) +
        N'/100 (' + CAST(COUNT(*) AS nvarchar(10)) + N' urun). ' +
        CASE WHEN SUM(CASE WHEN r.FlagSalesWithoutEntry=1 THEN 1 ELSE 0 END) > 0
             THEN CAST(SUM(CASE WHEN r.FlagSalesWithoutEntry=1 THEN 1 ELSE 0 END) AS nvarchar(10)) + N' GirissizSatis, ' ELSE N'' END +
        CASE WHEN SUM(CASE WHEN r.FlagNetAccumulation=1 THEN 1 ELSE 0 END) > 0
             THEN CAST(SUM(CASE WHEN r.FlagNetAccumulation=1 THEN 1 ELSE 0 END) AS nvarchar(10)) + N' NetBirikim, ' ELSE N'' END +
        CASE WHEN SUM(CASE WHEN r.FlagHighReturn=1 THEN 1 ELSE 0 END) > 0
             THEN CAST(SUM(CASE WHEN r.FlagHighReturn=1 THEN 1 ELSE 0 END) AS nvarchar(10)) + N' IadeYuksek, ' ELSE N'' END +
        N'Denetim planlanmasi onerilir.'
    FROM rpt.DailyProductRisk r
    WHERE r.LocationId = ai.ProactiveInsights.EntityId
      AND r.PeriodCode = 'Son30Gun'
      AND CONVERT(date, r.SnapshotDate) = (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk)
)
WHERE InsightType = 'DENETIM_PLANLA' AND EntityType = 'MEKAN';
GO

-- Generate new insights with enriched data for all locations now
EXEC ai.sp_Insight_DenetimPlanla @GunEsik=30, @RiskEsik=10;
GO
