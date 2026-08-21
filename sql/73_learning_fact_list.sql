-- ============================================================================
-- 73 — ai.sp_LearningFact_List: ogrenilen bilgilerin ekran listesi
--
-- Ogrenme ekrani "AI su an neyi biliyor" sorusunu yanitlayabilmeli. Bilgi
-- gorunmezse kullanici sistemin ogrendigine guvenemez; yanlis ogrenilmis bir
-- karari da fark edip kaldiramaz.
-- ============================================================================

CREATE OR ALTER PROCEDURE ai.sp_LearningFact_List
    @SadeceAktif bit = 1,
    @SkillId     varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT f.FactId, f.SkillId, f.FactText, f.SourceType, f.SourceId,
               f.Weight, f.IsActive, f.CreatedAt
          FROM ai.LearningFacts f
         WHERE (@SadeceAktif = 0 OR f.IsActive = 1)
           AND (@SkillId IS NULL OR f.SkillId IS NULL OR f.SkillId = @SkillId)
         ORDER BY f.IsActive DESC, f.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Yanlis ogrenilmis bir karari geri almak icin
CREATE OR ALTER PROCEDURE ai.sp_LearningFact_SetActive
    @BilgiId     int,
    @Aktif       bit,
    @KullaniciId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        UPDATE ai.LearningFacts
           SET IsActive = @Aktif, UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
         WHERE FactId = @BilgiId;

        IF @@ROWCOUNT = 0
            THROW 50730, N'Ogrenilen bilgi kaydi bulunamadi.', 1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '73_learning_fact_list.sql tamamlandi.';
GO
