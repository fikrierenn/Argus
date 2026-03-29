/* 22_sps_audit_dashboard.sql
   Reporting and Dashboard stored procedures for Field Audit module.

   Tables used:
     audit.Audits, audit.AuditResults, audit.AuditResultPhotos,
     dof.DofKayit (for pending DOF count)

   Convention:
     - Table/column names: ENGLISH
     - SP parameter names: TURKISH with @ prefix
     - SET NOCOUNT ON, TRY-CATCH, DROP+CREATE idempotency
*/
USE BKMDenetim;
GO

/* ==========================================================================
   REPORTS
   ========================================================================== */

/* --------------------------------------------------------------------------
   1. audit.sp_Report_AuditSummary
      Single audit summary: totals, compliance rate, risk breakdown.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Report_AuditSummary', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Report_AuditSummary;
GO

CREATE PROCEDURE audit.sp_Report_AuditSummary
    @DenetimId int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            a.LocationName,
            a.AuditDate,
            a.ReportNo,
            COUNT(*)                                            AS TotalItems,
            SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END)   AS PassedItems,
            SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END)   AS FailedItems,
            CAST(
                CASE WHEN COUNT(*) = 0 THEN 0
                     ELSE 100.0 * SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) / COUNT(*)
                END AS decimal(5,2)
            )                                                   AS ComplianceRate,
            CAST(AVG(CAST(r.RiskScore AS decimal(5,2))) AS decimal(5,2)) AS AvgRiskScore,
            SUM(CASE WHEN r.RiskLevel = 'High' AND r.IsPassed = 0 THEN 1 ELSE 0 END) AS HighRiskCount
        FROM audit.Audits a
        INNER JOIN audit.AuditResults r ON r.AuditId = a.Id
        WHERE a.Id = @DenetimId
        GROUP BY a.LocationName, a.AuditDate, a.ReportNo;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   2. audit.sp_Report_Scorecard
      Per-location scorecard with optional filters.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Report_Scorecard', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Report_Scorecard;
GO

CREATE PROCEDURE audit.sp_Report_Scorecard
    @MagazaAdi   nvarchar(100) = NULL,
    @BaslangicTarihi datetime2(0) = NULL,
    @BitisTarihi     datetime2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        ;WITH AuditStats AS (
            SELECT
                a.Id AS AuditId,
                a.LocationName,
                a.AuditDate,
                CAST(
                    CASE WHEN COUNT(*) = 0 THEN 0
                         ELSE 100.0 * SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) / COUNT(*)
                    END AS decimal(5,2)
                ) AS ComplianceRate
            FROM audit.Audits a
            INNER JOIN audit.AuditResults r ON r.AuditId = a.Id
            WHERE a.IsFinalized = 1
              AND (@MagazaAdi IS NULL OR a.LocationName = @MagazaAdi)
              AND (@BaslangicTarihi IS NULL OR a.AuditDate >= @BaslangicTarihi)
              AND (@BitisTarihi IS NULL OR a.AuditDate <= @BitisTarihi)
            GROUP BY a.Id, a.LocationName, a.AuditDate
        )
        SELECT
            s.LocationName,
            COUNT(DISTINCT s.AuditId)                           AS AuditCount,
            CAST(AVG(s.ComplianceRate) AS decimal(5,2))         AS AvgComplianceRate,
            MAX(s.AuditDate)                                    AS LastAuditDate,
            (
                SELECT TOP 1 sub.ComplianceRate
                FROM AuditStats sub
                WHERE sub.LocationName = s.LocationName
                ORDER BY sub.AuditDate DESC
            )                                                   AS LastComplianceRate
        FROM AuditStats s
        GROUP BY s.LocationName
        ORDER BY AvgComplianceRate ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   3. audit.sp_Report_RepeatingFindings
      Findings that repeat across multiple audits.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Report_RepeatingFindings', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Report_RepeatingFindings;
GO

CREATE PROCEDURE audit.sp_Report_RepeatingFindings
    @MinTekrar int = 2,
    @Ust        int = 20
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Ust)
            r.ItemText,
            COUNT(*)                                            AS TotalFailures,
            COUNT(DISTINCT a.LocationName)                      AS DistinctLocationCount,
            COUNT(DISTINCT r.AuditId)                           AS DistinctAuditCount,
            CAST(AVG(CAST(r.RiskScore AS decimal(5,2))) AS decimal(5,2)) AS AvgRiskScore,
            MAX(CAST(r.IsSystemic AS int))                      AS IsSystemic
        FROM audit.AuditResults r
        INNER JOIN audit.Audits a ON a.Id = r.AuditId
        WHERE r.IsPassed = 0
          AND a.IsFinalized = 1
        GROUP BY r.ItemText
        HAVING COUNT(*) >= @MinTekrar
        ORDER BY TotalFailures DESC, AvgRiskScore DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   4. audit.sp_Report_SystemicFindings
      Findings flagged as systemic (IsSystemic=1).
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Report_SystemicFindings', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Report_SystemicFindings;
GO

CREATE PROCEDURE audit.sp_Report_SystemicFindings
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            r.ItemText,
            COUNT(DISTINCT a.LocationName)                      AS DistinctLocationCount,
            COUNT(*)                                            AS TotalFailures,
            MAX(a.AuditDate)                                    AS LastSeenDate
        FROM audit.AuditResults r
        INNER JOIN audit.Audits a ON a.Id = r.AuditId
        WHERE r.IsPassed = 0
          AND r.IsSystemic = 1
          AND a.IsFinalized = 1
        GROUP BY r.ItemText
        ORDER BY DistinctLocationCount DESC, TotalFailures DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   5. audit.sp_Report_MonthlyTrend
      Monthly compliance trend for the last N months.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Report_MonthlyTrend', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Report_MonthlyTrend;
GO

CREATE PROCEDURE audit.sp_Report_MonthlyTrend
    @MagazaAdi nvarchar(100) = NULL,
    @AySayisi  int            = 12
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @KesimTarihi datetime2(0) = DATEADD(MONTH, -@AySayisi, SYSDATETIME());

        ;WITH AuditMonthly AS (
            SELECT
                a.Id AS AuditId,
                YEAR(a.AuditDate)  AS [Year],
                MONTH(a.AuditDate) AS [Month],
                CAST(
                    CASE WHEN COUNT(*) = 0 THEN 0
                         ELSE 100.0 * SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) / COUNT(*)
                    END AS decimal(5,2)
                ) AS ComplianceRate
            FROM audit.Audits a
            INNER JOIN audit.AuditResults r ON r.AuditId = a.Id
            WHERE a.IsFinalized = 1
              AND a.AuditDate >= @KesimTarihi
              AND (@MagazaAdi IS NULL OR a.LocationName = @MagazaAdi)
            GROUP BY a.Id, YEAR(a.AuditDate), MONTH(a.AuditDate)
        )
        SELECT
            [Year],
            [Month],
            COUNT(DISTINCT AuditId)                             AS AuditCount,
            CAST(AVG(ComplianceRate) AS decimal(5,2))           AS AvgComplianceRate
        FROM AuditMonthly
        GROUP BY [Year], [Month]
        ORDER BY [Year], [Month];
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ==========================================================================
   DASHBOARD
   ========================================================================== */

/* --------------------------------------------------------------------------
   6. audit.sp_Dashboard_FieldAudit_Kpi
      Single-row KPI summary for the field audit dashboard.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Dashboard_FieldAudit_Kpi', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Dashboard_FieldAudit_Kpi;
GO

CREATE PROCEDURE audit.sp_Dashboard_FieldAudit_Kpi
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @AyBaslangic datetime2(0) = DATEFROMPARTS(YEAR(SYSDATETIME()), MONTH(SYSDATETIME()), 1);

        SELECT
            -- Total finalized audits
            (SELECT COUNT(*) FROM audit.Audits WHERE IsFinalized = 1)
                AS TotalAudits,

            -- This month's audits
            (SELECT COUNT(*) FROM audit.Audits WHERE IsFinalized = 1 AND AuditDate >= @AyBaslangic)
                AS ThisMonthAudits,

            -- Overall average compliance rate
            (
                SELECT CAST(AVG(cr.ComplianceRate) AS decimal(5,2))
                FROM (
                    SELECT
                        a.Id,
                        CASE WHEN COUNT(*) = 0 THEN 0
                             ELSE 100.0 * SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) / COUNT(*)
                        END AS ComplianceRate
                    FROM audit.Audits a
                    INNER JOIN audit.AuditResults r ON r.AuditId = a.Id
                    WHERE a.IsFinalized = 1
                    GROUP BY a.Id
                ) cr
            )   AS AvgComplianceRate,

            -- Repeating findings (failed in 2+ audits)
            (
                SELECT COUNT(*)
                FROM (
                    SELECT r.ItemText
                    FROM audit.AuditResults r
                    INNER JOIN audit.Audits a ON a.Id = r.AuditId
                    WHERE r.IsPassed = 0 AND a.IsFinalized = 1
                    GROUP BY r.ItemText
                    HAVING COUNT(DISTINCT r.AuditId) >= 2
                ) rep
            )   AS RepeatingFindingCount,

            -- Systemic findings count
            (
                SELECT COUNT(DISTINCT r.ItemText)
                FROM audit.AuditResults r
                INNER JOIN audit.Audits a ON a.Id = r.AuditId
                WHERE r.IsPassed = 0 AND r.IsSystemic = 1 AND a.IsFinalized = 1
            )   AS SystemicCount,

            -- Pending DOF count (ACIK status)
            (
                SELECT CASE
                    WHEN OBJECT_ID(N'dof.DofKayit', N'U') IS NOT NULL
                    THEN (SELECT COUNT(*) FROM dof.DofKayit WHERE Durum = 'ACIK' AND KaynakSistemKodu = 'SAHA_DENETIM')
                    ELSE 0
                END
            )   AS PendingDofCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   7. audit.sp_Dashboard_RecentAudits
      Most recent audits for the dashboard feed.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Dashboard_RecentAudits', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Dashboard_RecentAudits;
GO

CREATE PROCEDURE audit.sp_Dashboard_RecentAudits
    @Ust int = 5
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Ust)
            a.Id,
            a.LocationName,
            a.AuditDate,
            CAST(
                CASE WHEN cnt.Total = 0 THEN 0
                     ELSE 100.0 * cnt.Passed / cnt.Total
                END AS decimal(5,2)
            ) AS ComplianceRate,
            a.IsFinalized
        FROM audit.Audits a
        CROSS APPLY (
            SELECT
                COUNT(*)                                        AS Total,
                SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) AS Passed
            FROM audit.AuditResults r
            WHERE r.AuditId = a.Id
        ) cnt
        ORDER BY a.AuditDate DESC, a.Id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   8. audit.sp_Dashboard_TopRiskFindings
      Top failing findings ranked by failure count and risk score.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Dashboard_TopRiskFindings', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Dashboard_TopRiskFindings;
GO

CREATE PROCEDURE audit.sp_Dashboard_TopRiskFindings
    @Ust int = 10
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Ust)
            r.ItemText,
            COUNT(*)                                            AS FailureCount,
            COUNT(DISTINCT a.LocationName)                      AS DistinctLocations,
            CAST(AVG(CAST(r.RiskScore AS decimal(5,2))) AS decimal(5,2)) AS AvgRiskScore,
            MAX(CAST(r.IsSystemic AS int))                      AS IsSystemic
        FROM audit.AuditResults r
        INNER JOIN audit.Audits a ON a.Id = r.AuditId
        WHERE r.IsPassed = 0
          AND a.IsFinalized = 1
        GROUP BY r.ItemText
        ORDER BY FailureCount DESC, AvgRiskScore DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* --------------------------------------------------------------------------
   9. audit.sp_Dashboard_LocationScores
      Per-location scores with repeating finding count.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'audit.sp_Dashboard_LocationScores', N'P') IS NOT NULL
    DROP PROCEDURE audit.sp_Dashboard_LocationScores;
GO

CREATE PROCEDURE audit.sp_Dashboard_LocationScores
    @Ust int = 10
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        ;WITH LocationAuditStats AS (
            SELECT
                a.Id AS AuditId,
                a.LocationName,
                a.AuditDate,
                CAST(
                    CASE WHEN COUNT(*) = 0 THEN 0
                         ELSE 100.0 * SUM(CASE WHEN r.IsPassed = 1 THEN 1 ELSE 0 END) / COUNT(*)
                    END AS decimal(5,2)
                ) AS ComplianceRate
            FROM audit.Audits a
            INNER JOIN audit.AuditResults r ON r.AuditId = a.Id
            WHERE a.IsFinalized = 1
            GROUP BY a.Id, a.LocationName, a.AuditDate
        ),
        LocationRepeats AS (
            SELECT
                a.LocationName,
                COUNT(*) AS RepeatingFindingCount
            FROM (
                SELECT
                    a2.LocationName,
                    r2.ItemText
                FROM audit.AuditResults r2
                INNER JOIN audit.Audits a2 ON a2.Id = r2.AuditId
                WHERE r2.IsPassed = 0 AND a2.IsFinalized = 1
                GROUP BY a2.LocationName, r2.ItemText
                HAVING COUNT(DISTINCT r2.AuditId) >= 2
            ) a
            GROUP BY a.LocationName
        )
        SELECT TOP (@Ust)
            s.LocationName,
            COUNT(DISTINCT s.AuditId)                           AS AuditCount,
            CAST(AVG(s.ComplianceRate) AS decimal(5,2))         AS AvgComplianceRate,
            MAX(s.AuditDate)                                    AS LastAuditDate,
            ISNULL(lr.RepeatingFindingCount, 0)                 AS RepeatingFindingCount
        FROM LocationAuditStats s
        LEFT JOIN LocationRepeats lr ON lr.LocationName = s.LocationName
        GROUP BY s.LocationName, lr.RepeatingFindingCount
        ORDER BY AvgComplianceRate ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '22_sps_audit_dashboard.sql completed successfully.';
GO
