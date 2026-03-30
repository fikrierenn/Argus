-- ============================================================================
-- FAZ 2 Column Rename Migration
-- Remaining Turkish column names → English
-- Idempotent: checks COL_LENGTH before rename
-- ============================================================================

PRINT '=== Column Rename Migration Start ===';

-- ─────────────────────────────────────────────────────
-- ref.LocationSettings: MekanId → LocationId
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ref.LocationSettings', 'MekanId') IS NOT NULL
    EXEC sp_rename 'ref.LocationSettings.MekanId', 'LocationId', 'COLUMN';
GO

-- ─────────────────────────────────────────────────────
-- ref.RiskScoreWeights: Aciklama → Description
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ref.RiskScoreWeights', 'Aciklama') IS NOT NULL
    EXEC sp_rename 'ref.RiskScoreWeights.Aciklama', 'Description', 'COLUMN';
GO

-- ─────────────────────────────────────────────────────
-- ref.UserPersonnelMap: Aciklama → Description
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('ref.UserPersonnelMap', 'Aciklama') IS NOT NULL
    EXEC sp_rename 'ref.UserPersonnelMap.Aciklama', 'Description', 'COLUMN';
GO

-- ─────────────────────────────────────────────────────
-- log.RiskEtlRuns: Turkish → English
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('log.RiskEtlRuns', 'BaslamaZamani') IS NOT NULL
    EXEC sp_rename 'log.RiskEtlRuns.BaslamaZamani', 'StartTime', 'COLUMN';
GO
IF COL_LENGTH('log.RiskEtlRuns', 'BitisZamani') IS NOT NULL
    EXEC sp_rename 'log.RiskEtlRuns.BitisZamani', 'EndTime', 'COLUMN';
GO
IF COL_LENGTH('log.RiskEtlRuns', 'Durum') IS NOT NULL
    EXEC sp_rename 'log.RiskEtlRuns.Durum', 'Status', 'COLUMN';
GO
IF COL_LENGTH('log.RiskEtlRuns', 'Hata') IS NOT NULL
    EXEC sp_rename 'log.RiskEtlRuns.Hata', 'ErrorMessage', 'COLUMN';
GO
IF COL_LENGTH('log.RiskEtlRuns', 'SureMs') IS NOT NULL
    EXEC sp_rename 'log.RiskEtlRuns.SureMs', 'DurationMs', 'COLUMN';
GO

-- ─────────────────────────────────────────────────────
-- log.StockEtlRuns: Turkish → English
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('log.StockEtlRuns', 'BaslamaZamani') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.BaslamaZamani', 'StartTime', 'COLUMN';
GO
IF COL_LENGTH('log.StockEtlRuns', 'BitisZamani') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.BitisZamani', 'EndTime', 'COLUMN';
GO
IF COL_LENGTH('log.StockEtlRuns', 'Durum') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.Durum', 'Status', 'COLUMN';
GO
IF COL_LENGTH('log.StockEtlRuns', 'Hata') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.Hata', 'ErrorMessage', 'COLUMN';
GO
IF COL_LENGTH('log.StockEtlRuns', 'SureMs') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.SureMs', 'DurationMs', 'COLUMN';
GO
IF COL_LENGTH('log.StockEtlRuns', 'HedefBaslangic') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.HedefBaslangic', 'TargetStartDate', 'COLUMN';
GO
IF COL_LENGTH('log.StockEtlRuns', 'HedefBitis') IS NOT NULL
    EXEC sp_rename 'log.StockEtlRuns.HedefBitis', 'TargetEndDate', 'COLUMN';
GO

-- ─────────────────────────────────────────────────────
-- log.PersonnelIntegrationLog: Turkish → English
-- ─────────────────────────────────────────────────────
IF COL_LENGTH('log.PersonnelIntegrationLog', 'KaynakSistem') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.KaynakSistem', 'SourceSystem', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'BaslamaZamani') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.BaslamaZamani', 'StartTime', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'BitisZamani') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.BitisZamani', 'EndTime', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'Toplam') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.Toplam', 'TotalRecords', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'Eklenen') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.Eklenen', 'InsertedCount', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'Guncellenen') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.Guncellenen', 'UpdatedCount', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'PasifEdilen') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.PasifEdilen', 'DeactivatedCount', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'Durum') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.Durum', 'Status', 'COLUMN';
GO
IF COL_LENGTH('log.PersonnelIntegrationLog', 'Hata') IS NOT NULL
    EXEC sp_rename 'log.PersonnelIntegrationLog.Hata', 'ErrorMessage', 'COLUMN';
GO

PRINT '=== Column Rename Migration Complete ===';
GO
