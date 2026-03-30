/*
    41_drop_old_turkish_sps.sql
    -----------------------------------------------
    Drop old Turkish-named SPs that have English replacements
    already deployed via 31_sps_ai_log_etl_english.sql
    and 32_sps_remaining_english.sql.

    Generated: 2026-03-30
*/
USE BKMDenetim;
GO

PRINT '--- 41_drop_old_turkish_sps.sql ---';

-- ai.* schema: old Turkish AI SPs (replaced by English versions in 31_sps_ai_log_etl_english.sql)
IF OBJECT_ID('ai.sp_Ai_Istek_Liste', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Liste;
IF OBJECT_ID('ai.sp_Ai_Istek_Getir', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Getir;
IF OBJECT_ID('ai.sp_Ai_LlmSonuc_Liste', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Liste;
IF OBJECT_ID('ai.sp_Ai_Reset_ve_Tetikle', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Reset_ve_Tetikle;
IF OBJECT_ID('ai.sp_Ai_GecmisVektor_Liste', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_GecmisVektor_Liste;
IF OBJECT_ID('ai.sp_Ai_GecmisVektor_Upsert', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_GecmisVektor_Upsert;
IF OBJECT_ID('ai.sp_Ai_GecmisVektor_KaynakListe', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_GecmisVektor_KaynakListe;
IF OBJECT_ID('ai.sp_Ai_RiskOzet_Getir', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_RiskOzet_Getir;
IF OBJECT_ID('ai.sp_AiRisk_Predict', 'P') IS NOT NULL DROP PROCEDURE ai.sp_AiRisk_Predict;

-- log.* schema: old Turkish log SP (replaced by log.sp_HealthCheck_Run)
IF OBJECT_ID('log.sp_SaglikKontrol_Calistir', 'P') IS NOT NULL DROP PROCEDURE log.sp_SaglikKontrol_Calistir;

-- Also drop other old Turkish SPs that may still exist from 14_sps_ai.sql
IF OBJECT_ID('ai.sp_Ai_Istek_Olustur', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Olustur;
IF OBJECT_ID('ai.sp_Ai_Istek_Al', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Al;
IF OBJECT_ID('ai.sp_Ai_Istek_Retry', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Retry;
IF OBJECT_ID('ai.sp_Ai_Istek_Guncelle', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_Istek_Guncelle;
IF OBJECT_ID('ai.sp_Ai_LlmSonuc_Getir', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Getir;
IF OBJECT_ID('ai.sp_Ai_LlmSonuc_Son', 'P') IS NOT NULL DROP PROCEDURE ai.sp_Ai_LlmSonuc_Son;

GO

PRINT '  9+6 old Turkish SPs dropped (idempotent).';
GO
