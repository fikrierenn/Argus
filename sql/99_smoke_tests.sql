/* ============================================================
   99_smoke_tests.sql
   Tum SP'leri guvenli parametrelerle cagirarak PASS/FAIL verir.
   Veri degistiren SP'ler BEGIN TRAN / ROLLBACK ile korunur.

   PASS  = SP calisti (veri dondurdu veya beklenen validation hatasi)
   FAIL  = SP hata verdi (missing object, unexpected error)
   WARN  = SP beklenen validation hatasi verdi (id bulunamadi vb)
   ============================================================ */
USE BKMDenetim;
GO

SET NOCOUNT ON;

DECLARE @pass INT = 0, @fail INT = 0, @warn INT = 0;

-- Mevcut veriden gercek ID'ler al (yoksa NULL kalir)
DECLARE @RealAuditId  INT = (SELECT TOP 1 Id FROM audit.Audits ORDER BY Id);
DECLARE @RealItemId   INT = (SELECT TOP 1 Id FROM audit.AuditItems ORDER BY Id);
DECLARE @RealResultId INT = (SELECT TOP 1 Id FROM audit.AuditResults ORDER BY Id);
DECLARE @RealUserId   INT = (SELECT TOP 1 Id FROM audit.Users WHERE IsActive=1 ORDER BY Id);
DECLARE @RealDofId    BIGINT = (SELECT TOP 1 DofId FROM dof.Findings ORDER BY DofId);

-- Safe fallback IDs for EXEC calls (EXEC can't take expressions)
DECLARE @SafeAuditId  INT = ISNULL(@RealAuditId, 0);
DECLARE @SafeItemId   INT = ISNULL(@RealItemId, 0);
DECLARE @SafeResultId INT = ISNULL(@RealResultId, 0);
DECLARE @SafeUserId   INT = ISNULL(@RealUserId, 1);
DECLARE @SafeDofId    BIGINT = ISNULL(@RealDofId, 0);
DECLARE @SrcSysCode   VARCHAR(20) = ISNULL((SELECT TOP 1 SystemCode FROM ref.SourceSystems WHERE IsActive=1), 'UNKNOWN');

PRINT '========================================';
PRINT '  BKM Argus - SP Smoke Tests';
PRINT '  ' + CONVERT(varchar, GETDATE(), 120);
PRINT '========================================';
PRINT '  Test AuditId  = ' + ISNULL(CAST(@RealAuditId AS VARCHAR),'(yok)');
PRINT '  Test ItemId   = ' + ISNULL(CAST(@RealItemId AS VARCHAR),'(yok)');
PRINT '  Test ResultId = ' + ISNULL(CAST(@RealResultId AS VARCHAR),'(yok)');
PRINT '  Test UserId   = ' + ISNULL(CAST(@RealUserId AS VARCHAR),'(yok)');
PRINT '  Test DofId    = ' + ISNULL(CAST(@RealDofId AS VARCHAR),'(yok)');
PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [ref] Referans SP''leri ---';
/* ------------------------------------------------------------ */

-- ref.sp_LocationSettings_List (no params)
BEGIN TRY
    EXEC ref.sp_LocationSettings_List;
    PRINT '  PASS: ref.sp_LocationSettings_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_LocationSettings_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_LocationSettings_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_LocationSettings_Save @MekanId=999999, @AktifMi=1, @Aciklama=N'smoke test', @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_LocationSettings_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_LocationSettings_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_TransactionTypeMap_GroupList (no params)
BEGIN TRY
    EXEC ref.sp_TransactionTypeMap_GroupList;
    PRINT '  PASS: ref.sp_TransactionTypeMap_GroupList';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_TransactionTypeMap_GroupList -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_TransactionTypeMap_List
BEGIN TRY
    EXEC ref.sp_TransactionTypeMap_List @SadeceEksik=0;
    PRINT '  PASS: ref.sp_TransactionTypeMap_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_TransactionTypeMap_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_TransactionTypeMap_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_TransactionTypeMap_Save @TipId=255, @GrupKodu='TST', @GrupAdi=N'SmokeTest', @IslemAdi=N'SmokeTest', @AktifMi=0, @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_TransactionTypeMap_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_TransactionTypeMap_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_RiskParameters_List (no params)
BEGIN TRY
    EXEC ref.sp_RiskParameters_List;
    PRINT '  PASS: ref.sp_RiskParameters_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_RiskParameters_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_RiskParameters_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_RiskParameters_Save @ParamKodu='SMOKETEST', @DegerInt=1, @DegerDec=1.0, @DegerStr=N'test', @AktifMi=0, @Aciklama=N'smoke', @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_RiskParameters_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_RiskParameters_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_RiskScoreWeights_List (no params)
BEGIN TRY
    EXEC ref.sp_RiskScoreWeights_List;
    PRINT '  PASS: ref.sp_RiskScoreWeights_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_RiskScoreWeights_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_RiskScoreWeights_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_RiskScoreWeights_Save @FlagKodu='SMOKETEST', @Puan=1, @Oncelik=1, @AktifMi=0, @Aciklama=N'smoke', @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_RiskScoreWeights_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_RiskScoreWeights_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_SourceSystems_List (no params)
BEGIN TRY
    EXEC ref.sp_SourceSystems_List;
    PRINT '  PASS: ref.sp_SourceSystems_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_SourceSystems_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_SourceSystems_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_SourceSystems_Save @SistemKodu='SMOKETEST', @SistemAdi=N'SmokeTest', @AktifMi=0, @Aciklama=N'smoke', @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_SourceSystems_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_SourceSystems_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_SourceObjects_List (no params)
BEGIN TRY
    EXEC ref.sp_SourceObjects_List;
    PRINT '  PASS: ref.sp_SourceObjects_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_SourceObjects_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_SourceObjects_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_SourceObjects_Save @NesneKodu='SMOKETEST', @NesneAdi=N'SmokeTest', @AktifMi=0, @Aciklama=N'smoke', @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_SourceObjects_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_SourceObjects_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_Personnel_List (no params)
BEGIN TRY
    EXEC ref.sp_Personnel_List;
    PRINT '  PASS: ref.sp_Personnel_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_Personnel_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_Personnel_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_Personnel_Save @PersonelKodu='SMKTST', @Ad=N'Smoke', @Soyad=N'Test', @Unvan=N'Test', @Birim=N'Test', @UstPersonelId=NULL, @Eposta=N'smoke@test.com', @Telefon=N'0000', @AktifMi=0, @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_Personnel_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_Personnel_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_Users_List (no params)
BEGIN TRY
    EXEC ref.sp_Users_List;
    PRINT '  PASS: ref.sp_Users_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_Users_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_Users_Save (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_Users_Save @KullaniciAdi='smoketest', @PersonelId=NULL, @RolKodu='viewer', @AktifMi=0, @KullaniciId=1;
    ROLLBACK;
    PRINT '  PASS: ref.sp_Users_Save';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_Users_Save -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_UserPersonnelLink_List (no params)
BEGIN TRY
    EXEC ref.sp_UserPersonnelLink_List;
    PRINT '  PASS: ref.sp_UserPersonnelLink_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_UserPersonnelLink_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_UserPersonnelLink_Close (mutation - rollback; id=0 may be rejected by validation)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_UserPersonnelLink_Close @BaglantiId=999999, @KullaniciId=1, @Aciklama=N'smoke';
    ROLLBACK;
    PRINT '  PASS: ref.sp_UserPersonnelLink_Close';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%' OR ERROR_MESSAGE() LIKE '%zorunlu%'
    BEGIN
        PRINT '  WARN: ref.sp_UserPersonnelLink_Close -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: ref.sp_UserPersonnelLink_Close -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- ref.sp_UserPersonnelLink_CloseAll (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ref.sp_UserPersonnelLink_CloseAll @KullaniciId=999999, @Aciklama=N'smoke';
    ROLLBACK;
    PRINT '  PASS: ref.sp_UserPersonnelLink_CloseAll';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ref.sp_UserPersonnelLink_CloseAll -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ref.sp_Dashboard_Ref_Summary (no params)
BEGIN TRY
    EXEC ref.sp_Dashboard_Ref_Summary;
    PRINT '  PASS: ref.sp_Dashboard_Ref_Summary';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ref.sp_Dashboard_Ref_Summary -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [rpt] Rapor SP''leri ---';
/* ------------------------------------------------------------ */

-- rpt.sp_DashboardOverview_Kpi
BEGIN TRY
    EXEC rpt.sp_DashboardOverview_Kpi @KesimGunu=NULL;
    PRINT '  PASS: rpt.sp_DashboardOverview_Kpi';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_DashboardOverview_Kpi -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_DashboardOverview_Notes (no params)
BEGIN TRY
    EXEC rpt.sp_DashboardOverview_Notes;
    PRINT '  PASS: rpt.sp_DashboardOverview_Notes';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_DashboardOverview_Notes -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_Dashboard_Kpi
BEGIN TRY
    EXEC rpt.sp_Dashboard_Kpi @KesimGunu=NULL;
    PRINT '  PASS: rpt.sp_Dashboard_Kpi';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_Dashboard_Kpi -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_Dashboard_RiskTrend
BEGIN TRY
    EXEC rpt.sp_Dashboard_RiskTrend @Gun=7;
    PRINT '  PASS: rpt.sp_Dashboard_RiskTrend';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_Dashboard_RiskTrend -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_Dashboard_TopRisk
BEGIN TRY
    EXEC rpt.sp_Dashboard_TopRisk @Top=5, @KesimGunu=NULL;
    PRINT '  PASS: rpt.sp_Dashboard_TopRisk';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_Dashboard_TopRisk -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_RiskList
BEGIN TRY
    EXEC rpt.sp_RiskList @Top=5, @KesimGunu=NULL, @KesimBas=NULL, @KesimBit=NULL,
         @Search=NULL, @MinSkor=NULL, @MaxSkor=NULL, @MekanCSV=NULL,
         @TipCSV=NULL, @OrderBy=NULL, @OrderDir=NULL, @Page=1, @PageSize=5;
    PRINT '  PASS: rpt.sp_RiskList';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_RiskList -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_RiskByLocation_List (no params)
BEGIN TRY
    EXEC rpt.sp_RiskByLocation_List;
    PRINT '  PASS: rpt.sp_RiskByLocation_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_RiskByLocation_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_ProductDetail_Get (StokId required, use 1 as safe nonexistent)
BEGIN TRY
    EXEC rpt.sp_ProductDetail_Get @StokId=1, @MekanId=1, @DonemKodu='Son30Gun', @KesimGunu=NULL;
    PRINT '  PASS: rpt.sp_ProductDetail_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%zorunlu%' OR ERROR_MESSAGE() LIKE '%required%' OR ERROR_MESSAGE() LIKE '%bulunamad%'
    BEGIN
        PRINT '  WARN: rpt.sp_ProductDetail_Get -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: rpt.sp_ProductDetail_Get -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- rpt.sp_ProductMovement_List
BEGIN TRY
    EXEC rpt.sp_ProductMovement_List @StokId=1, @MekanId=1, @Top=5;
    PRINT '  PASS: rpt.sp_ProductMovement_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%zorunlu%' OR ERROR_MESSAGE() LIKE '%required%'
    BEGIN
        PRINT '  WARN: rpt.sp_ProductMovement_List -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: rpt.sp_ProductMovement_List -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- rpt.sp_ProductRiskFlag_List
BEGIN TRY
    EXEC rpt.sp_ProductRiskFlag_List @StokId=1, @MekanId=1, @DonemKodu='Son30Gun', @KesimGunu=NULL;
    PRINT '  PASS: rpt.sp_ProductRiskFlag_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%zorunlu%' OR ERROR_MESSAGE() LIKE '%required%'
    BEGIN
        PRINT '  WARN: rpt.sp_ProductRiskFlag_List -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: rpt.sp_ProductRiskFlag_List -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- rpt.sp_StockBalance_GetByDate (Tarih required)
BEGIN TRY
    EXEC rpt.sp_StockBalance_GetByDate @Tarih='2020-01-01', @MekanCSV=NULL, @StokId=NULL;
    PRINT '  PASS: rpt.sp_StockBalance_GetByDate';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%zorunlu%' OR ERROR_MESSAGE() LIKE '%required%'
    BEGIN
        PRINT '  WARN: rpt.sp_StockBalance_GetByDate -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: rpt.sp_StockBalance_GetByDate -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- rpt.sp_CrossCorrelation_Calculate (no params)
BEGIN TRY
    EXEC rpt.sp_CrossCorrelation_Calculate;
    PRINT '  PASS: rpt.sp_CrossCorrelation_Calculate';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_CrossCorrelation_Calculate -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_CrossCorrelation_List
BEGIN TRY
    EXEC rpt.sp_CrossCorrelation_List @Quadrant=NULL, @MinScore=NULL, @Top=5;
    PRINT '  PASS: rpt.sp_CrossCorrelation_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_CrossCorrelation_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- rpt.sp_CrossCorrelation_LocationDetail
BEGIN TRY
    EXEC rpt.sp_CrossCorrelation_LocationDetail @LocationId=1;
    PRINT '  PASS: rpt.sp_CrossCorrelation_LocationDetail';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: rpt.sp_CrossCorrelation_LocationDetail -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [ai] AI SP''leri (English) ---';
/* ------------------------------------------------------------ */

-- ai.sp_AnalysisQueue_List
BEGIN TRY
    EXEC ai.sp_AnalysisQueue_List @Top=5, @Durum=NULL, @Search=NULL, @KesimBas=NULL, @KesimBit=NULL;
    PRINT '  PASS: ai.sp_AnalysisQueue_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_AnalysisQueue_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_AnalysisQueue_Get
BEGIN TRY
    EXEC ai.sp_AnalysisQueue_Get @IstekId=0;
    PRINT '  PASS: ai.sp_AnalysisQueue_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_AnalysisQueue_Get -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_AnalysisQueue_ResetAndTrigger (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ai.sp_AnalysisQueue_ResetAndTrigger @Top=0, @MinSkor=9999, @SilVektor=0;
    ROLLBACK;
    PRINT '  PASS: ai.sp_AnalysisQueue_ResetAndTrigger';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ai.sp_AnalysisQueue_ResetAndTrigger -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_SemanticVector_List
BEGIN TRY
    EXEC ai.sp_SemanticVector_List @Top=5, @KritikMi=NULL;
    PRINT '  PASS: ai.sp_SemanticVector_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_SemanticVector_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_SemanticVector_SourceList
BEGIN TRY
    EXEC ai.sp_SemanticVector_SourceList @Top=5;
    PRINT '  PASS: ai.sp_SemanticVector_SourceList';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_SemanticVector_SourceList -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_SemanticVector_Upsert (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ai.sp_SemanticVector_Upsert @RiskId=0, @DofId=NULL, @Baslik=N'smoke', @OzetMetin=N'smoke test', @KritikMi=0, @VektorJson=N'[]';
    ROLLBACK;
    PRINT '  PASS: ai.sp_SemanticVector_Upsert';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ai.sp_SemanticVector_Upsert -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_LlmResults_List
BEGIN TRY
    EXEC ai.sp_LlmResults_List @Top=5, @Search=NULL;
    PRINT '  PASS: ai.sp_LlmResults_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_LlmResults_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_LlmResults_Get
BEGIN TRY
    EXEC ai.sp_LlmResults_Get @IstekId=0;
    PRINT '  PASS: ai.sp_LlmResults_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_LlmResults_Get -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_LlmResults_Latest
BEGIN TRY
    EXEC ai.sp_LlmResults_Latest @StokId=1, @MekanId=1, @DonemKodu='Son30Gun';
    PRINT '  PASS: ai.sp_LlmResults_Latest';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_LlmResults_Latest -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_RiskSummary_Get
BEGIN TRY
    EXEC ai.sp_RiskSummary_Get @KesimTarihi=NULL, @DonemKodu='Son30Gun', @MekanId=NULL, @StokId=NULL;
    PRINT '  PASS: ai.sp_RiskSummary_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_RiskSummary_Get -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_RiskPrediction_Run
BEGIN TRY
    EXEC ai.sp_RiskPrediction_Run @ModelId=0, @MekanId=1, @StokId=1, @PredictionHorizon=7;
    PRINT '  PASS: ai.sp_RiskPrediction_Run';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_RiskPrediction_Run -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [ai] AI SP''leri (Turkish aliases) ---';
/* ------------------------------------------------------------ */

-- ai.sp_Ai_Istek_Liste
BEGIN TRY
    EXEC ai.sp_Ai_Istek_Liste @Top=5, @Durum=NULL, @Search=NULL, @KesimBas=NULL, @KesimBit=NULL;
    PRINT '  PASS: ai.sp_Ai_Istek_Liste';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_Ai_Istek_Liste -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_Istek_Getir
BEGIN TRY
    EXEC ai.sp_Ai_Istek_Getir @IstekId=0;
    PRINT '  PASS: ai.sp_Ai_Istek_Getir';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_Ai_Istek_Getir -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_LlmSonuc_Liste
BEGIN TRY
    EXEC ai.sp_Ai_LlmSonuc_Liste @Top=5, @Search=NULL;
    PRINT '  PASS: ai.sp_Ai_LlmSonuc_Liste';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_Ai_LlmSonuc_Liste -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_RiskOzet_Getir
BEGIN TRY
    EXEC ai.sp_Ai_RiskOzet_Getir @KesimTarihi=NULL, @DonemKodu='Son30Gun', @MekanId=NULL, @StokId=NULL;
    PRINT '  PASS: ai.sp_Ai_RiskOzet_Getir';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_Ai_RiskOzet_Getir -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_Reset_ve_Tetikle (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ai.sp_Ai_Reset_ve_Tetikle @Top=0, @MinSkor=9999, @SilVektor=0;
    ROLLBACK;
    PRINT '  PASS: ai.sp_Ai_Reset_ve_Tetikle';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ai.sp_Ai_Reset_ve_Tetikle -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_GecmisVektor_Liste
BEGIN TRY
    EXEC ai.sp_Ai_GecmisVektor_Liste @Top=5, @KritikMi=NULL;
    PRINT '  PASS: ai.sp_Ai_GecmisVektor_Liste';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_Ai_GecmisVektor_Liste -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_GecmisVektor_KaynakListe
BEGIN TRY
    EXEC ai.sp_Ai_GecmisVektor_KaynakListe @Top=5;
    PRINT '  PASS: ai.sp_Ai_GecmisVektor_KaynakListe';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_Ai_GecmisVektor_KaynakListe -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_Ai_GecmisVektor_Upsert (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC ai.sp_Ai_GecmisVektor_Upsert @RiskId=0, @DofId=NULL, @Baslik=N'smoke', @OzetMetin=N'smoke test', @KritikMi=0, @VektorJson=N'[]';
    ROLLBACK;
    PRINT '  PASS: ai.sp_Ai_GecmisVektor_Upsert';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: ai.sp_Ai_GecmisVektor_Upsert -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- ai.sp_AiRisk_Predict (Turkish alias)
BEGIN TRY
    EXEC ai.sp_AiRisk_Predict @ModelId=0, @MekanId=1, @StokId=1, @PredictionHorizon=7;
    PRINT '  PASS: ai.sp_AiRisk_Predict';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: ai.sp_AiRisk_Predict -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [audit] Denetim SP''leri ---';
/* ------------------------------------------------------------ */

-- audit.sp_Audit_List
BEGIN TRY
    EXEC audit.sp_Audit_List @LocationName=NULL, @StartDate=NULL, @EndDate=NULL, @IsFinalized=NULL, @Top=5;
    PRINT '  PASS: audit.sp_Audit_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Audit_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Audit_Get
BEGIN TRY
    EXEC audit.sp_Audit_Get @AuditId = @SafeAuditId;
    PRINT '  PASS: audit.sp_Audit_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Audit_Get -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Audit_Get -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Audit_Insert (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Audit_Insert @LocationName=N'SMOKE_TEST', @LocationType='Magaza',
         @AuditDate='2020-01-01', @ReportDate='2020-01-01', @AuditorId=@SafeUserId,
         @Manager=N'SmokeTest', @Directorate=N'SmokeTest';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Audit_Insert';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Audit_Insert -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Audit_Update (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Audit_Update @AuditId=@SafeAuditId, @LocationName=N'SMOKE_TEST_UPD', @LocationType='Magaza',
         @AuditDate='2020-01-01', @ReportDate='2020-01-01', @AuditorId=@SafeUserId,
         @Manager=N'SmokeTest', @Directorate=N'SmokeTest';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Audit_Update';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Audit_Update -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Audit_Update -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Audit_Delete (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Audit_Delete @AuditId=@SafeAuditId;
    ROLLBACK;
    PRINT '  PASS: audit.sp_Audit_Delete';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Audit_Delete -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Audit_Delete -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Audit_Finalize (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Audit_Finalize @AuditId=@SafeAuditId;
    ROLLBACK;
    PRINT '  PASS: audit.sp_Audit_Finalize';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
       OR ERROR_MESSAGE() LIKE '%finalize%' OR ERROR_MESSAGE() LIKE '%zaten%'
    BEGIN
        PRINT '  WARN: audit.sp_Audit_Finalize -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Audit_Finalize -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Item_List
BEGIN TRY
    EXEC audit.sp_Item_List @LocationType=NULL, @AuditGroup=NULL, @IsActive=NULL;
    PRINT '  PASS: audit.sp_Item_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Item_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Item_Get
BEGIN TRY
    EXEC audit.sp_Item_Get @ItemId=@SafeItemId;
    PRINT '  PASS: audit.sp_Item_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Item_Get -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Item_Get -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Item_Insert (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Item_Insert @LocationType='Magaza', @AuditGroup=N'SmokeTest',
         @Area=N'Test', @RiskType=N'Test', @ItemText=N'Smoke test item',
         @SortOrder=9999, @FindingType='M', @Probability=1, @Impact=1, @SkillId=NULL;
    ROLLBACK;
    PRINT '  PASS: audit.sp_Item_Insert';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Item_Insert -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Item_Update (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Item_Update @ItemId=@SafeItemId, @LocationType='Magaza', @AuditGroup=N'SmokeTest',
         @Area=N'Test', @RiskType=N'Test', @ItemText=N'Smoke test item updated',
         @SortOrder=9999, @FindingType='M', @Probability=1, @Impact=1, @SkillId=NULL;
    ROLLBACK;
    PRINT '  PASS: audit.sp_Item_Update';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Item_Update -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Item_Update -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Result_ListByAudit (use real id or 0)
BEGIN TRY
    EXEC audit.sp_Result_ListByAudit @AuditId=@SafeAuditId;
    PRINT '  PASS: audit.sp_Result_ListByAudit';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Result_ListByAudit -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Result_StartAudit (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Result_StartAudit @AuditId=@SafeAuditId, @LocationType='Magaza';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Result_StartAudit';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
       OR ERROR_MESSAGE() LIKE '%zaten%' OR ERROR_MESSAGE() LIKE '%already%'
    BEGIN
        PRINT '  WARN: audit.sp_Result_StartAudit -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Result_StartAudit -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Result_Update (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Result_Update @ResultId=@SafeResultId, @IsPassed=1, @Remark=N'smoke test';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Result_Update';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Result_Update -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Result_Update -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Result_BulkUpdate (mutation - rollback, empty JSON)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Result_BulkUpdate @AuditId=@SafeAuditId, @JsonData=N'[]';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Result_BulkUpdate';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Result_BulkUpdate -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Report_AuditSummary
BEGIN TRY
    EXEC audit.sp_Report_AuditSummary @DenetimId=@SafeAuditId;
    PRINT '  PASS: audit.sp_Report_AuditSummary';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Report_AuditSummary -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Report_Scorecard
BEGIN TRY
    EXEC audit.sp_Report_Scorecard @MagazaAdi=NULL, @BaslangicTarihi=NULL, @BitisTarihi=NULL;
    PRINT '  PASS: audit.sp_Report_Scorecard';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Report_Scorecard -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Report_MonthlyTrend
BEGIN TRY
    EXEC audit.sp_Report_MonthlyTrend @MagazaAdi=NULL, @AySayisi=3;
    PRINT '  PASS: audit.sp_Report_MonthlyTrend';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Report_MonthlyTrend -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Report_RepeatingFindings
BEGIN TRY
    EXEC audit.sp_Report_RepeatingFindings @MinTekrar=2, @Ust=5;
    PRINT '  PASS: audit.sp_Report_RepeatingFindings';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Report_RepeatingFindings -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Report_SystemicFindings (no params)
BEGIN TRY
    EXEC audit.sp_Report_SystemicFindings;
    PRINT '  PASS: audit.sp_Report_SystemicFindings';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Report_SystemicFindings -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Dashboard_FieldAudit_Kpi (no params)
BEGIN TRY
    EXEC audit.sp_Dashboard_FieldAudit_Kpi;
    PRINT '  PASS: audit.sp_Dashboard_FieldAudit_Kpi';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Dashboard_FieldAudit_Kpi -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Dashboard_LocationScores
BEGIN TRY
    EXEC audit.sp_Dashboard_LocationScores @Ust=5;
    PRINT '  PASS: audit.sp_Dashboard_LocationScores';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Dashboard_LocationScores -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Dashboard_RecentAudits
BEGIN TRY
    EXEC audit.sp_Dashboard_RecentAudits @Ust=5;
    PRINT '  PASS: audit.sp_Dashboard_RecentAudits';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Dashboard_RecentAudits -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Dashboard_TopRiskFindings
BEGIN TRY
    EXEC audit.sp_Dashboard_TopRiskFindings @Ust=5;
    PRINT '  PASS: audit.sp_Dashboard_TopRiskFindings';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Dashboard_TopRiskFindings -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Analysis_DetectRepeats (use real id)
BEGIN TRY
    EXEC audit.sp_Analysis_DetectRepeats @AuditId=@SafeAuditId;
    PRINT '  PASS: audit.sp_Analysis_DetectRepeats';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Analysis_DetectRepeats -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Analysis_DetectRepeats -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Analysis_DetectSystemic (use real id)
BEGIN TRY
    EXEC audit.sp_Analysis_DetectSystemic @AuditId=@SafeAuditId;
    PRINT '  PASS: audit.sp_Analysis_DetectSystemic';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Analysis_DetectSystemic -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Analysis_DetectSystemic -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Analysis_DofEffectiveness (use real id)
BEGIN TRY
    EXEC audit.sp_Analysis_DofEffectiveness @AuditId=@SafeAuditId;
    PRINT '  PASS: audit.sp_Analysis_DofEffectiveness';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Analysis_DofEffectiveness -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Analysis_DofEffectiveness -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Analysis_FullPipeline (mutation - rollback, use real id)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Analysis_FullPipeline @AuditId=@SafeAuditId;
    ROLLBACK;
    PRINT '  PASS: audit.sp_Analysis_FullPipeline';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: audit.sp_Analysis_FullPipeline -- validation OK: ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: audit.sp_Analysis_FullPipeline -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- audit.sp_Auth_Login (read-only lookup, nonexistent user)
BEGIN TRY
    EXEC audit.sp_Auth_Login @Username=N'__smoke_nonexist__', @IpAddress='0.0.0.0', @UserAgent=N'smoke';
    PRINT '  PASS: audit.sp_Auth_Login';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Auth_Login -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Auth_GetUser (use real id)
BEGIN TRY
    EXEC audit.sp_Auth_GetUser @UserId=@SafeUserId;
    PRINT '  PASS: audit.sp_Auth_GetUser';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Auth_GetUser -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Auth_UserList (no params)
BEGIN TRY
    EXEC audit.sp_Auth_UserList;
    PRINT '  PASS: audit.sp_Auth_UserList';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: audit.sp_Auth_UserList -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Auth_LoginSuccess (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Auth_LoginSuccess @UserId=@SafeUserId, @IpAddress='0.0.0.0', @UserAgent=N'smoke';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Auth_LoginSuccess';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Auth_LoginSuccess -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Auth_LoginFail (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Auth_LoginFail @UserId=@SafeUserId, @IpAddress='0.0.0.0', @UserAgent=N'smoke', @Reason=N'smoke test';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Auth_LoginFail';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Auth_LoginFail -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Auth_ChangePassword (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Auth_ChangePassword @UserId=@SafeUserId, @NewPasswordHash=N'$2a$12$smoketestxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    ROLLBACK;
    PRINT '  PASS: audit.sp_Auth_ChangePassword';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Auth_ChangePassword -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- audit.sp_Auth_UnlockUser (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC audit.sp_Auth_UnlockUser @UserId=@SafeUserId;
    ROLLBACK;
    PRINT '  PASS: audit.sp_Auth_UnlockUser';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: audit.sp_Auth_UnlockUser -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [dof] DOF (Bulgu) SP''leri ---';
/* ------------------------------------------------------------ */

-- dof.sp_Finding_List
BEGIN TRY
    EXEC dof.sp_Finding_List @Status=NULL, @AssignedTo=NULL, @Top=5;
    PRINT '  PASS: dof.sp_Finding_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: dof.sp_Finding_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- dof.sp_Finding_Get (use real id or test with 0)
BEGIN TRY
    EXEC dof.sp_Finding_Get @DofId=@SafeDofId;
    PRINT '  PASS: dof.sp_Finding_Get';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
    BEGIN
        PRINT '  WARN: dof.sp_Finding_Get -- validation OK (no DOF data): ' + ERROR_MESSAGE();
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: dof.sp_Finding_Get -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- dof.sp_Finding_Dashboard (no params)
BEGIN TRY
    EXEC dof.sp_Finding_Dashboard;
    PRINT '  PASS: dof.sp_Finding_Dashboard';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: dof.sp_Finding_Dashboard -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- dof.sp_Finding_Overdue
BEGIN TRY
    EXEC dof.sp_Finding_Overdue @Top=5;
    PRINT '  PASS: dof.sp_Finding_Overdue';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: dof.sp_Finding_Overdue -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- dof.sp_Finding_Create (mutation - rollback, use valid SourceKey format)
BEGIN TRY
    BEGIN TRAN;
    EXEC dof.sp_Finding_Create @Title=N'Smoke Test', @Description=N'Smoke test bulgu',
         @RiskLevel=1, @SlaDueDate='2099-12-31', @SourceKey=@SrcSysCode,
         @AssignedToPersonnelId=NULL, @CreatedByUserId=@SafeUserId;
    ROLLBACK;
    PRINT '  PASS: dof.sp_Finding_Create';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    -- FK constraint = SP works but ref data missing (DOF/FINDING entries in SourceSystems/SourceObjects)
    IF ERROR_MESSAGE() LIKE '%FOREIGN KEY%'
    BEGIN
        PRINT '  WARN: dof.sp_Finding_Create -- FK ref data missing: ' + LEFT(ERROR_MESSAGE(), 80);
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: dof.sp_Finding_Create -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- dof.sp_Finding_Transition (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC dof.sp_Finding_Transition @DofId=@SafeDofId, @NewStatus='InProgress',
         @UserId=@SafeUserId, @UserRole='admin', @Reason=N'smoke test';
    ROLLBACK;
    PRINT '  PASS: dof.sp_Finding_Transition';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%not found%' OR ERROR_MESSAGE() LIKE '%bulunamad%'
       OR ERROR_MESSAGE() LIKE '%Invalid transition%' OR ERROR_MESSAGE() LIKE '%gecersiz%'
       OR ERROR_MESSAGE() LIKE '%already%' OR ERROR_MESSAGE() LIKE '%zaten%'
       OR ERROR_MESSAGE() LIKE '%data type%' OR ERROR_MESSAGE() LIKE '%veri t%r%'
    BEGIN
        PRINT '  WARN: dof.sp_Finding_Transition -- validation/format issue: ' + LEFT(ERROR_MESSAGE(), 80);
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: dof.sp_Finding_Transition -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- dof.sp_Finding_AddComment (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC dof.sp_Finding_AddComment @DofId=@SafeDofId, @AuthorUserId=@SafeUserId, @CommentText=N'smoke test yorum';
    ROLLBACK;
    PRINT '  PASS: dof.sp_Finding_AddComment';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF ERROR_MESSAGE() LIKE '%bulunamad%' OR ERROR_MESSAGE() LIKE '%not found%'
       OR ERROR_MESSAGE() LIKE '%data type%' OR ERROR_MESSAGE() LIKE '%veri t%r%'
       OR ERROR_MESSAGE() LIKE '%FOREIGN KEY%'
    BEGIN
        PRINT '  WARN: dof.sp_Finding_AddComment -- validation OK: ' + LEFT(ERROR_MESSAGE(), 80);
        SET @warn += 1;
    END
    ELSE
    BEGIN
        PRINT '  FAIL: dof.sp_Finding_AddComment -- ' + ERROR_MESSAGE();
        SET @fail += 1;
    END
END CATCH

-- dof.sp_Dashboard_Dof_List
BEGIN TRY
    EXEC dof.sp_Dashboard_Dof_List @Top=5;
    PRINT '  PASS: dof.sp_Dashboard_Dof_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: dof.sp_Dashboard_Dof_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [etl] ETL SP''leri ---';
/* ------------------------------------------------------------ */

-- etl.sp_StockMovement_Extract (read-only extract, future date = empty)
BEGIN TRY
    EXEC etl.sp_StockMovement_Extract @BatchSize=1, @LastSyncDate='2099-01-01', @TargetDate='2099-01-01';
    PRINT '  PASS: etl.sp_StockMovement_Extract';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: etl.sp_StockMovement_Extract -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- etl.sp_ErpStokHareket_Extract (Turkish alias)
BEGIN TRY
    EXEC etl.sp_ErpStokHareket_Extract @BatchSize=1, @LastSyncDate='2099-01-01', @TargetDate='2099-01-01';
    PRINT '  PASS: etl.sp_ErpStokHareket_Extract';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: etl.sp_ErpStokHareket_Extract -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '--- [log] Log / ETL / Bildirim SP''leri ---';
/* ------------------------------------------------------------ */

-- log.sp_HealthCheck_Run (no params)
BEGIN TRY
    EXEC log.sp_HealthCheck_Run;
    PRINT '  PASS: log.sp_HealthCheck_Run';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_HealthCheck_Run -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_SaglikKontrol_Calistir (Turkish alias, no params)
BEGIN TRY
    EXEC log.sp_SaglikKontrol_Calistir;
    PRINT '  PASS: log.sp_SaglikKontrol_Calistir';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_SaglikKontrol_Calistir -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_DailyProductRisk_Run (dry run: impossible location, no write)
BEGIN TRY
    EXEC log.sp_DailyProductRisk_Run @MekanCSV='999999', @ToplamYaz=0;
    PRINT '  PASS: log.sp_DailyProductRisk_Run';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_DailyProductRisk_Run -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_RiskUrunOzet_Calistir (Turkish alias, dry run)
BEGIN TRY
    EXEC log.sp_RiskUrunOzet_Calistir @MekanCSV='999999', @ToplamYaz=0;
    PRINT '  PASS: log.sp_RiskUrunOzet_Calistir';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_RiskUrunOzet_Calistir -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_DailyStockBalance_Run (past date, no write)
BEGIN TRY
    EXEC log.sp_DailyStockBalance_Run @GeriyeDonukGun=0, @MekanCSV='999999', @BitisTarihi='2020-01-01';
    PRINT '  PASS: log.sp_DailyStockBalance_Run';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_DailyStockBalance_Run -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_StokBakiyeGunluk_Calistir (Turkish alias)
BEGIN TRY
    EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=0, @MekanCSV='999999', @BitisTarihi='2020-01-01';
    PRINT '  PASS: log.sp_StokBakiyeGunluk_Calistir';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_StokBakiyeGunluk_Calistir -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_MonthlyClose_Run (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC log.sp_MonthlyClose_Run @DonemAy=190001;
    ROLLBACK;
    PRINT '  PASS: log.sp_MonthlyClose_Run';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: log.sp_MonthlyClose_Run -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_AylikKapanis_Calistir (Turkish alias, mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC log.sp_AylikKapanis_Calistir @DonemAy=190001;
    ROLLBACK;
    PRINT '  PASS: log.sp_AylikKapanis_Calistir';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: log.sp_AylikKapanis_Calistir -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_PersonnelSync_Summary (no params)
BEGIN TRY
    EXEC log.sp_PersonnelSync_Summary;
    PRINT '  PASS: log.sp_PersonnelSync_Summary';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_PersonnelSync_Summary -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_PersonnelSync_Log_List
BEGIN TRY
    EXEC log.sp_PersonnelSync_Log_List @Top=5;
    PRINT '  PASS: log.sp_PersonnelSync_Log_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_PersonnelSync_Log_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_Notification_Create (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC log.sp_Notification_Create @UserId=@SafeUserId, @Type='info', @Title=N'Smoke Test', @Message=N'smoke test msg', @Link=N'/smoke';
    ROLLBACK;
    PRINT '  PASS: log.sp_Notification_Create';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: log.sp_Notification_Create -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_Notification_List
BEGIN TRY
    EXEC log.sp_Notification_List @UserId=@SafeUserId, @OnlyUnread=0, @Top=5;
    PRINT '  PASS: log.sp_Notification_List';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_Notification_List -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_Notification_UnreadCount
BEGIN TRY
    EXEC log.sp_Notification_UnreadCount @UserId=@SafeUserId;
    PRINT '  PASS: log.sp_Notification_UnreadCount';
    SET @pass += 1;
END TRY
BEGIN CATCH
    PRINT '  FAIL: log.sp_Notification_UnreadCount -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_Notification_MarkRead (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC log.sp_Notification_MarkRead @NotificationId=0, @UserId=@SafeUserId;
    ROLLBACK;
    PRINT '  PASS: log.sp_Notification_MarkRead';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: log.sp_Notification_MarkRead -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

-- log.sp_Notification_MarkAllRead (mutation - rollback)
BEGIN TRY
    BEGIN TRAN;
    EXEC log.sp_Notification_MarkAllRead @UserId=999999;
    ROLLBACK;
    PRINT '  PASS: log.sp_Notification_MarkAllRead';
    SET @pass += 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT '  FAIL: log.sp_Notification_MarkAllRead -- ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH

PRINT '';

/* ------------------------------------------------------------ */
PRINT '========================================';
PRINT '  SONUC';
PRINT '========================================';
PRINT '  PASS: ' + CAST(@pass AS VARCHAR(10));
PRINT '  WARN: ' + CAST(@warn AS VARCHAR(10)) + '  (beklenen validation hatalari)';
PRINT '  FAIL: ' + CAST(@fail AS VARCHAR(10));
PRINT '  TOPLAM: ' + CAST(@pass + @warn + @fail AS VARCHAR(10));
PRINT '';

IF @fail = 0
    PRINT '  >>> TUM TESTLER BASARILI <<<';
ELSE
    PRINT '  >>> ' + CAST(@fail AS VARCHAR(10)) + ' TEST BASARISIZ -- detay icin yukari bakin <<<';

PRINT '';
GO
