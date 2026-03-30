---
description: "Tek bir C# dosyasini FAZ 2 standartlarina guncelle (SP + property rename)"
---

Verilen dosyayi FAZ 2 standartlarina guncelle:

## KONTROL LISTESI:
1. **SP referanslari:** Turkce SP adlarini Ingilizce'ye cevir
2. **Model property'leri:** Turkce property adlarini Ingilizce'ye cevir
3. **Inline SQL:** Turkce tablo/kolon adlarini Ingilizce'ye cevir
4. **Dapper parametreleri:** TURKCE BIRAK (SP param convention)
5. **Razor referanslari:** Eslesen .cshtml dosyasini da guncelle

## TURKCE KALACAKLAR:
- SP parametreleri (@KesimTarihi, @DonemKodu, @MekanId, @StokId, vb.)
- src.vw_* view kolonlari (MekanAd, UrunKod, UrunAd)
- dof.DofKayit kolonlari (Baslik, Aciklama, Durum, vb.)

## SP MAPPING (kullan):
ai.sp_Ai_Istek_Liste → ai.sp_AnalysisQueue_List
ai.sp_Ai_Istek_Getir → ai.sp_AnalysisQueue_Get
ai.sp_Ai_LlmSonuc_Liste → ai.sp_LlmResults_List
ai.sp_Ai_LlmSonuc_Getir → ai.sp_LlmResults_Get
ai.sp_Ai_LlmSonuc_Son → ai.sp_LlmResults_Latest
ai.sp_Ai_Reset_ve_Tetikle → ai.sp_AnalysisQueue_ResetAndTrigger
ai.sp_Ai_RiskOzet_Getir → ai.sp_RiskSummary_Get
ai.sp_Ai_GecmisVektor_Liste → ai.sp_SemanticVector_List
ai.sp_Ai_GecmisVektor_Upsert → ai.sp_SemanticVector_Upsert
ai.sp_Ai_GecmisVektor_KaynakListe → ai.sp_SemanticVector_SourceList
rpt.sp_GenelBakis_Kpi → rpt.sp_DashboardOverview_Kpi
rpt.sp_GenelBakis_Not → rpt.sp_DashboardOverview_Notes
rpt.sp_RiskMekan_Liste → rpt.sp_RiskByLocation_List
rpt.sp_RiskListe → rpt.sp_RiskList
rpt.sp_Dashboard_Kpi → rpt.sp_Dashboard_Kpi (zaten semi-English)
rpt.sp_Dashboard_RiskTrend → rpt.sp_Dashboard_RiskTrend (zaten English)
rpt.sp_Dashboard_TopRisk → rpt.sp_Dashboard_TopRisk (zaten English)
rpt.sp_UrunDetay_Getir → rpt.sp_ProductDetail_Get
rpt.sp_UrunRiskFlag_Liste → rpt.sp_ProductRiskFlag_List
rpt.sp_UrunHareket_Liste → rpt.sp_ProductMovement_List
dof.sp_Dashboard_Dof_Liste → dof.sp_Dashboard_Dof_List
ref.sp_Dashboard_Ref_Ozet → ref.sp_Dashboard_Ref_Summary
ref.sp_MekanKapsam_Liste → ref.sp_LocationSettings_List
ref.sp_MekanKapsam_Kaydet → ref.sp_LocationSettings_Save
ref.sp_IrsTipGrupMap_Liste → ref.sp_TransactionTypeMap_GroupList
ref.sp_IrsTipMap_Kaydet → ref.sp_TransactionTypeMap_Save
ref.sp_IrsTipMap_Liste → ref.sp_TransactionTypeMap_List
ref.sp_RiskParam_Liste → ref.sp_RiskParameters_List
ref.sp_RiskParam_Kaydet → ref.sp_RiskParameters_Save
ref.sp_RiskSkorAgirlik_Liste → ref.sp_RiskScoreWeights_List
ref.sp_RiskSkorAgirlik_Kaydet → ref.sp_RiskScoreWeights_Save
ref.sp_KaynakSistem_Liste → ref.sp_SourceSystems_List
ref.sp_KaynakSistem_Kaydet → ref.sp_SourceSystems_Save
ref.sp_KaynakNesne_Liste → ref.sp_SourceObjects_List
ref.sp_KaynakNesne_Kaydet → ref.sp_SourceObjects_Save
ref.sp_Personel_Liste → ref.sp_Personnel_List
ref.sp_Personel_Kaydet → ref.sp_Personnel_Save
ref.sp_Kullanici_Liste → ref.sp_Users_List
ref.sp_Kullanici_Kaydet → ref.sp_Users_Save
ref.sp_KullaniciPersonel_Liste → ref.sp_UserPersonnelLink_List
ref.sp_KullaniciPersonel_Kapat → ref.sp_UserPersonnelLink_Close
ref.sp_KullaniciPersonel_GunSonuKapat → ref.sp_UserPersonnelLink_CloseAll
log.sp_SaglikKontrol_Calistir → log.sp_HealthCheck_Run
log.sp_PersonelEntegrasyon_Ozet → log.sp_PersonnelSync_Summary
log.sp_PersonelEntegrasyon_Log_Liste → log.sp_PersonnelSync_Log_List

$ARGUMENTS
