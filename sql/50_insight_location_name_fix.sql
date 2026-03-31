/* 50_insight_location_name_fix.sql
   Fix sp_Insight_List and sp_Insight_DenetimPlanla to use src.vw_Mekan.MekanAd
   instead of ref.LocationSettings.Description for MEKAN entity names.
   2026-03-31
*/
USE BKMDenetim;
GO

-- Fix sp_Insight_List: join src.vw_Mekan for EntityName
IF OBJECT_ID('ai.sp_Insight_List', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_List;
GO
CREATE PROCEDURE ai.sp_Insight_List
    @Top                int = 50,
    @SadeceAktif        bit = 1,
    @InsightType        varchar(30) = NULL,
    @VarlikTipi         varchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT TOP (@Top)
            i.InsightId, i.InsightType, i.Severity, i.Title, i.Description,
            i.EntityType, i.EntityId, i.MetricValue, i.ThresholdValue,
            i.IsActioned, i.ActionedByUserId, i.ActionedAt, i.ActionNote,
            i.CreatedAt,
            CASE i.EntityType
                WHEN 'MEKAN' THEN (SELECT TOP 1 m.MekanAd FROM src.vw_Mekan m WHERE m.MekanId = i.EntityId)
                ELSE NULL
            END AS EntityName
        FROM ai.ProactiveInsights i
        WHERE (@SadeceAktif = 0 OR i.IsActioned = 0)
          AND (@InsightType IS NULL OR i.InsightType = @InsightType)
          AND (@VarlikTipi IS NULL OR i.EntityType = @VarlikTipi)
        ORDER BY
            CASE i.Severity WHEN 'KRITIK' THEN 1 WHEN 'YUKSEK' THEN 2 ELSE 3 END,
            i.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Also fix sp_Insight_DenetimPlanla title to use src.vw_Mekan.MekanAd
-- (already fixed in 49_insight_detail_enrichment.sql, just update existing row)
UPDATE ai.ProactiveInsights
SET Title = N'Yuksek Riskli Mekan: ' + ISNULL(
    (SELECT TOP 1 m.MekanAd FROM src.vw_Mekan m WHERE m.MekanId = EntityId),
    N'Mekan #' + CAST(EntityId AS nvarchar(10)))
WHERE InsightType = 'DENETIM_PLANLA' AND EntityType = 'MEKAN';
GO
