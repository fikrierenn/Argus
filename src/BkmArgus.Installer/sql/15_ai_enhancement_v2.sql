/* 15_ai_enhancement_v2.sql
   BKMDenetim AI Geliştirme V2 - Veritabanı Şeması
   Bu script AI sistemini V1'den V2'ye geçiş için gerekli tüm tablo ve SP'leri içerir
*/
USE BKMDenetim;
GO

-- =============================================================================
-- FAZ 1: TEMEL ALTYAPI GÜÇLENDİRME
-- =============================================================================

/* Migrasyon takip tablosu */
IF OBJECT_ID(N'ai.AiMigrationStatus', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiMigrationStatus (
        MigrationId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ComponentName varchar(100) NOT NULL,
        OldVersion varchar(20) NOT NULL,
        NewVersion varchar(20) NOT NULL,
        MigrationDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        Status varchar(20) NOT NULL DEFAULT 'PENDING', -- BEKLEMEDE, DEVAM_EDIYOR, TAMAMLANDI, BASARISIZ
        RecordsProcessed int DEFAULT 0,
        TotalRecords int DEFAULT 0,
        ErrorMessage nvarchar(max) NULL,
        StartTime datetime2(0) NULL,
        EndTime datetime2(0) NULL
    );
END
GO

-- =============================================================================
-- FAZ 2: ÇOK BOYUTLU SEMANTİK HAFIZA SİSTEMİ
-- =============================================================================

/* Gelişmiş Çok Boyutlu Embedding Depolama */
IF OBJECT_ID(N'ai.AiMultiModalEmbedding', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiMultiModalEmbedding (
        EmbeddingId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RiskId bigint NOT NULL,
        DofId bigint NULL,
        
        -- Multi-modal embedding types
        RiskPatternEmbedding nvarchar(max) NULL,    -- Risk pattern vectors
        MetricEmbedding nvarchar(max) NULL,         -- Numerical metric vectors  
        TemporalEmbedding nvarchar(max) NULL,       -- Time-based pattern vectors
        ContextEmbedding nvarchar(max) NULL,        -- Contextual information vectors
        
        -- Embedding metadata
        EmbeddingModel varchar(100) NOT NULL,
        EmbeddingVersion varchar(20) NOT NULL,
        VectorDimension int NOT NULL,
        
        -- Memory layer classification
        MemoryLayer varchar(10) NOT NULL DEFAULT 'HOT', -- HOT, WARM, COLD
        AccessCount int NOT NULL DEFAULT 0,
        LastAccessTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        -- Quality metrics
        QualityScore decimal(5,2) NULL,
        ConfidenceScore decimal(5,2) NULL,
        
        -- Metadata
        SourceMetadata nvarchar(max) NULL,
        Tags nvarchar(500) NULL,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT FK_AiMultiModalEmbedding_Dof FOREIGN KEY (DofId) REFERENCES dof.DofKayit(DofId)
    );
    
    CREATE INDEX IX_AiMultiModalEmbedding_RiskId ON ai.AiMultiModalEmbedding (RiskId);
    CREATE INDEX IX_AiMultiModalEmbedding_MemoryLayer ON ai.AiMultiModalEmbedding (MemoryLayer, LastAccessTime);
    CREATE INDEX IX_AiMultiModalEmbedding_Model ON ai.AiMultiModalEmbedding (EmbeddingModel, EmbeddingVersion);
END
GO

/* Hierarchical Memory Management */
IF OBJECT_ID(N'ai.AiMemoryLayerConfig', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiMemoryLayerConfig (
        LayerId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        LayerName varchar(10) NOT NULL UNIQUE, -- HOT, WARM, COLD
        RetentionDays int NOT NULL,
        MaxCapacity int NOT NULL,
        AccessThreshold int NOT NULL,
        CompressionEnabled bit NOT NULL DEFAULT 0,
        AutoArchiveEnabled bit NOT NULL DEFAULT 1,
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    -- Insert default configurations
    INSERT INTO ai.AiMemoryLayerConfig (LayerName, RetentionDays, MaxCapacity, AccessThreshold)
    VALUES 
        ('HOT', 30, 10000, 5),
        ('WARM', 365, 50000, 2),
        ('COLD', 1825, 100000, 1);
END
GO

/* Adaptive Similarity Thresholds */
IF OBJECT_ID(N'ai.AiSimilarityThreshold', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiSimilarityThreshold (
        ThresholdId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RiskType varchar(50) NOT NULL,
        EmbeddingType varchar(50) NOT NULL, -- RISK_PATTERN, METRIC, TEMPORAL, CONTEXT
        BaseThreshold decimal(5,4) NOT NULL,
        AdaptiveThreshold decimal(5,4) NOT NULL,
        ConfidenceLevel decimal(5,2) NOT NULL,
        LastUpdateDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdateCount int NOT NULL DEFAULT 0,
        PerformanceScore decimal(5,2) NULL,
        IsActive bit NOT NULL DEFAULT 1
    );
    
    CREATE UNIQUE INDEX UX_AiSimilarityThreshold ON ai.AiSimilarityThreshold (RiskType, EmbeddingType);
END
GO

-- =============================================================================
-- FAZ 3: MULTI-AGENT LLM SYSTEM
-- =============================================================================

/* Agent Configuration */
IF OBJECT_ID(N'ai.AiAgentConfig', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAgentConfig (
        AgentId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AgentName varchar(100) NOT NULL UNIQUE,
        AgentType varchar(50) NOT NULL, -- RISK_ANALYST, ROOT_CAUSE_EXPERT, ACTION_PLANNER, QUALITY_ASSURANCE
        ModelName varchar(100) NOT NULL,
        Temperature decimal(3,2) NOT NULL,
        MaxTokens int NOT NULL,
        ExecutionOrder int NOT NULL,
        IsActive bit NOT NULL DEFAULT 1,
        
        -- Agent-specific parameters
        SpecialtyArea varchar(100) NULL,
        PromptTemplate nvarchar(max) NULL,
        SystemPrompt nvarchar(max) NULL,
        
        -- Performance settings
        TimeoutSeconds int NOT NULL DEFAULT 300,
        RetryCount int NOT NULL DEFAULT 3,
        
        -- Metadata
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    -- Insert default agents
    INSERT INTO ai.AiAgentConfig (AgentName, AgentType, ModelName, Temperature, MaxTokens, ExecutionOrder, SpecialtyArea)
    VALUES 
        ('RiskAnalyst', 'RISK_ANALYST', 'llama3.1:70b', 0.3, 8000, 1, 'RISK_ANALYSIS'),
        ('RootCauseExpert', 'ROOT_CAUSE_EXPERT', 'mixtral:8x7b', 0.5, 6000, 2, 'ROOT_CAUSE_ANALYSIS'),
        ('ActionPlanner', 'ACTION_PLANNER', 'llama3.1:8b', 0.7, 4000, 3, 'ACTION_PLANNING'),
        ('QualityAssurance', 'QUALITY_ASSURANCE', 'phi3.5', 0.2, 2000, 4, 'QUALITY_CONTROL');
END
GO

/* Agent Execution Results */
IF OBJECT_ID(N'ai.AiAgentExecution', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAgentExecution (
        ExecutionId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RequestId bigint NOT NULL,
        AgentId int NOT NULL,
        
        -- Execution details
        StartTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        EndTime datetime2(0) NULL,
        Status varchar(20) NOT NULL DEFAULT 'RUNNING', -- RUNNING, COMPLETED, FAILED, TIMEOUT
        
        -- Input/Output
        InputData nvarchar(max) NULL,
        OutputData nvarchar(max) NULL,
        ErrorMessage nvarchar(max) NULL,
        
        -- Performance metrics
        ExecutionTimeMs int NULL,
        TokensUsed int NULL,
        ConfidenceScore decimal(5,2) NULL,
        QualityScore decimal(5,2) NULL,
        
        -- Inter-agent communication
        PreviousAgentOutput nvarchar(max) NULL,
        NextAgentInput nvarchar(max) NULL,
        
        CONSTRAINT FK_AiAgentExecution_Request FOREIGN KEY (RequestId) REFERENCES ai.AiAnalizIstegi(IstekId),
        CONSTRAINT FK_AiAgentExecution_Agent FOREIGN KEY (AgentId) REFERENCES ai.AiAgentConfig(AgentId)
    );
    
    CREATE INDEX IX_AiAgentExecution_Request ON ai.AiAgentExecution (RequestId, AgentId);
    CREATE INDEX IX_AiAgentExecution_Status ON ai.AiAgentExecution (Status, StartTime);
END
GO

/* Agent Pipeline Orchestration */
IF OBJECT_ID(N'ai.AiAgentPipeline', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAgentPipeline (
        PipelineId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RequestId bigint NOT NULL,
        
        -- Pipeline status
        Status varchar(20) NOT NULL DEFAULT 'PENDING', -- PENDING, RUNNING, COMPLETED, FAILED
        StartTime datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        EndTime datetime2(0) NULL,
        
        -- Pipeline configuration
        PipelineConfig nvarchar(max) NULL,
        AgentSequence varchar(500) NULL, -- Comma-separated agent IDs
        
        -- Results aggregation
        FinalOutput nvarchar(max) NULL,
        QualityAssessment nvarchar(max) NULL,
        OverallConfidence decimal(5,2) NULL,
        
        -- Performance metrics
        TotalExecutionTimeMs int NULL,
        TotalTokensUsed int NULL,
        
        CONSTRAINT FK_AiAgentPipeline_Request FOREIGN KEY (RequestId) REFERENCES ai.AiAnalizIstegi(IstekId)
    );
    
    CREATE INDEX IX_AiAgentPipeline_Request ON ai.AiAgentPipeline (RequestId);
    CREATE INDEX IX_AiAgentPipeline_Status ON ai.AiAgentPipeline (Status, StartTime);
END
GO

-- =============================================================================
-- FAZ 4: REAL-TIME LEARNING PIPELINE
-- =============================================================================

/* Enhanced Feedback System */
IF OBJECT_ID(N'ai.AiEnhancedFeedback', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiEnhancedFeedback (
        FeedbackId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RequestId bigint NOT NULL,
        ExecutionId bigint NULL,
        
        -- Multi-dimensional feedback
        AccuracyScore decimal(5,2) NOT NULL,
        RelevanceScore decimal(5,2) NOT NULL,
        CompletenessScore decimal(5,2) NOT NULL,
        ActionabilityScore decimal(5,2) NOT NULL,
        ExplanationQualityScore decimal(5,2) NOT NULL,
        
        -- Overall assessment
        OverallScore decimal(5,2) NOT NULL,
        WeightedScore decimal(5,2) NOT NULL,
        
        -- Detailed feedback
        CorrectRootCause varchar(100) NULL,
        MissedFactors nvarchar(max) NULL,
        ImprovementSuggestions nvarchar(max) NULL,
        
        -- Feedback metadata
        FeedbackProvider varchar(100) NOT NULL,
        FeedbackDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        FeedbackType varchar(50) NOT NULL, -- MANUAL, AUTOMATED, OUTCOME_BASED
        
        -- Learning integration
        IntegratedIntoModel bit NOT NULL DEFAULT 0,
        IntegrationDate datetime2(0) NULL,
        
        CONSTRAINT FK_AiEnhancedFeedback_Request FOREIGN KEY (RequestId) REFERENCES ai.AiAnalizIstegi(IstekId),
        CONSTRAINT FK_AiEnhancedFeedback_Execution FOREIGN KEY (ExecutionId) REFERENCES ai.AiAgentExecution(ExecutionId)
    );
    
    CREATE INDEX IX_AiEnhancedFeedback_Request ON ai.AiEnhancedFeedback (RequestId);
    CREATE INDEX IX_AiEnhancedFeedback_Integration ON ai.AiEnhancedFeedback (IntegratedIntoModel, IntegrationDate);
END
GO

/* Model Performance Tracking */
IF OBJECT_ID(N'ai.AiModelPerformance', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiModelPerformance (
        PerformanceId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModelName varchar(100) NOT NULL,
        ModelVersion varchar(50) NOT NULL,
        AgentType varchar(50) NULL,
        
        -- Performance metrics
        MeasurementDate date NOT NULL,
        TotalRequests int NOT NULL,
        SuccessfulRequests int NOT NULL,
        FailedRequests int NOT NULL,
        
        -- Quality metrics
        AverageAccuracy decimal(5,2) NULL,
        AverageConfidence decimal(5,2) NULL,
        AverageResponseTime int NULL, -- milliseconds
        
        -- Learning metrics
        FeedbackCount int NOT NULL DEFAULT 0,
        PositiveFeedbackCount int NOT NULL DEFAULT 0,
        ImprovementRate decimal(5,2) NULL,
        
        -- Resource usage
        TotalTokensUsed bigint NULL,
        AverageTokensPerRequest int NULL,
        
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    CREATE UNIQUE INDEX UX_AiModelPerformance ON ai.AiModelPerformance (ModelName, ModelVersion, MeasurementDate, AgentType);
END
GO

/* Adaptive Learning Configuration */
IF OBJECT_ID(N'ai.AiLearningConfig', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiLearningConfig (
        ConfigId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ConfigName varchar(100) NOT NULL UNIQUE,
        
        -- Learning parameters
        LearningRate decimal(6,4) NOT NULL DEFAULT 0.01,
        MinAccuracyThreshold decimal(5,2) NOT NULL DEFAULT 0.75,
        UpdateFrequency varchar(20) NOT NULL DEFAULT 'DAILY', -- REAL_TIME, HOURLY, DAILY, WEEKLY
        
        -- Feedback weights
        AccuracyWeight decimal(3,2) NOT NULL DEFAULT 0.30,
        RelevanceWeight decimal(3,2) NOT NULL DEFAULT 0.25,
        CompletenessWeight decimal(3,2) NOT NULL DEFAULT 0.20,
        ActionabilityWeight decimal(3,2) NOT NULL DEFAULT 0.15,
        ExplanationWeight decimal(3,2) NOT NULL DEFAULT 0.10,
        
        -- Adaptation settings
        AdaptationEnabled bit NOT NULL DEFAULT 1,
        AutoRetrainingEnabled bit NOT NULL DEFAULT 0,
        
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    -- Insert default configuration
    INSERT INTO ai.AiLearningConfig (ConfigName) VALUES ('DEFAULT');
END
GO

-- =============================================================================
-- FAZ 5: PREDICTIVE ANALYTICS SYSTEM
-- =============================================================================

/* Time Series Prediction Models */
IF OBJECT_ID(N'ai.AiPredictionModel', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiPredictionModel (
        ModelId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModelName varchar(100) NOT NULL,
        ModelType varchar(50) NOT NULL, -- ARIMA, LSTM, PROPHET, ENSEMBLE
        
        -- Model configuration
        ModelParameters nvarchar(max) NULL, -- JSON configuration
        TrainingDataPeriod int NOT NULL, -- days
        PredictionHorizon int NOT NULL, -- days
        
        -- Performance metrics
        Accuracy decimal(5,2) NULL,
        MAE decimal(10,4) NULL, -- Mean Absolute Error
        RMSE decimal(10,4) NULL, -- Root Mean Square Error
        
        -- Model status
        Status varchar(20) NOT NULL DEFAULT 'TRAINING', -- TRAINING, ACTIVE, DEPRECATED
        LastTrainingDate datetime2(0) NULL,
        NextRetrainingDate datetime2(0) NULL,
        
        IsActive bit NOT NULL DEFAULT 1,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        UpdatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME()
    );
    
    -- Insert default models
    INSERT INTO ai.AiPredictionModel (ModelName, ModelType, TrainingDataPeriod, PredictionHorizon, ModelParameters)
    VALUES 
        ('ARIMA_7Day', 'ARIMA', 90, 7, '{"p": 2, "d": 1, "q": 2}'),
        ('LSTM_14Day', 'LSTM', 180, 14, '{"units": 50, "dropout": 0.2}'),
        ('Prophet_30Day', 'PROPHET', 365, 30, '{"seasonality_mode": "multiplicative"}'),
        ('Ensemble_7Day', 'ENSEMBLE', 90, 7, '{"models": ["ARIMA", "LSTM"], "weights": [0.6, 0.4]}');
END
GO

/* Risk Predictions */
IF OBJECT_ID(N'ai.AiRiskPrediction', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiRiskPrediction (
        PredictionId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ModelId int NOT NULL,
        
        -- Prediction target
        MekanId int NOT NULL,
        StokId int NULL, -- NULL for mekan-level predictions
        RiskType varchar(50) NOT NULL,
        
        -- Prediction details
        PredictionDate date NOT NULL,
        TargetDate date NOT NULL,
        PredictedValue decimal(10,4) NOT NULL,
        ConfidenceInterval_Lower decimal(10,4) NULL,
        ConfidenceInterval_Upper decimal(10,4) NULL,
        ConfidenceScore decimal(5,2) NOT NULL,
        
        -- Actual outcome (for validation)
        ActualValue decimal(10,4) NULL,
        ActualDate date NULL,
        PredictionError decimal(10,4) NULL,
        
        -- Metadata
        PredictionMetadata nvarchar(max) NULL,
        CreatedDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT FK_AiRiskPrediction_Model FOREIGN KEY (ModelId) REFERENCES ai.AiPredictionModel(ModelId)
    );
    
    CREATE INDEX IX_AiRiskPrediction_Target ON ai.AiRiskPrediction (MekanId, StokId, TargetDate);
    CREATE INDEX IX_AiRiskPrediction_Model ON ai.AiRiskPrediction (ModelId, PredictionDate);
END
GO

/* Anomaly Detection */
IF OBJECT_ID(N'ai.AiAnomalyDetection', N'U') IS NULL
BEGIN
    CREATE TABLE ai.AiAnomalyDetection (
        AnomalyId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        
        -- Detection target
        MekanId int NOT NULL,
        StokId int NULL,
        DetectionDate datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        -- Anomaly details
        AnomalyType varchar(50) NOT NULL, -- STATISTICAL, ML_BASED, PATTERN_BASED
        AnomalyScore decimal(5,2) NOT NULL,
        Severity varchar(20) NOT NULL, -- LOW, MEDIUM, HIGH, CRITICAL
        
        -- Detection method
        DetectionMethod varchar(50) NOT NULL, -- Z_SCORE, IQR, ISOLATION_FOREST, AUTOENCODER
        DetectionParameters nvarchar(max) NULL,
        
        -- Anomaly description
        AnomalyDescription nvarchar(max) NULL,
        AffectedMetrics nvarchar(500) NULL,
        
        -- Investigation status
        Status varchar(20) NOT NULL DEFAULT 'NEW', -- NEW, INVESTIGATING, RESOLVED, FALSE_POSITIVE
        InvestigatedBy varchar(100) NULL,
        InvestigationNotes nvarchar(max) NULL,
        ResolutionDate datetime2(0) NULL,
        
        -- Related entities
        RelatedDofId bigint NULL,
        RelatedRequestId bigint NULL,
        
        CONSTRAINT FK_AiAnomalyDetection_Dof FOREIGN KEY (RelatedDofId) REFERENCES dof.DofKayit(DofId),
        CONSTRAINT FK_AiAnomalyDetection_Request FOREIGN KEY (RelatedRequestId) REFERENCES ai.AiAnalizIstegi(IstekId)
    );
    
    CREATE INDEX IX_AiAnomalyDetection_Target ON ai.AiAnomalyDetection (MekanId, StokId, DetectionDate);
    CREATE INDEX IX_AiAnomalyDetection_Status ON ai.AiAnomalyDetection (Status, Severity);
END
GO

-- =============================================================================
-- BACKWARD COMPATIBILITY VIEWS
-- =============================================================================

/* Legacy compatibility view for AiGecmisVektorler */
IF OBJECT_ID(N'ai.vw_AiGecmisVektorler_Legacy', N'V') IS NOT NULL DROP VIEW ai.vw_AiGecmisVektorler_Legacy;
GO
CREATE VIEW ai.vw_AiGecmisVektorler_Legacy
AS
SELECT 
    VektorId,
    RiskId,
    DofId,
    Baslik,
    OzetMetin,
    KritikMi,
    VektorJson,
    OlusturmaTarihi
FROM ai.AiGecmisVektorler
WHERE 1=1; -- Placeholder for future filtering
GO

-- =============================================================================
-- ENHANCED STORED PROCEDURES
-- =============================================================================

/* Multi-Modal Embedding Management */
IF OBJECT_ID(N'ai.sp_AiMultiModal_Upsert', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiMultiModal_Upsert;
GO
CREATE PROCEDURE ai.sp_AiMultiModal_Upsert
    @RiskId bigint,
    @DofId bigint = NULL,
    @RiskPatternEmbedding nvarchar(max) = NULL,
    @MetricEmbedding nvarchar(max) = NULL,
    @TemporalEmbedding nvarchar(max) = NULL,
    @ContextEmbedding nvarchar(max) = NULL,
    @EmbeddingModel varchar(100),
    @EmbeddingVersion varchar(20),
    @VectorDimension int,
    @MemoryLayer varchar(10) = 'HOT',
    @QualityScore decimal(5,2) = NULL,
    @ConfidenceScore decimal(5,2) = NULL,
    @SourceMetadata nvarchar(max) = NULL,
    @Tags nvarchar(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE ai.AiMultiModalEmbedding AS target
    USING (SELECT @RiskId AS RiskId) AS source
    ON target.RiskId = source.RiskId
    WHEN MATCHED THEN
        UPDATE SET
            DofId = @DofId,
            RiskPatternEmbedding = @RiskPatternEmbedding,
            MetricEmbedding = @MetricEmbedding,
            TemporalEmbedding = @TemporalEmbedding,
            ContextEmbedding = @ContextEmbedding,
            EmbeddingModel = @EmbeddingModel,
            EmbeddingVersion = @EmbeddingVersion,
            VectorDimension = @VectorDimension,
            MemoryLayer = @MemoryLayer,
            QualityScore = @QualityScore,
            ConfidenceScore = @ConfidenceScore,
            SourceMetadata = @SourceMetadata,
            Tags = @Tags,
            AccessCount = AccessCount + 1,
            LastAccessTime = SYSDATETIME(),
            UpdatedDate = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (RiskId, DofId, RiskPatternEmbedding, MetricEmbedding, TemporalEmbedding, 
                ContextEmbedding, EmbeddingModel, EmbeddingVersion, VectorDimension, 
                MemoryLayer, QualityScore, ConfidenceScore, SourceMetadata, Tags)
        VALUES (@RiskId, @DofId, @RiskPatternEmbedding, @MetricEmbedding, @TemporalEmbedding,
                @ContextEmbedding, @EmbeddingModel, @EmbeddingVersion, @VectorDimension,
                @MemoryLayer, @QualityScore, @ConfidenceScore, @SourceMetadata, @Tags);
END
GO

/* Memory Layer Management */
IF OBJECT_ID(N'ai.sp_AiMemory_LayerMaintenance', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiMemory_LayerMaintenance;
GO
CREATE PROCEDURE ai.sp_AiMemory_LayerMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @HotRetention int, @WarmRetention int, @ColdRetention int;
    DECLARE @HotCapacity int, @WarmCapacity int, @ColdCapacity int;
    DECLARE @HotThreshold int, @WarmThreshold int, @ColdThreshold int;
    
    -- Get configuration
    SELECT @HotRetention = RetentionDays, @HotCapacity = MaxCapacity, @HotThreshold = AccessThreshold
    FROM ai.AiMemoryLayerConfig WHERE LayerName = 'HOT';
    
    SELECT @WarmRetention = RetentionDays, @WarmCapacity = MaxCapacity, @WarmThreshold = AccessThreshold
    FROM ai.AiMemoryLayerConfig WHERE LayerName = 'WARM';
    
    SELECT @ColdRetention = RetentionDays, @ColdCapacity = MaxCapacity, @ColdThreshold = AccessThreshold
    FROM ai.AiMemoryLayerConfig WHERE LayerName = 'COLD';
    
    -- Move HOT to WARM based on age and access
    UPDATE ai.AiMultiModalEmbedding
    SET MemoryLayer = 'WARM', UpdatedDate = SYSDATETIME()
    WHERE MemoryLayer = 'HOT'
      AND (
          DATEDIFF(day, LastAccessTime, SYSDATETIME()) > @HotRetention
          OR AccessCount < @HotThreshold
      );
    
    -- Move WARM to COLD based on age and access
    UPDATE ai.AiMultiModalEmbedding
    SET MemoryLayer = 'COLD', UpdatedDate = SYSDATETIME()
    WHERE MemoryLayer = 'WARM'
      AND (
          DATEDIFF(day, LastAccessTime, SYSDATETIME()) > @WarmRetention
          OR AccessCount < @WarmThreshold
      );
    
    -- Archive or delete COLD entries based on retention
    UPDATE ai.AiMultiModalEmbedding
    SET IsActive = 0, UpdatedDate = SYSDATETIME()
    WHERE MemoryLayer = 'COLD'
      AND DATEDIFF(day, LastAccessTime, SYSDATETIME()) > @ColdRetention;
      
    -- Capacity management - keep most accessed items
    WITH HotOverCapacity AS (
        SELECT EmbeddingId, ROW_NUMBER() OVER (ORDER BY AccessCount DESC, LastAccessTime DESC) as rn
        FROM ai.AiMultiModalEmbedding 
        WHERE MemoryLayer = 'HOT' AND IsActive = 1
    )
    UPDATE e SET MemoryLayer = 'WARM', UpdatedDate = SYSDATETIME()
    FROM ai.AiMultiModalEmbedding e
    INNER JOIN HotOverCapacity h ON e.EmbeddingId = h.EmbeddingId
    WHERE h.rn > @HotCapacity;
END
GO

/* Agent Pipeline Execution */
IF OBJECT_ID(N'ai.sp_AiAgent_ExecutePipeline', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiAgent_ExecutePipeline;
GO
CREATE PROCEDURE ai.sp_AiAgent_ExecutePipeline
    @RequestId bigint,
    @PipelineConfig nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PipelineId bigint;
    DECLARE @AgentSequence varchar(500);
    
    -- Get active agents in execution order
    SELECT @AgentSequence = STRING_AGG(CAST(AgentId AS varchar(10)), ',') WITHIN GROUP (ORDER BY ExecutionOrder)
    FROM ai.AiAgentConfig 
    WHERE IsActive = 1;
    
    -- Create pipeline record
    INSERT INTO ai.AiAgentPipeline (RequestId, PipelineConfig, AgentSequence, Status)
    VALUES (@RequestId, @PipelineConfig, @AgentSequence, 'PENDING');
    
    SET @PipelineId = SCOPE_IDENTITY();
    
    -- Update request status
    UPDATE ai.AiAnalizIstegi 
    SET Durum = 'AGENT_PIPELINE_RUNNING', GuncellemeTarihi = SYSDATETIME()
    WHERE IstekId = @RequestId;
    
    SELECT @PipelineId as PipelineId, @AgentSequence as AgentSequence;
END
GO

/* Enhanced Feedback Processing */
IF OBJECT_ID(N'ai.sp_AiFeedback_Process', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiFeedback_Process;
GO
CREATE PROCEDURE ai.sp_AiFeedback_Process
    @RequestId bigint,
    @ExecutionId bigint = NULL,
    @AccuracyScore decimal(5,2),
    @RelevanceScore decimal(5,2),
    @CompletenessScore decimal(5,2),
    @ActionabilityScore decimal(5,2),
    @ExplanationQualityScore decimal(5,2),
    @CorrectRootCause varchar(100) = NULL,
    @MissedFactors nvarchar(max) = NULL,
    @ImprovementSuggestions nvarchar(max) = NULL,
    @FeedbackProvider varchar(100),
    @FeedbackType varchar(50) = 'MANUAL'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AccuracyWeight decimal(3,2), @RelevanceWeight decimal(3,2), @CompletenessWeight decimal(3,2);
    DECLARE @ActionabilityWeight decimal(3,2), @ExplanationWeight decimal(3,2);
    DECLARE @WeightedScore decimal(5,2), @OverallScore decimal(5,2);
    
    -- Get feedback weights from configuration
    SELECT 
        @AccuracyWeight = AccuracyWeight,
        @RelevanceWeight = RelevanceWeight,
        @CompletenessWeight = CompletenessWeight,
        @ActionabilityWeight = ActionabilityWeight,
        @ExplanationWeight = ExplanationWeight
    FROM ai.AiLearningConfig 
    WHERE ConfigName = 'DEFAULT' AND IsActive = 1;
    
    -- Calculate weighted score
    SET @OverallScore = (@AccuracyScore + @RelevanceScore + @CompletenessScore + @ActionabilityScore + @ExplanationQualityScore) / 5.0;
    SET @WeightedScore = (@AccuracyScore * @AccuracyWeight) + 
                        (@RelevanceScore * @RelevanceWeight) + 
                        (@CompletenessScore * @CompletenessWeight) + 
                        (@ActionabilityScore * @ActionabilityWeight) + 
                        (@ExplanationQualityScore * @ExplanationWeight);
    
    -- Insert feedback
    INSERT INTO ai.AiEnhancedFeedback (
        RequestId, ExecutionId, AccuracyScore, RelevanceScore, CompletenessScore,
        ActionabilityScore, ExplanationQualityScore, OverallScore, WeightedScore,
        CorrectRootCause, MissedFactors, ImprovementSuggestions, 
        FeedbackProvider, FeedbackType
    )
    VALUES (
        @RequestId, @ExecutionId, @AccuracyScore, @RelevanceScore, @CompletenessScore,
        @ActionabilityScore, @ExplanationQualityScore, @OverallScore, @WeightedScore,
        @CorrectRootCause, @MissedFactors, @ImprovementSuggestions,
        @FeedbackProvider, @FeedbackType
    );
    
    -- Update model performance metrics
    EXEC ai.sp_AiModel_UpdatePerformance @RequestId = @RequestId, @FeedbackScore = @WeightedScore;
END
GO

/* Model Performance Update */
IF OBJECT_ID(N'ai.sp_AiModel_UpdatePerformance', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiModel_UpdatePerformance;
GO
CREATE PROCEDURE ai.sp_AiModel_UpdatePerformance
    @RequestId bigint,
    @FeedbackScore decimal(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today date = CAST(SYSDATETIME() AS date);
    
    -- Update performance for each agent that processed this request
    WITH AgentPerformance AS (
        SELECT 
            ac.ModelName,
            'V1.0' as ModelVersion, -- TODO: Get from config
            ac.AgentType,
            ae.Status,
            ae.ExecutionTimeMs,
            ae.TokensUsed,
            ae.ConfidenceScore,
            @FeedbackScore as FeedbackScore
        FROM ai.AiAgentExecution ae
        INNER JOIN ai.AiAgentConfig ac ON ae.AgentId = ac.AgentId
        WHERE ae.RequestId = @RequestId
    )
    MERGE ai.AiModelPerformance AS target
    USING (
        SELECT 
            ModelName, ModelVersion, AgentType, @Today as MeasurementDate,
            COUNT(*) as TotalRequests,
            SUM(CASE WHEN Status = 'COMPLETED' THEN 1 ELSE 0 END) as SuccessfulRequests,
            SUM(CASE WHEN Status = 'FAILED' THEN 1 ELSE 0 END) as FailedRequests,
            AVG(ConfidenceScore) as AvgConfidence,
            AVG(ExecutionTimeMs) as AvgResponseTime,
            SUM(TokensUsed) as TotalTokens,
            AVG(TokensUsed) as AvgTokens,
            COUNT(CASE WHEN FeedbackScore IS NOT NULL THEN 1 END) as FeedbackCount,
            COUNT(CASE WHEN FeedbackScore >= 3.0 THEN 1 END) as PositiveFeedbackCount
        FROM AgentPerformance
        GROUP BY ModelName, ModelVersion, AgentType
    ) AS source ON (
        target.ModelName = source.ModelName 
        AND target.ModelVersion = source.ModelVersion 
        AND target.MeasurementDate = source.MeasurementDate
        AND ISNULL(target.AgentType, '') = ISNULL(source.AgentType, '')
    )
    WHEN MATCHED THEN
        UPDATE SET
            TotalRequests = target.TotalRequests + source.TotalRequests,
            SuccessfulRequests = target.SuccessfulRequests + source.SuccessfulRequests,
            FailedRequests = target.FailedRequests + source.FailedRequests,
            AverageConfidence = (target.AverageConfidence * target.TotalRequests + source.AvgConfidence * source.TotalRequests) / (target.TotalRequests + source.TotalRequests),
            AverageResponseTime = (target.AverageResponseTime * target.TotalRequests + source.AvgResponseTime * source.TotalRequests) / (target.TotalRequests + source.TotalRequests),
            FeedbackCount = target.FeedbackCount + source.FeedbackCount,
            PositiveFeedbackCount = target.PositiveFeedbackCount + source.PositiveFeedbackCount,
            TotalTokensUsed = target.TotalTokensUsed + source.TotalTokens,
            AverageTokensPerRequest = (target.TotalTokensUsed + source.TotalTokens) / (target.TotalRequests + source.TotalRequests)
    WHEN NOT MATCHED THEN
        INSERT (ModelName, ModelVersion, AgentType, MeasurementDate, TotalRequests, SuccessfulRequests, FailedRequests,
                AverageConfidence, AverageResponseTime, FeedbackCount, PositiveFeedbackCount, TotalTokensUsed, AverageTokensPerRequest)
        VALUES (source.ModelName, source.ModelVersion, source.AgentType, source.MeasurementDate, source.TotalRequests, 
                source.SuccessfulRequests, source.FailedRequests, source.AvgConfidence, source.AvgResponseTime,
                source.FeedbackCount, source.PositiveFeedbackCount, source.TotalTokens, source.AvgTokens);
END
GO

/* Anomaly Detection */
IF OBJECT_ID(N'ai.sp_AiAnomaly_Detect', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiAnomaly_Detect;
GO
CREATE PROCEDURE ai.sp_AiAnomaly_Detect
    @MekanId int = NULL,
    @StokId int = NULL,
    @DetectionMethod varchar(50) = 'Z_SCORE',
    @SensitivityLevel decimal(3,2) = 2.5
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AnomalyThreshold decimal(5,2) = @SensitivityLevel;
    
    -- Z-Score based anomaly detection for risk scores
    WITH RiskStats AS (
        SELECT 
            MekanId, StokId,
            AVG(CAST(RiskSkor AS decimal(10,2))) as MeanRisk,
            STDEV(CAST(RiskSkor AS decimal(10,2))) as StdRisk,
            COUNT(*) as RecordCount
        FROM rpt.RiskUrunOzet_Gunluk
        WHERE KesimGunu >= DATEADD(day, -30, CAST(SYSDATETIME() AS date))
          AND (@MekanId IS NULL OR MekanId = @MekanId)
          AND (@StokId IS NULL OR StokId = @StokId)
        GROUP BY MekanId, StokId
        HAVING COUNT(*) >= 10 -- Minimum records for statistical significance
    ),
    AnomalousRisks AS (
        SELECT 
            r.MekanId, r.StokId, r.KesimGunu, r.RiskSkor,
            rs.MeanRisk, rs.StdRisk,
            ABS(r.RiskSkor - rs.MeanRisk) / NULLIF(rs.StdRisk, 0) as ZScore
        FROM rpt.RiskUrunOzet_Gunluk r
        INNER JOIN RiskStats rs ON r.MekanId = rs.MekanId AND r.StokId = rs.StokId
        WHERE r.KesimGunu = CAST(SYSDATETIME() AS date) -- Today's data
          AND ABS(r.RiskSkor - rs.MeanRisk) / NULLIF(rs.StdRisk, 0) > @AnomalyThreshold
    )
    INSERT INTO ai.AiAnomalyDetection (
        MekanId, StokId, AnomalyType, AnomalyScore, Severity, DetectionMethod,
        DetectionParameters, AnomalyDescription, AffectedMetrics
    )
    SELECT 
        MekanId, StokId, 
        'STATISTICAL' as AnomalyType,
        CASE WHEN ZScore > 4 THEN 5.0 ELSE ZScore END as AnomalyScore,
        CASE 
            WHEN ZScore > 4 THEN 'CRITICAL'
            WHEN ZScore > 3 THEN 'HIGH'
            WHEN ZScore > 2.5 THEN 'MEDIUM'
            ELSE 'LOW'
        END as Severity,
        @DetectionMethod,
        '{"threshold":' + CAST(@AnomalyThreshold AS NVARCHAR(50)) + ',"mean":' + CAST(MeanRisk AS NVARCHAR(50)) + ',"std":' + CAST(StdRisk AS NVARCHAR(50)) + '}' as DetectionParameters,
        CONCAT('Risk score (', RiskSkor, ') deviates significantly from historical mean (', ROUND(MeanRisk, 2), ') with Z-score of ', ROUND(ZScore, 2)) as AnomalyDescription,
        'RiskSkor' as AffectedMetrics
    FROM AnomalousRisks
    WHERE NOT EXISTS (
        SELECT 1 FROM ai.AiAnomalyDetection ad
        WHERE ad.MekanId = AnomalousRisks.MekanId 
          AND ad.StokId = AnomalousRisks.StokId
          AND CAST(ad.DetectionDate AS date) = CAST(SYSDATETIME() AS date)
          AND ad.Status IN ('NEW', 'INVESTIGATING')
    );
    
    SELECT @@ROWCOUNT as AnomaliesDetected;
END
GO

/* Risk Prediction */
IF OBJECT_ID(N'ai.sp_AiRisk_Predict', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiRisk_Predict;
GO
CREATE PROCEDURE ai.sp_AiRisk_Predict
    @ModelId int,
    @MekanId int,
    @StokId int = NULL,
    @PredictionHorizon int = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PredictionDate date = CAST(SYSDATETIME() AS date);
    DECLARE @TargetDate date = DATEADD(day, @PredictionHorizon, @PredictionDate);
    
    -- Simple moving average prediction (placeholder for more sophisticated models)
    WITH HistoricalData AS (
        SELECT 
            MekanId, StokId, KesimGunu, RiskSkor,
            AVG(CAST(RiskSkor AS decimal(10,2))) OVER (
                PARTITION BY MekanId, StokId 
                ORDER BY KesimGunu 
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ) as MovingAvg7,
            ROW_NUMBER() OVER (PARTITION BY MekanId, StokId ORDER BY KesimGunu DESC) as rn
        FROM rpt.RiskUrunOzet_Gunluk
        WHERE MekanId = @MekanId
          AND (@StokId IS NULL OR StokId = @StokId)
          AND KesimGunu >= DATEADD(day, -30, @PredictionDate)
    ),
    LatestData AS (
        SELECT MekanId, StokId, MovingAvg7, RiskSkor
        FROM HistoricalData 
        WHERE rn = 1
    )
    INSERT INTO ai.AiRiskPrediction (
        ModelId, MekanId, StokId, RiskType, PredictionDate, TargetDate,
        PredictedValue, ConfidenceScore, PredictionMetadata
    )
    SELECT 
        @ModelId, MekanId, StokId, 'OVERALL_RISK', @PredictionDate, @TargetDate,
        MovingAvg7 as PredictedValue,
        CASE 
            WHEN ABS(RiskSkor - MovingAvg7) < 5 THEN 0.9
            WHEN ABS(RiskSkor - MovingAvg7) < 10 THEN 0.7
            ELSE 0.5
        END as ConfidenceScore,
        '{"method":"moving_average","window":7,"last_actual":' + CAST(RiskSkor AS NVARCHAR(50)) + '}' as PredictionMetadata
    FROM LatestData;
    
    SELECT @@ROWCOUNT as PredictionsCreated;
END
GO

-- =============================================================================
-- MIGRATION AND MAINTENANCE PROCEDURES
-- =============================================================================

/* Data Migration from V1 to V2 */
IF OBJECT_ID(N'ai.sp_AiMigration_V1toV2', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiMigration_V1toV2;
GO
CREATE PROCEDURE ai.sp_AiMigration_V1toV2
    @ComponentName varchar(100) = 'FULL_MIGRATION',
    @BatchSize int = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MigrationId int;
    DECLARE @TotalRecords int = 0;
    DECLARE @ProcessedRecords int = 0;
    
    BEGIN TRY
        -- Start migration tracking
        INSERT INTO ai.AiMigrationStatus (ComponentName, OldVersion, NewVersion, Status, StartTime)
        VALUES (@ComponentName, 'V1', 'V2', 'IN_PROGRESS', SYSDATETIME());
        
        SET @MigrationId = SCOPE_IDENTITY();
        
        -- Migrate existing vectors to multi-modal format
        IF @ComponentName IN ('FULL_MIGRATION', 'EMBEDDINGS')
        BEGIN
            SELECT @TotalRecords = COUNT(*) FROM ai.AiGecmisVektorler WHERE VektorJson IS NOT NULL;
            
            UPDATE ai.AiMigrationStatus 
            SET TotalRecords = @TotalRecords 
            WHERE MigrationId = @MigrationId;
            
            -- Migrate in batches
            WHILE @ProcessedRecords < @TotalRecords
            BEGIN
                WITH BatchData AS (
                    SELECT TOP (@BatchSize) VektorId, RiskId, DofId, Baslik, OzetMetin, KritikMi, VektorJson
                    FROM ai.AiGecmisVektorler 
                    WHERE VektorId > @ProcessedRecords
                    ORDER BY VektorId
                )
                INSERT INTO ai.AiMultiModalEmbedding (
                    RiskId, DofId, RiskPatternEmbedding, EmbeddingModel, EmbeddingVersion, 
                    VectorDimension, MemoryLayer, SourceMetadata
                )
                SELECT 
                    RiskId, DofId, VektorJson, 'legacy-model', 'v1.0', 
                    1536, -- Default dimension
                    CASE WHEN KritikMi = 1 THEN 'HOT' ELSE 'WARM' END,
                    '{"migrated_from":"AiGecmisVektorler","original_id":' + CAST(VektorId AS NVARCHAR(50)) + ',"baslik":"' + REPLACE(Baslik, '"', '\"') + '"}' 
                FROM BatchData;
                
                SET @ProcessedRecords = @ProcessedRecords + @@ROWCOUNT;
                
                UPDATE ai.AiMigrationStatus 
                SET RecordsProcessed = @ProcessedRecords 
                WHERE MigrationId = @MigrationId;
            END
        END
        
        -- Complete migration
        UPDATE ai.AiMigrationStatus 
        SET Status = 'COMPLETED', EndTime = SYSDATETIME()
        WHERE MigrationId = @MigrationId;
        
        SELECT 'Migration completed successfully' as Result, @ProcessedRecords as RecordsProcessed;
        
    END TRY
    BEGIN CATCH
        UPDATE ai.AiMigrationStatus 
        SET Status = 'FAILED', 
            ErrorMessage = ERROR_MESSAGE(),
            EndTime = SYSDATETIME()
        WHERE MigrationId = @MigrationId;
        
        THROW;
    END CATCH
END
GO

/* System Health Check */
IF OBJECT_ID(N'ai.sp_AiSystem_HealthCheck', N'P') IS NOT NULL DROP PROCEDURE ai.sp_AiSystem_HealthCheck;
GO
CREATE PROCEDURE ai.sp_AiSystem_HealthCheck
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        'AI Enhancement V2 System Health' as Component,
        SYSDATETIME() as CheckTime,
        (SELECT COUNT(*) FROM ai.AiMultiModalEmbedding WHERE IsActive = 1) as ActiveEmbeddings,
        (SELECT COUNT(*) FROM ai.AiAgentConfig WHERE IsActive = 1) as ActiveAgents,
        (SELECT COUNT(*) FROM ai.AiAnalizIstegi WHERE Durum IN ('NEW', 'BEKLEMEDE')) as PendingRequests,
        (SELECT COUNT(*) FROM ai.AiAgentPipeline WHERE Status = 'RUNNING') as RunningPipelines,
        (SELECT COUNT(*) FROM ai.AiAnomalyDetection WHERE Status = 'NEW') as NewAnomalies,
        (SELECT AVG(OverallScore) FROM ai.AiEnhancedFeedback WHERE FeedbackDate >= DATEADD(day, -7, SYSDATETIME())) as AvgFeedbackScore7Days,
        (SELECT COUNT(*) FROM ai.AiRiskPrediction WHERE PredictionDate >= CAST(SYSDATETIME() AS date)) as TodaysPredictions;
END
GO

-- =============================================================================
-- INITIAL DATA SETUP
-- =============================================================================

/* Insert default similarity thresholds */
INSERT INTO ai.AiSimilarityThreshold (RiskType, EmbeddingType, BaseThreshold, AdaptiveThreshold, ConfidenceLevel)
VALUES 
    ('OVERALL_RISK', 'RISK_PATTERN', 0.8500, 0.8500, 0.75),
    ('OVERALL_RISK', 'METRIC', 0.7500, 0.7500, 0.70),
    ('OVERALL_RISK', 'TEMPORAL', 0.8000, 0.8000, 0.65),
    ('OVERALL_RISK', 'CONTEXT', 0.7000, 0.7000, 0.60),
    ('VERI_KALITE', 'RISK_PATTERN', 0.9000, 0.9000, 0.80),
    ('STOK_ANOMALI', 'METRIC', 0.8500, 0.8500, 0.75),
    ('SATIS_ANOMALI', 'TEMPORAL', 0.8000, 0.8000, 0.70);

PRINT 'AI Enhancement V2 database schema created successfully!';
PRINT 'Components installed:';
PRINT '- Multi-Modal Semantic Memory System';
PRINT '- Multi-Agent LLM System';  
PRINT '- Real-time Learning Pipeline';
PRINT '- Predictive Analytics System';
PRINT '- Anomaly Detection System';
PRINT '- Migration and Maintenance Tools';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Run ai.sp_AiMigration_V1toV2 to migrate existing data';
PRINT '2. Configure agent parameters in ai.AiAgentConfig';
PRINT '3. Set up memory layer maintenance job';
PRINT '4. Configure predictive models';
PRINT '5. Test system with ai.sp_AiSystem_HealthCheck';
GO