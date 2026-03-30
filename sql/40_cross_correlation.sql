/* 40_cross_correlation.sql
   Cross-Correlation: ERP Risk x Saha Denetim
   Table: rpt.CrossCorrelation
   SPs: rpt.sp_CrossCorrelation_Calculate, _List, _LocationDetail
*/
USE BKMDenetim;
GO

/* ===== 1. Table ===== */

IF OBJECT_ID(N'rpt.CrossCorrelation', N'U') IS NULL
BEGIN
    CREATE TABLE rpt.CrossCorrelation
    (
        Id                  int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LocationId          int           NOT NULL,
        LocationName        nvarchar(100) NULL,
        SnapshotDate        date          NOT NULL CONSTRAINT DF_CrossCorr_SnapDate DEFAULT(CONVERT(date, SYSDATETIME())),
        ErpRiskScore        decimal(5,1)  NULL,
        AuditComplianceRate decimal(5,1)  NULL,
        RepeatFactor        decimal(5,2)  NULL,
        CombinedScore       decimal(5,1)  NULL,
        Quadrant            varchar(20)   NULL,
        AuditCount          int           NOT NULL CONSTRAINT DF_CrossCorr_AuditCnt DEFAULT(0),
        LastAuditDate       date          NULL,
        CreatedAt           datetime2(0)  NOT NULL CONSTRAINT DF_CrossCorr_CreatedAt DEFAULT(SYSDATETIME())
    );

    CREATE UNIQUE INDEX UX_CrossCorr_LocDate ON rpt.CrossCorrelation (LocationId, SnapshotDate);
    CREATE INDEX IX_CrossCorr_Quadrant ON rpt.CrossCorrelation (Quadrant, CombinedScore DESC);
END
GO

/* ===== 2. SP: Calculate ===== */

IF OBJECT_ID(N'rpt.sp_CrossCorrelation_Calculate', N'P') IS NOT NULL
    DROP PROCEDURE rpt.sp_CrossCorrelation_Calculate;
GO
CREATE PROCEDURE rpt.sp_CrossCorrelation_Calculate
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today date = CONVERT(date, SYSDATETIME());

    /* --- ERP Risk: per location avg from latest snapshot --- */
    ;WITH LatestErp AS (
        SELECT
            LocationId,
            AVG(CAST(RiskScore AS decimal(10,2))) AS AvgRiskScore
        FROM rpt.DailyProductRisk
        WHERE SnapshotDate = (
            SELECT MAX(SnapshotDate) FROM rpt.DailyProductRisk
        )
        GROUP BY LocationId
    ),

    /* --- Map audit.Audits (LocationName) -> vw_Mekan (MekanId) via name matching --- */
    AuditWithLoc AS (
        SELECT
            a.Id AS AuditId,
            a.LocationName,
            m.MekanId AS LocationId,
            a.AuditDate,
            a.IsFinalized
        FROM audit.Audits a
        LEFT JOIN src.vw_Mekan m ON a.LocationName LIKE '%' + m.MekanAd + '%'
                                 OR m.MekanAd LIKE '%' + a.LocationName + '%'
        WHERE a.IsFinalized = 1
    ),

    /* --- Audit: latest finalized audit per location --- */
    LatestAudit AS (
        SELECT
            LocationId,
            AuditId,
            LocationName,
            AuditDate,
            ROW_NUMBER() OVER (PARTITION BY LocationId ORDER BY AuditDate DESC, AuditId DESC) AS rn
        FROM AuditWithLoc
        WHERE LocationId IS NOT NULL
    ),
    AuditMetrics AS (
        SELECT
            la.LocationId,
            la.LocationName,
            la.AuditDate,
            COUNT(*) AS TotalItems,
            SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) AS PassedItems,
            CAST(100.0 * SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS decimal(5,1)) AS ComplianceRate,
            ISNULL(SUM(r.RepeatCount), 0) AS TotalRepeats,
            SUM(CASE WHEN r.IsSystemic = 1 THEN 1 ELSE 0 END) AS SystemicCount
        FROM LatestAudit la
        INNER JOIN audit.AuditResults r ON r.AuditId = la.AuditId
        WHERE la.rn = 1
        GROUP BY la.LocationId, la.LocationName, la.AuditDate
    ),
    AuditCounts AS (
        SELECT
            awl.LocationId,
            COUNT(DISTINCT awl.AuditId) AS AuditCount
        FROM AuditWithLoc awl
        WHERE awl.LocationId IS NOT NULL
        GROUP BY awl.LocationId
    ),

    /* --- All locations from Mekan view --- */
    AllLocations AS (
        SELECT MekanId AS LocationId, MekanAd AS LocationName
        FROM src.vw_Mekan
    ),

    /* --- Combined --- */
    Combined AS (
        SELECT
            loc.LocationId,
            COALESCE(am.LocationName, loc.LocationName) AS LocationName,
            COALESCE(erp.AvgRiskScore, 0) AS ErpRiskScore,
            COALESCE(am.ComplianceRate, 100) AS AuditComplianceRate,
            /* RepeatFactor: scaled 0-100 based on total repeats + systemic (capped at 100) */
            CAST(CASE
                WHEN COALESCE(am.TotalRepeats, 0) * 5.0 + COALESCE(am.SystemicCount, 0) * 15.0 > 100 THEN 100
                ELSE COALESCE(am.TotalRepeats, 0) * 5.0 + COALESCE(am.SystemicCount, 0) * 15.0
            END AS decimal(5,2)) AS RepeatFactor,
            COALESCE(ac.AuditCount, 0) AS AuditCount,
            am.AuditDate AS LastAuditDate
        FROM AllLocations loc
        LEFT JOIN LatestErp erp ON erp.LocationId = loc.LocationId
        LEFT JOIN AuditMetrics am ON am.LocationId = loc.LocationId
        LEFT JOIN AuditCounts ac ON ac.LocationId = loc.LocationId
        WHERE erp.LocationId IS NOT NULL OR am.LocationId IS NOT NULL
    ),
    Scored AS (
        SELECT
            *,
            /* CombinedScore = ERP*0.4 + (100-AuditCompliance)*0.4 + RepeatFactor*0.2 */
            CAST(
                ErpRiskScore * 0.4
                + (100 - AuditComplianceRate) * 0.4
                + RepeatFactor * 0.2
            AS decimal(5,1)) AS CombinedScore,
            CASE
                WHEN ErpRiskScore >= 50 AND AuditComplianceRate < 50
                    THEN 'YUKSEK_YUKSEK'
                WHEN ErpRiskScore >= 50 AND AuditComplianceRate >= 50
                    THEN 'YUKSEK_DUSUK'
                WHEN ErpRiskScore < 50 AND AuditComplianceRate < 50
                    THEN 'DUSUK_YUKSEK'
                ELSE 'DUSUK_DUSUK'
            END AS Quadrant
        FROM Combined
    )

    MERGE rpt.CrossCorrelation AS tgt
    USING (
        SELECT LocationId, LocationName, ErpRiskScore, AuditComplianceRate,
               RepeatFactor, CombinedScore, Quadrant, AuditCount, LastAuditDate
        FROM Scored
    ) AS src
    ON tgt.LocationId = src.LocationId AND tgt.SnapshotDate = @Today
    WHEN MATCHED THEN
        UPDATE SET
            tgt.LocationName        = src.LocationName,
            tgt.ErpRiskScore        = src.ErpRiskScore,
            tgt.AuditComplianceRate = src.AuditComplianceRate,
            tgt.RepeatFactor        = src.RepeatFactor,
            tgt.CombinedScore       = src.CombinedScore,
            tgt.Quadrant            = src.Quadrant,
            tgt.AuditCount          = src.AuditCount,
            tgt.LastAuditDate       = src.LastAuditDate
    WHEN NOT MATCHED THEN
        INSERT (LocationId, LocationName, SnapshotDate, ErpRiskScore, AuditComplianceRate,
                RepeatFactor, CombinedScore, Quadrant, AuditCount, LastAuditDate)
        VALUES (src.LocationId, src.LocationName, @Today, src.ErpRiskScore, src.AuditComplianceRate,
                src.RepeatFactor, src.CombinedScore, src.Quadrant, src.AuditCount, src.LastAuditDate);
END
GO

/* ===== 3. SP: List ===== */

IF OBJECT_ID(N'rpt.sp_CrossCorrelation_List', N'P') IS NOT NULL
    DROP PROCEDURE rpt.sp_CrossCorrelation_List;
GO
CREATE PROCEDURE rpt.sp_CrossCorrelation_List
    @Quadrant varchar(20) = NULL,
    @MinScore decimal(5,1) = NULL,
    @Top int = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SnapDate date = (
        SELECT MAX(SnapshotDate) FROM rpt.CrossCorrelation
    );

    IF @SnapDate IS NULL RETURN;

    SELECT TOP (@Top)
        Id,
        LocationId,
        LocationName,
        SnapshotDate,
        ErpRiskScore,
        AuditComplianceRate,
        RepeatFactor,
        CombinedScore,
        Quadrant,
        AuditCount,
        LastAuditDate,
        CreatedAt
    FROM rpt.CrossCorrelation
    WHERE SnapshotDate = @SnapDate
      AND (@Quadrant IS NULL OR Quadrant = @Quadrant)
      AND (@MinScore IS NULL OR CombinedScore >= @MinScore)
    ORDER BY CombinedScore DESC;
END
GO

/* ===== 4. SP: Location Detail ===== */

IF OBJECT_ID(N'rpt.sp_CrossCorrelation_LocationDetail', N'P') IS NOT NULL
    DROP PROCEDURE rpt.sp_CrossCorrelation_LocationDetail;
GO
CREATE PROCEDURE rpt.sp_CrossCorrelation_LocationDetail
    @LocationId int
AS
BEGIN
    SET NOCOUNT ON;

    /* Result set 1: Latest correlation record */
    SELECT TOP 1
        Id, LocationId, LocationName, SnapshotDate,
        ErpRiskScore, AuditComplianceRate, RepeatFactor,
        CombinedScore, Quadrant, AuditCount, LastAuditDate
    FROM rpt.CrossCorrelation
    WHERE LocationId = @LocationId
    ORDER BY SnapshotDate DESC;

    /* Result set 2: Top 20 ERP risk products for this location (latest snapshot) */
    SELECT TOP 20
        ProductId,
        RiskScore,
        RiskComment,
        FlagSalesWithoutEntry,
        FlagDeadStock,
        FlagNetAccumulation,
        FlagHighReturn,
        FlagFastTurnover,
        SnapshotDate
    FROM rpt.DailyProductRisk
    WHERE LocationId = @LocationId
      AND SnapshotDate = (SELECT MAX(SnapshotDate) FROM rpt.DailyProductRisk)
    ORDER BY RiskScore DESC;

    /* Result set 3: Latest finalized audit results for this location */
    DECLARE @LocName nvarchar(100) = (SELECT MekanAd FROM src.vw_Mekan WHERE MekanId = @LocationId);

    SELECT
        r.AuditItemId,
        r.AuditGroup,
        r.Area,
        r.ItemText,
        r.IsPassed,
        r.RiskScore,
        r.RepeatCount,
        r.IsSystemic,
        r.Remark,
        a.AuditDate,
        a.ReportNo
    FROM audit.AuditResults r
    INNER JOIN audit.Audits a ON a.Id = r.AuditId
    WHERE a.IsFinalized = 1
      AND (a.LocationName LIKE '%' + @LocName + '%' OR @LocName LIKE '%' + a.LocationName + '%')
      AND a.Id = (
          SELECT TOP 1 a2.Id FROM audit.Audits a2
          WHERE a2.IsFinalized = 1
            AND (a2.LocationName LIKE '%' + @LocName + '%' OR @LocName LIKE '%' + a2.LocationName + '%')
          ORDER BY a2.AuditDate DESC, a2.Id DESC
      )
    ORDER BY r.SortOrder;

    /* Result set 4: Correlation history (last 30 snapshots) */
    SELECT TOP 30
        SnapshotDate,
        ErpRiskScore,
        AuditComplianceRate,
        CombinedScore,
        Quadrant
    FROM rpt.CrossCorrelation
    WHERE LocationId = @LocationId
    ORDER BY SnapshotDate DESC;
END
GO

PRINT '40_cross_correlation.sql completed successfully.';
GO
