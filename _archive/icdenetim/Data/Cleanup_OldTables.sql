-- =============================================
-- BKMDenetim DB Temizlik - Gereksiz deneme tablolari/view/function
-- Bu objeler uygulama tarafindan KULLANILMIYOR ve verisi YOK.
-- Tarih: 2026-03-29
-- NOT: Her DROP ayri batch olarak calistirilir (GO ile ayrilmis)
-- =============================================

-- Once FK constraint'leri temizle (child tablolar silinmeden once)
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(parent_object_id))
    + ' DROP CONSTRAINT ' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.foreign_keys
WHERE OBJECT_NAME(parent_object_id) IN (
    'AiAgentExecution','AiAgentPipeline','AiAgentConfig','AiAnalizIstegi','AiAnalizSonucu',
    'AiAnomalyDetection','AiEnhancedFeedback','AiGecmisVektorler','AiGeriBildirim',
    'AiLearningConfig','AiLlmSonuc','AiLmSonuc','AiMemoryLayerConfig','AiMigrationStatus',
    'AiModelPerformance','AiMultiModalEmbedding','AiPredictionModel','AiRiskPrediction',
    'AiSimilarityThreshold','DofAksiyon','DofBulgu','DofDurumGecmis','DofKanit','DofKayit',
    'AyarMekanKapsam','KaynakNesne','KaynakSistem','IrsTipGrupMap',
    'KullaniciPersonel','Kullanici','PersonelEntegrasyonLog','Personel',
    'RiskCalismaLog','RiskParam','RiskSkorAgirlik','RiskUrunOzet_Aylik','RiskUrunOzet_Gunluk',
    'SatisStaging','StokBakiyeGunluk','StokCalismaLog','StokHareketStaging','StokStaging',
    'EtlDataQualityIssue','EtlLog','EtlSyncStatus'
)
OR OBJECT_NAME(referenced_object_id) IN (
    'AiAgentExecution','AiAgentPipeline','AiAgentConfig','AiAnalizIstegi','AiAnalizSonucu',
    'AiAnomalyDetection','AiEnhancedFeedback','AiGecmisVektorler','AiGeriBildirim',
    'AiLearningConfig','AiLlmSonuc','AiLmSonuc','AiMemoryLayerConfig','AiMigrationStatus',
    'AiModelPerformance','AiMultiModalEmbedding','AiPredictionModel','AiRiskPrediction',
    'AiSimilarityThreshold','DofAksiyon','DofBulgu','DofDurumGecmis','DofKanit','DofKayit',
    'AyarMekanKapsam','KaynakNesne','KaynakSistem','IrsTipGrupMap',
    'KullaniciPersonel','Kullanici','PersonelEntegrasyonLog','Personel',
    'RiskCalismaLog','RiskParam','RiskSkorAgirlik','RiskUrunOzet_Aylik','RiskUrunOzet_Gunluk',
    'SatisStaging','StokBakiyeGunluk','StokCalismaLog','StokHareketStaging','StokStaging',
    'EtlDataQualityIssue','EtlLog','EtlSyncStatus'
);
EXEC sp_executesql @sql;
GO

-- View'lari sil
DROP VIEW IF EXISTS vw_AiGecmisVektorler_Legacy;
GO
DROP VIEW IF EXISTS vw_EvrakBaslik;
GO
DROP VIEW IF EXISTS vw_EvrakDetay;
GO
DROP VIEW IF EXISTS vw_IrsTip;
GO
DROP VIEW IF EXISTS vw_Mekan;
GO
DROP VIEW IF EXISTS vw_RiskUrunOzet_Son;
GO
DROP VIEW IF EXISTS vw_RiskUrunOzet_Stok;
GO
DROP VIEW IF EXISTS vw_RiskUrunOzet_Toplam;
GO
DROP VIEW IF EXISTS vw_StokHareket;
GO
DROP VIEW IF EXISTS vw_Urun;
GO

-- Function sil
DROP FUNCTION IF EXISTS tvf_MekanListesi;
GO

-- Tablolari sil (hepsi bos)
DROP TABLE IF EXISTS AiAgentExecution;
GO
DROP TABLE IF EXISTS AiAgentPipeline;
GO
DROP TABLE IF EXISTS AiAgentConfig;
GO
DROP TABLE IF EXISTS AiAnalizIstegi;
GO
DROP TABLE IF EXISTS AiAnalizSonucu;
GO
DROP TABLE IF EXISTS AiAnomalyDetection;
GO
DROP TABLE IF EXISTS AiEnhancedFeedback;
GO
DROP TABLE IF EXISTS AiGecmisVektorler;
GO
DROP TABLE IF EXISTS AiGeriBildirim;
GO
DROP TABLE IF EXISTS AiLearningConfig;
GO
DROP TABLE IF EXISTS AiLlmSonuc;
GO
DROP TABLE IF EXISTS AiLmSonuc;
GO
DROP TABLE IF EXISTS AiMemoryLayerConfig;
GO
DROP TABLE IF EXISTS AiMigrationStatus;
GO
DROP TABLE IF EXISTS AiModelPerformance;
GO
DROP TABLE IF EXISTS AiMultiModalEmbedding;
GO
DROP TABLE IF EXISTS AiPredictionModel;
GO
DROP TABLE IF EXISTS AiRiskPrediction;
GO
DROP TABLE IF EXISTS AiSimilarityThreshold;
GO
DROP TABLE IF EXISTS DofAksiyon;
GO
DROP TABLE IF EXISTS DofBulgu;
GO
DROP TABLE IF EXISTS DofDurumGecmis;
GO
DROP TABLE IF EXISTS DofKanit;
GO
DROP TABLE IF EXISTS DofKayit;
GO
DROP TABLE IF EXISTS AyarMekanKapsam;
GO
DROP TABLE IF EXISTS KaynakNesne;
GO
DROP TABLE IF EXISTS KaynakSistem;
GO
DROP TABLE IF EXISTS IrsTipGrupMap;
GO
DROP TABLE IF EXISTS KullaniciPersonel;
GO
DROP TABLE IF EXISTS Kullanici;
GO
DROP TABLE IF EXISTS PersonelEntegrasyonLog;
GO
DROP TABLE IF EXISTS Personel;
GO
DROP TABLE IF EXISTS RiskCalismaLog;
GO
DROP TABLE IF EXISTS RiskParam;
GO
DROP TABLE IF EXISTS RiskSkorAgirlik;
GO
DROP TABLE IF EXISTS RiskUrunOzet_Aylik;
GO
DROP TABLE IF EXISTS RiskUrunOzet_Gunluk;
GO
DROP TABLE IF EXISTS SatisStaging;
GO
DROP TABLE IF EXISTS StokBakiyeGunluk;
GO
DROP TABLE IF EXISTS StokCalismaLog;
GO
DROP TABLE IF EXISTS StokHareketStaging;
GO
DROP TABLE IF EXISTS StokStaging;
GO
DROP TABLE IF EXISTS EtlDataQualityIssue;
GO
DROP TABLE IF EXISTS EtlLog;
GO
DROP TABLE IF EXISTS EtlSyncStatus;
GO
