/*
    42_fix_broken_sp_references.sql
    -----------------------------------------------
    Fix all SPs that reference non-existent objects:

    1) Recreate log.tvf_MekanListesi using ref.LocationSettings
       (was using src.vw_Mekan which may not exist)
    2) ALTER log.sp_DailyProductRisk_Run  - uses tvf_MekanListesi (now fixed by #1)
    3) ALTER log.sp_DailyStockBalance_Run - uses tvf_MekanListesi (now fixed by #1)
    4) ALTER rpt.sp_StockBalance_GetByDate - uses tvf_MekanListesi (now fixed by #1)
    5) Fix etl.sp_StockMovement_Extract   - src.StokHareket -> src.vw_StokHareket
    6) Fix etl.sp_ErpStokHareket_Extract  - etl.EtlLog -> etl.EtlRuns
    7) Create ai.sp_AnalysisQueue_Create  - missing SP called by ResetAndTrigger

    Generated: 2026-03-30
*/
USE BKMDenetim;
GO

PRINT '--- 42_fix_broken_sp_references.sql ---';
GO


-- =============================================
-- 1) Recreate log.tvf_MekanListesi
--    Was in 04_sps_etl.sql referencing src.vw_Mekan.
--    Now uses ref.LocationSettings (English table).
-- =============================================
IF OBJECT_ID('log.tvf_MekanListesi', 'IF') IS NOT NULL
    DROP FUNCTION log.tvf_MekanListesi;
GO

CREATE FUNCTION log.tvf_MekanListesi(@MekanCSV varchar(max))
RETURNS TABLE
AS
RETURN
(
    -- If CSV provided, parse it
    SELECT TRY_CAST(value AS int) AS MekanId
    FROM STRING_SPLIT(COALESCE(@MekanCSV,''), ',')
    WHERE LTRIM(RTRIM(COALESCE(value,''))) <> ''
      AND TRY_CAST(value AS int) IS NOT NULL

    UNION

    -- If no CSV, return all active locations
    SELECT DISTINCT LocationId AS MekanId
    FROM ref.LocationSettings
    WHERE IsActive = 1
      AND (COALESCE(@MekanCSV,'') = '')
);
GO

PRINT '  TVF log.tvf_MekanListesi recreated (uses ref.LocationSettings).';
GO


-- =============================================
-- 2) Fix etl.sp_StockMovement_Extract
--    src.StokHareket -> src.vw_StokHareket
-- =============================================
IF OBJECT_ID('etl.sp_StockMovement_Extract', 'P') IS NOT NULL
    DROP PROCEDURE etl.sp_StockMovement_Extract;
GO

CREATE PROCEDURE etl.sp_StockMovement_Extract
    @BatchSize int = 10000,
    @LastSyncDate datetime2(0) = NULL,
    @TargetDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @BatchId uniqueidentifier = NEWID();
    DECLARE @ProcessedRecords int = 0;

    BEGIN TRY
        -- Hedef tarih belirleme (varsayilan dun)
        IF @TargetDate IS NULL
            SET @TargetDate = CAST(DATEADD(day, -1, SYSDATETIME()) AS date);

        -- Son senkronizasyon tarihini al
        IF @LastSyncDate IS NULL
        BEGIN
            SELECT @LastSyncDate = ISNULL(LastSyncDate, CAST(DATEADD(day, -7, SYSDATETIME()) AS datetime2(0)))
            FROM etl.SyncStatus
            WHERE TableName = 'src.StokHareket';
        END

        -- Log kaydini baslat
        INSERT INTO etl.EtlRuns (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('StockMovement_Extract', 'EXTRACT', 'CALISIYOR', @StartTime, 'ERP_SYSTEM', 'STAGING',
                CONCAT('Stok hareket verisi cekme baslatildi. Hedef tarih: ', @TargetDate));

        -- ERP'den stok hareket verilerini cek
        -- FIX: src.StokHareket -> src.vw_StokHareket
        INSERT INTO etl.StockMovementStaging (
            ErpHareketNo, ErpStokKodu, MekanKodu, HareketTarihi, HareketTipi,
            GirisMiktar, CikisMiktar, BirimMaliyet, ToplamMaliyet, EtlBatchId, EtlTarihi
        )
        SELECT TOP (@BatchSize)
            CONCAT('ERP-H-', sh.HareketId) as ErpHareketNo,
            s.StokKodu as ErpStokKodu,
            m.MekanKodu,
            CAST(sh.HareketTarihi AS date) as HareketTarihi,
            CASE
                WHEN sh.Adet > 0 THEN 'GIRIS'
                WHEN sh.Adet < 0 THEN 'CIKIS'
                ELSE 'TRANSFER'
            END as HareketTipi,
            CASE WHEN sh.Adet > 0 THEN sh.Adet ELSE NULL END as GirisMiktar,
            CASE WHEN sh.Adet < 0 THEN ABS(sh.Adet) ELSE NULL END as CikisMiktar,
            CASE WHEN sh.Tutar <> 0 AND sh.Adet <> 0 THEN ABS(sh.Tutar / sh.Adet) ELSE 0 END as BirimMaliyet,
            ABS(sh.Tutar) as ToplamMaliyet,
            @BatchId,
            SYSDATETIME()
        FROM src.vw_StokHareket sh
        INNER JOIN ref.Stok s ON s.StokId = sh.StokId
        INNER JOIN ref.Mekan m ON m.MekanId = sh.MekanId
        WHERE CAST(sh.HareketTarihi AS date) = @TargetDate
          AND NOT EXISTS (
              SELECT 1 FROM etl.StockMovementStaging es
              WHERE es.ErpHareketNo = CONCAT('ERP-H-', sh.HareketId)
                AND es.ProcessedFlag = 0
          )
        ORDER BY sh.HareketTarihi, sh.HareketId;

        SET @ProcessedRecords = @@ROWCOUNT;

        -- Senkronizasyon durumunu guncelle
        MERGE etl.SyncStatus AS target
        USING (SELECT 'src.StokHareket' as TableName) AS source
        ON target.TableName = source.TableName
        WHEN MATCHED THEN
            UPDATE SET
                LastSyncDate = SYSDATETIME(),
                LastUpdateDate = @TargetDate,
                RecordsProcessed = @ProcessedRecords,
                Status = 'TAMAMLANDI',
                UpdatedDate = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (TableName, LastSyncDate, LastUpdateDate, RecordsProcessed, Status)
            VALUES (source.TableName, SYSDATETIME(), @TargetDate, @ProcessedRecords, 'TAMAMLANDI');

        -- Log kaydini tamamla
        UPDATE etl.EtlRuns
        SET Status = 'TAMAMLANDI',
            EndTime = SYSDATETIME(),
            RecordsProcessed = @ProcessedRecords,
            Message = CONCAT('Stok hareket verisi cekme tamamlandi. Islenen kayit: ', @ProcessedRecords)
        WHERE JobName = 'StockMovement_Extract'
          AND StartTime = @StartTime;

        SELECT @ProcessedRecords as ProcessedRecords, 'Basarili' as Status;

    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlRuns (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('StockMovement_Extract', 'EXTRACT', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());

        THROW;
    END CATCH
END
GO

PRINT '  etl.sp_StockMovement_Extract fixed (src.vw_StokHareket).';
GO


-- =============================================
-- 3) Fix etl.sp_ErpStokHareket_Extract
--    etl.EtlLog -> etl.EtlRuns
--    etl.EtlSyncStatus -> etl.SyncStatus
--    src.StokHareket -> src.vw_StokHareket
--    etl.StokHareketStaging -> etl.StockMovementStaging
-- =============================================
IF OBJECT_ID('etl.sp_ErpStokHareket_Extract', 'P') IS NOT NULL
    DROP PROCEDURE etl.sp_ErpStokHareket_Extract;
GO

CREATE PROCEDURE etl.sp_ErpStokHareket_Extract
    @BatchSize int = 10000,
    @LastSyncDate datetime2(0) = NULL,
    @TargetDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime datetime2(0) = SYSDATETIME();
    DECLARE @BatchId uniqueidentifier = NEWID();
    DECLARE @ProcessedRecords int = 0;

    BEGIN TRY
        -- Hedef tarih belirleme (varsayilan dun)
        IF @TargetDate IS NULL
            SET @TargetDate = CAST(DATEADD(day, -1, SYSDATETIME()) AS date);

        -- Son senkronizasyon tarihini al
        IF @LastSyncDate IS NULL
        BEGIN
            SELECT @LastSyncDate = ISNULL(LastSyncDate, CAST(DATEADD(day, -7, SYSDATETIME()) AS datetime2(0)))
            FROM etl.SyncStatus
            WHERE TableName = 'src.StokHareket';
        END

        -- Log kaydini baslat
        INSERT INTO etl.EtlRuns (JobName, JobType, Status, StartTime, SourceSystem, TargetSystem, Message)
        VALUES ('ErpStokHareket_Extract', 'EXTRACT', 'CALISIYOR', @StartTime, 'ERP_SYSTEM', 'STAGING',
                CONCAT('Stok hareket verisi cekme baslatildi. Hedef tarih: ', @TargetDate));

        -- ERP'den stok hareket verilerini cek
        INSERT INTO etl.StockMovementStaging (
            ErpHareketNo, ErpStokKodu, MekanKodu, HareketTarihi, HareketTipi,
            GirisMiktar, CikisMiktar, BirimMaliyet, ToplamMaliyet, EtlBatchId, EtlTarihi
        )
        SELECT TOP (@BatchSize)
            CONCAT('ERP-H-', sh.HareketId) as ErpHareketNo,
            s.StokKodu as ErpStokKodu,
            m.MekanKodu,
            CAST(sh.HareketTarihi AS date) as HareketTarihi,
            CASE
                WHEN sh.Adet > 0 THEN 'GIRIS'
                WHEN sh.Adet < 0 THEN 'CIKIS'
                ELSE 'TRANSFER'
            END as HareketTipi,
            CASE WHEN sh.Adet > 0 THEN sh.Adet ELSE NULL END as GirisMiktar,
            CASE WHEN sh.Adet < 0 THEN ABS(sh.Adet) ELSE NULL END as CikisMiktar,
            CASE WHEN sh.Tutar <> 0 AND sh.Adet <> 0 THEN ABS(sh.Tutar / sh.Adet) ELSE 0 END as BirimMaliyet,
            ABS(sh.Tutar) as ToplamMaliyet,
            @BatchId,
            SYSDATETIME()
        FROM src.vw_StokHareket sh
        INNER JOIN ref.Stok s ON s.StokId = sh.StokId
        INNER JOIN ref.Mekan m ON m.MekanId = sh.MekanId
        WHERE CAST(sh.HareketTarihi AS date) = @TargetDate
          AND NOT EXISTS (
              SELECT 1 FROM etl.StockMovementStaging es
              WHERE es.ErpHareketNo = CONCAT('ERP-H-', sh.HareketId)
                AND es.ProcessedFlag = 0
          )
        ORDER BY sh.HareketTarihi, sh.HareketId;

        SET @ProcessedRecords = @@ROWCOUNT;

        -- Senkronizasyon durumunu guncelle
        MERGE etl.SyncStatus AS target
        USING (SELECT 'src.StokHareket' as TableName) AS source
        ON target.TableName = source.TableName
        WHEN MATCHED THEN
            UPDATE SET
                LastSyncDate = SYSDATETIME(),
                LastUpdateDate = @TargetDate,
                RecordsProcessed = @ProcessedRecords,
                Status = 'TAMAMLANDI',
                UpdatedDate = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (TableName, LastSyncDate, LastUpdateDate, RecordsProcessed, Status)
            VALUES (source.TableName, SYSDATETIME(), @TargetDate, @ProcessedRecords, 'TAMAMLANDI');

        -- Log kaydini tamamla
        UPDATE etl.EtlRuns
        SET Status = 'TAMAMLANDI',
            EndTime = SYSDATETIME(),
            RecordsProcessed = @ProcessedRecords,
            Message = CONCAT('Stok hareket verisi cekme tamamlandi. Islenen kayit: ', @ProcessedRecords)
        WHERE JobName = 'ErpStokHareket_Extract'
          AND StartTime = @StartTime;

        SELECT @ProcessedRecords as ProcessedRecords, 'Basarili' as Status;

    END TRY
    BEGIN CATCH
        INSERT INTO etl.EtlRuns (JobName, JobType, Status, StartTime, EndTime, ErrorMessage)
        VALUES ('ErpStokHareket_Extract', 'EXTRACT', 'BASARISIZ', @StartTime, SYSDATETIME(), ERROR_MESSAGE());

        THROW;
    END CATCH
END
GO

PRINT '  etl.sp_ErpStokHareket_Extract fixed (EtlRuns, SyncStatus, vw_StokHareket, StockMovementStaging).';
GO


-- =============================================
-- 4) Create ai.sp_AnalysisQueue_Create
--    This SP was called by ai.sp_AnalysisQueue_ResetAndTrigger
--    but was never created. Based on old ai.sp_Ai_Istek_Olustur
--    but using English table/column names.
-- =============================================
IF OBJECT_ID('ai.sp_AnalysisQueue_Create', 'P') IS NOT NULL
    DROP PROCEDURE ai.sp_AnalysisQueue_Create;
GO

CREATE PROCEDURE ai.sp_AnalysisQueue_Create
    @Top int = 200,
    @KesimGunu date = NULL,
    @MinSkor int = 80
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Kesim date = COALESCE(@KesimGunu,
        (SELECT MAX(CONVERT(date, SnapshotDate)) FROM rpt.DailyProductRisk));
    IF @Kesim IS NULL
        RETURN;

    INSERT INTO ai.AnalysisQueue
        (SnapshotDate, PeriodCode, LocationId, ProductId, SourceType, SourceKey, Priority, Status)
    SELECT TOP (@Top)
        r.SnapshotDate,
        r.PeriodCode,
        r.LocationId,
        r.ProductId,
        'RISK',
        CONCAT('Kesim=', CONVERT(varchar(10), CONVERT(date, r.SnapshotDate), 120),
               '|Donem=', r.PeriodCode,
               '|Mekan=', r.LocationId,
               '|Stok=', r.ProductId),
        Priority = CASE WHEN r.RiskScore >= 90 THEN 1 WHEN r.RiskScore >= 75 THEN 2 ELSE 3 END,
        Status = 'NEW'
    FROM rpt.DailyProductRisk r
    WHERE CONVERT(date, r.SnapshotDate) = @Kesim
      AND r.RiskScore >= @MinSkor
      AND NOT EXISTS (
          SELECT 1
          FROM ai.AnalysisQueue a
          WHERE a.SnapshotDate = r.SnapshotDate
            AND a.PeriodCode = r.PeriodCode
            AND a.LocationId = r.LocationId
            AND a.ProductId = r.ProductId
      )
    ORDER BY r.RiskScore DESC;
END
GO

PRINT '  ai.sp_AnalysisQueue_Create created (was missing dependency).';
GO


-- =============================================
-- 5) Fix log.sp_DailyProductRisk_Run
--    log.tvf_MekanListesi is now recreated above,
--    but we still need to re-deploy this SP to
--    ensure it compiles cleanly. The SP was already
--    correct in 31_sps_ai_log_etl_english.sql but
--    the TVF it depends on was missing. Recreating
--    the TVF (step 1 above) fixes this.
--    NO ACTION NEEDED - TVF recreation fixes it.
-- =============================================

-- =============================================
-- 6) Fix log.sp_DailyStockBalance_Run
--    Same as above - depends on tvf_MekanListesi.
--    NO ACTION NEEDED - TVF recreation fixes it.
-- =============================================

-- =============================================
-- 7) Fix rpt.sp_StockBalance_GetByDate
--    Same as above - depends on tvf_MekanListesi.
--    NO ACTION NEEDED - TVF recreation fixes it.
-- =============================================


PRINT '--- 42_fix_broken_sp_references.sql complete ---';
GO
