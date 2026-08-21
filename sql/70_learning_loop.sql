-- ============================================================================
-- 70 — Ogrenme dongusu: tutarsizlik tespiti -> insana soru -> kalici bilgi
--
-- NEDEN: ai.Feedback tablosu vardi, endpoint vardi, sp_Feedback_TopApproved
-- onaylanmis ciktilari few-shot olarak geri veriyordu — ama tabloda 0 kayit
-- vardi ve dongu hic donmemisti. Ustelik yalnizca ONAY ogretiyordu
-- (IsApproved=1 AND Rating>=4); RED sinyali — ki en degerlisi odur, cunku
-- "sunu yanlis dedin, cunku su" bilgisini tasir — hic kullanilmiyordu.
--
-- KATMAN SECIMI (ai-layer.md kademeli maliyet): tutarsizlik tespiti bir
-- KURAL isidir, LLM isi degil. Tamami deterministik SQL, sifir maliyet.
-- LLM bu dosyada hic cagrilmaz.
--
-- TOPLU SORU ILKESI: 91 satirda denetci notu bos. Kullaniciya 91 kez sormak
-- ise yaramaz — bir kez sorulur, cevap POLITIKA olur ve sonraki tum skill
-- calistirmalarinin baglamina girer. Soru basina ornek + sayi verilir;
-- sayilar SQL'den gelir (halusinasyon kapisi).
--
-- Idempotent: sorular imza (Signature) ile tekillestirilir; tarama tekrar
-- kosarsa acik soruyu cogaltmaz, yalnizca sayisini gunceller.
-- ============================================================================

SET NOCOUNT ON;
GO

------------------------------------------------------------------------------
-- 1. ai.LearningQuestions — sisteme sorulan, insana yoneltilen sorular
------------------------------------------------------------------------------
IF OBJECT_ID('ai.LearningQuestions', 'U') IS NULL
BEGIN
    CREATE TABLE ai.LearningQuestions
    (
        QuestionId      int IDENTITY(1,1) NOT NULL,
        -- Ayni tutarsizligin tekrar sorulmasini engelleyen imza
        Signature       varchar(200)   NOT NULL,
        Category        varchar(50)    NOT NULL,   -- VERI_EKSIK | CELISKI | SLA | BAYAT_SEMA
        Severity        varchar(20)    NOT NULL,   -- kritik | uyari | bilgi
        QuestionText    nvarchar(1000) NOT NULL,
        -- Iddiayi dogrulayan sayi ve ornek: SQL'den gelir, LLM uretmez
        AffectedCount   int            NOT NULL CONSTRAINT DF_LQ_Count DEFAULT(0),
        EvidenceSample  nvarchar(max)  NULL,
        -- Kullanicinin secebilecegi hazir cevaplar (JSON dizi)
        OptionsJson     nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_LQ_Status DEFAULT('ACIK'),
        AnswerText      nvarchar(2000) NULL,
        AnsweredByUserId int           NULL,
        AnsweredAt      datetime2(0)   NULL,
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_LQ_Created DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CONSTRAINT PK_LearningQuestions PRIMARY KEY (QuestionId),
        CONSTRAINT UQ_LearningQuestions_Signature UNIQUE (Signature),
        CONSTRAINT CK_LearningQuestions_Status
            CHECK (Status IN ('ACIK','CEVAPLANDI','YOKSAYILDI')),
        CONSTRAINT CK_LearningQuestions_Severity
            CHECK (Severity IN ('kritik','uyari','bilgi'))
    );

    CREATE INDEX IX_LearningQuestions_Status ON ai.LearningQuestions (Status, Severity);
END
GO

------------------------------------------------------------------------------
-- 2. ai.LearningFacts — cevaplardan dogan kalici bilgi (skill baglamina girer)
--
-- Bir soru cevaplandiginda buraya bir satir duser. Bundan sonra ilgili
-- skill'in her calistirmasinda prompt'a tasinir — ogrenmenin gerceklestigi
-- yer burasidir. Kaynak izlenebilir kalir (SourceType/SourceId).
------------------------------------------------------------------------------
IF OBJECT_ID('ai.LearningFacts', 'U') IS NULL
BEGIN
    CREATE TABLE ai.LearningFacts
    (
        FactId          int IDENTITY(1,1) NOT NULL,
        -- Kapsam: NULL = tum skill'ler, dolu = yalniz o skill
        SkillId         varchar(50)    NULL,
        FactText        nvarchar(2000) NOT NULL,
        -- Nereden ogrenildi: SORU (insan cevabi) | RED (reddedilen cikti)
        SourceType      varchar(20)    NOT NULL,
        SourceId        int            NULL,
        Weight          decimal(3,2)   NOT NULL CONSTRAINT DF_LF_Weight DEFAULT(1.00),
        IsActive        bit            NOT NULL CONSTRAINT DF_LF_Active DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_LF_Created DEFAULT(SYSDATETIME()),
        CreatedByUserId int            NULL,
        UpdatedAt       datetime2(0)   NULL,
        UpdatedByUserId int            NULL,
        CONSTRAINT PK_LearningFacts PRIMARY KEY (FactId),
        CONSTRAINT CK_LearningFacts_Source CHECK (SourceType IN ('SORU','RED','ELLE'))
    );

    CREATE INDEX IX_LearningFacts_Skill ON ai.LearningFacts (IsActive, SkillId);
END
GO

------------------------------------------------------------------------------
-- 3. ai.sp_Consistency_Scan — deterministik tutarsizlik taramasi
--
-- Sifir LLM maliyeti. Her bulgu TOPLU bir soruya donusur; ayni imza tekrar
-- gelirse yeni satir acilmaz, sayisi guncellenir (idempotency).
-- Cevaplanmis bir soru tekrar ACIK'a donmez — insan zaten karar verdi.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ai.sp_Consistency_Scan
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @Bulgu TABLE
        (
            Signature      varchar(200),
            Category       varchar(50),
            Severity       varchar(20),
            QuestionText   nvarchar(1000),
            AffectedCount  int,
            EvidenceSample nvarchar(max),
            OptionsJson    nvarchar(max)
        );

        ------------------------------------------------------------------
        -- (a) Uygunsuz bulunmus ama denetci notu bos maddeler
        -- Bu, AI'in "neden uygunsuz" sorusunu yanitlayamamasinin kok sebebi
        ------------------------------------------------------------------
        DECLARE @NotsuzSayi int = (
            SELECT COUNT(*) FROM audit.AuditResults
             WHERE IsPassed = 0 AND NULLIF(LTRIM(RTRIM(Remark)), N'') IS NULL);

        IF @NotsuzSayi > 0
            INSERT INTO @Bulgu VALUES (
                'REMARK_BOS', 'VERI_EKSIK', 'kritik',
                N'Uygunsuz bulunan maddelerin ' + CAST(@NotsuzSayi AS nvarchar(10))
                  + N' tanesinde denetci notu (Remark) bos. AI bir bulgunun NEDEN '
                  + N'uygunsuz oldugunu bilemiyor; yalniz maddenin metnini goruyor. '
                  + N'Bu alan zorunlu hale getirilsin mi?',
                @NotsuzSayi,
                (SELECT TOP 5 STRING_AGG(CAST(N'- ' + LEFT(r.ItemText, 90) AS nvarchar(max)), CHAR(10))
                   FROM (SELECT TOP 5 ItemText FROM audit.AuditResults
                          WHERE IsPassed = 0 AND NULLIF(LTRIM(RTRIM(Remark)), N'') IS NULL
                          ORDER BY RiskScore DESC) r),
                N'["Evet — uygunsuz maddede not zorunlu olsun",
                   "Hayir — not opsiyonel kalsin, AI notsuz calissin",
                   "Yalniz kritik/yuksek riskli maddelerde zorunlu olsun"]');

        ------------------------------------------------------------------
        -- (b) SLA suresi gecmis ama hala acik DOF'lar
        ------------------------------------------------------------------
        DECLARE @SlaSayi int = (
            SELECT COUNT(*) FROM dof.Findings
             WHERE Status <> N'CLOSED' AND SlaDueDate < SYSDATETIME());

        IF @SlaSayi > 0
            INSERT INTO @Bulgu VALUES (
                'SLA_ASILDI', 'SLA', 'kritik',
                N'SLA suresi gecmis ancak hala acik ' + CAST(@SlaSayi AS nvarchar(10))
                  + N' DOF var. Bunlar gercekten gecikmis mi, yoksa SLA tarihi '
                  + N'bastan yanlis mi hesaplandi? AI gecikmeyi bulgu sayacak.',
                @SlaSayi,
                (SELECT STRING_AGG(CAST(N'- DOF #' + CAST(f.DofId AS nvarchar(10)) + N' ('
                        + CONVERT(nvarchar(10), f.SlaDueDate, 104) + N') ' + LEFT(f.Title, 60) AS nvarchar(max)), CHAR(10))
                   FROM (SELECT TOP 5 DofId, SlaDueDate, Title FROM dof.Findings
                          WHERE Status <> N'CLOSED' AND SlaDueDate < SYSDATETIME()
                          ORDER BY SlaDueDate) f),
                N'["Gercekten gecikmis — AI bunlari eskalasyon konusu saysin",
                   "SLA tarihleri hatali kurulmus — AI gecikme iddiasinda bulunmasin",
                   "Bu kayitlar test/gecmis veri — AI bunlari yok saysin"]');

        ------------------------------------------------------------------
        -- (c) Kapatilmis ama etkinlik notu olmayan DOF'lar
        ------------------------------------------------------------------
        DECLARE @KapaliNotsuz int = (
            SELECT COUNT(*) FROM dof.Findings
             WHERE Status = N'CLOSED' AND NULLIF(LTRIM(RTRIM(EffectivenessNote)), N'') IS NULL);

        IF @KapaliNotsuz > 0
            INSERT INTO @Bulgu VALUES (
                'KAPANIS_NOTU_BOS', 'VERI_EKSIK', 'uyari',
                N'Kapatilmis ' + CAST(@KapaliNotsuz AS nvarchar(10))
                  + N' DOF''ta etkinlik notu bos. AI "duzeltme ise yaradi mi" '
                  + N'sorusunu yanitlayamaz — kanit yok.',
                @KapaliNotsuz,
                (SELECT STRING_AGG(CAST(N'- DOF #' + CAST(f.DofId AS nvarchar(10)) + N' ' + LEFT(f.Title, 70) AS nvarchar(max)), CHAR(10))
                   FROM (SELECT TOP 5 DofId, Title FROM dof.Findings
                          WHERE Status = N'CLOSED' AND NULLIF(LTRIM(RTRIM(EffectivenessNote)), N'') IS NULL) f),
                N'["Kapanista etkinlik notu zorunlu olsun",
                   "Opsiyonel kalsin — AI etkinligi degerlendirmeye calismasin",
                   "Gecmis kayitlar icin gecerli degil, bundan sonrasi zorunlu"]');

        ------------------------------------------------------------------
        -- (d) RepeatCount > 1 ama baska denetimde karsiligi olmayan maddeler
        ------------------------------------------------------------------
        DECLARE @TekrarTutarsiz int = (
            SELECT COUNT(*) FROM (
                SELECT ItemText FROM audit.AuditResults
                 WHERE RepeatCount > 1 GROUP BY ItemText HAVING COUNT(*) = 1) z);

        IF @TekrarTutarsiz > 0
            INSERT INTO @Bulgu VALUES (
                'TEKRAR_TUTARSIZ', 'CELISKI', 'uyari',
                N'RepeatCount alani 1''den buyuk oldugu halde sistemde tek kaydi olan '
                  + CAST(@TekrarTutarsiz AS nvarchar(10)) + N' madde var. '
                  + N'Ya tekrar sayaci yanlis, ya gecmis denetim verisi eksik. '
                  + N'AI "tekrar eden bulgu" iddiasini buna dayandiriyor.',
                @TekrarTutarsiz,
                (SELECT STRING_AGG(CAST(N'- ' + LEFT(z.ItemText, 90) AS nvarchar(max)), CHAR(10))
                   FROM (SELECT TOP 5 ItemText FROM audit.AuditResults
                          WHERE RepeatCount > 1 GROUP BY ItemText HAVING COUNT(*) = 1) z),
                N'["Sayac yanlis — AI RepeatCount''a guvenmesin",
                   "Gecmis veri eksik — AI tekrar iddiasini dikkatli kursun",
                   "Dogru, gecmis denetimler sisteme girilmedi"]');

        ------------------------------------------------------------------
        -- (e) Ayni bulguda skill'ler celisiyor
        -- 5why "sistemsel" derken systemic.classify "TEKIL" diyebiliyor.
        -- Ikisi farkli soru yanitliyor ama ekranda celiski gibi okunur.
        ------------------------------------------------------------------
        DECLARE @SkillCeliski int = (
            SELECT COUNT(*)
              FROM ai.SkillExecutions a
              JOIN ai.SkillExecutions b
                ON b.EntityType = a.EntityType AND b.EntityId = a.EntityId
             WHERE a.SkillId = 'audit.rootcause.5why'
               AND b.SkillId = 'audit.systemic.classify'
               AND a.Status = 'DONE' AND b.Status = 'DONE'
               AND a.OutputJson LIKE '%"sistemselMi": true%'
               AND b.OutputJson LIKE '%"sinif": "TEKIL"%');

        IF @SkillCeliski > 0
            INSERT INTO @Bulgu VALUES (
                'SKILL_CELISKI_SISTEMIK', 'CELISKI', 'uyari',
                N'Ayni bulguda iki skill zit sonuc verdi: kok sebep analizi '
                  + N'"sistemsel" derken sistemiklik siniflandirmasi "TEKIL" dedi. '
                  + N'(' + CAST(@SkillCeliski AS nvarchar(10)) + N' kayit). Ikisi farkli sey '
                  + N'olcuyor olabilir — kok sebebin DOGASI ile bulgunun YAYILIMI. '
                  + N'AI bunlari nasil sunmali?',
                @SkillCeliski,
                N'5why.sistemselMi = kok sebep bir surec/sistem boslugu mu?' + CHAR(10)
                  + N'systemic.classify.sinif = bulgu kac mekanda goruldu?',
                N'["Ikisi farkli sey olcuyor — ekranda ayri ayri gosterilsin",
                   "Celiskidir — yayilim TEKIL ise kok sebep de sistemsel sayilmasin",
                   "Kok sebep sistemselse yayilimdan bagimsiz sistemik sayilsin"]');

        ------------------------------------------------------------------
        -- (f) Bayatlamis semantik katman kayitlari
        ------------------------------------------------------------------
        DECLARE @Bayat int = (SELECT COUNT(*) FROM sem.vw_Stale);

        IF @Bayat > 0
            INSERT INTO @Bulgu VALUES (
                'SEMA_BAYAT', 'BAYAT_SEMA', 'bilgi',
                N'Semantik katmanda ' + CAST(@Bayat AS nvarchar(10))
                  + N' kayit TTL suresini asti. AI bunlari hala dogruymus gibi '
                  + N'kullaniyor. Yeniden dogrulansin mi?',
                @Bayat, NULL,
                N'["Dogrulanana kadar AI baglamindan cikarilsin",
                   "Kullanilmaya devam etsin ama dusuk guvenle",
                   "TTL suresi uzatilsin"]');

        ------------------------------------------------------------------
        -- Yazma: imza bazli upsert. Cevaplanmis soru tekrar acilmaz.
        ------------------------------------------------------------------
        MERGE ai.LearningQuestions AS h
        USING @Bulgu AS k ON h.Signature = k.Signature
        WHEN MATCHED AND h.Status = 'ACIK' THEN
            UPDATE SET h.AffectedCount  = k.AffectedCount,
                       h.EvidenceSample = k.EvidenceSample,
                       h.QuestionText   = k.QuestionText,
                       h.Severity       = k.Severity,
                       h.UpdatedAt      = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (Signature, Category, Severity, QuestionText,
                    AffectedCount, EvidenceSample, OptionsJson)
            VALUES (k.Signature, k.Category, k.Severity, k.QuestionText,
                    k.AffectedCount, k.EvidenceSample, k.OptionsJson);

        -- Artik gecerli olmayan acik sorulari kapat (sorun cozulmus demektir)
        UPDATE ai.LearningQuestions
           SET Status = 'YOKSAYILDI',
               AnswerText = N'(tarama bu tutarsizligi artik bulmuyor — kendiliginden cozuldu)',
               UpdatedAt = SYSDATETIME()
         WHERE Status = 'ACIK'
           AND Signature NOT IN (SELECT Signature FROM @Bulgu);

        SELECT QuestionId, Signature, Category, Severity, QuestionText,
               AffectedCount, EvidenceSample, OptionsJson, Status
          FROM ai.LearningQuestions
         WHERE Status = 'ACIK'
         ORDER BY CASE Severity WHEN 'kritik' THEN 0 WHEN 'uyari' THEN 1 ELSE 2 END,
                  AffectedCount DESC;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

------------------------------------------------------------------------------
-- 4. ai.sp_LearningQuestion_Answer — cevap ver, bilgiye donustur
--
-- Cevap yalniz kaydedilmez; ai.LearningFacts'e gecer ve oradan her skill
-- calistirmasinin baglamina girer. Ogrenmenin gerceklestigi nokta budur.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ai.sp_LearningQuestion_Answer
    @SoruId       int,
    @Cevap        nvarchar(2000),
    @KullaniciId  int,
    @Yoksay       bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: bos cevap kabul edilmez, "ogrenildi" yalani uretir
        IF @Yoksay = 0 AND NULLIF(LTRIM(RTRIM(@Cevap)), N'') IS NULL
            THROW 50710, N'Cevap bos olamaz.', 1;

        IF NOT EXISTS (SELECT 1 FROM ai.LearningQuestions WHERE QuestionId = @SoruId)
            THROW 50711, N'Soru bulunamadi.', 1;

        DECLARE @Imza varchar(200), @Metin nvarchar(1000);
        SELECT @Imza = Signature, @Metin = QuestionText
          FROM ai.LearningQuestions WHERE QuestionId = @SoruId;

        UPDATE ai.LearningQuestions
           SET Status           = CASE WHEN @Yoksay = 1 THEN 'YOKSAYILDI' ELSE 'CEVAPLANDI' END,
               AnswerText       = @Cevap,
               AnsweredByUserId = @KullaniciId,
               AnsweredAt       = SYSDATETIME(),
               UpdatedAt        = SYSDATETIME()
         WHERE QuestionId = @SoruId;

        -- Yoksayilan soru bilgi uretmez — insan "bu onemli degil" dedi
        IF @Yoksay = 0
        BEGIN
            -- Ayni sorunun eski cevabi varsa pasife cek (son karar gecerli)
            UPDATE ai.LearningFacts
               SET IsActive = 0, UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE SourceType = 'SORU' AND SourceId = @SoruId AND IsActive = 1;

            INSERT INTO ai.LearningFacts (SkillId, FactText, SourceType, SourceId, CreatedByUserId)
            VALUES (NULL,
                    N'Denetim ekibinin karari — ' + @Metin + N' CEVAP: ' + @Cevap,
                    'SORU', @SoruId, @KullaniciId);
        END

        COMMIT TRANSACTION;

        SELECT QuestionId, Status, AnswerText FROM ai.LearningQuestions WHERE QuestionId = @SoruId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

------------------------------------------------------------------------------
-- 5. ai.sp_LearningQuestion_List — ekran icin
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ai.sp_LearningQuestion_List
    @Durum varchar(20) = 'ACIK'
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT q.QuestionId, q.Signature, q.Category, q.Severity, q.QuestionText,
               q.AffectedCount, q.EvidenceSample, q.OptionsJson, q.Status,
               q.AnswerText, q.AnsweredAt, q.CreatedAt
          FROM ai.LearningQuestions q
         WHERE (@Durum IS NULL OR q.Status = @Durum)
         ORDER BY CASE q.Severity WHEN 'kritik' THEN 0 WHEN 'uyari' THEN 1 ELSE 2 END,
                  q.AffectedCount DESC, q.QuestionId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

------------------------------------------------------------------------------
-- 6. ai.sp_Feedback_RecentRejected — RED sinyali
--
-- Onaylanan ciktilar zaten few-shot olarak geri veriliyordu. Reddedilenler
-- hic kullanilmiyordu — oysa "sunu neden yanlis buldum" en ogretici bilgidir.
-- Yalniz YORUMU olan redler dondurulur: gerekcesiz red ogretmez.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ai.sp_Feedback_RecentRejected
    @Top     int = 3,
    @SkillId varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Top)
               f.FeedbackId,
               COALESCE(se.SkillId, 'analysis') AS SkillId,
               f.UserComment                    AS RedGerekcesi,
               LEFT(COALESCE(se.OutputJson, lr.ResultText), 1500) AS ReddedilenCikti,
               f.CreatedAt
          FROM ai.Feedback f
          LEFT JOIN ai.SkillExecutions se ON se.ExecutionId = f.SkillExecutionId
          LEFT JOIN ai.LlmResults     lr ON lr.RequestId    = f.RequestId
         WHERE f.IsApproved = 0
           AND NULLIF(LTRIM(RTRIM(f.UserComment)), N'') IS NOT NULL
           AND (@SkillId IS NULL OR COALESCE(se.SkillId, 'analysis') = @SkillId)
         ORDER BY f.CreatedAt DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

------------------------------------------------------------------------------
-- 7. ai.sp_LearningContext_Get — ogrenilenleri skill baglamina tasi
--
-- sp_SkillContext_Build bunu cagirir. Uc kaynak birlesir:
--   1) insan cevaplarindan dogan kalici bilgiler (ai.LearningFacts)
--   2) reddedilen ciktilar + red gerekceleri (tekrarlanmamasi icin)
--   3) onaylanmis ornekler (taklit edilmesi icin)
-- Hicbiri yoksa NULL doner ve prompt'a bos blok eklenmez.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ai.sp_LearningContext_Get
    @SkillId varchar(50) = NULL,
    @TopRed  int = 2,
    @TopOnay int = 2
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Parca TABLE (Sira int, Metin nvarchar(max));

        -- 1) Insan kararlari — en agir basan kaynak
        INSERT INTO @Parca (Sira, Metin)
        SELECT 1, N'DENETIM EKIBININ VERDIGI KARARLAR (bunlara UY):' + CHAR(10)
                  + STRING_AGG(CAST(N'- ' + f.FactText AS nvarchar(max)), CHAR(10))
          FROM ai.LearningFacts f
         WHERE f.IsActive = 1 AND (f.SkillId IS NULL OR f.SkillId = @SkillId)
        HAVING COUNT(*) > 0;

        -- 2) Reddedilmis ciktilar — ayni hatayi tekrarlama
        INSERT INTO @Parca (Sira, Metin)
        SELECT 2, N'GECMISTE REDDEDILEN CIKTILAR (bu hatalari TEKRARLAMA):' + CHAR(10)
                  + STRING_AGG(CAST(N'- Red gerekcesi: ' + r.RedGerekcesi
                        + CHAR(10) + N'  Reddedilen cikti: ' + LEFT(r.ReddedilenCikti, 400) AS nvarchar(max)), CHAR(10))
          FROM (
            SELECT TOP (@TopRed) f.UserComment AS RedGerekcesi,
                   LEFT(COALESCE(se.OutputJson, lr.ResultText), 400) AS ReddedilenCikti, f.CreatedAt
              FROM ai.Feedback f
              LEFT JOIN ai.SkillExecutions se ON se.ExecutionId = f.SkillExecutionId
              LEFT JOIN ai.LlmResults     lr ON lr.RequestId    = f.RequestId
             WHERE f.IsApproved = 0
               AND NULLIF(LTRIM(RTRIM(f.UserComment)), N'') IS NOT NULL
               AND (@SkillId IS NULL OR COALESCE(se.SkillId, 'analysis') = @SkillId)
             ORDER BY f.CreatedAt DESC) r
        HAVING COUNT(*) > 0;

        -- 3) Onaylanmis ornekler — skill BAZLI (karisik ornek gurultu uretir)
        INSERT INTO @Parca (Sira, Metin)
        SELECT 3, N'ONAYLANMIS ORNEK CIKTILAR (bicim ve derinlik olarak bunlari izle):' + CHAR(10)
                  + STRING_AGG(CAST(N'- ' + LEFT(o.Cikti, 500) AS nvarchar(max)), CHAR(10))
          FROM (
            SELECT TOP (@TopOnay) COALESCE(se.OutputJson, lr.ResultText) AS Cikti, f.Rating, f.CreatedAt
              FROM ai.Feedback f
              LEFT JOIN ai.SkillExecutions se ON se.ExecutionId = f.SkillExecutionId
              LEFT JOIN ai.LlmResults     lr ON lr.RequestId    = f.RequestId
             WHERE f.IsApproved = 1 AND f.Rating >= 4
               AND NULLIF(COALESCE(se.OutputJson, lr.ResultText), N'') IS NOT NULL
               AND (@SkillId IS NULL OR COALESCE(se.SkillId, 'analysis') = @SkillId)
             ORDER BY f.Rating DESC, f.CreatedAt DESC) o
        HAVING COUNT(*) > 0;

        SELECT Metin = STRING_AGG(CAST(Metin AS nvarchar(max)), CHAR(10) + CHAR(10))
                       WITHIN GROUP (ORDER BY Sira)
          FROM @Parca;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '70_learning_loop.sql tamamlandi.';
GO
