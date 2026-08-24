/* =====================================================================
   77_status_vocabulary_repair.sql — statu sozlugu tekillestirmesi
   Tarih   : 2026-08-22
   Bagimli : yok (mevcut SP'leri duzeltir, sema degismez)
   Geri al : SP'ler eski govdeleriyle yeniden olusturulabilir; ancak bu bir
             HATA DUZELTMESIDIR, geri alinmasi icin sebep yok.

   SORUN (olculdu):
   dof.Findings gercekte su statuleri kullaniyor —
       DRAFT 67 · IN_PROGRESS 5 · OPEN 5 · PENDING_VALIDATION 5 · CLOSED 2
   Hicbir satirda 'KAPANDI' YOK. Buna ragmen 5 SP bu degere referans veriyordu.

   Hicbiri hata vermiyor; hepsi sessizce yanlis sonuc donuyor:
     - rpt.sp_DashboardOverview_Kpi  : "acik DOF" 84 gosteriyor, gercek 82
     - rpt.sp_Dashboard_Kpi          : ayni
     - dof.sp_Dashboard_Dof_List     : liste filtresi kapali DOF'u da getiriyor
     - audit.sp_Analysis_DofEffectiveness : HER ZAMAN sifir satir

   Sonuncusu CIFTE olu: statu yanlis olmasinin yani sira SourceKey
   eslestirmesi de yanlis formatta ('%ItemId:...%' bekliyor, gercek format
   'AUDIT_2_RESULT_94'). Yani "DOF etkinligi olculuyor" diye sunulan
   mekanizma hic calismamis.

   ai.sp_SemanticVector_SourceList BOZUK DEGILDI — IN ('CLOSED','KAPANDI')
   yaziyordu, CLOSED'u yakaliyordu. Yalniz olu deger temizlendi.

   DONE KRITERI: duzeltme sonrasi KPI DEGISMELI.
     acik DOF   84 -> 82
     kapali DOF  0 -> 2
   Degismiyorsa duzeltme uygulanmamistir.

   NOT: SP govdeleri CANLI TANIMDAN alinip yalniz ilgili satirlar
   degistirilmistir; gerisi birebir korunmustur.
   ===================================================================== */

SET NOCOUNT ON;
GO

-- ---------------------------------------------------------------------
-- rpt.sp_DashboardOverview_Kpi
-- acik DOF kapsami: 'KAPANDI' hic eslesmiyordu, kapali DOF'lar da acik sayiliyordu. REJECTED de haric (dof modulunun tanimi, sql/38)
-- ---------------------------------------------------------------------

-- ===========================================================================
-- 1) rpt.sp_DashboardOverview_Kpi  (was: rpt.sp_GenelBakis_Kpi)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
--    View:  rpt.vw_RiskUrunOzet_Stok stays as-is
-- ===========================================================================
CREATE OR ALTER PROCEDURE rpt.sp_DashboardOverview_Kpi
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            SET @Kesim = CONVERT(date, SYSDATETIME());

        DECLARE @KritikSkorEsik int = COALESCE(
            (SELECT IntValue FROM ref.RiskParameters WHERE ParamCode = 'KritikSkorEsik'), 80);

        DECLARE @RiskSatir int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
        );

        DECLARE @KritikSkor int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
              AND RiskScore >= @KritikSkorEsik
        );

        DECLARE @DofAcik int = (
            SELECT COUNT(*) FROM dof.Findings
            WHERE Status NOT IN ('CLOSED', 'REJECTED')
        );

        DECLARE @StokSapma int = (
            SELECT COUNT(*) FROM rpt.vw_RiskUrunOzet_Stok
            WHERE KesimGunu = @Kesim AND DonemKodu = 'Son30Gun'
              AND (FlagStokKaydiYok = 1 OR FlagStokSifir = 1)
        );

        SELECT Sira, Kodu, Baslik, Deger, NotAciklama, Tone
        FROM (
            SELECT
                Sira = 1,
                Kodu = 'RiskSatir',
                Baslik = 'Risk Satir',
                Deger = @RiskSatir,
                NotAciklama = 'Son 24 saat',
                Tone = CASE WHEN @RiskSatir > 0 THEN 'tone-good' ELSE 'tone-warn' END
            UNION ALL
            SELECT 2, 'KritikSkor', 'Kritik Skor', @KritikSkor,
                CONCAT('Esik ', @KritikSkorEsik, '+'),
                CASE WHEN @KritikSkor > 0 THEN 'tone-warn' ELSE 'tone-good' END
            UNION ALL
            SELECT 3, 'DofAcik', 'Dof Acik', @DofAcik,
                'SLA takibi',
                CASE WHEN @DofAcik > 0 THEN 'tone-alert' ELSE 'tone-good' END
            UNION ALL
            SELECT 4, 'StokSapma', 'Stok Sapma', @StokSapma,
                'Dun yakalanan',
                CASE WHEN @StokSapma > 0 THEN 'tone-warn' ELSE 'tone-good' END
        ) x
        ORDER BY x.Sira;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------------------------------------------------------------------
-- rpt.sp_Dashboard_Kpi
-- acik DOF kapsami: 'KAPANDI' hic eslesmiyordu, kapali DOF'lar da acik sayiliyordu. REJECTED de haric (dof modulunun tanimi, sql/38)
-- ---------------------------------------------------------------------

-- ===========================================================================
-- 3) rpt.sp_Dashboard_Kpi  (was: rpt.sp_Dashboard_Kpi from 11_sps_dashboard)
--    Table: rpt.DailyProductRisk (was: rpt.RiskUrunOzet_Gunluk)
-- ===========================================================================
CREATE OR ALTER PROCEDURE rpt.sp_Dashboard_Kpi
    @KesimGunu date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @Kesim date = COALESCE(@KesimGunu,
            (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
        IF @Kesim IS NULL
            SET @Kesim = CONVERT(date, SYSDATETIME());

        DECLARE @KritikSkorEsik int = COALESCE(
            (SELECT IntValue FROM ref.RiskParameters WHERE ParamCode = 'KritikSkorEsik'), 80);

        DECLARE @KritikRisk int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
              AND RiskScore >= @KritikSkorEsik
        );

        DECLARE @BekleyenDof int = (
            SELECT COUNT(*) FROM dof.Findings
            WHERE Status NOT IN ('CLOSED', 'REJECTED')
        );

        DECLARE @TarananStok int = (
            SELECT COUNT(*)
            FROM rpt.DailyProductRisk
            WHERE CONVERT(date, SnapshotDate) = @Kesim AND PeriodCode = 'Son30Gun'
        );

        SELECT Sira, Kodu, Deger, NotAciklama
        FROM (
            SELECT
                Sira = 1,
                Kodu = 'KRITIK_RISK',
                Deger = @KritikRisk,
                NotAciklama = CONCAT('Esik ', @KritikSkorEsik, '+')
            UNION ALL
            SELECT 2, 'BEKLEYEN_DOF', @BekleyenDof, 'SLA takibi'
            UNION ALL
            SELECT 3, 'TARANAN_STOK', @TarananStok, 'Son gece'
        ) x
        ORDER BY x.Sira;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------------------------------------------------------------------
-- dof.sp_Dashboard_Dof_List
-- acik DOF kapsami: 'KAPANDI' hic eslesmiyordu, kapali DOF'lar da acik sayiliyordu. REJECTED de haric (dof modulunun tanimi, sql/38)
-- ---------------------------------------------------------------------

-- ===========================================================================
-- 6) dof.sp_Dashboard_Dof_List  (was: dof.sp_Dashboard_Dof_Liste)
--    Table: dof.Findings stays as-is (not yet renamed)
-- ===========================================================================
CREATE OR ALTER PROCEDURE dof.sp_Dashboard_Dof_List
    @Top int = 5
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Top)
            Title,
            Sorumlu = COALESCE(NULLIF(LTRIM(RTRIM(AssignedTo)), ''), 'Atanmadi'),
            SLA = CASE
                WHEN SlaDueDate IS NULL THEN 'Suresiz'
                ELSE CONCAT(DATEDIFF(day, CONVERT(date, SYSDATETIME()), SlaDueDate), ' gun')
            END,
            Status
        FROM dof.Findings
        WHERE Status NOT IN ('CLOSED', 'REJECTED')
        ORDER BY RiskLevel DESC, SlaDueDate;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------------------------------------------------------------------
-- ai.sp_SemanticVector_SourceList
-- olu 'KAPANDI' degeri temizlendi — bu SP BOZUK DEGILDI, IN listesi CLOSED'u zaten yakaliyordu
-- ---------------------------------------------------------------------

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
                WHEN d.Status IN ('CLOSED') AND d.IsEffective = 1 THEN 1.00
                WHEN d.Status IN ('CLOSED')                       THEN 0.85
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

-- ---------------------------------------------------------------------
-- audit.sp_Analysis_DofEffectiveness
-- cifte olu: statu 'KAPANDI' (gercek 'CLOSED') + SourceKey formati uyusmuyordu
-- ---------------------------------------------------------------------

CREATE OR ALTER PROCEDURE audit.sp_Analysis_DofEffectiveness
    @AuditId    int
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- dof.Findings tablosu yoksa cik
        IF OBJECT_ID(N'dof.Findings', N'U') IS NULL
            RETURN;

        DECLARE @LocationName nvarchar(100);
        DECLARE @AuditDate   datetime2(0);

        SELECT @LocationName = LocationName, @AuditDate = AuditDate
        FROM audit.Audits
        WHERE Id = @AuditId;

        IF @LocationName IS NULL
        BEGIN
            RAISERROR('Denetim bulunamadi. AuditId: %d', 16, 1, @AuditId);
            RETURN;
        END

        -- Basarisiz sonuclar icin: ayni madde + ayni lokasyon icin
        -- daha once kapatilmis DOF'lari bul ve etkinligini dusur
        ;WITH FailedWithClosedDof AS
        (
            SELECT
                d.DofId,
                FailCount = COUNT(DISTINCT r.AuditId)
            FROM audit.AuditResults r
            INNER JOIN audit.Audits a ON a.Id = r.AuditId
            INNER JOIN dof.Findings d ON d.SourceSystemCode = 'SAHA_DENETIM'
                AND d.Status = 'CLOSED'
                -- SourceKey gercek formati: 'AUDIT_{AuditId}_RESULT_{ResultId}'
                -- Eski hali '%ItemId:...%Loc:...%' bekliyordu ve hicbir zaman
                -- eslesmiyordu; statu de yanlisti. Iki hata birden oldugu icin
                -- SP sessizce HER ZAMAN sifir satir donuyordu.
                -- Dogru yol: DOF'un isaret ettigi eski denetim sonucuna joinle,
                -- oradan ayni madde + ayni mekan karsilastirmasi yap.
                AND EXISTS (
                    SELECT 1
                    FROM audit.AuditResults prev
                    JOIN audit.Audits prevA ON prevA.Id = prev.AuditId
                    WHERE d.SourceKey = CONCAT('AUDIT_', prev.AuditId, '_RESULT_', prev.Id)
                      AND prevA.LocationName = @LocationName
                      AND (prev.AuditItemId = r.AuditItemId
                           OR (prev.AuditItemId IS NULL AND prev.ItemText = r.ItemText))
                )
                AND d.UpdatedAt < @AuditDate
            WHERE r.AuditId = @AuditId
              AND r.IsPassed = 0
            GROUP BY d.DofId
        )
        UPDATE d
        SET d.IsEffective       = 0,
            d.EffectivenessScore = CASE
                WHEN (1.0 - fcd.FailCount * 0.25) < 0 THEN 0
                ELSE (1.0 - fcd.FailCount * 0.25)
            END,
            d.EffectivenessNote  = CONCAT(
                N'Saha denetim tekrar tespiti - AuditId: ', @AuditId,
                N', Lokasyon: ', @LocationName,
                N', Tarih: ', CONVERT(varchar(10), @AuditDate, 120)
            ),
            d.UpdatedAt          = SYSDATETIME()
        FROM dof.Findings d
        INNER JOIN FailedWithClosedDof fcd ON fcd.DofId = d.DofId;

        SELECT @@ROWCOUNT AS UpdatedCount;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg17 nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg17, 16, 1);
    END CATCH
END
GO

PRINT '77_status_vocabulary_repair.sql tamamlandi.';
GO
