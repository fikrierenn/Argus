-- ============================================================================
-- 69 — ai.sp_SkillExecution_Update: prompt surum izi
--
-- SkillExecutor zaten skill.VersionNo'yu hesaplayip SkillResult'a koyuyordu
-- (SkillExecutor.cs:49) ama SP'de karsilik parametre olmadigi icin deger
-- atiliyordu: ai.SkillExecutions.SkillVersionNo tum satirlarda NULL.
--
-- Sonuc: prompt'u revize edince eski ciktinin hangi surumle uretildigi
-- bilinemiyordu — surumlemenin tek amaci buydu. sql/66 ile 10 skill'in
-- tamami surum 2'ye gecti; hangi ciktinin 1, hangisinin 2 oldugunu ayirt
-- edecek veri yoktu.
--
-- Idempotent: CREATE OR ALTER.
-- ============================================================================

CREATE OR ALTER PROCEDURE ai.sp_SkillExecution_Update
    @ExecutionId int,
    @Durum       varchar(20),
    @CiktiJson   nvarchar(max) = NULL,
    @ModelAdi    varchar(100)  = NULL,
    @GuvenSkoru  int           = NULL,
    @HataMesaji  nvarchar(1000)= NULL,
    @SurumNo     int           = NULL   -- hangi prompt surumu uretti
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        UPDATE ai.SkillExecutions
           SET Status          = @Durum,
               OutputJson      = ISNULL(@CiktiJson, OutputJson),
               ModelName       = ISNULL(@ModelAdi, ModelName),
               ConfidenceScore = ISNULL(@GuvenSkoru, ConfidenceScore),
               ErrorMessage    = @HataMesaji,
               SkillVersionNo  = ISNULL(@SurumNo, SkillVersionNo),
               CompletedAt     = CASE WHEN @Durum IN ('DONE','ERROR')
                                      THEN SYSDATETIME() ELSE CompletedAt END
         WHERE ExecutionId = @ExecutionId;

        IF @@ROWCOUNT = 0
            THROW 50410, N'Skill calistirma kaydi bulunamadi.', 1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '69_skill_execution_version.sql tamamlandi.';
GO
