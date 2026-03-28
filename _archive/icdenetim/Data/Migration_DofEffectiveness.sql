-- DOF Effectiveness tracking - CorrectiveActions tablosuna etkinlik alanlari
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('CorrectiveActions') AND name = 'IsEffective')
    ALTER TABLE CorrectiveActions ADD IsEffective BIT NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('CorrectiveActions') AND name = 'EffectivenessScore')
    ALTER TABLE CorrectiveActions ADD EffectivenessScore DECIMAL(3,2) NULL;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('CorrectiveActions') AND name = 'EffectivenessNote')
    ALTER TABLE CorrectiveActions ADD EffectivenessNote NVARCHAR(500) NULL;
