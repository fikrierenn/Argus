-- ============================================================================
-- 68 — ai.sp_SkillContext_Build: skill prompt degiskenlerinin TEK kaynagi
--
-- SORUN (olculdu, B2 kosumu): 10 skill'in tamami "DONE" dondu ama cogu bos
-- yapi uretti. GLM'in kendi aciklamasi: "Veri seti (checklistItems,
-- itemHitRates, findingsWithoutItem) bos veya placeholder".
--
-- Sebep: prompt'lar ile C# yukleyicileri BAGIMSIZ iki sozluk kullaniyordu.
-- Prompt'lar 47 degisken slotu bekliyor, yukleyiciler 5'ini dolduruyordu (%11).
-- Kesisen tek isimler: locationName, findingTitle. Eslesmeyen degisken sessizce
-- bos string kaliyor — LLM de bos veriye bakip "bulgu yok" diyordu.
--
-- COZUM: degisken adlari artik TEK yerde tanimli — burada. Yeni skill eklemek
-- SQL'e dal eklemek demek; C# tarafi degismez. Iki sozluk bir daha ayrisamaz.
--
-- VERI YOKLUGU AYRIMI (en kritik tasarim karari):
--   '(veri toplanmamis...)' -> alan var ama hic doldurulmamis (Remark 0/91,
--                              foto 0/91). LLM BUNDAN SONUC CIKARMAMALI.
--   '(kayit yok)'           -> sorgu calisti, gercekten sifir. Sonuc cikarilabilir.
-- Ikisi ayni sekilde bos gecilirse AI "sorun yok" der — olmayan bulgunun
-- yoklugunu kanit sayar. Denetim yaziliminda en pahali hata tipi budur.
--
-- Cikti: (Ad nvarchar(100), Deger nvarchar(max)) satirlari.
-- ============================================================================

CREATE OR ALTER PROCEDURE ai.sp_SkillContext_Build
    @SkillId     varchar(50),
    @VarlikTipi  varchar(20) = NULL,
    @VarlikId    int         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Ctx TABLE (Ad nvarchar(100) PRIMARY KEY, Deger nvarchar(max));

        -- Alan hic doldurulmamissa bunu SOYLE; bos string birakma.
        DECLARE @YOK nvarchar(100) = N'(kayit yok)';
        DECLARE @TOPLANMAMIS nvarchar(200) =
            N'(veri toplanmamis — bu alan sistemde hic doldurulmamis, yoklugundan sonuc cikarma)';

        ------------------------------------------------------------------
        -- Ortak: DENETIM kimligini coz
        -- DOF geldiginde SourceKey 'AUDIT_<denetim>_RESULT_<sonuc>' formatinda
        ------------------------------------------------------------------
        DECLARE @AuditId int = CASE WHEN @VarlikTipi = 'DENETIM' THEN @VarlikId END;
        DECLARE @ResultId int = NULL;
        DECLARE @DofId int = CASE WHEN @VarlikTipi = 'DOF' THEN @VarlikId END;
        DECLARE @LocationId int = CASE WHEN @VarlikTipi = 'MEKAN' THEN @VarlikId END;

        IF @DofId IS NOT NULL
        BEGIN
            DECLARE @sk nvarchar(200) = (SELECT SourceKey FROM dof.Findings WHERE DofId = @DofId);

            IF @sk LIKE N'AUDIT[_]%[_]RESULT[_]%'
            BEGIN
                SET @AuditId  = TRY_CAST(SUBSTRING(@sk, 7, CHARINDEX(N'_RESULT_', @sk) - 7) AS int);
                SET @ResultId = TRY_CAST(SUBSTRING(@sk, CHARINDEX(N'_RESULT_', @sk) + 8, 20) AS int);
            END
        END

        -- Mekan adi: MEKAN icin ERP'den, DENETIM icin denetim kaydindan
        DECLARE @MekanAd nvarchar(200) =
            CASE WHEN @LocationId IS NOT NULL
                 THEN (SELECT TOP 1 MekanAd FROM src.vw_Mekan WHERE MekanId = @LocationId)
                 WHEN @AuditId IS NOT NULL
                 THEN (SELECT LocationName FROM audit.Audits WHERE Id = @AuditId)
            END;

        INSERT INTO @Ctx (Ad, Deger)
        VALUES (N'locationName', ISNULL(@MekanAd, N'(mekan belirlenemedi)'));

        ------------------------------------------------------------------
        -- DENETIM tabanli degiskenler
        ------------------------------------------------------------------
        IF @AuditId IS NOT NULL
        BEGIN
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'auditId', CAST(@AuditId AS nvarchar(20));

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'auditSummary', CONCAT(
                N'Denetim #', a.Id, N' — ', a.LocationName, N' (', a.LocationType, N'), ',
                FORMAT(a.AuditDate, 'dd.MM.yyyy'), N'. Durum: ',
                CASE WHEN a.IsFinalized = 1 THEN N'tamamlandi' ELSE N'taslak' END,
                N'. Toplam madde: ', (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id),
                N', basarisiz: ', (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = a.Id AND r.IsPassed = 0),
                N'. Yonetici: ', ISNULL(a.Manager, N'-'), N', Mudurluk: ', ISNULL(a.Directorate, N'-'), N'.')
            FROM audit.Audits a WHERE a.Id = @AuditId;

            -- Kritik bulgular: risk skoruna gore. Remark bos ise ACIKCA belirt
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'criticalFindings', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 25 CONCAT(N'- [', r.AuditGroup, N'/', r.Area, N'] ', r.ItemText,
                       N' (risk ', r.RiskScore, N'/', r.RiskLevel,
                       CASE WHEN r.RepeatCount > 1 THEN CONCAT(N', ', r.RepeatCount, N'x tekrar') ELSE N'' END,
                       CASE WHEN r.IsSystemic = 1 THEN N', SISTEMIK' ELSE N'' END, N') Denetci notu: ',
                       CASE WHEN NULLIF(LTRIM(RTRIM(r.Remark)), N'') IS NULL
                            THEN @TOPLANMAMIS ELSE r.Remark END) AS S
                FROM audit.AuditResults r
                WHERE r.AuditId = @AuditId AND r.IsPassed = 0
                ORDER BY r.RiskScore DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'findings', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 40 CONCAT(N'- #', r.Id, N' [', r.Area, N'] ', r.ItemText,
                       N' — ', CASE WHEN r.IsPassed = 1 THEN N'UYGUN' ELSE N'UYGUNSUZ' END) AS S
                FROM audit.AuditResults r WHERE r.AuditId = @AuditId
                ORDER BY r.IsPassed, r.RiskScore DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'itemDescriptions', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT DISTINCT TOP 40 CONCAT(N'- ', r.AuditGroup, N' / ', r.Area, N': ', r.ItemText) AS S
                FROM audit.AuditResults r WHERE r.AuditId = @AuditId
            ) x;

            -- Foto sayilari: tablo su an BOS — bunu gizleme
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'photoCounts',
                   CASE WHEN NOT EXISTS (SELECT 1 FROM audit.AuditResultPhotos p
                                         JOIN audit.AuditResults r ON r.Id = p.AuditResultId
                                         WHERE r.AuditId = @AuditId)
                        THEN CONCAT(N'Bu denetimde hic fotograf kaydi yok. ', @TOPLANMAMIS)
                        ELSE (SELECT CAST(COUNT(*) AS nvarchar(20)) + N' fotograf, '
                                   + CAST(COUNT(DISTINCT p.AuditResultId) AS nvarchar(20)) + N' maddede'
                              FROM audit.AuditResultPhotos p
                              JOIN audit.AuditResults r ON r.Id = p.AuditResultId
                              WHERE r.AuditId = @AuditId)
                   END;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'scores', CONCAT(
                N'Basari orani: ',
                CAST(CAST(100.0 * SUM(CASE WHEN IsPassed = 1 THEN 1 ELSE 0 END)
                     / NULLIF(COUNT(*), 0) AS decimal(5,1)) AS nvarchar(10)), N'%. ',
                N'Ortalama risk skoru: ', CAST(CAST(AVG(CAST(RiskScore AS decimal(9,2))) AS decimal(9,2)) AS nvarchar(20)),
                N'. Sistemik madde: ', CAST(SUM(CASE WHEN IsSystemic = 1 THEN 1 ELSE 0 END) AS nvarchar(10)),
                N'. Tekrar eden: ', CAST(SUM(CASE WHEN RepeatCount > 1 THEN 1 ELSE 0 END) AS nvarchar(10)), N'.')
            FROM audit.AuditResults WHERE AuditId = @AuditId;

            -- Onceki denetimle kiyas: ayni mekanin bir onceki denetimi
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'comparisonPrevious', ISNULL((
                SELECT TOP 1 CONCAT(
                    N'Onceki denetim #', p.Id, N' (', FORMAT(p.AuditDate, 'dd.MM.yyyy'), N'): ',
                    (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = p.Id AND r.IsPassed = 0),
                    N' uygunsuz / ',
                    (SELECT COUNT(*) FROM audit.AuditResults r WHERE r.AuditId = p.Id), N' madde.')
                FROM audit.Audits p
                JOIN audit.Audits c ON c.Id = @AuditId
                WHERE p.LocationName = c.LocationName AND p.Id <> c.Id AND p.AuditDate <= c.AuditDate
                ORDER BY p.AuditDate DESC
            ), N'(bu mekanda onceki denetim yok — kiyaslama YAPMA)');

            -- Acik DOF'lar: bu denetimden dogan veya ayni mekana ait olanlar.
            -- MEKAN dalinda da uretiliyor; rapor skill'i DENETIM uzerinden
            -- kostugu icin burada da gerekli.
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'openDofs', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)),
                   N'(bu denetime bagli acik DOF yok)')
            FROM (
                SELECT TOP 25 CONCAT(N'- DOF #', f.DofId, N' [', f.Status, N', risk ', f.RiskLevel, N'] ',
                       f.Title, CASE WHEN f.SlaDueDate < SYSDATETIME() AND f.Status <> N'CLOSED'
                                     THEN N' (SLA ASILDI)' ELSE N'' END) AS S
                FROM dof.Findings f
                WHERE f.Status <> N'CLOSED'
                  AND f.SourceKey LIKE N'AUDIT[_]' + CAST(@AuditId AS nvarchar(20)) + N'[_]%'
                ORDER BY f.RiskLevel DESC, f.CreatedAt DESC
            ) x;
        END

        ------------------------------------------------------------------
        -- Checklist iyilestirme: denetim madde havuzu geneli
        ------------------------------------------------------------------
        IF @SkillId = 'audit.checklist.improve'
        BEGIN
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'auditCount', CAST((SELECT COUNT(*) FROM audit.Audits) AS nvarchar(20));

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'checklistItems', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 120 CONCAT(N'- #', i.Id, N' [', i.AuditGroup, N'/', i.Area, N'] ',
                       i.ItemText, N' (tip: ', ISNULL(i.RiskType, N'-'),
                       N', mekan tipi: ', ISNULL(i.LocationType, N'hepsi'), N')') AS S
                FROM audit.AuditItems i ORDER BY i.AuditGroup, i.SortOrder
            ) x;

            -- Isabet orani: madde kac olcumde uygunsuz cikti
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'itemHitRates', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 120 CONCAT(N'- ', LEFT(r.ItemText, 70), N': ', COUNT(*), N' olcum, ',
                       SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END), N' uygunsuz (%',
                       CAST(CAST(100.0 * SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END)
                            / NULLIF(COUNT(*), 0) AS decimal(5,1)) AS nvarchar(10)), N')') AS S
                FROM audit.AuditResults r
                GROUP BY r.ItemText
                ORDER BY COUNT(*) DESC
            ) x;

            -- Checklist maddesine baglanmayan bulgular = checklist boslugu
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'findingsWithoutItem', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 40 CONCAT(N'- #', r.Id, N' ', LEFT(r.ItemText, 80)) AS S
                FROM audit.AuditResults r
                WHERE r.AuditItemId IS NULL AND r.IsPassed = 0
            ) x;
        END

        ------------------------------------------------------------------
        -- MEKAN tabanli: ERP risk sinyalleri + saha bulgulari
        ------------------------------------------------------------------
        IF @LocationId IS NOT NULL
        BEGIN
            DECLARE @SonGun date = (SELECT MAX(SnapshotDate) FROM rpt.DailyProductRisk WHERE LocationId = @LocationId);

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'period', ISNULL(CONCAT(N'Son snapshot: ', FORMAT(@SonGun, 'dd.MM.yyyy'),
                   N'. Periyot: ', (SELECT TOP 1 PeriodCode FROM rpt.DailyProductRisk
                                    WHERE LocationId = @LocationId AND SnapshotDate = @SonGun)),
                   N'(bu mekan icin ERP risk snapshot kaydi yok)');

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'erpSignals', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 25 CONCAT(N'- Urun ', d.ProductId, N' (', ISNULL(u.UrunAd, N'?'), N') risk ',
                       d.RiskScore,
                       CASE WHEN d.FlagSalesWithoutEntry    = 1 THEN N' [girissiz-satis]'    ELSE N'' END,
                       CASE WHEN d.FlagDeadStock            = 1 THEN N' [olu-stok]'          ELSE N'' END,
                       CASE WHEN d.FlagNetAccumulation      = 1 THEN N' [net-birikim]'       ELSE N'' END,
                       CASE WHEN d.FlagHighReturn           = 1 THEN N' [yuksek-iade]'       ELSE N'' END,
                       CASE WHEN d.FlagHighCountAdjustment  = 1 THEN N' [sayim-duzeltme]'    ELSE N'' END,
                       CASE WHEN d.FlagHighInternalUse      = 1 THEN N' [ic-kullanim]'       ELSE N'' END,
                       CASE WHEN d.FlagDataQuality          = 1 THEN N' [veri-kalitesi]'     ELSE N'' END,
                       ISNULL(N' — ' + NULLIF(d.RiskComment, N''), N'')) AS S
                FROM rpt.DailyProductRisk d
                LEFT JOIN src.vw_Urun u ON u.StokId = d.ProductId
                WHERE d.LocationId = @LocationId AND d.SnapshotDate = @SonGun AND d.RiskScore > 0
                ORDER BY d.RiskScore DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'riskSignals', (SELECT Deger FROM @Ctx WHERE Ad = N'erpSignals');

            -- Saha bulgulari: denetim adi ile ERP mekan adini eslestir
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'fieldFindings', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)),
                   N'(bu mekan icin saha denetimi kaydi bulunamadi — ERP sinyalini saha bulgusuyla DOGRULAMA)')
            FROM (
                SELECT TOP 30 CONCAT(N'- [', FORMAT(a.AuditDate, 'dd.MM.yyyy'), N'] ',
                       r.Area, N': ', r.ItemText, N' (risk ', r.RiskScore, N')') AS S
                FROM audit.AuditResults r
                JOIN audit.Audits a ON a.Id = r.AuditId
                WHERE r.IsPassed = 0 AND @MekanAd IS NOT NULL AND a.LocationName = @MekanAd
                ORDER BY a.AuditDate DESC, r.RiskScore DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'pastFindings', (SELECT Deger FROM @Ctx WHERE Ad = N'fieldFindings');

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'lastAuditDate', ISNULL((
                SELECT TOP 1 FORMAT(a.AuditDate, 'dd.MM.yyyy') FROM audit.Audits a
                WHERE @MekanAd IS NOT NULL AND a.LocationName = @MekanAd ORDER BY a.AuditDate DESC
            ), N'(bu mekan hic denetlenmemis)');

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'openDofs', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 25 CONCAT(N'- DOF #', f.DofId, N' [', f.Status, N', risk ', f.RiskLevel, N'] ',
                       f.Title, CASE WHEN f.SlaDueDate < SYSDATETIME() AND f.Status <> N'CLOSED'
                                     THEN N' (SLA ASILDI)' ELSE N'' END) AS S
                FROM dof.Findings f
                WHERE f.Status <> N'CLOSED'
                  AND (@MekanAd IS NULL OR f.Title LIKE N'%' + @MekanAd + N'%'
                       OR EXISTS (SELECT 1 FROM audit.Audits a
                                  WHERE a.LocationName = @MekanAd
                                    AND f.SourceKey LIKE N'AUDIT[_]' + CAST(a.Id AS nvarchar(20)) + N'[_]%'))
                ORDER BY f.RiskLevel DESC, f.CreatedAt DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'checklistItems', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 80 CONCAT(N'- [', i.AuditGroup, N'/', i.Area, N'] ', i.ItemText) AS S
                FROM audit.AuditItems i ORDER BY i.AuditGroup, i.SortOrder
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'focusAreas', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), N', '), @YOK)
            FROM (
                SELECT TOP 8 r.Area AS S
                FROM audit.AuditResults r
                JOIN audit.Audits a ON a.Id = r.AuditId
                WHERE r.IsPassed = 0 AND @MekanAd IS NOT NULL AND a.LocationName = @MekanAd
                GROUP BY r.Area ORDER BY SUM(r.RiskScore) DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger) VALUES (N'role', N'Magaza/Kafe sorumlusu');
        END

        ------------------------------------------------------------------
        -- Trend: donem karsilastirmasi
        ------------------------------------------------------------------
        IF @SkillId = 'audit.trend.detect'
        BEGIN
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'periodSummary', CONCAT(
                N'Toplam denetim: ', (SELECT COUNT(*) FROM audit.Audits),
                N', toplam olcum: ', (SELECT COUNT(*) FROM audit.AuditResults),
                N', uygunsuz: ', (SELECT COUNT(*) FROM audit.AuditResults WHERE IsPassed = 0),
                N'. Tarih araligi: ',
                (SELECT CONCAT(FORMAT(MIN(AuditDate), 'dd.MM.yyyy'), N' — ',
                               FORMAT(MAX(AuditDate), 'dd.MM.yyyy')) FROM audit.Audits), N'.');

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'categoryBreakdown', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 30 CONCAT(N'- ', r.AuditGroup, N' / ', r.Area, N': ', COUNT(*), N' olcum, ',
                       SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END), N' uygunsuz, ort. risk ',
                       CAST(CAST(AVG(CAST(r.RiskScore AS decimal(9,2))) AS decimal(9,2)) AS nvarchar(20))) AS S
                FROM audit.AuditResults r GROUP BY r.AuditGroup, r.Area
                ORDER BY SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END) DESC
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'locationScores', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)), @YOK)
            FROM (
                SELECT TOP 30 CONCAT(N'- ', a.LocationName, N' (', FORMAT(a.AuditDate, 'dd.MM.yyyy'), N'): ',
                       SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END), N'/', COUNT(*), N' uygunsuz') AS S
                FROM audit.Audits a JOIN audit.AuditResults r ON r.AuditId = a.Id
                GROUP BY a.Id, a.LocationName, a.AuditDate ORDER BY a.AuditDate DESC
            ) x;

            -- Tek donem varsa trend YOKTUR; modele bunu acikca soyle
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'previousPeriods',
                   CASE WHEN (SELECT COUNT(DISTINCT FORMAT(AuditDate, 'yyyy-MM')) FROM audit.Audits) < 2
                        THEN N'(tek donem verisi var — trend hesaplanamaz, trend iddiasinda BULUNMA)'
                        ELSE (SELECT STRING_AGG(CAST(y.S AS nvarchar(max)), CHAR(10))
                              FROM (SELECT TOP 12 CONCAT(N'- ', FORMAT(a.AuditDate, 'yyyy-MM'), N': ',
                                           COUNT(DISTINCT a.Id), N' denetim, ',
                                           SUM(CASE WHEN r.IsPassed = 0 THEN 1 ELSE 0 END), N' uygunsuz') AS S
                                    FROM audit.Audits a LEFT JOIN audit.AuditResults r ON r.AuditId = a.Id
                                    GROUP BY FORMAT(a.AuditDate, 'yyyy-MM')
                                    ORDER BY FORMAT(a.AuditDate, 'yyyy-MM') DESC) y)
                   END;
        END

        ------------------------------------------------------------------
        -- DOF tabanli: kok sebep, sistemiklik, etkinlik
        ------------------------------------------------------------------
        IF @DofId IS NOT NULL
        BEGIN
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'dofId', CAST(@DofId AS nvarchar(20));

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'findingTitle', f.Title FROM dof.Findings f WHERE f.DofId = @DofId;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'findingDetail',
                   CASE WHEN NULLIF(LTRIM(RTRIM(f.Description)), N'') IS NULL
                        THEN @TOPLANMAMIS ELSE f.Description END
            FROM dof.Findings f WHERE f.DofId = @DofId;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'originalFinding', CONCAT(
                N'DOF #', f.DofId, N' [', f.Status, N', risk ', f.RiskLevel, N'] ', f.Title,
                N'. Acilis: ', FORMAT(f.CreatedAt, 'dd.MM.yyyy'),
                N', SLA: ', ISNULL(FORMAT(f.SlaDueDate, 'dd.MM.yyyy'), N'-'), N'. Aciklama: ',
                CASE WHEN NULLIF(LTRIM(RTRIM(f.Description)), N'') IS NULL
                     THEN @TOPLANMAMIS ELSE f.Description END)
            FROM dof.Findings f WHERE f.DofId = @DofId;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'locationContext', ISNULL((
                SELECT CONCAT(a.LocationName, N' (', a.LocationType, N'), denetim ',
                       FORMAT(a.AuditDate, 'dd.MM.yyyy'), N', yonetici: ', ISNULL(a.Manager, N'-'))
                FROM audit.Audits a WHERE a.Id = @AuditId
            ), N'(bulgu bir saha denetimine baglanamadi)');

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'processContext', ISNULL((
                SELECT CONCAT(N'Surec alani: ', r.AuditGroup, N' / ', r.Area,
                       N'. Risk tipi: ', ISNULL(r.RiskType, N'-'),
                       N'. Bulgu tipi: ', ISNULL(r.FindingType, N'-'),
                       N'. Olasilik/Etki: ', r.Probability, N'/', r.Impact,
                       N'. Sistemik: ', CASE WHEN r.IsSystemic = 1 THEN N'evet' ELSE N'hayir' END)
                FROM audit.AuditResults r WHERE r.Id = @ResultId
            ), N'(surec baglami cozulemedi)');

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'processOwner', ISNULL((
                SELECT CONCAT(ISNULL(a.Manager, N'-'), N' / ', ISNULL(a.Directorate, N'-'))
                FROM audit.Audits a WHERE a.Id = @AuditId
            ), N'(surec sahibi kayitli degil)');

            -- Tekrar gecmisi: ayni madde metni baska denetimlerde
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'recurrenceHistory', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)),
                   N'(bu bulgu baska denetimde tekrarlamamis)')
            FROM (
                SELECT TOP 20 CONCAT(N'- [', FORMAT(a.AuditDate, 'dd.MM.yyyy'), N'] ', a.LocationName,
                       N': ', CASE WHEN r.IsPassed = 0 THEN N'UYGUNSUZ' ELSE N'uygun' END,
                       CASE WHEN r.RepeatCount > 1 THEN CONCAT(N' (', r.RepeatCount, N'x)') ELSE N'' END) AS S
                FROM audit.AuditResults r
                JOIN audit.Audits a ON a.Id = r.AuditId
                WHERE @ResultId IS NOT NULL
                  AND r.ItemText = (SELECT ItemText FROM audit.AuditResults WHERE Id = @ResultId)
                  AND r.Id <> @ResultId
                ORDER BY a.AuditDate DESC
            ) x;

            -- Sistemiklik: ayni madde kac FARKLI mekanda uygunsuz
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'sameFindingOtherLocations', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)),
                   N'(bu bulgu baska mekanda gorulmemis — tekil olabilir)')
            FROM (
                SELECT DISTINCT TOP 25 CONCAT(N'- ', a.LocationName, N' (', a.LocationType, N')') AS S
                FROM audit.AuditResults r
                JOIN audit.Audits a ON a.Id = r.AuditId
                WHERE @ResultId IS NOT NULL AND r.IsPassed = 0
                  AND r.ItemText = (SELECT ItemText FROM audit.AuditResults WHERE Id = @ResultId)
                  AND a.LocationName <> ISNULL(@MekanAd, N'')
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'totalLocations', CAST((SELECT COUNT(DISTINCT LocationName) FROM audit.Audits) AS nvarchar(20));

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'timeSpread', ISNULL((
                SELECT CONCAT(N'Ilk gorulme: ', FORMAT(MIN(a.AuditDate), 'dd.MM.yyyy'),
                       N', son gorulme: ', FORMAT(MAX(a.AuditDate), 'dd.MM.yyyy'),
                       N', ', COUNT(DISTINCT a.Id), N' denetimde')
                FROM audit.AuditResults r JOIN audit.Audits a ON a.Id = r.AuditId
                WHERE @ResultId IS NOT NULL AND r.IsPassed = 0
                  AND r.ItemText = (SELECT ItemText FROM audit.AuditResults WHERE Id = @ResultId)
            ), N'(zaman yayilimi hesaplanamadi)');

            -- Duzeltici faaliyetler
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'actionsTaken', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)),
                   N'(bu bulguya bagli duzeltici faaliyet kaydi yok)')
            FROM (
                SELECT TOP 20 CONCAT(N'- [', c.Status, N'] ', c.Title,
                       N' (sorumlu bolum: ', ISNULL(c.Department, N'-'),
                       N', termin: ', ISNULL(FORMAT(c.DueDate, 'dd.MM.yyyy'), N'-'), N')',
                       ISNULL(N' Kok sebep: ' + NULLIF(c.RootCause, N''), N'')) AS S
                FROM audit.CorrectiveActions c
                WHERE (@ResultId IS NOT NULL AND c.AuditResultId = @ResultId)
                   OR (@AuditId IS NOT NULL AND c.AuditId = @AuditId)
            ) x;

            -- Kapanis kaniti: EffectivenessNote 0/84 dolu — ayrimi koru
            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'closureEvidence',
                   CASE WHEN f.Status <> N'CLOSED'
                        THEN CONCAT(N'DOF henuz kapanmamis (durum: ', f.Status,
                                    N') — kapanis etkinligi degerlendirilemez.')
                        WHEN NULLIF(LTRIM(RTRIM(f.EffectivenessNote)), N'') IS NULL
                        THEN CONCAT(N'DOF kapali ama etkinlik notu bos. ', @TOPLANMAMIS)
                        ELSE f.EffectivenessNote END
            FROM dof.Findings f WHERE f.DofId = @DofId;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'postClosureAudits', ISNULL(STRING_AGG(CAST(x.S AS nvarchar(max)), CHAR(10)),
                   N'(kapanistan sonra bu mekanda denetim yapilmamis — etkinlik DOGRULANAMAZ)')
            FROM (
                SELECT TOP 10 CONCAT(N'- [', FORMAT(a.AuditDate, 'dd.MM.yyyy'), N'] ', a.LocationName,
                       N': ', (SELECT COUNT(*) FROM audit.AuditResults r2
                               WHERE r2.AuditId = a.Id AND r2.IsPassed = 0), N' uygunsuz') AS S
                FROM audit.Audits a
                JOIN dof.Findings f ON f.DofId = @DofId
                WHERE f.Status = N'CLOSED' AND a.AuditDate > f.UpdatedAt
                  AND @MekanAd IS NOT NULL AND a.LocationName = @MekanAd
                ORDER BY a.AuditDate
            ) x;

            INSERT INTO @Ctx (Ad, Deger)
            SELECT N'recurrenceAfterClosure',
                   CASE WHEN (SELECT Status FROM dof.Findings WHERE DofId = @DofId) <> N'CLOSED'
                        THEN N'(DOF acik — kapanis sonrasi tekrar sorusu gecersiz)'
                        ELSE ISNULL((
                            SELECT CONCAT(COUNT(*), N' kez tekrar etti')
                            FROM audit.AuditResults r
                            JOIN audit.Audits a ON a.Id = r.AuditId
                            JOIN dof.Findings f ON f.DofId = @DofId
                            WHERE r.IsPassed = 0 AND a.AuditDate > f.UpdatedAt
                              AND @ResultId IS NOT NULL
                              AND r.ItemText = (SELECT ItemText FROM audit.AuditResults WHERE Id = @ResultId)
                            HAVING COUNT(*) > 0
                        ), N'Kapanistan sonra tekrar gorulmedi.')
                   END;
        END

        ------------------------------------------------------------------
        -- Ogrenilen bilgi: insan kararlari + reddedilen ciktilar + onayli
        -- ornekler. sql/71'deki fonksiyondan gelir; hicbiri yoksa NULL doner
        -- ve degisken hic eklenmez (bos blok prompt butcesi harcamasin).
        ------------------------------------------------------------------
        DECLARE @Ogrenilen nvarchar(max) = ai.fn_LearningContext(@SkillId, 2, 2, 4000);
        -- NOT: skaler UDF'te varsayilan parametre ATLANAMAZ; dorduncu
        -- argumani vermezsek 'yetersiz arguman' hatasi alinir.

        IF @Ogrenilen IS NOT NULL
            INSERT INTO @Ctx (Ad, Deger) VALUES (N'OgrenilenBilgi', @Ogrenilen);

        SELECT Ad, Deger FROM @Ctx WHERE Deger IS NOT NULL;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '68_skill_context_build.sql tamamlandi.';
GO
