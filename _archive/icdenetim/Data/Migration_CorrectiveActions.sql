-- CorrectiveActions (DOF - Düzeltici/Önleyici Faaliyetler)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CorrectiveActions')
CREATE TABLE CorrectiveActions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AuditResultId INT NOT NULL,
    AuditId INT NOT NULL,
    Title NVARCHAR(500) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL,
    RootCause NVARCHAR(MAX) NULL,
    Type NVARCHAR(20) NOT NULL DEFAULT 'Corrective',  -- Corrective, Preventive
    AssignedToUserId INT NULL,
    Department NVARCHAR(200) NULL,
    DueDate DATE NOT NULL,
    Priority NVARCHAR(20) NOT NULL DEFAULT 'Medium',  -- Low, Medium, High, Critical
    Status NVARCHAR(50) NOT NULL DEFAULT 'Open',  -- Open, InProgress, PendingValidation, Closed, Rejected
    ClosedAt DATETIME2 NULL,
    ClosedBy INT NULL,
    ClosureNote NVARCHAR(MAX) NULL,
    AiGenerated BIT NOT NULL DEFAULT 0,
    AiConfidence DECIMAL(3,2) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_CorrectiveActions_AuditResult FOREIGN KEY (AuditResultId) REFERENCES AuditResults(Id),
    CONSTRAINT FK_CorrectiveActions_Audit FOREIGN KEY (AuditId) REFERENCES Audits(Id),
    CONSTRAINT FK_CorrectiveActions_AssignedTo FOREIGN KEY (AssignedToUserId) REFERENCES Users(Id)
);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CorrectiveActions_AuditId')
CREATE INDEX IX_CorrectiveActions_AuditId ON CorrectiveActions(AuditId);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CorrectiveActions_Status')
CREATE INDEX IX_CorrectiveActions_Status ON CorrectiveActions(Status);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CorrectiveActions_AuditResultId')
CREATE INDEX IX_CorrectiveActions_AuditResultId ON CorrectiveActions(AuditResultId);
