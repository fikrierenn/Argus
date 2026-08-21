-- ============================================================================
-- 62 — Gomulen metnin ayirt ediciligi + kirik ogrenme dongusu
--
-- Olcum: 189 vektorle geri getirme YAPILMIYOR. Ne sorulursa sorulsun ayni
-- alakasiz kayit donuyor, ham benzerlik dagilimi en yuksek 0.8035 / ortanca
-- 0.7539 / en dusuk 0.7087 — toplam yayilim 0.09. Her sey her seye esit
-- uzaklikta; bu geri getirme degil, gurultu.
--
-- SEBEP 1 — sablon oneki (sql/61'de biz ekledik)
-- Her AUDIT kaydinin ozeti "Kafe / Insan Kaynaklari Alani / Operasyonel Risk. "
-- ile basliyordu. Sabit onek tum ciftler arasi benzerligi yukari itiyor ve
-- e5'in zaten sikisik araligini iyice sikistiriyor. 83 vektorde yalniz 51
-- tekil ilk-60-karakter kalmisti.
--
-- SEBEP 2 — DOF'ta Description tamamen kalip
-- Ornek: "Denetim: Ozluce (30.01.2026) - KAFE/Kafe Depo - RiskScore: 25".
-- Bu metadata; gozlem degil. Gommeye kattigimizda ayirt edicilige katki
-- vermeden benzerligi sisiriyor. Ayni bilgi zaten iliskisel kolonlarda var
-- ve SQL filtresiyle kullanilmali.
--
-- Kural: gomulen metin YALNIZ ayirt edici icerik tasir. Kategori, mekan,
-- tarih ve skor filtre kolonudur, gomme girdisi degil.
--
-- SEBEP 3 — ai.sp_SemanticVector_UpsertGolden iki ayri nedenle olu
--   (a) C# RiskId/OzetMetin/VektorJson gonderiyor, SP @SourceId/@Ozet/@VectorJson
--       bekliyor -> parametre adlari tutmuyor, calisma aninda hata.
--   (b) SP EmbeddingModel yazmiyor, sp_SemanticVector_ListWeighted o kolona
--       gore filtreliyor -> yazilsa bile hicbir zaman okunmaz.
-- Onaylanmis ornekler ogrenme dongusunun tek gercek mekanizmasi; bu hat
-- kirikken "ogrenen sistem" iddiasinin dayanagi yok.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

-- ─────────────────────────────────────────────────────
-- Kaynak listesi — yalniz ayirt edici metin
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_SemanticVector_SourceList
    @Top          int          = 200,
    @KaynakTipi   varchar(20)  = NULL,
    @ModelAdi     varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH kaynaklar AS
    (
        -- DOF: Title gercek icerik, Description otomatik kalip.
        -- Kalip gomulmez; EffectivenessNote (varsa) en degerli kisim cunku
        -- "ne yapildi" bilgisini tasiyan tek alan odur.
        SELECT
            'DOF'              AS Source,
            d.DofId            AS SourceId,
            d.DofId            AS DofId,
            LEFT(d.Title, 500) AS Title,
            LTRIM(RTRIM(CONCAT(
                d.Title,
                CASE WHEN NULLIF(LTRIM(RTRIM(d.EffectivenessNote)), '') IS NOT NULL
                     THEN N' Yapilan: ' + d.EffectivenessNote ELSE N'' END
            )))                AS SummaryText,
            CAST(CASE WHEN d.RiskLevel >= 4 THEN 1 ELSE 0 END AS bit) AS IsCritical,
            CASE
                WHEN d.Status IN ('CLOSED','KAPANDI') AND d.IsEffective = 1 THEN 1.00
                WHEN d.Status IN ('CLOSED','KAPANDI')                       THEN 0.85
                ELSE 0.60
            END                AS Weight
        FROM dof.Findings d
        WHERE NULLIF(LTRIM(RTRIM(d.Title)), '') IS NOT NULL

        UNION ALL

        -- AUDIT: kategori oneki KALDIRILDI. Denetcinin gozlemi (Remark) varsa
        -- asil deger odur; yoksa geriye yalniz kontrol maddesi metni kalir.
        SELECT
            'AUDIT',
            r.Id,
            NULL,
            LEFT(ISNULL(NULLIF(r.ItemText, N''), CONCAT(N'Denetim bulgusu #', r.Id)), 500),
            LTRIM(RTRIM(CONCAT(
                ISNULL(r.ItemText, N''),
                CASE WHEN NULLIF(LTRIM(RTRIM(r.Remark)), '') IS NOT NULL
                     THEN N' Gozlem: ' + r.Remark ELSE N'' END
            ))),
            CAST(CASE WHEN r.RiskLevel IN ('YUKSEK','KRITIK') OR r.IsSystemic = 1 THEN 1 ELSE 0 END AS bit),
            CASE WHEN r.IsSystemic = 1 THEN 0.90
                 WHEN r.RepeatCount > 1 THEN 0.80
                 ELSE 0.70 END
        FROM audit.AuditResults r
        WHERE NULLIF(LTRIM(RTRIM(r.ItemText)), '') IS NOT NULL
           OR NULLIF(LTRIM(RTRIM(r.Remark)), '') IS NOT NULL

        UNION ALL

        -- AI analizleri: Summary zaten serbest metin, kalip yok
        SELECT
            'AI',
            a.Id,
            NULL,
            LEFT(CONCAT(a.AnalysisType, N' analizi #', a.Id), 500),
            a.Summary,
            CAST(CASE WHEN a.Severity IN ('HIGH','CRITICAL') THEN 1 ELSE 0 END AS bit),
            0.50
        FROM audit.AiAnalyses a
        WHERE NULLIF(LTRIM(RTRIM(a.Summary)), '') IS NOT NULL
    )
    SELECT TOP (@Top)
        k.Source, k.SourceId, k.DofId, k.Title, k.SummaryText, k.IsCritical, k.Weight
    FROM   kaynaklar k
    LEFT JOIN ai.SemanticVectors v
           ON v.Source = k.Source
          AND v.SourceId = k.SourceId
          AND (@ModelAdi IS NULL OR v.EmbeddingModel = @ModelAdi)
    WHERE  v.VectorId IS NULL
      AND  (@KaynakTipi IS NULL OR k.Source = @KaynakTipi)
    ORDER BY k.Weight DESC, k.SourceId DESC;
END
GO

-- ─────────────────────────────────────────────────────
-- Onaylanmis ornek (GOLDEN) yazimi — ana upsert'e devrediliyor
--
-- Ayri bir SP tutmanin gerekcesi yoktu ve iki kopya birbirinden sapti.
-- Artik tek yol var: ai.sp_SemanticVector_Upsert. Bu SP geriye uyumluluk
-- icin duruyor ve dogru parametrelerle ona yonlendiriyor.
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_SemanticVector_UpsertGolden
    @KaynakId    bigint,
    @Baslik      nvarchar(500),
    @OzetMetin   nvarchar(max),
    @VektorJson  nvarchar(max),
    @ModelAdi    varchar(100),
    @Boyut       int,
    @Kritik      bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Onaylanmis ornek en yuksek agirligi hak eder: insan gozunden gecmis,
    -- dogrulanmis cikti. Ogrenme dongusunun tek gercek girdisi budur.
    EXEC ai.sp_SemanticVector_Upsert
        @KaynakTipi = 'GOLDEN',
        @KaynakId   = @KaynakId,
        @DofId      = NULL,
        @Baslik     = @Baslik,
        @OzetMetin  = @OzetMetin,
        @Kritik     = @Kritik,
        @VektorJson = @VektorJson,
        @Agirlik    = 1.0,
        @ModelAdi   = @ModelAdi,
        @Boyut      = @Boyut;
END
GO

-- ─────────────────────────────────────────────────────
-- Mevcut vektorleri temizle — metin uretimi degisti, hepsi yeniden gomulmeli
-- ─────────────────────────────────────────────────────
DELETE FROM ai.SemanticVectors;
GO

PRINT '62_semantic_text_quality uygulandi. Vektorler temizlendi, yeniden gomulmeli.';
GO
