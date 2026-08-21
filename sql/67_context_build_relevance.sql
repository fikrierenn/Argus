-- ============================================================================
-- 67 — sem.sp_Context_Build alaka filtresi duzeltmesi
--
-- SORUN (olculdu): filtre `LIKE '%' + @Konu + '%'` idi, yani TUM konu cumlesini
-- tek parca ariyordu. "stok sayim fark kasa" hicbir Note/EntityId icinde aynen
-- gecmedigi icin 2-7. bolumler HER ZAMAN 0 satir donuyordu. Kanit: uc farkli
-- konu ("stok sayim fark kasa", "kirmizi zurafa piyano tarifi", "cari hesap
-- fatura tahsilat") ayni 53 satiri dondurdu — hepsi kosulsuz AiHints.
--
-- Sonuc: sql/65 ile aktarilan 94 varlik / 63 kopru / 40 metrik AI'a hic
-- ulasmiyordu. Katman doluydu, kapi kapaliydi.
--
-- COZUM: konu kelimelere bolunur, satir kelimelerden HERHANGI BIRI ile
-- eslesirse aday olur, KAC kelime eslestigine gore siralanir. Boylece
-- alakasiz skill'ler az/hic baglam alir (prompt butcesi bosa gitmez),
-- alakali olanlar en cok ortusen kayitlari alir.
--
-- Nokta ve alt cizgi de ayirac: "audit.rootcause.5why" -> audit, rootcause,
-- 5why. 3 karakterden kisa kelimeler atilir ("ve", "bir" gurultu uretir).
--
-- AiHints kosulsuz KALIR — onlar konuya bagli degil, her sorguda gecerli
-- tuzaklar ("stkKod barkod DEGIL" gibi).
--
-- Idempotent: CREATE OR ALTER.
-- ============================================================================

CREATE OR ALTER PROCEDURE sem.sp_Context_Build
    @Konu     nvarchar(200) = NULL,   -- NULL = tum aktif katman ozeti
    @MinGuven decimal(3,2)  = 0.50,
    @TopHer   int           = 15
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Konu kelimeleri: nokta/alt cizgi/tire de ayirac sayilir
        DECLARE @Kelime TABLE (K nvarchar(100) PRIMARY KEY);

        IF @Konu IS NOT NULL AND LTRIM(RTRIM(@Konu)) <> ''
        BEGIN
            INSERT INTO @Kelime (K)
            SELECT DISTINCT LTRIM(RTRIM(s.value))
            FROM   STRING_SPLIT(
                       REPLACE(REPLACE(REPLACE(REPLACE(@Konu, '.', ' '), '_', ' '), '-', ' '), ',', ' '),
                       ' ') AS s
            WHERE  LEN(LTRIM(RTRIM(s.value))) >= 3;
        END

        DECLARE @KonuVar bit = CASE WHEN EXISTS (SELECT 1 FROM @Kelime) THEN 1 ELSE 0 END;

        -- 1) Her zaman gecerli ipuclari — konuya bagli degil
        SELECT Scope, Severity, HintText
        FROM   sem.AiHints
        WHERE  IsActive = 1
        ORDER BY CASE Severity WHEN 'kritik' THEN 0 WHEN 'uyari' THEN 1 ELSE 2 END, Id;

        -- 2) Ilgili varliklar
        SELECT TOP (@TopHer) e.EntityId, e.ObjectType, e.PkColumns, e.KeyColumns,
               e.Grain, e.Note, e.Confidence
        FROM   sem.Entities e
        OUTER APPLY (
            SELECT COUNT(*) AS Skor FROM @Kelime k
            WHERE  e.EntityId LIKE '%' + k.K + '%' OR e.ObjectName LIKE '%' + k.K + '%'
                OR e.KeyColumns LIKE '%' + k.K + '%' OR e.Note LIKE '%' + k.K + '%'
        ) m
        WHERE  e.IsActive = 1 AND e.Status <> 'curuk' AND e.Confidence >= @MinGuven
          AND (@KonuVar = 0 OR m.Skor > 0)
        ORDER BY m.Skor DESC, e.Confidence DESC;

        -- 3) Ilgili kopruler (join yollari)
        SELECT TOP (@TopHer) b.BridgeId, b.FromRef, b.ToRef, b.JoinExpression,
               b.Cardinality, b.Note, b.Confidence
        FROM   sem.Bridges b
        OUTER APPLY (
            SELECT COUNT(*) AS Skor FROM @Kelime k
            WHERE  b.BridgeId LIKE '%' + k.K + '%' OR b.FromRef LIKE '%' + k.K + '%'
                OR b.ToRef LIKE '%' + k.K + '%' OR b.Note LIKE '%' + k.K + '%'
        ) m
        WHERE  b.IsActive = 1 AND b.Status <> 'curuk' AND b.Confidence >= @MinGuven
          AND (@KonuVar = 0 OR m.Skor > 0)
        ORDER BY m.Skor DESC, b.Confidence DESC;

        -- 4) Kod kumeleri + degerleri
        SELECT TOP (@TopHer) cs.CodeSetId, cs.Name, cs.LookupTable, cs.JoinExpression, cs.Note,
               STUFF((SELECT ', ' + v.CodeValue + '=' + v.Label
                      FROM sem.CodeValues v
                      WHERE v.CodeSetId = cs.CodeSetId AND v.IsActive = 1
                      ORDER BY v.CodeValue
                      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') AS Degerler,
               cs.Confidence
        FROM   sem.CodeSets cs
        OUTER APPLY (
            SELECT COUNT(*) AS Skor FROM @Kelime k
            WHERE  cs.CodeSetId LIKE '%' + k.K + '%' OR cs.Name LIKE '%' + k.K + '%'
                OR cs.Note LIKE '%' + k.K + '%'
        ) m
        WHERE  cs.IsActive = 1 AND cs.Status <> 'curuk' AND cs.Confidence >= @MinGuven
          AND (@KonuVar = 0 OR m.Skor > 0)
        ORDER BY m.Skor DESC, cs.Confidence DESC;

        -- 5) Metrikler — Caveat (tuzak) alani en kritik kisim
        SELECT TOP (@TopHer) mt.MetricId, mt.Name, mt.SourceRef, mt.Formula,
               mt.Caveat, mt.Unit, mt.Confidence
        FROM   sem.Metrics mt
        OUTER APPLY (
            SELECT COUNT(*) AS Skor FROM @Kelime k
            WHERE  mt.MetricId LIKE '%' + k.K + '%' OR mt.Name LIKE '%' + k.K + '%'
                OR mt.Formula LIKE '%' + k.K + '%' OR mt.Caveat LIKE '%' + k.K + '%'
        ) m
        WHERE  mt.IsActive = 1 AND mt.Status <> 'curuk' AND mt.Confidence >= @MinGuven
          AND (@KonuVar = 0 OR m.Skor > 0)
        ORDER BY m.Skor DESC, mt.Confidence DESC;

        -- 6) Dogrulanmis (golden) SQL ornekleri
        SELECT TOP (@TopHer) q.QueryId, q.Question, q.VerifiedSql, q.ResultNote,
               q.LastVerifiedAt, q.Confidence
        FROM   sem.Queries q
        OUTER APPLY (
            SELECT COUNT(*) AS Skor FROM @Kelime k
            WHERE  q.QueryId LIKE '%' + k.K + '%' OR q.Question LIKE '%' + k.K + '%'
        ) m
        WHERE  q.IsActive = 1 AND q.Status <> 'curuk' AND q.Confidence >= @MinGuven
          AND (@KonuVar = 0 OR m.Skor > 0)
        ORDER BY m.Skor DESC, q.Confidence DESC;

        -- 7) Is sozlugu (ref.SemanticDefinitions koprusu)
        SELECT TOP (@TopHer) d.TermType, d.BusinessName, d.TechnicalName,
               d.Description, d.Aliases, d.Category
        FROM   ref.SemanticDefinitions d
        OUTER APPLY (
            SELECT COUNT(*) AS Skor FROM @Kelime k
            WHERE  d.BusinessName LIKE '%' + k.K + '%' OR d.TechnicalName LIKE '%' + k.K + '%'
                OR d.Aliases LIKE '%' + k.K + '%' OR d.Description LIKE '%' + k.K + '%'
        ) m
        WHERE  d.IsActive = 1
          AND (@KonuVar = 0 OR m.Skor > 0)
        ORDER BY m.Skor DESC, d.Category, d.BusinessName;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '67_context_build_relevance.sql tamamlandi.';
GO
