-- ============================================================================
-- AI Feedback, Proactive Insights, Skill Executions
-- Part of: AI Full Activation (BLOK 1)
-- Tables: ai.Feedback, ai.ProactiveInsights, ai.SkillExecutions
-- Modifies: ai.SemanticVectors (Weight + Source columns)
-- SPs: ~20 stored procedures
-- ============================================================================

-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- 1A. ai.Feedback — user feedback on AI outputs
IF OBJECT_ID('ai.Feedback', 'U') IS NULL
CREATE TABLE ai.Feedback (
    FeedbackId          int IDENTITY(1,1) PRIMARY KEY,
    RequestId           int NULL,                      -- FK to ai.AnalysisQueue (nullable: feedback can be on skill too)
    SkillExecutionId    int NULL,                      -- FK to ai.SkillExecutions
    IsApproved          bit NOT NULL,                  -- thumbs up/down
    Rating              tinyint NULL,                  -- 1-5 stars (optional)
    UserComment         nvarchar(1000) NULL,
    UserId              int NOT NULL,                  -- who gave the feedback
    CreatedAt           datetime2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Feedback_Request_User' AND object_id = OBJECT_ID('ai.Feedback'))
CREATE UNIQUE INDEX UX_Feedback_Request_User ON ai.Feedback(RequestId, UserId) WHERE RequestId IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Feedback_SkillExec_User' AND object_id = OBJECT_ID('ai.Feedback'))
CREATE UNIQUE INDEX UX_Feedback_SkillExec_User ON ai.Feedback(SkillExecutionId, UserId) WHERE SkillExecutionId IS NOT NULL;
GO

-- 1B. ai.ProactiveInsights — AI-generated proactive recommendations
IF OBJECT_ID('ai.ProactiveInsights', 'U') IS NULL
CREATE TABLE ai.ProactiveInsights (
    InsightId           int IDENTITY(1,1) PRIMARY KEY,
    InsightType         varchar(30) NOT NULL,          -- DENETIM_PLANLA, TREND_UYARI, ANOMALI_TESPIT
    Severity            varchar(10) NOT NULL,          -- KRITIK, YUKSEK, ORTA
    Title               nvarchar(300) NOT NULL,
    Description         nvarchar(2000) NULL,
    EntityType          varchar(20) NOT NULL,          -- MEKAN, URUN, DENETIM
    EntityId            int NOT NULL,
    MetricValue         decimal(18,2) NULL,            -- actual observed value
    ThresholdValue      decimal(18,2) NULL,            -- threshold that was exceeded
    IsActioned          bit NOT NULL DEFAULT 0,
    ActionedByUserId    int NULL,
    ActionedAt          datetime2(0) NULL,
    ActionNote          nvarchar(500) NULL,
    CreatedAt           datetime2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProactiveInsights_Unactioned' AND object_id = OBJECT_ID('ai.ProactiveInsights'))
CREATE INDEX IX_ProactiveInsights_Unactioned ON ai.ProactiveInsights(IsActioned, CreatedAt DESC)
    WHERE IsActioned = 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProactiveInsights_Entity' AND object_id = OBJECT_ID('ai.ProactiveInsights'))
CREATE INDEX IX_ProactiveInsights_Entity ON ai.ProactiveInsights(EntityType, EntityId);
GO

-- 1C. ai.SkillExecutions — Skill execution queue (Web→Worker bridge)
IF OBJECT_ID('ai.SkillExecutions', 'U') IS NULL
CREATE TABLE ai.SkillExecutions (
    ExecutionId         int IDENTITY(1,1) PRIMARY KEY,
    SkillId             varchar(50) NOT NULL,          -- e.g. audit.analyze, dof.recommend
    RequestedByUserId   int NOT NULL,
    EntityType          varchar(20) NOT NULL,          -- DENETIM, DOF, MEKAN, URUN
    EntityId            int NOT NULL,
    Status              varchar(20) NOT NULL DEFAULT 'QUEUED',  -- QUEUED, RUNNING, DONE, ERROR
    InputJson           nvarchar(max) NULL,            -- context variables for template rendering
    OutputJson          nvarchar(max) NULL,            -- skill result
    ModelName           varchar(100) NULL,
    ConfidenceScore     int NULL,                      -- 0-100
    ErrorMessage        nvarchar(2000) NULL,
    CreatedAt           datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
    CompletedAt         datetime2(0) NULL
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SkillExecutions_Status' AND object_id = OBJECT_ID('ai.SkillExecutions'))
CREATE INDEX IX_SkillExecutions_Status ON ai.SkillExecutions(Status, CreatedAt)
    WHERE Status IN ('QUEUED', 'RUNNING');
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SkillExecutions_Entity' AND object_id = OBJECT_ID('ai.SkillExecutions'))
CREATE INDEX IX_SkillExecutions_Entity ON ai.SkillExecutions(EntityType, EntityId);
GO

-- 1D. Extend ai.SemanticVectors — add Weight and Source
IF COL_LENGTH('ai.SemanticVectors', 'Weight') IS NULL
    ALTER TABLE ai.SemanticVectors ADD Weight float NOT NULL DEFAULT 1.0;
GO

IF COL_LENGTH('ai.SemanticVectors', 'Source') IS NULL
    ALTER TABLE ai.SemanticVectors ADD Source varchar(20) NOT NULL DEFAULT 'DOF';
GO

-- ============================================================================
-- 2. STORED PROCEDURES — Feedback
-- ============================================================================

-- 2A. ai.sp_Feedback_Upsert — Insert or update feedback
IF OBJECT_ID('ai.sp_Feedback_Upsert', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Feedback_Upsert;
GO
CREATE PROCEDURE ai.sp_Feedback_Upsert
    @RequestId          int = NULL,
    @SkillExecutionId   int = NULL,
    @Onay               bit,              -- IsApproved
    @Puan               tinyint = NULL,   -- Rating
    @Yorum              nvarchar(1000) = NULL,
    @KullaniciId        int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @RequestId IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM ai.Feedback WHERE RequestId = @RequestId AND UserId = @KullaniciId)
                UPDATE ai.Feedback
                SET IsApproved = @Onay, Rating = @Puan, UserComment = @Yorum, CreatedAt = SYSDATETIME()
                WHERE RequestId = @RequestId AND UserId = @KullaniciId;
            ELSE
                INSERT INTO ai.Feedback (RequestId, IsApproved, Rating, UserComment, UserId)
                VALUES (@RequestId, @Onay, @Puan, @Yorum, @KullaniciId);
        END
        ELSE IF @SkillExecutionId IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM ai.Feedback WHERE SkillExecutionId = @SkillExecutionId AND UserId = @KullaniciId)
                UPDATE ai.Feedback
                SET IsApproved = @Onay, Rating = @Puan, UserComment = @Yorum, CreatedAt = SYSDATETIME()
                WHERE SkillExecutionId = @SkillExecutionId AND UserId = @KullaniciId;
            ELSE
                INSERT INTO ai.Feedback (SkillExecutionId, IsApproved, Rating, UserComment, UserId)
                VALUES (@SkillExecutionId, @Onay, @Puan, @Yorum, @KullaniciId);
        END

        SELECT @@ROWCOUNT AS Affected;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 2B. ai.sp_Feedback_Stats — Feedback statistics
IF OBJECT_ID('ai.sp_Feedback_Stats', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Feedback_Stats;
GO
CREATE PROCEDURE ai.sp_Feedback_Stats
    @BaslangicTarih     datetime2(0) = NULL,
    @BitisTarih         datetime2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @BaslangicTarih = ISNULL(@BaslangicTarih, DATEADD(day, -30, SYSDATETIME()));
        SET @BitisTarih = ISNULL(@BitisTarih, SYSDATETIME());

        SELECT
            COUNT(*) AS TotalFeedback,
            SUM(CASE WHEN IsApproved = 1 THEN 1 ELSE 0 END) AS ApprovedCount,
            SUM(CASE WHEN IsApproved = 0 THEN 1 ELSE 0 END) AS RejectedCount,
            CAST(AVG(CAST(Rating AS float)) AS decimal(3,1)) AS AvgRating,
            CAST(
                CASE WHEN COUNT(*) > 0
                    THEN SUM(CASE WHEN IsApproved = 1 THEN 1.0 ELSE 0 END) / COUNT(*) * 100
                    ELSE 0
                END AS decimal(5,1)
            ) AS ApprovalRate
        FROM ai.Feedback
        WHERE CreatedAt >= @BaslangicTarih AND CreatedAt <= @BitisTarih;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 2C. ai.sp_Feedback_TopApproved — Best approved results for few-shot learning
IF OBJECT_ID('ai.sp_Feedback_TopApproved', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Feedback_TopApproved;
GO
CREATE PROCEDURE ai.sp_Feedback_TopApproved
    @Top                int = 3,
    @SkillId            varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT TOP (@Top)
            f.FeedbackId,
            f.RequestId,
            f.SkillExecutionId,
            f.Rating,
            COALESCE(
                se.OutputJson,
                lr.ExecutiveSummary
            ) AS ApprovedOutput,
            COALESCE(se.SkillId, 'analysis') AS SkillId,
            COALESCE(se.InputJson, '') AS InputContext
        FROM ai.Feedback f
        LEFT JOIN ai.SkillExecutions se ON se.ExecutionId = f.SkillExecutionId
        LEFT JOIN ai.LlmResults lr ON lr.RequestId = f.RequestId
        WHERE f.IsApproved = 1
          AND f.Rating >= 4
          AND (@SkillId IS NULL OR COALESCE(se.SkillId, 'analysis') = @SkillId)
        ORDER BY f.Rating DESC, f.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 3. STORED PROCEDURES — Proactive Insights
-- ============================================================================

-- 3A. ai.sp_Insight_Insert
IF OBJECT_ID('ai.sp_Insight_Insert', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_Insert;
GO
CREATE PROCEDURE ai.sp_Insight_Insert
    @InsightType        varchar(30),
    @Onem               varchar(10),      -- Severity
    @Baslik             nvarchar(300),     -- Title
    @Aciklama           nvarchar(2000) = NULL,
    @VarlikTipi         varchar(20),      -- EntityType
    @VarlikId           int,              -- EntityId
    @MetrikDeger        decimal(18,2) = NULL,
    @EsikDeger          decimal(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Prevent duplicate insights for same entity within 24 hours
        IF NOT EXISTS (
            SELECT 1 FROM ai.ProactiveInsights
            WHERE InsightType = @InsightType AND EntityType = @VarlikTipi AND EntityId = @VarlikId
              AND CreatedAt >= DATEADD(hour, -24, SYSDATETIME())
        )
        BEGIN
            INSERT INTO ai.ProactiveInsights (InsightType, Severity, Title, Description, EntityType, EntityId, MetricValue, ThresholdValue)
            VALUES (@InsightType, @Onem, @Baslik, @Aciklama, @VarlikTipi, @VarlikId, @MetrikDeger, @EsikDeger);

            SELECT SCOPE_IDENTITY() AS InsightId;
        END
        ELSE
            SELECT CAST(0 AS int) AS InsightId;  -- duplicate, skip
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 3B. ai.sp_Insight_List
IF OBJECT_ID('ai.sp_Insight_List', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_List;
GO
CREATE PROCEDURE ai.sp_Insight_List
    @Top                int = 50,
    @SadeceAktif        bit = 1,          -- only unactioned
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
                WHEN 'MEKAN' THEN (SELECT TOP 1 ls.LocationName FROM ref.LocationSettings ls WHERE ls.LocationId = i.EntityId)
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

-- 3C. ai.sp_Insight_Action — Mark insight as actioned
IF OBJECT_ID('ai.sp_Insight_Action', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_Action;
GO
CREATE PROCEDURE ai.sp_Insight_Action
    @InsightId          int,
    @KullaniciId        int,
    @Not                nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ai.ProactiveInsights
        SET IsActioned = 1,
            ActionedByUserId = @KullaniciId,
            ActionedAt = SYSDATETIME(),
            ActionNote = @Not
        WHERE InsightId = @InsightId AND IsActioned = 0;

        SELECT @@ROWCOUNT AS Affected;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 3D. ai.sp_Insight_Dashboard — Summary for dashboard
IF OBJECT_ID('ai.sp_Insight_Dashboard', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_Dashboard;
GO
CREATE PROCEDURE ai.sp_Insight_Dashboard
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Active insight counts by type
        SELECT
            InsightType,
            COUNT(*) AS Total,
            SUM(CASE WHEN Severity = 'KRITIK' THEN 1 ELSE 0 END) AS Kritik,
            SUM(CASE WHEN Severity = 'YUKSEK' THEN 1 ELSE 0 END) AS Yuksek,
            SUM(CASE WHEN Severity = 'ORTA' THEN 1 ELSE 0 END) AS Orta
        FROM ai.ProactiveInsights
        WHERE IsActioned = 0
        GROUP BY InsightType;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 4. STORED PROCEDURES — Skill Executions
-- ============================================================================

-- 4A. ai.sp_SkillExecution_Insert
IF OBJECT_ID('ai.sp_SkillExecution_Insert', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SkillExecution_Insert;
GO
CREATE PROCEDURE ai.sp_SkillExecution_Insert
    @SkillId            varchar(50),
    @KullaniciId        int,
    @VarlikTipi         varchar(20),
    @VarlikId           int,
    @GirdiJson          nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ai.SkillExecutions (SkillId, RequestedByUserId, EntityType, EntityId, InputJson)
        VALUES (@SkillId, @KullaniciId, @VarlikTipi, @VarlikId, @GirdiJson);

        SELECT SCOPE_IDENTITY() AS ExecutionId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 4B. ai.sp_SkillExecution_Update — Worker updates status/output
IF OBJECT_ID('ai.sp_SkillExecution_Update', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SkillExecution_Update;
GO
CREATE PROCEDURE ai.sp_SkillExecution_Update
    @ExecutionId        int,
    @Durum              varchar(20),       -- Status
    @CiktiJson          nvarchar(max) = NULL,
    @ModelAdi           varchar(100) = NULL,
    @GuvenSkoru         int = NULL,
    @HataMesaji         nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ai.SkillExecutions
        SET Status = @Durum,
            OutputJson = COALESCE(@CiktiJson, OutputJson),
            ModelName = COALESCE(@ModelAdi, ModelName),
            ConfidenceScore = COALESCE(@GuvenSkoru, ConfidenceScore),
            ErrorMessage = @HataMesaji,
            CompletedAt = CASE WHEN @Durum IN ('DONE', 'ERROR') THEN SYSDATETIME() ELSE CompletedAt END
        WHERE ExecutionId = @ExecutionId;

        SELECT @@ROWCOUNT AS Affected;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 4C. ai.sp_SkillExecution_Get
IF OBJECT_ID('ai.sp_SkillExecution_Get', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SkillExecution_Get;
GO
CREATE PROCEDURE ai.sp_SkillExecution_Get
    @ExecutionId        int
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            se.ExecutionId, se.SkillId, se.RequestedByUserId, se.EntityType, se.EntityId,
            se.Status, se.InputJson, se.OutputJson, se.ModelName, se.ConfidenceScore,
            se.ErrorMessage, se.CreatedAt, se.CompletedAt,
            u.KullaniciAdi AS RequestedByUserName
        FROM ai.SkillExecutions se
        LEFT JOIN audit.Users u ON u.UserId = se.RequestedByUserId
        WHERE se.ExecutionId = @ExecutionId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 4D. ai.sp_SkillExecution_List
IF OBJECT_ID('ai.sp_SkillExecution_List', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SkillExecution_List;
GO
CREATE PROCEDURE ai.sp_SkillExecution_List
    @Top                int = 50,
    @SkillId            varchar(50) = NULL,
    @VarlikTipi         varchar(20) = NULL,
    @VarlikId           int = NULL,
    @Durum              varchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT TOP (@Top)
            se.ExecutionId, se.SkillId, se.RequestedByUserId, se.EntityType, se.EntityId,
            se.Status, se.ModelName, se.ConfidenceScore, se.ErrorMessage,
            se.CreatedAt, se.CompletedAt,
            u.KullaniciAdi AS RequestedByUserName
        FROM ai.SkillExecutions se
        LEFT JOIN audit.Users u ON u.UserId = se.RequestedByUserId
        WHERE (@SkillId IS NULL OR se.SkillId = @SkillId)
          AND (@VarlikTipi IS NULL OR se.EntityType = @VarlikTipi)
          AND (@VarlikId IS NULL OR se.EntityId = @VarlikId)
          AND (@Durum IS NULL OR se.Status = @Durum)
        ORDER BY se.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 4E. ai.sp_SkillExecution_Pending — Worker picks up QUEUED items (safe dequeue)
IF OBJECT_ID('ai.sp_SkillExecution_Pending', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SkillExecution_Pending;
GO
CREATE PROCEDURE ai.sp_SkillExecution_Pending
    @Top                int = 10
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        ;WITH cte AS (
            SELECT TOP (@Top) *
            FROM ai.SkillExecutions WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE Status = 'QUEUED'
            ORDER BY CreatedAt
        )
        UPDATE cte
        SET Status = 'RUNNING'
        OUTPUT
            inserted.ExecutionId,
            inserted.SkillId,
            inserted.RequestedByUserId,
            inserted.EntityType,
            inserted.EntityId,
            inserted.InputJson,
            inserted.CreatedAt;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 5. INSIGHT DETECTION SPs — Called by ProactiveInsightJob
-- ============================================================================

-- 5A. ai.sp_Insight_DenetimPlanla — Suggest audit for locations with no recent audit + high ERP risk
IF OBJECT_ID('ai.sp_Insight_DenetimPlanla', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_DenetimPlanla;
GO
CREATE PROCEDURE ai.sp_Insight_DenetimPlanla
    @GunEsik            int = 30,         -- days since last audit
    @RiskEsik           int = 60          -- min ERP risk score
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Find locations: no audit in @GunEsik days AND ERP risk >= @RiskEsik
        ;WITH LocationLastAudit AS (
            SELECT a.LocationId, MAX(a.AuditDate) AS LastAuditDate
            FROM audit.Audits a
            WHERE a.Status = 'KESINLESMIS'
            GROUP BY a.LocationId
        ),
        LocationRisk AS (
            SELECT r.LocationId, AVG(r.RiskScore) AS AvgRisk
            FROM rpt.DailyProductRisk r
            WHERE r.SnapshotDate >= DATEADD(day, -7, CAST(SYSDATETIME() AS date))
            GROUP BY r.LocationId
            HAVING AVG(r.RiskScore) >= @RiskEsik
        )
        INSERT INTO ai.ProactiveInsights (InsightType, Severity, Title, Description, EntityType, EntityId, MetricValue, ThresholdValue)
        SELECT
            'DENETIM_PLANLA',
            CASE WHEN lr.AvgRisk >= 80 THEN 'KRITIK' WHEN lr.AvgRisk >= 70 THEN 'YUKSEK' ELSE 'ORTA' END,
            N'Denetim Planlanmali: ' + ISNULL(ls.LocationName, N'Mekan #' + CAST(lr.LocationId AS nvarchar(10))),
            N'Son denetim: ' +
                CASE
                    WHEN la.LastAuditDate IS NULL THEN N'Hic denetlenmemis'
                    ELSE FORMAT(la.LastAuditDate, 'dd.MM.yyyy') + N' (' + CAST(DATEDIFF(day, la.LastAuditDate, SYSDATETIME()) AS nvarchar(10)) + N' gun once)'
                END +
                N'. Ortalama ERP risk skoru: ' + CAST(CAST(lr.AvgRisk AS int) AS nvarchar(10)),
            'MEKAN',
            lr.LocationId,
            lr.AvgRisk,
            @RiskEsik
        FROM LocationRisk lr
        LEFT JOIN LocationLastAudit la ON la.LocationId = lr.LocationId
        LEFT JOIN ref.LocationSettings ls ON ls.LocationId = lr.LocationId
        WHERE (la.LastAuditDate IS NULL OR DATEDIFF(day, la.LastAuditDate, SYSDATETIME()) >= @GunEsik)
          -- Avoid duplicates within 24h
          AND NOT EXISTS (
              SELECT 1 FROM ai.ProactiveInsights p
              WHERE p.InsightType = 'DENETIM_PLANLA' AND p.EntityType = 'MEKAN' AND p.EntityId = lr.LocationId
                AND p.CreatedAt >= DATEADD(hour, -24, SYSDATETIME())
          );

        SELECT @@ROWCOUNT AS InsertedCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 5B. ai.sp_Insight_TrendUyari — Alert for declining compliance trend
IF OBJECT_ID('ai.sp_Insight_TrendUyari', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_TrendUyari;
GO
CREATE PROCEDURE ai.sp_Insight_TrendUyari
    @DusisEsik          decimal(5,1) = 10.0   -- minimum % drop to trigger
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Compare current quarter avg compliance vs previous quarter
        ;WITH QuarterlyCompliance AS (
            SELECT
                a.LocationId,
                CASE
                    WHEN a.AuditDate >= DATEADD(month, -3, SYSDATETIME()) THEN 'CURRENT'
                    WHEN a.AuditDate >= DATEADD(month, -6, SYSDATETIME()) THEN 'PREVIOUS'
                END AS Period,
                AVG(ar.ComplianceRate) AS AvgCompliance
            FROM audit.Audits a
            INNER JOIN (
                SELECT AuditId,
                    CAST(SUM(CASE WHEN IsCompliant = 1 THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100 AS decimal(5,1)) AS ComplianceRate
                FROM audit.AuditResults
                GROUP BY AuditId
            ) ar ON ar.AuditId = a.AuditId
            WHERE a.Status = 'KESINLESMIS'
              AND a.AuditDate >= DATEADD(month, -6, SYSDATETIME())
            GROUP BY a.LocationId,
                CASE
                    WHEN a.AuditDate >= DATEADD(month, -3, SYSDATETIME()) THEN 'CURRENT'
                    WHEN a.AuditDate >= DATEADD(month, -6, SYSDATETIME()) THEN 'PREVIOUS'
                END
        ),
        TrendDrop AS (
            SELECT
                c.LocationId,
                c.AvgCompliance AS CurrentRate,
                p.AvgCompliance AS PreviousRate,
                p.AvgCompliance - c.AvgCompliance AS DropAmount
            FROM QuarterlyCompliance c
            INNER JOIN QuarterlyCompliance p ON c.LocationId = p.LocationId AND p.Period = 'PREVIOUS'
            WHERE c.Period = 'CURRENT'
              AND p.AvgCompliance - c.AvgCompliance >= @DusisEsik
        )
        INSERT INTO ai.ProactiveInsights (InsightType, Severity, Title, Description, EntityType, EntityId, MetricValue, ThresholdValue)
        SELECT
            'TREND_UYARI',
            CASE WHEN td.DropAmount >= 20 THEN 'KRITIK' WHEN td.DropAmount >= 15 THEN 'YUKSEK' ELSE 'ORTA' END,
            N'Uyum Dususu: ' + ISNULL(ls.LocationName, N'Mekan #' + CAST(td.LocationId AS nvarchar(10))),
            N'Uyum orani %%' + CAST(CAST(td.PreviousRate AS int) AS nvarchar(5)) +
                N' -> %%' + CAST(CAST(td.CurrentRate AS int) AS nvarchar(5)) +
                N' (%%' + CAST(CAST(td.DropAmount AS int) AS nvarchar(5)) + N' dusus)',
            'MEKAN',
            td.LocationId,
            td.DropAmount,
            @DusisEsik
        FROM TrendDrop td
        LEFT JOIN ref.LocationSettings ls ON ls.LocationId = td.LocationId
        WHERE NOT EXISTS (
            SELECT 1 FROM ai.ProactiveInsights p
            WHERE p.InsightType = 'TREND_UYARI' AND p.EntityType = 'MEKAN' AND p.EntityId = td.LocationId
              AND p.CreatedAt >= DATEADD(hour, -24, SYSDATETIME())
        );

        SELECT @@ROWCOUNT AS InsertedCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 5C. ai.sp_Insight_AnomaliTespit — Detect risk anomalies (2 std deviations)
IF OBJECT_ID('ai.sp_Insight_AnomaliTespit', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Insight_AnomaliTespit;
GO
CREATE PROCEDURE ai.sp_Insight_AnomaliTespit
    @SapmaCarpani       decimal(3,1) = 2.0   -- std deviation multiplier
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Compare today's risk with 90-day mean ± @SapmaCarpani * stddev
        ;WITH Stats AS (
            SELECT
                LocationId,
                ProductId,
                AVG(CAST(RiskScore AS float)) AS MeanRisk,
                STDEV(CAST(RiskScore AS float)) AS StdRisk,
                COUNT(*) AS DataPoints
            FROM rpt.DailyProductRisk
            WHERE SnapshotDate >= DATEADD(day, -90, CAST(SYSDATETIME() AS date))
              AND SnapshotDate < CAST(SYSDATETIME() AS date)  -- exclude today
            GROUP BY LocationId, ProductId
            HAVING COUNT(*) >= 10  -- need enough data
        ),
        TodayRisk AS (
            SELECT LocationId, ProductId, RiskScore
            FROM rpt.DailyProductRisk
            WHERE SnapshotDate = CAST(SYSDATETIME() AS date)
        ),
        Anomalies AS (
            SELECT
                t.LocationId, t.ProductId, t.RiskScore,
                s.MeanRisk, s.StdRisk,
                (t.RiskScore - s.MeanRisk) / NULLIF(s.StdRisk, 0) AS ZScore
            FROM TodayRisk t
            INNER JOIN Stats s ON s.LocationId = t.LocationId AND s.ProductId = t.ProductId
            WHERE s.StdRisk > 0
              AND ABS(t.RiskScore - s.MeanRisk) > @SapmaCarpani * s.StdRisk
        )
        INSERT INTO ai.ProactiveInsights (InsightType, Severity, Title, Description, EntityType, EntityId, MetricValue, ThresholdValue)
        SELECT
            'ANOMALI_TESPIT',
            CASE WHEN a.ZScore >= 3 THEN 'KRITIK' WHEN a.ZScore >= 2.5 THEN 'YUKSEK' ELSE 'ORTA' END,
            N'Risk Anomalisi: Mekan ' + CAST(a.LocationId AS nvarchar(10)) + N', Urun ' + CAST(a.ProductId AS nvarchar(10)),
            N'Gunluk risk: ' + CAST(a.RiskScore AS nvarchar(10)) +
                N', 90-gun ortalama: ' + CAST(CAST(a.MeanRisk AS int) AS nvarchar(10)) +
                N', Z-skor: ' + CAST(CAST(a.ZScore AS decimal(4,1)) AS nvarchar(10)),
            'URUN',
            a.ProductId,
            a.RiskScore,
            CAST(a.MeanRisk + @SapmaCarpani * a.StdRisk AS decimal(18,2))
        FROM Anomalies a
        WHERE NOT EXISTS (
            SELECT 1 FROM ai.ProactiveInsights p
            WHERE p.InsightType = 'ANOMALI_TESPIT' AND p.EntityType = 'URUN' AND p.EntityId = a.ProductId
              AND p.CreatedAt >= DATEADD(hour, -24, SYSDATETIME())
        );

        SELECT @@ROWCOUNT AS InsertedCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 6. DASHBOARD SPs
-- ============================================================================

-- 6A. ai.sp_AiDashboard_Kpi — AI KPI summary
IF OBJECT_ID('ai.sp_AiDashboard_Kpi', 'P') IS NOT NULL DROP PROCEDURE ai.sp_AiDashboard_Kpi;
GO
CREATE PROCEDURE ai.sp_AiDashboard_Kpi
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            (SELECT COUNT(*) FROM ai.ProactiveInsights WHERE IsActioned = 0) AS ActiveInsights,
            (SELECT CAST(
                CASE WHEN COUNT(*) > 0
                    THEN SUM(CASE WHEN IsApproved = 1 THEN 1.0 ELSE 0 END) / COUNT(*) * 100
                    ELSE 0
                END AS decimal(5,1))
             FROM ai.Feedback
             WHERE CreatedAt >= DATEADD(day, -30, SYSDATETIME())) AS ApprovalRate,
            (SELECT COUNT(*) FROM ai.SkillExecutions
             WHERE CreatedAt >= DATEADD(day, -7, SYSDATETIME())) AS WeeklyExecutions,
            (SELECT CAST(AVG(CAST(ConfidenceScore AS float)) AS int)
             FROM ai.SkillExecutions
             WHERE Status = 'DONE' AND ConfidenceScore IS NOT NULL
               AND CreatedAt >= DATEADD(day, -30, SYSDATETIME())) AS AvgConfidence;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 6B. ai.sp_AiDashboard_FeedbackTrend — Weekly feedback trend
IF OBJECT_ID('ai.sp_AiDashboard_FeedbackTrend', 'P') IS NOT NULL DROP PROCEDURE ai.sp_AiDashboard_FeedbackTrend;
GO
CREATE PROCEDURE ai.sp_AiDashboard_FeedbackTrend
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        ;WITH Weeks AS (
            SELECT 0 AS WeekOffset UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
            UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
        )
        SELECT
            DATEADD(week, -w.WeekOffset, CAST(SYSDATETIME() AS date)) AS WeekStart,
            COUNT(f.FeedbackId) AS Total,
            SUM(CASE WHEN f.IsApproved = 1 THEN 1 ELSE 0 END) AS Approved,
            SUM(CASE WHEN f.IsApproved = 0 THEN 1 ELSE 0 END) AS Rejected
        FROM Weeks w
        LEFT JOIN ai.Feedback f ON f.CreatedAt >= DATEADD(week, -w.WeekOffset - 1, CAST(SYSDATETIME() AS date))
            AND f.CreatedAt < DATEADD(week, -w.WeekOffset, CAST(SYSDATETIME() AS date))
        GROUP BY w.WeekOffset
        ORDER BY w.WeekOffset;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 6C. ai.sp_AiDashboard_SkillHistory — Recent skill executions
IF OBJECT_ID('ai.sp_AiDashboard_SkillHistory', 'P') IS NOT NULL DROP PROCEDURE ai.sp_AiDashboard_SkillHistory;
GO
CREATE PROCEDURE ai.sp_AiDashboard_SkillHistory
    @Top                int = 10
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT TOP (@Top)
            se.ExecutionId, se.SkillId, se.EntityType, se.EntityId,
            se.Status, se.ModelName, se.ConfidenceScore,
            se.CreatedAt, se.CompletedAt,
            u.KullaniciAdi AS RequestedByUserName
        FROM ai.SkillExecutions se
        LEFT JOIN audit.Users u ON u.UserId = se.RequestedByUserId
        ORDER BY se.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 7. HELPER SPs
-- ============================================================================

-- 7A. ai.sp_SemanticVector_UpsertGolden — Store approved results as golden memory vectors
IF OBJECT_ID('ai.sp_SemanticVector_UpsertGolden', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SemanticVector_UpsertGolden;
GO
CREATE PROCEDURE ai.sp_SemanticVector_UpsertGolden
    @SourceId           int,               -- FeedbackId
    @Baslik             nvarchar(500),     -- Title
    @Ozet               nvarchar(4000),    -- Summary text
    @VectorJson         nvarchar(max),     -- embedding vector
    @Kritik             bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM ai.SemanticVectors WHERE SourceId = @SourceId AND Source = 'GOLDEN')
        BEGIN
            UPDATE ai.SemanticVectors
            SET Title = @Baslik, SummaryText = @Ozet, VectorJson = @VectorJson,
                IsCritical = @Kritik, Weight = 5.0
            WHERE SourceId = @SourceId AND Source = 'GOLDEN';
        END
        ELSE
        BEGIN
            INSERT INTO ai.SemanticVectors (SourceId, Title, SummaryText, VectorJson, IsCritical, Weight, Source)
            VALUES (@SourceId, @Baslik, @Ozet, @VectorJson, @Kritik, 5.0, 'GOLDEN');
        END

        SELECT @@ROWCOUNT AS Affected;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 7B. Update existing sp_SemanticVector_List to return Weight
-- We need to check if the SP already returns Weight
IF OBJECT_ID('ai.sp_SemanticVector_ListWeighted', 'P') IS NOT NULL DROP PROCEDURE ai.sp_SemanticVector_ListWeighted;
GO
CREATE PROCEDURE ai.sp_SemanticVector_ListWeighted
    @Top                int = 500
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT TOP (@Top)
            VectorId, SourceId, DofId, Title, SummaryText, IsCritical, VectorJson,
            Weight, Source
        FROM ai.SemanticVectors
        WHERE VectorJson IS NOT NULL
        ORDER BY Weight DESC, VectorId DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 8. POST-RISK-ETL TRIGGER SP
-- ============================================================================

IF OBJECT_ID('ai.sp_Trigger_PostRiskEtl', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Trigger_PostRiskEtl;
GO
CREATE PROCEDURE ai.sp_Trigger_PostRiskEtl
    @RiskEsik           int = 85
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- After daily risk ETL, queue high-risk items for AI analysis
        INSERT INTO ai.AnalysisQueue (SnapshotDate, LocationId, ProductId, SourceType, SourceKey, Priority, Status)
        SELECT DISTINCT
            r.SnapshotDate,
            r.LocationId,
            r.ProductId,
            'ETL_TRIGGER',
            CAST(r.LocationId AS varchar(20)) + '_' + CAST(r.ProductId AS varchar(20)),
            CASE WHEN r.RiskScore >= 90 THEN 90 ELSE 70 END,
            'NEW'
        FROM rpt.DailyProductRisk r
        WHERE r.SnapshotDate = CAST(SYSDATETIME() AS date)
          AND r.RiskScore >= @RiskEsik
          AND NOT EXISTS (
              SELECT 1 FROM ai.AnalysisQueue aq
              WHERE aq.LocationId = r.LocationId AND aq.ProductId = r.ProductId
                AND aq.SnapshotDate = r.SnapshotDate
          );

        SELECT @@ROWCOUNT AS QueuedCount;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

PRINT '48_ai_feedback_insights.sql completed successfully';
GO
