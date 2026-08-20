/* =====================================================================
   54_semantic_layer_sps.sql — Semantik katman SP'leri
   Tarih   : 2026-08-20
   Bagimli : 53_semantic_layer.sql
   Amac    : Upsert (surekli ogrenme) + arama + AI context uretimi + decay raporu.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   Entity upsert
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Entity_Upsert
    @EntityId       varchar(120),
    @VeritabaniAdi  varchar(100)   = NULL,
    @SemaAdi        varchar(50)    = NULL,
    @NesneAdi       varchar(120),
    @NesneTipi      varchar(20)    = 'TABLE',
    @PkKolonlari    varchar(300)   = NULL,
    @AnahtarKolonlar varchar(1000) = NULL,
    @Tanecik        nvarchar(300)  = NULL,
    @Not            nvarchar(2000) = NULL,
    @Guven          decimal(3,2)   = 0.80,
    @Kanit          nvarchar(max)  = NULL,
    @Durum          varchar(20)    = 'aktif',
    @TtlGun         int            = NULL,
    @KullaniciId    int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: kanitsiz yuksek guven kabul edilmez
        IF @Guven >= 0.90 AND LTRIM(RTRIM(ISNULL(@Kanit, ''))) = ''
            THROW 50130, N'Guven 0.90 ve uzeri icin kanit (evidence) zorunludur.', 1;

        IF EXISTS (SELECT 1 FROM sem.Entities WHERE EntityId = @EntityId)
            UPDATE sem.Entities
               SET DbName = @VeritabaniAdi, SchemaName = @SemaAdi, ObjectName = @NesneAdi,
                   ObjectType = @NesneTipi, PkColumns = @PkKolonlari, KeyColumns = @AnahtarKolonlar,
                   Grain = @Tanecik, Note = @Not, Confidence = @Guven, Evidence = @Kanit,
                   Status = @Durum, TtlDays = @TtlGun,
                   LastVerifiedAt = CAST(SYSDATETIME() AS date),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE EntityId = @EntityId;
        ELSE
            INSERT INTO sem.Entities (EntityId, DbName, SchemaName, ObjectName, ObjectType, PkColumns,
                                      KeyColumns, Grain, Note, Confidence, Evidence, Status, TtlDays,
                                      LastVerifiedAt, CreatedByUserId)
            VALUES (@EntityId, @VeritabaniAdi, @SemaAdi, @NesneAdi, @NesneTipi, @PkKolonlari,
                    @AnahtarKolonlar, @Tanecik, @Not, @Guven, @Kanit, @Durum, @TtlGun,
                    CAST(SYSDATETIME() AS date), @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Bridge upsert
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Bridge_Upsert
    @BridgeId      varchar(120),
    @Kaynak        varchar(300),
    @Hedef         varchar(300),
    @JoinIfadesi   nvarchar(1000) = NULL,
    @Kapsam        varchar(50)    = NULL,
    @Kardinalite   varchar(20)    = NULL,
    @Not           nvarchar(2000) = NULL,
    @Guven         decimal(3,2)   = 0.80,
    @Kanit         nvarchar(max)  = NULL,
    @Durum         varchar(20)    = 'aktif',
    @TtlGun        int            = NULL,
    @KullaniciId   int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Guven >= 0.90 AND LTRIM(RTRIM(ISNULL(@Kanit, ''))) = ''
            THROW 50131, N'Guven 0.90 ve uzeri icin kanit (evidence) zorunludur.', 1;

        IF EXISTS (SELECT 1 FROM sem.Bridges WHERE BridgeId = @BridgeId)
            UPDATE sem.Bridges
               SET FromRef = @Kaynak, ToRef = @Hedef, JoinExpression = @JoinIfadesi,
                   Scope = @Kapsam, Cardinality = @Kardinalite, Note = @Not,
                   Confidence = @Guven, Evidence = @Kanit, Status = @Durum, TtlDays = @TtlGun,
                   LastVerifiedAt = CAST(SYSDATETIME() AS date),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE BridgeId = @BridgeId;
        ELSE
            INSERT INTO sem.Bridges (BridgeId, FromRef, ToRef, JoinExpression, Scope, Cardinality,
                                     Note, Confidence, Evidence, Status, TtlDays, LastVerifiedAt, CreatedByUserId)
            VALUES (@BridgeId, @Kaynak, @Hedef, @JoinIfadesi, @Kapsam, @Kardinalite,
                    @Not, @Guven, @Kanit, @Durum, @TtlGun, CAST(SYSDATETIME() AS date), @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   CodeSet + deger upsert
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_CodeSet_Upsert
    @CodeSetId    varchar(120),
    @Ad           nvarchar(200),
    @LookupTablo  varchar(200)   = NULL,
    @JoinIfadesi  nvarchar(500)  = NULL,
    @Not          nvarchar(1000) = NULL,
    @Guven        decimal(3,2)   = 0.80,
    @Kanit        nvarchar(max)  = NULL,
    @KullaniciId  int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM sem.CodeSets WHERE CodeSetId = @CodeSetId)
            UPDATE sem.CodeSets
               SET Name = @Ad, LookupTable = @LookupTablo, JoinExpression = @JoinIfadesi, Note = @Not,
                   Confidence = @Guven, Evidence = @Kanit, LastVerifiedAt = CAST(SYSDATETIME() AS date),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE CodeSetId = @CodeSetId;
        ELSE
            INSERT INTO sem.CodeSets (CodeSetId, Name, LookupTable, JoinExpression, Note, Confidence, Evidence, LastVerifiedAt, CreatedByUserId)
            VALUES (@CodeSetId, @Ad, @LookupTablo, @JoinIfadesi, @Not, @Guven, @Kanit, CAST(SYSDATETIME() AS date), @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sem.sp_CodeValue_Upsert
    @CodeSetId   varchar(120),
    @Kod         varchar(50),
    @Etiket      nvarchar(200),
    @Not         nvarchar(500) = NULL,
    @KullaniciId int           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM sem.CodeSets WHERE CodeSetId = @CodeSetId)
            THROW 50132, N'Kod kumesi bulunamadi. Once sem.sp_CodeSet_Upsert calistirin.', 1;

        IF EXISTS (SELECT 1 FROM sem.CodeValues WHERE CodeSetId = @CodeSetId AND CodeValue = @Kod)
            UPDATE sem.CodeValues
               SET Label = @Etiket, Note = @Not, UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE CodeSetId = @CodeSetId AND CodeValue = @Kod;
        ELSE
            INSERT INTO sem.CodeValues (CodeSetId, CodeValue, Label, Note, CreatedByUserId)
            VALUES (@CodeSetId, @Kod, @Etiket, @Not, @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Metric upsert
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Metric_Upsert
    @MetricId    varchar(120),
    @Ad          nvarchar(200),
    @Kaynak      nvarchar(1000) = NULL,
    @Formul      nvarchar(max)  = NULL,
    @Tuzak       nvarchar(2000) = NULL,
    @Birim       varchar(50)    = NULL,
    @Guven       decimal(3,2)   = 0.80,
    @Kanit       nvarchar(max)  = NULL,
    @Durum       varchar(20)    = 'aktif',
    @TtlGun      int            = NULL,
    @KullaniciId int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Guven >= 0.90 AND LTRIM(RTRIM(ISNULL(@Kanit, ''))) = ''
            THROW 50133, N'Guven 0.90 ve uzeri icin kanit zorunludur.', 1;

        IF EXISTS (SELECT 1 FROM sem.Metrics WHERE MetricId = @MetricId)
            UPDATE sem.Metrics
               SET Name = @Ad, SourceRef = @Kaynak, Formula = @Formul, Caveat = @Tuzak, Unit = @Birim,
                   Confidence = @Guven, Evidence = @Kanit, Status = @Durum, TtlDays = @TtlGun,
                   LastVerifiedAt = CAST(SYSDATETIME() AS date),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE MetricId = @MetricId;
        ELSE
            INSERT INTO sem.Metrics (MetricId, Name, SourceRef, Formula, Caveat, Unit, Confidence, Evidence,
                                     Status, TtlDays, LastVerifiedAt, CreatedByUserId)
            VALUES (@MetricId, @Ad, @Kaynak, @Formul, @Tuzak, @Birim, @Guven, @Kanit,
                    @Durum, @TtlGun, CAST(SYSDATETIME() AS date), @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Query (golden SQL) upsert
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Query_Upsert
    @QueryId       varchar(120),
    @Soru          nvarchar(500),
    @DogrulanmisSql nvarchar(max),
    @IlgiliMetrik  varchar(500)   = NULL,
    @IlgiliKopru   varchar(500)   = NULL,
    @SonucNotu     nvarchar(1000) = NULL,
    @Guven         decimal(3,2)   = 0.80,
    @Kanit         nvarchar(max)  = NULL,
    @TtlGun        int            = NULL,
    @KullaniciId   int            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Is kurali: dogrulanmamis SQL katalogda yer alamaz
        IF LTRIM(RTRIM(ISNULL(@DogrulanmisSql, ''))) = ''
            THROW 50134, N'Dogrulanmis SQL bos olamaz.', 1;

        IF EXISTS (SELECT 1 FROM sem.Queries WHERE QueryId = @QueryId)
            UPDATE sem.Queries
               SET Question = @Soru, VerifiedSql = @DogrulanmisSql, RelatedMetrics = @IlgiliMetrik,
                   RelatedBridges = @IlgiliKopru, ResultNote = @SonucNotu, Confidence = @Guven,
                   Evidence = @Kanit, TtlDays = @TtlGun, LastVerifiedAt = CAST(SYSDATETIME() AS date),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE QueryId = @QueryId;
        ELSE
            INSERT INTO sem.Queries (QueryId, Question, VerifiedSql, RelatedMetrics, RelatedBridges,
                                     ResultNote, Confidence, Evidence, TtlDays, LastVerifiedAt, CreatedByUserId)
            VALUES (@QueryId, @Soru, @DogrulanmisSql, @IlgiliMetrik, @IlgiliKopru,
                    @SonucNotu, @Guven, @Kanit, @TtlGun, CAST(SYSDATETIME() AS date), @KullaniciId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Yeniden dogrulama — kayit hala gecerli
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Verify
    @Katman      varchar(20),      -- Entity|Bridge|CodeSet|Metric|Query
    @KayitId     varchar(120),
    @YeniGuven   decimal(3,2) = NULL,
    @Kanit       nvarchar(max) = NULL,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @Bugun date = CAST(SYSDATETIME() AS date);

        IF @Katman = 'Entity'
            UPDATE sem.Entities SET LastVerifiedAt = @Bugun,
                   Confidence = ISNULL(@YeniGuven, Confidence),
                   Evidence = ISNULL(@Kanit, Evidence),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE EntityId = @KayitId;
        ELSE IF @Katman = 'Bridge'
            UPDATE sem.Bridges SET LastVerifiedAt = @Bugun,
                   Confidence = ISNULL(@YeniGuven, Confidence),
                   Evidence = ISNULL(@Kanit, Evidence),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE BridgeId = @KayitId;
        ELSE IF @Katman = 'CodeSet'
            UPDATE sem.CodeSets SET LastVerifiedAt = @Bugun,
                   Confidence = ISNULL(@YeniGuven, Confidence),
                   Evidence = ISNULL(@Kanit, Evidence),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE CodeSetId = @KayitId;
        ELSE IF @Katman = 'Metric'
            UPDATE sem.Metrics SET LastVerifiedAt = @Bugun,
                   Confidence = ISNULL(@YeniGuven, Confidence),
                   Evidence = ISNULL(@Kanit, Evidence),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE MetricId = @KayitId;
        ELSE IF @Katman = 'Query'
            UPDATE sem.Queries SET LastVerifiedAt = @Bugun,
                   Confidence = ISNULL(@YeniGuven, Confidence),
                   Evidence = ISNULL(@Kanit, Evidence),
                   UpdatedAt = SYSDATETIME(), UpdatedByUserId = @KullaniciId
             WHERE QueryId = @KayitId;
        ELSE
            THROW 50135, N'Gecersiz katman. Entity|Bridge|CodeSet|Metric|Query bekleniyor.', 1;

        IF @@ROWCOUNT = 0
            THROW 50136, N'Kayit bulunamadi.', 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Bayatlamis kayitlar (curator-check)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Stale_List
    @Top int = 50
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT TOP (@Top) Katman, KayitId, Ad, Confidence, LastVerifiedAt, EtkinTtlGun, GecenGun
        FROM   sem.vw_Stale
        ORDER BY CASE WHEN LastVerifiedAt IS NULL THEN 1 ELSE 0 END DESC,
                 (ISNULL(GecenGun, 99999) - EtkinTtlGun) DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   Arama — AI/gelistirici icin tek giris noktasi
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Search
    @Arama     nvarchar(200),
    @MinGuven  decimal(3,2) = 0.30,
    @Top       int = 30
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @P nvarchar(210) = '%' + @Arama + '%';

        SELECT TOP (@Top) *
        FROM (
            SELECT 'Entity' AS Katman, EntityId AS KayitId,
                   CAST(ObjectName + ISNULL(' | ' + Grain, '') + ISNULL(' | ' + Note, '') AS nvarchar(2000)) AS Icerik,
                   Confidence, LastVerifiedAt
            FROM   sem.Entities
            WHERE  IsActive = 1 AND Confidence >= @MinGuven AND Status <> 'curuk'
              AND (EntityId LIKE @P OR ObjectName LIKE @P OR KeyColumns LIKE @P OR Note LIKE @P OR Grain LIKE @P)
            UNION ALL
            SELECT 'Bridge', BridgeId,
                   CAST(FromRef + ' -> ' + ToRef + ISNULL(' | ' + Note, '') AS nvarchar(2000)),
                   Confidence, LastVerifiedAt
            FROM   sem.Bridges
            WHERE  IsActive = 1 AND Confidence >= @MinGuven AND Status <> 'curuk'
              AND (BridgeId LIKE @P OR FromRef LIKE @P OR ToRef LIKE @P OR Note LIKE @P)
            UNION ALL
            SELECT 'CodeSet', cs.CodeSetId,
                   CAST(cs.Name + ISNULL(' | ' + cs.Note, '') AS nvarchar(2000)),
                   cs.Confidence, cs.LastVerifiedAt
            FROM   sem.CodeSets cs
            WHERE  cs.IsActive = 1 AND cs.Confidence >= @MinGuven AND cs.Status <> 'curuk'
              AND (cs.CodeSetId LIKE @P OR cs.Name LIKE @P OR cs.Note LIKE @P
                   OR EXISTS (SELECT 1 FROM sem.CodeValues v WHERE v.CodeSetId = cs.CodeSetId AND (v.Label LIKE @P OR v.CodeValue LIKE @P)))
            UNION ALL
            SELECT 'Metric', MetricId,
                   CAST(Name + ISNULL(' | ' + CAST(Formula AS nvarchar(500)), '') + ISNULL(' | TUZAK: ' + Caveat, '') AS nvarchar(2000)),
                   Confidence, LastVerifiedAt
            FROM   sem.Metrics
            WHERE  IsActive = 1 AND Confidence >= @MinGuven AND Status <> 'curuk'
              AND (MetricId LIKE @P OR Name LIKE @P OR Formula LIKE @P OR Caveat LIKE @P)
            UNION ALL
            SELECT 'Query', QueryId,
                   CAST(Question AS nvarchar(2000)),
                   Confidence, LastVerifiedAt
            FROM   sem.Queries
            WHERE  IsActive = 1 AND Confidence >= @MinGuven AND Status <> 'curuk'
              AND (QueryId LIKE @P OR Question LIKE @P OR CAST(VerifiedSql AS nvarchar(max)) LIKE @P)
        ) x
        ORDER BY Confidence DESC, Katman;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   AI context uretimi — skill'lere verilecek semantik paket
   BuildSkillVariables bu SP'yi cagirir; LLM ezbere sema uydurmaz.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE sem.sp_Context_Build
    @Konu     nvarchar(200) = NULL,   -- NULL = tum aktif katman ozeti
    @MinGuven decimal(3,2)  = 0.50,
    @TopHer   int           = 15
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @P nvarchar(210) = '%' + ISNULL(@Konu, '') + '%';

        -- 1) Her zaman gecerli ipuclari
        SELECT Scope, Severity, HintText
        FROM   sem.AiHints
        WHERE  IsActive = 1
        ORDER BY CASE Severity WHEN 'kritik' THEN 0 WHEN 'uyari' THEN 1 ELSE 2 END, Id;

        -- 2) Ilgili entity'ler
        SELECT TOP (@TopHer) EntityId, ObjectType, PkColumns, KeyColumns, Grain, Note, Confidence
        FROM   sem.Entities
        WHERE  IsActive = 1 AND Status <> 'curuk' AND Confidence >= @MinGuven
          AND (@Konu IS NULL OR EntityId LIKE @P OR ObjectName LIKE @P OR KeyColumns LIKE @P OR Note LIKE @P)
        ORDER BY Confidence DESC;

        -- 3) Ilgili koprüler
        SELECT TOP (@TopHer) BridgeId, FromRef, ToRef, JoinExpression, Cardinality, Note, Confidence
        FROM   sem.Bridges
        WHERE  IsActive = 1 AND Status <> 'curuk' AND Confidence >= @MinGuven
          AND (@Konu IS NULL OR BridgeId LIKE @P OR FromRef LIKE @P OR ToRef LIKE @P OR Note LIKE @P)
        ORDER BY Confidence DESC;

        -- 4) Kod kumeleri + degerleri
        SELECT TOP (@TopHer) cs.CodeSetId, cs.Name, cs.LookupTable, cs.JoinExpression, cs.Note,
               STUFF((SELECT ', ' + v.CodeValue + '=' + v.Label
                      FROM sem.CodeValues v
                      WHERE v.CodeSetId = cs.CodeSetId AND v.IsActive = 1
                      ORDER BY v.CodeValue
                      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') AS Degerler,
               cs.Confidence
        FROM   sem.CodeSets cs
        WHERE  cs.IsActive = 1 AND cs.Status <> 'curuk' AND cs.Confidence >= @MinGuven
          AND (@Konu IS NULL OR cs.CodeSetId LIKE @P OR cs.Name LIKE @P OR cs.Note LIKE @P)
        ORDER BY cs.Confidence DESC;

        -- 5) Metrikler (tuzaklariyla birlikte — en kritik kisim)
        SELECT TOP (@TopHer) MetricId, Name, SourceRef, Formula, Caveat, Unit, Confidence
        FROM   sem.Metrics
        WHERE  IsActive = 1 AND Status <> 'curuk' AND Confidence >= @MinGuven
          AND (@Konu IS NULL OR MetricId LIKE @P OR Name LIKE @P OR Formula LIKE @P OR Caveat LIKE @P)
        ORDER BY Confidence DESC;

        -- 6) Golden SQL ornekleri
        SELECT TOP (@TopHer) QueryId, Question, VerifiedSql, ResultNote, LastVerifiedAt, Confidence
        FROM   sem.Queries
        WHERE  IsActive = 1 AND Status <> 'curuk' AND Confidence >= @MinGuven
          AND (@Konu IS NULL OR QueryId LIKE @P OR Question LIKE @P)
        ORDER BY Confidence DESC;

        -- 7) Is sozlugu (ref.SemanticDefinitions ile koprü)
        SELECT TOP (@TopHer) TermType, BusinessName, TechnicalName, Description, Aliases, Category
        FROM   ref.SemanticDefinitions
        WHERE  IsActive = 1
          AND (@Konu IS NULL OR BusinessName LIKE @P OR TechnicalName LIKE @P OR Aliases LIKE @P OR Description LIKE @P)
        ORDER BY Category, BusinessName;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '54_semantic_layer_sps.sql tamamlandi.';
GO
