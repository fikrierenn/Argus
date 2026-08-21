-- ============================================================================
-- 66 — Skill prompt'larina semantik baglam blogu (TODO B1 tamamlayici)
--
-- sql/65 ile sem.* katmani doldu (94 varlik, 63 kopru, 40 metrik, 14 golden
-- sorgu, 22 ipucu) ve AiWorkerService bunu {{SemantikBaglam}} degiskenine
-- yukluyor. Ama 10 skill prompt'undan HICBIRI o degiskeni kullanmiyordu —
-- yani baglam uretiliyor, tasiniyor ve atiliyordu.
--
-- Bu, bu projede tekrar eden desen: parca kuruluyor, baglanmiyor, "yapildi"
-- sayiliyor. Kontrol: prompt'ta degisken ADI gecmiyorsa deger asla yerine
-- konmaz (SkillExecutor.RenderTemplate basit metin degistirme yapar).
--
-- Blok SISTEM prompt'una eklenir, kullanici prompt'una degil: sema bilgisi
-- modelin NASIL akil yurutecegine dair bir kisittir, kullanicinin sordugu
-- seyin parcasi degil.
--
-- sp_Skill_Upsert prompt degisince YENI SURUM acar; eski cikti hangi
-- prompt'la uretildi izlenebilir kalir.
--
-- Idempotent: blok zaten varsa skill atlanir.
-- ============================================================================

SET NOCOUNT ON;
GO

DECLARE @blok nvarchar(max) = N'

SEMA BAGLAMI
Asagida bu konuyla ilgili dogrulanmis sema bilgisi var: tablolar, join yollari,
kod anlamlari, metrik tanimlari ve calistirilarak dogrulanmis ornek sorgular.

{{SemantikBaglam}}

Bu baglami kullanirken:
- Burada YAZMAYAN bir tablo, kolon veya join UYDURMA. Bilmiyorsan "bu bilgi
  semada tanimli degil" de.
- Metriklerin TUZAK notlarina uy; bir metrigin neyi ICERMEDIGI, ne oldugundan
  daha sik hataya yol acar.
- Baglam bos gelirse sema hakkinda hicbir iddiada bulunma, yalnizca sana
  verilen veriye dayan.';

DECLARE @SkillId varchar(50), @Ad nvarchar(200), @Aciklama nvarchar(1000),
        @Kategori varchar(50), @TetikModu varchar(20), @CiktiTipi varchar(20),
        @GerekliBaglam varchar(200), @Sicaklik decimal(3,2), @MaksToken int,
        @Sys nvarchar(max), @Usr nvarchar(max), @SysYeni nvarchar(max);

DECLARE @guncellenen int = 0, @atlanan int = 0;

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.SkillId, s.Name, s.Description, s.Category, s.TriggerMode, s.OutputType,
           s.RequiredContext, s.Temperature, s.MaxTokens,
           v.SystemPromptTemplate, v.UserPromptTemplate
    FROM   ai.Skills s
    JOIN   ai.SkillVersions v ON v.SkillId = s.SkillId AND v.VersionNo = s.CurrentVersion
    WHERE  s.IsActive = 1;

OPEN c;
FETCH NEXT FROM c INTO @SkillId, @Ad, @Aciklama, @Kategori, @TetikModu, @CiktiTipi,
                       @GerekliBaglam, @Sicaklik, @MaksToken, @Sys, @Usr;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Is kurali: blok zaten varsa yeni surum acma (idempotency)
    IF @Sys LIKE '%{{SemantikBaglam}}%' OR @Usr LIKE '%{{SemantikBaglam}}%'
    BEGIN
        SET @atlanan += 1;
    END
    ELSE
    BEGIN
        -- EXEC parametresi ifade kabul etmez; once degiskene al
        SET @SysYeni = @Sys + @blok;

        EXEC ai.sp_Skill_Upsert
            @SkillId         = @SkillId,
            @Ad              = @Ad,
            @Aciklama        = @Aciklama,
            @Kategori        = @Kategori,
            @TetikModu       = @TetikModu,
            @CiktiTipi       = @CiktiTipi,
            @GerekliBaglam   = @GerekliBaglam,
            @Sicaklik        = @Sicaklik,
            @MaksToken       = @MaksToken,
            @SistemPrompt    = @SysYeni,
            @KullaniciPrompt = @Usr,
            @DegisiklikNotu  = N'Semantik baglam blogu eklendi (sql/66). sem.* katmani artik prompt''a tasiniyor.';

        SET @guncellenen += 1;
    END

    FETCH NEXT FROM c INTO @SkillId, @Ad, @Aciklama, @Kategori, @TetikModu, @CiktiTipi,
                           @GerekliBaglam, @Sicaklik, @MaksToken, @Sys, @Usr;
END

CLOSE c;
DEALLOCATE c;

PRINT CONCAT(N'66_skill_semantic_context: ', @guncellenen, N' skill guncellendi, ',
             @atlanan, N' zaten iceriyordu.');
GO
