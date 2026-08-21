-- ============================================================================
-- 71 — Ogrenilen bilgiyi skill baglamina bagla
--
-- sql/70 sorulari ve cevaplari uretti ama cevap prompt'a ulasmiyordu —
-- sql/66'da yasanan hatanin aynisi: parca kuruldu, kapi acilmadi.
--
-- NEDEN FONKSIYON: sp_SkillContext_Build baska bir SP'nin sonucunu almak
-- icin INSERT ... EXEC kullanmak zorunda kalirdi; o SP'nin kendisi de
-- INSERT ... EXEC ile cagrilabildigi icin SQL Server "ic ice INSERT EXEC"
-- hatasi verir. Mantik skaler fonksiyona alinarak sorun tamamen kaldirildi;
-- hem SP hem fonksiyon ayni kaynagi kullanir, kopya mantik olusmaz.
--
-- Idempotent: CREATE OR ALTER.
-- ============================================================================

------------------------------------------------------------------------------
-- 1. ai.fn_LearningContext — ogrenilenlerin tek metin hali
--
-- Uc kaynak: insan kararlari, reddedilen ciktilar (+gerekce), onaylanmis
-- ornekler. Hicbiri yoksa NULL doner — bos blok prompt butcesi harcamasin.
------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION ai.fn_LearningContext
(
    @SkillId varchar(50) = NULL,
    @TopRed  int = 2,
    @TopOnay int = 2
)
RETURNS nvarchar(max)
AS
BEGIN
    DECLARE @Sonuc nvarchar(max) = NULL;

    -- 1) Insan kararlari — en agir basan kaynak, hepsi verilir
    DECLARE @Kararlar nvarchar(max) = (
        SELECT STRING_AGG(CAST(N'- ' + f.FactText AS nvarchar(max)), CHAR(10))
          FROM ai.LearningFacts f
         WHERE f.IsActive = 1 AND (f.SkillId IS NULL OR f.SkillId = @SkillId));

    IF @Kararlar IS NOT NULL
        SET @Sonuc = N'DENETIM EKIBININ VERDIGI KARARLAR (bunlara UY):' + CHAR(10) + @Kararlar;

    -- 2) Reddedilmis ciktilar — gerekcesi olanlar; gerekcesiz red ogretmez
    DECLARE @Redler nvarchar(max) = (
        SELECT STRING_AGG(CAST(N'- Red gerekcesi: ' + r.Gerekce + CHAR(10)
                             + N'  Reddedilen cikti: ' + r.Cikti AS nvarchar(max)), CHAR(10))
          FROM (SELECT TOP (@TopRed)
                       f.UserComment AS Gerekce,
                       LEFT(COALESCE(se.OutputJson, lr.ResultText), 400) AS Cikti,
                       f.CreatedAt
                  FROM ai.Feedback f
                  LEFT JOIN ai.SkillExecutions se ON se.ExecutionId = f.SkillExecutionId
                  LEFT JOIN ai.LlmResults     lr ON lr.RequestId    = f.RequestId
                 WHERE f.IsApproved = 0
                   AND NULLIF(LTRIM(RTRIM(f.UserComment)), N'') IS NOT NULL
                   AND (@SkillId IS NULL OR COALESCE(se.SkillId, 'analysis') = @SkillId)
                 ORDER BY f.CreatedAt DESC) r);

    IF @Redler IS NOT NULL
        SET @Sonuc = ISNULL(@Sonuc + CHAR(10) + CHAR(10), N'')
                   + N'GECMISTE REDDEDILEN CIKTILAR (bu hatalari TEKRARLAMA):' + CHAR(10) + @Redler;

    -- 3) Onaylanmis ornekler — SKILL BAZLI. Karisik ornek gurultu uretir:
    --    5-neden ornegini trend prompt'una koymak modeli yaniltiyordu.
    DECLARE @Onaylar nvarchar(max) = (
        SELECT STRING_AGG(CAST(N'- ' + o.Cikti AS nvarchar(max)), CHAR(10))
          FROM (SELECT TOP (@TopOnay)
                       LEFT(COALESCE(se.OutputJson, lr.ResultText), 500) AS Cikti,
                       f.Rating, f.CreatedAt
                  FROM ai.Feedback f
                  LEFT JOIN ai.SkillExecutions se ON se.ExecutionId = f.SkillExecutionId
                  LEFT JOIN ai.LlmResults     lr ON lr.RequestId    = f.RequestId
                 WHERE f.IsApproved = 1 AND f.Rating >= 4
                   AND NULLIF(COALESCE(se.OutputJson, lr.ResultText), N'') IS NOT NULL
                   AND (@SkillId IS NULL OR COALESCE(se.SkillId, 'analysis') = @SkillId)
                 ORDER BY f.Rating DESC, f.CreatedAt DESC) o);

    IF @Onaylar IS NOT NULL
        SET @Sonuc = ISNULL(@Sonuc + CHAR(10) + CHAR(10), N'')
                   + N'ONAYLANMIS ORNEKLER (bicim ve derinlik olarak bunlari izle):' + CHAR(10) + @Onaylar;

    RETURN @Sonuc;
END
GO

------------------------------------------------------------------------------
-- 2. sp_LearningContext_Get artik ayni fonksiyonu kullanir (tek kaynak)
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ai.sp_LearningContext_Get
    @SkillId varchar(50) = NULL,
    @TopRed  int = 2,
    @TopOnay int = 2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ai.fn_LearningContext(@SkillId, @TopRed, @TopOnay) AS Metin;
END
GO

PRINT '71_learning_context_wire.sql tamamlandi.';
GO
