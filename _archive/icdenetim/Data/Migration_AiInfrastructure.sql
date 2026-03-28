IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AiAnalyses')
CREATE TABLE AiAnalyses (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    EntityType NVARCHAR(50) NOT NULL,
    EntityId INT NOT NULL,
    AnalysisType NVARCHAR(50) NOT NULL,
    InputData NVARCHAR(MAX) NULL,
    Result NVARCHAR(MAX) NOT NULL,
    Summary NVARCHAR(MAX) NOT NULL,
    Confidence DECIMAL(3,2) NOT NULL DEFAULT 0.0,
    Severity NVARCHAR(20) NULL,
    IsActionable BIT NOT NULL DEFAULT 0,
    ActionTaken BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_AiAnalyses_Entity')
CREATE INDEX IX_AiAnalyses_Entity ON AiAnalyses(EntityType, EntityId);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_AiAnalyses_Type')
CREATE INDEX IX_AiAnalyses_Type ON AiAnalyses(AnalysisType, CreatedAt);
