/* =====================================================================
   53_semantic_layer.sql — Semantik Katman (sem semasi)
   Tarih   : 2026-08-20
   Amac    : pusula sema YAML dosyalarini semantik katmanini DB'ye tasir.
             Entity / Bridge / Code / Metric / Query sozlugu + surekli-ogrenme
             disiplini (confidence + evidence + last_verified + ttl -> decay).
             AI skill context'i buradan beslenir (ezbere SQL yazilmaz).
   Bagimli : 47_semantic_definitions.sql (ref.SemanticDefinitions is sozlugu — AYRI, tamamlayici)
   Geri al : DROP SCHEMA sem CASCADE esdegeri — once yedek al.

   Katman ayrimi:
     ref.SemanticDefinitions -> IS sozlugu (Turkce is terimi <-> teknik ad)
     sem.*                   -> SEMA sozlugu (tablo/join/kod/metrik/golden SQL)
   ===================================================================== */

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'sem')
    EXEC('CREATE SCHEMA sem');
GO

/* =====================================================================
   1. sem.Databases — hangi DB ne ise yarar, tuzaklari ne
   ===================================================================== */
IF OBJECT_ID('sem.Databases', 'U') IS NULL
BEGIN
    CREATE TABLE sem.Databases
    (
        DbName          varchar(100)   NOT NULL,
        Role            nvarchar(300)  NOT NULL,
        DateFormat      nvarchar(100)  NULL,   -- 'DMY dd.MM.yyyy (104)' / 'ISO YYYYMMDD'
        CompatLevel     int            NULL,
        Unavailable     nvarchar(500)  NULL,   -- compat nedeniyle kullanilamayan fonksiyonlar
        Note            nvarchar(1000) NULL,
        Confidence      decimal(3,2)   NOT NULL CONSTRAINT DF_SemDb_Conf     DEFAULT(0.80),
        Evidence        nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_SemDb_Status   DEFAULT('aktif'),
        LastVerifiedAt  date           NULL,
        TtlDays         int            NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemDb_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemDb_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemDatabases PRIMARY KEY CLUSTERED (DbName),
        CONSTRAINT CK_SemDb_Conf   CHECK (Confidence BETWEEN 0.00 AND 1.00),
        CONSTRAINT CK_SemDb_Status CHECK (Status IN ('aktif','teyit bekliyor','curuk'))
    );
END
GO

/* =====================================================================
   2. sem.Entities — tablo/view sozlugu
   ===================================================================== */
IF OBJECT_ID('sem.Entities', 'U') IS NULL
BEGIN
    CREATE TABLE sem.Entities
    (
        EntityId        varchar(120)   NOT NULL,   -- 'src.vw_StokHareket' / 'DerinSISBkm.dbo.irsHrk'
        DbName          varchar(100)   NULL,
        SchemaName      varchar(50)    NULL,
        ObjectName      varchar(120)   NOT NULL,
        ObjectType      varchar(20)    NOT NULL CONSTRAINT DF_SemEnt_Type DEFAULT('TABLE'),
        PkColumns       varchar(300)   NULL,
        KeyColumns      varchar(1000)  NULL,       -- sik kullanilan kolonlar
        Grain           nvarchar(300)  NULL,       -- 'bir satir = mekan+urun+gun+periyot'
        Note            nvarchar(2000) NULL,       -- tuzaklar, adlandirma sapmalari
        Confidence      decimal(3,2)   NOT NULL CONSTRAINT DF_SemEnt_Conf     DEFAULT(0.80),
        Evidence        nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_SemEnt_Status   DEFAULT('aktif'),
        LastVerifiedAt  date           NULL,
        TtlDays         int            NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemEnt_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemEnt_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemEntities PRIMARY KEY CLUSTERED (EntityId),
        CONSTRAINT CK_SemEnt_Conf   CHECK (Confidence BETWEEN 0.00 AND 1.00),
        CONSTRAINT CK_SemEnt_Status CHECK (Status IN ('aktif','teyit bekliyor','curuk')),
        CONSTRAINT CK_SemEnt_Type   CHECK (ObjectType IN ('TABLE','VIEW','SP','FUNCTION'))
    );
END
GO

/* =====================================================================
   3. sem.Bridges — join/koprü tanimlari (en kritik katman)
   ===================================================================== */
IF OBJECT_ID('sem.Bridges', 'U') IS NULL
BEGIN
    CREATE TABLE sem.Bridges
    (
        BridgeId        varchar(120)   NOT NULL,   -- 'risk-mekan', 'dof-audit'
        FromRef         varchar(300)   NOT NULL,   -- 'rpt.DailyProductRisk.LocationId'
        ToRef           varchar(300)   NOT NULL,   -- 'ref.LocationSettings.LocationId'
        JoinExpression  nvarchar(1000) NULL,       -- tam JOIN ifadesi (collate, nolock dahil)
        Scope           varchar(50)    NULL,       -- 'bkmdenetim' / 'crossdb' / 'derinsis'
        Cardinality     varchar(20)    NULL,       -- '1-1','1-N','N-N'
        Note            nvarchar(2000) NULL,
        Confidence      decimal(3,2)   NOT NULL CONSTRAINT DF_SemBr_Conf     DEFAULT(0.80),
        Evidence        nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_SemBr_Status   DEFAULT('aktif'),
        LastVerifiedAt  date           NULL,
        TtlDays         int            NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemBr_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemBr_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemBridges PRIMARY KEY CLUSTERED (BridgeId),
        CONSTRAINT CK_SemBr_Conf   CHECK (Confidence BETWEEN 0.00 AND 1.00),
        CONSTRAINT CK_SemBr_Status CHECK (Status IN ('aktif','teyit bekliyor','curuk'))
    );
END
GO

/* =====================================================================
   4. sem.CodeSets / sem.CodeValues — enum/lookup sozlugu
   ===================================================================== */
IF OBJECT_ID('sem.CodeSets', 'U') IS NULL
BEGIN
    CREATE TABLE sem.CodeSets
    (
        CodeSetId       varchar(120)   NOT NULL,   -- 'src.vw_StokHareket.ehTip'
        Name            nvarchar(200)  NOT NULL,
        LookupTable     varchar(200)   NULL,       -- kanonik lookup varsa (hardcode etme)
        JoinExpression  nvarchar(500)  NULL,
        Note            nvarchar(1000) NULL,
        Confidence      decimal(3,2)   NOT NULL CONSTRAINT DF_SemCs_Conf     DEFAULT(0.80),
        Evidence        nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_SemCs_Status   DEFAULT('aktif'),
        LastVerifiedAt  date           NULL,
        TtlDays         int            NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemCs_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemCs_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemCodeSets PRIMARY KEY CLUSTERED (CodeSetId),
        CONSTRAINT CK_SemCs_Conf   CHECK (Confidence BETWEEN 0.00 AND 1.00),
        CONSTRAINT CK_SemCs_Status CHECK (Status IN ('aktif','teyit bekliyor','curuk'))
    );
END
GO

IF OBJECT_ID('sem.CodeValues', 'U') IS NULL
BEGIN
    CREATE TABLE sem.CodeValues
    (
        Id              int            IDENTITY(1,1) NOT NULL,
        CodeSetId       varchar(120)   NOT NULL,
        CodeValue       varchar(50)    NOT NULL,
        Label           nvarchar(200)  NOT NULL,
        Note            nvarchar(500)  NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemCv_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemCv_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemCodeValues PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_SemCodeValues UNIQUE (CodeSetId, CodeValue),
        CONSTRAINT FK_SemCodeValues_Set FOREIGN KEY (CodeSetId) REFERENCES sem.CodeSets(CodeSetId)
    );
END
GO

/* =====================================================================
   5. sem.Metrics — turetilmis is mantigi / formul
   ===================================================================== */
IF OBJECT_ID('sem.Metrics', 'U') IS NULL
BEGIN
    CREATE TABLE sem.Metrics
    (
        MetricId        varchar(120)   NOT NULL,   -- 'risk_skoru', 'net_hareket'
        Name            nvarchar(200)  NOT NULL,
        SourceRef       nvarchar(1000) NULL,       -- hangi tablo/SP/koprü
        Formula         nvarchar(max)  NULL,       -- hesap tanimi (SQL veya acik tarif)
        Caveat          nvarchar(2000) NULL,       -- tuzak: neyi ICERMEZ, ne zaman yaniltir
        Unit            varchar(50)    NULL,
        Confidence      decimal(3,2)   NOT NULL CONSTRAINT DF_SemMt_Conf     DEFAULT(0.80),
        Evidence        nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_SemMt_Status   DEFAULT('aktif'),
        LastVerifiedAt  date           NULL,
        TtlDays         int            NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemMt_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemMt_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemMetrics PRIMARY KEY CLUSTERED (MetricId),
        CONSTRAINT CK_SemMt_Conf   CHECK (Confidence BETWEEN 0.00 AND 1.00),
        CONSTRAINT CK_SemMt_Status CHECK (Status IN ('aktif','teyit bekliyor','curuk'))
    );
END
GO

/* =====================================================================
   6. sem.Queries — dogrulanmis sorgu katalogu (golden SQL)
   ===================================================================== */
IF OBJECT_ID('sem.Queries', 'U') IS NULL
BEGIN
    CREATE TABLE sem.Queries
    (
        QueryId         varchar(120)   NOT NULL,
        Question        nvarchar(500)  NOT NULL,   -- dogal dil soru
        VerifiedSql     nvarchar(max)  NOT NULL,   -- canli dogrulanmis SQL
        RelatedMetrics  varchar(500)   NULL,
        RelatedBridges  varchar(500)   NULL,
        ResultNote      nvarchar(1000) NULL,       -- son calistirmada ne dondu
        Confidence      decimal(3,2)   NOT NULL CONSTRAINT DF_SemQr_Conf     DEFAULT(0.80),
        Evidence        nvarchar(max)  NULL,
        Status          varchar(20)    NOT NULL CONSTRAINT DF_SemQr_Status   DEFAULT('aktif'),
        LastVerifiedAt  date           NULL,
        TtlDays         int            NULL,
        IsActive        bit            NOT NULL CONSTRAINT DF_SemQr_IsActive DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemQr_Created  DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemQueries PRIMARY KEY CLUSTERED (QueryId),
        CONSTRAINT CK_SemQr_Conf   CHECK (Confidence BETWEEN 0.00 AND 1.00),
        CONSTRAINT CK_SemQr_Status CHECK (Status IN ('aktif','teyit bekliyor','curuk'))
    );
END
GO

/* =====================================================================
   7. sem.AiHints — her sorgu uretiminde gecerli kalici ipuclari
   ===================================================================== */
IF OBJECT_ID('sem.AiHints', 'U') IS NULL
BEGIN
    CREATE TABLE sem.AiHints
    (
        Id              int            IDENTITY(1,1) NOT NULL,
        Scope           varchar(50)    NOT NULL CONSTRAINT DF_SemHint_Scope DEFAULT('global'),
        HintText        nvarchar(1000) NOT NULL,
        Severity        varchar(20)    NOT NULL CONSTRAINT DF_SemHint_Sev   DEFAULT('uyari'),
        IsActive        bit            NOT NULL CONSTRAINT DF_SemHint_Act   DEFAULT(1),
        CreatedAt       datetime2(0)   NOT NULL CONSTRAINT DF_SemHint_Cre   DEFAULT(SYSDATETIME()),
        UpdatedAt       datetime2(0)   NULL,
        CreatedByUserId int NULL,
        UpdatedByUserId int NULL,
        CONSTRAINT PK_SemAiHints PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT CK_SemHint_Sev CHECK (Severity IN ('bilgi','uyari','kritik'))
    );
END
GO

/* =====================================================================
   8. Decay view — bayatlamis kayitlar
   Confidence 1.00 MUAF (kalici PK/FK gercegi).
   Ttl yoksa confidence'tan turetilir: 0.90+ ->180g, 0.50+ ->90g, digeri ->30g.
   ===================================================================== */
CREATE OR ALTER VIEW sem.vw_Stale
AS
    SELECT Katman, KayitId, Ad, Confidence, LastVerifiedAt, EtkinTtlGun,
           DATEDIFF(day, LastVerifiedAt, CAST(SYSDATETIME() AS date)) AS GecenGun
    FROM (
        SELECT 'Entity' AS Katman, EntityId AS KayitId, CAST(ObjectName AS nvarchar(300)) AS Ad,
               Confidence, LastVerifiedAt,
               COALESCE(TtlDays, CASE WHEN Confidence >= 0.90 THEN 180 WHEN Confidence >= 0.50 THEN 90 ELSE 30 END) AS EtkinTtlGun
        FROM sem.Entities WHERE IsActive = 1 AND Confidence < 1.00
        UNION ALL
        SELECT 'Bridge', BridgeId, CAST(FromRef + ' -> ' + ToRef AS nvarchar(300)),
               Confidence, LastVerifiedAt,
               COALESCE(TtlDays, CASE WHEN Confidence >= 0.90 THEN 180 WHEN Confidence >= 0.50 THEN 90 ELSE 30 END)
        FROM sem.Bridges WHERE IsActive = 1 AND Confidence < 1.00
        UNION ALL
        SELECT 'CodeSet', CodeSetId, CAST(Name AS nvarchar(300)),
               Confidence, LastVerifiedAt,
               COALESCE(TtlDays, CASE WHEN Confidence >= 0.90 THEN 180 WHEN Confidence >= 0.50 THEN 90 ELSE 30 END)
        FROM sem.CodeSets WHERE IsActive = 1 AND Confidence < 1.00
        UNION ALL
        SELECT 'Metric', MetricId, CAST(Name AS nvarchar(300)),
               Confidence, LastVerifiedAt,
               COALESCE(TtlDays, CASE WHEN Confidence >= 0.90 THEN 180 WHEN Confidence >= 0.50 THEN 90 ELSE 30 END)
        FROM sem.Metrics WHERE IsActive = 1 AND Confidence < 1.00
        UNION ALL
        SELECT 'Query', QueryId, CAST(Question AS nvarchar(300)),
               Confidence, LastVerifiedAt,
               COALESCE(TtlDays, CASE WHEN Confidence >= 0.90 THEN 180 WHEN Confidence >= 0.50 THEN 90 ELSE 30 END)
        FROM sem.Queries WHERE IsActive = 1 AND Confidence < 1.00
    ) x
    WHERE LastVerifiedAt IS NULL
       OR DATEDIFF(day, LastVerifiedAt, CAST(SYSDATETIME() AS date)) > EtkinTtlGun;
GO

PRINT '53_semantic_layer.sql — tablolar ve view tamamlandi.';
GO
