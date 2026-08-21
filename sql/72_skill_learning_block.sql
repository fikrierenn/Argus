-- ============================================================================
-- 72 — Skill prompt'larina OGRENILEN BILGI blogu (ogrenme dongusu)
--
-- sql/70-71 ogrenme dongusunu kurdu: tutarsizlik taramasi soru uretiyor,
-- insan cevapliyor, cevap ai.LearningFacts'e dusuyor, ai.fn_LearningContext
-- bunu tek metne ceviriyor ve sp_SkillContext_Build {{OgrenilenBilgi}}
-- degiskenine yaziyor.
--
-- Ama prompt'larda o degisken GECMIYORDU. RenderTemplate duz metin
-- degistirme yapar: adi gecmeyen degisken hicbir zaman yerine konmaz ve
-- kimse hata vermez. sql/66'da ayni hata {{SemantikBaglam}} icin yasandi.
-- Bu blok kapiyi aciyor.
--
-- Idempotent: blok zaten varsa skill atlanir.
-- ============================================================================

SET NOCOUNT ON;
GO

DECLARE @blok nvarchar(max) = N'

OGRENILEN BILGI
Asagidaki bilgi denetim ekibinin GECMISTEKI KARARLARINDAN ve senin onceki
ciktilarina verdikleri geri bildirimden geliyor. Sema bilgisi degildir —
bu ekibin bu konudaki durusudur.

{{OgrenilenBilgi}}

Bu bilgiyi kullanirken:
- Ekibin verdigi karar senin genel muhakemenden ONCELIKLIDIR. Karar bir
  alanin guvenilmez oldugunu soyluyorsa o alana dayanan iddia kurma.
- Reddedilen bir ciktinin gerekcesini okudugun halde ayni hatayi
  tekrarlarsan cikti yine reddedilir.
- Blok bosssa gecmis karar yok demektir; kendi muhakemeni kullan.';

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
    IF @Sys LIKE '%{{OgrenilenBilgi}}%' OR @Usr LIKE '%{{OgrenilenBilgi}}%'
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
            @DegisiklikNotu  = N'Ogrenilen bilgi blogu eklendi (sql/72). Insan kararlari ve red gerekceleri prompt''a tasiniyor.';

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
