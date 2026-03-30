-- ============================================================================
-- Semantic Definitions - Shared semantic layer foundation
-- Used by: BkmArgus, YonetIQ, AI modules
-- Contains: business terms, risk flags, audit groups, ERP dimensions
-- ============================================================================

-- 1. Create ref schema if not exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')
    EXEC('CREATE SCHEMA ref');
GO

-- 2. Create table
IF OBJECT_ID('ref.SemanticDefinitions', 'U') IS NULL
CREATE TABLE ref.SemanticDefinitions (
    Id int IDENTITY(1,1) PRIMARY KEY,
    TermType varchar(20) NOT NULL,        -- metric, dimension, entity, rule, flag, category, action
    BusinessName nvarchar(200) NOT NULL,   -- Turkish user-friendly name
    TechnicalName varchar(100),            -- DB column/table/SP name
    Description nvarchar(1000),            -- Detailed explanation
    Aliases nvarchar(500),                 -- Comma-separated synonyms/alternatives
    Category varchar(30) NOT NULL,         -- risk, audit, dof, erp, personnel, general
    SqlExpression nvarchar(500),           -- For metrics: SUM(Amount), COUNT(*), etc.
    SampleValues nvarchar(500),            -- Example values for this term
    ParentId int NULL,                     -- Hierarchy (e.g., flag group -> individual flag)
    IsActive bit NOT NULL DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
    UpdatedAt datetime2(0) NULL
);
GO

-- 3. Unique index on (Category, TechnicalName)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_SemanticDefinitions_Category_TechnicalName' AND object_id = OBJECT_ID('ref.SemanticDefinitions'))
CREATE UNIQUE INDEX UX_SemanticDefinitions_Category_TechnicalName
    ON ref.SemanticDefinitions(Category, TechnicalName)
    WHERE TechnicalName IS NOT NULL AND IsActive = 1;
GO

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Helper: Insert only if TechnicalName doesn't exist in category
-- Risk Flags (category='risk', termType='flag')
IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagDataQuality')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Veri Kalitesi Sorunu', 'FlagDataQuality', N'Veri kalitesinde tespit edilen tutarsizlik, eksiklik veya hata durumu', N'veri hatasi, eksik veri, tutarsizlik, data quality', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagSalesWithoutEntry')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Girissiz Satis', 'FlagSalesWithoutEntry', N'Stok girisi olmadan gerceklesen satis hareketi', N'kacak satis, kayitsiz satis, stoksuz satis', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagDeadStock')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Olu Stok', 'FlagDeadStock', N'Belirli sure icerisinde hicbir hareket gormeyen stok kalemi', N'hareket gormeyen, duragan stok, dead stock', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagNetAccumulation')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Net Birikim', 'FlagNetAccumulation', N'Normal seviyenin uzerinde stok birikimi tespit edilen kalem', N'stok birikimi, fazla stok, birikim', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagHighReturn')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Yuksek Iade', 'FlagHighReturn', N'Iade orani normalin uzerinde olan urun veya mekan', N'iade orani yuksek, musteri iade, return', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagHighDamagedReturn')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Bozuk Iade Yuksek', 'FlagHighDamagedReturn', N'Bozuk veya hasarli urun iade orani normalin uzerinde', N'hasarli urun, bozuk iade, damaged return', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagHighCountAdjustment')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Sayim Duzeltme Yuksek', 'FlagHighCountAdjustment', N'Stok sayim farki normalin uzerinde olan kalem veya mekan', N'sayim farki, stok sayim, envanter duzeltme', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagHighInternalUse')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Ic Kullanim Yuksek', 'FlagHighInternalUse', N'Ic kullanim miktari veya orani normalin uzerinde', N'personel kullanimi, dahili tuketim, internal use', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagFastTurnover')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Hizli Devir', 'FlagFastTurnover', N'Stok devir hizi normalin cok uzerinde olan kalem', N'hizli stok devri, yuksek devir, fast turnover', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagSalesAging')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Satis Yaslanmasi', 'FlagSalesAging', N'Son satis tarihi uzerinden uzun sure gecmis urun', N'eski satis, satis gecmisi, aging', 'risk', N'0, 1');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='FlagStockZero')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('flag', N'Sifir Stok', 'FlagStockZero', N'Stok miktari sifir olan aktif urun', N'stok yok, stok tukendi, out of stock', 'risk', N'0, 1');

-- Risk Parameters (category='risk', termType='metric')
IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='KritikSkorEsik')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SqlExpression, SampleValues)
VALUES ('metric', N'Kritik Risk Esigi', 'KritikSkorEsik', N'Bu skorun uzerindeki mekanlar kritik risk grubuna alinir', N'kritik esik, alarm seviyesi, threshold', 'risk', N'RiskScore >= @Threshold', N'70, 80, 90');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='risk' AND TechnicalName='IadeOranEsik')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SqlExpression, SampleValues)
VALUES ('metric', N'Iade Oran Esigi', 'IadeOranEsik', N'Bu oranin uzerindeki iade oranlari alarm uretir', N'iade limiti, return threshold', 'risk', N'ReturnRate >= @Threshold', N'5, 10, 15');

-- Audit Groups (category='audit', termType='category')
IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='audit' AND TechnicalName='KAFE')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('category', N'Kafe Denetim Grubu', 'KAFE', N'Kafe, mutfak ve bar alanlarinin denetim kategorisi', N'kafe, cafe, mutfak, bar', 'audit', N'KAFE');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='audit' AND TechnicalName='KASA')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('category', N'Kasa Denetim Grubu', 'KASA', N'Kasa, odeme ve POS islemlerinin denetim kategorisi', N'kasa, odeme, pos, fis', 'audit', N'KASA');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='audit' AND TechnicalName='DEPO')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('category', N'Depo Denetim Grubu', 'DEPO', N'Depo, raf ve stok alanlarinin denetim kategorisi', N'depo, raf, stok alani', 'audit', N'DEPO');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='audit' AND TechnicalName='GENEL')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('category', N'Genel Denetim', 'GENEL', N'Magaza geneli, temizlik ve diger genel denetim maddeleri', N'genel, magaza geneli, temizlik', 'audit', N'GENEL');

-- Transaction Types (category='erp', termType='dimension')
IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='SATIS')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Satis Hareketi', 'SATIS', N'Musteri satis islem tipi', N'satis, ciro, revenue, sale', 'erp', N'SATIS');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='IADE')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Iade Hareketi', 'IADE', N'Musteri iade islem tipi', N'iade, musteri iade, return', 'erp', N'IADE');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='ALIS')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Alis Hareketi', 'ALIS', N'Satin alma / tedarikci alim islem tipi', N'alis, satin alma, purchase', 'erp', N'ALIS');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='TRANSFER')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Transfer Hareketi', 'TRANSFER', N'Magazalar arasi stok transfer islem tipi', N'transfer, sevk, gonderi', 'erp', N'TRANSFER');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='SAYIM')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Sayim Hareketi', 'SAYIM', N'Stok sayim islem tipi', N'sayim, envanter, count', 'erp', N'SAYIM');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='DUZELTME')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Duzeltme Hareketi', 'DUZELTME', N'Stok duzeltme / ayarlama islem tipi', N'duzeltme, ayarlama, adjustment', 'erp', N'DUZELTME');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='ICKULLANIM')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Ic Kullanim', 'ICKULLANIM', N'Dahili / personel kullanim islem tipi', N'ic kullanim, personel, internal', 'erp', N'ICKULLANIM');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='erp' AND TechnicalName='BOZUK')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SampleValues)
VALUES ('dimension', N'Bozuk/Imha', 'BOZUK', N'Bozuk, hasarli veya imha edilen urun islem tipi', N'bozuk, imha, hasar, damaged', 'erp', N'BOZUK');

-- DOF Actions (category='dof', termType='action')
IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='dof' AND TechnicalName='DOF_OLUSTUR')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category)
VALUES ('action', N'DOF Olustur', 'DOF_OLUSTUR', N'Yeni duzeltici onleyici faaliyet kaydinin olusturulmasi', N'dof ac, bulgu, corrective action', 'dof');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='dof' AND TechnicalName='DOF_KAPAT')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category)
VALUES ('action', N'DOF Kapat', 'DOF_KAPAT', N'Acik DOF kaydinin basariyla tamamlanip kapatilmasi', N'dof sonlandir, tamamla, close', 'dof');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='dof' AND TechnicalName='DOF_REDDET')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category)
VALUES ('action', N'DOF Reddet', 'DOF_REDDET', N'DOF kaydinin reddedilerek iade edilmesi', N'dof reddet, iade et, reject', 'dof');

-- Entities (category='general', termType='entity')
IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='general' AND TechnicalName='MEKAN')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category)
VALUES ('entity', N'Magaza/Mekan', 'MEKAN', N'Fiziksel magaza, sube veya lokasyon', N'magaza, sube, lokasyon, mekan, store, location', 'general');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='general' AND TechnicalName='URUN')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category)
VALUES ('entity', N'Urun/Stok', 'URUN', N'Satis veya stok yonetimindeki urun kalemi', N'urun, stok, stok kalemi, product, item', 'general');

IF NOT EXISTS (SELECT 1 FROM ref.SemanticDefinitions WHERE Category='general' AND TechnicalName='PERSONEL')
INSERT INTO ref.SemanticDefinitions (TermType, BusinessName, TechnicalName, Description, Aliases, Category)
VALUES ('entity', N'Personel', 'PERSONEL', N'Magaza calisani veya sistem kullanicisi', N'calisan, personel, employee, staff', 'general');
GO

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- SP 1: List with filters
IF OBJECT_ID('ref.sp_SemanticDefinition_List', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SemanticDefinition_List;
GO
CREATE PROCEDURE ref.sp_SemanticDefinition_List
    @Category varchar(30) = NULL,
    @TermType varchar(20) = NULL,
    @Search nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, TermType, BusinessName, TechnicalName, Description, Aliases,
           Category, SqlExpression, SampleValues, ParentId, IsActive, CreatedAt, UpdatedAt
    FROM ref.SemanticDefinitions
    WHERE IsActive = 1
      AND (@Category IS NULL OR Category = @Category)
      AND (@TermType IS NULL OR TermType = @TermType)
      AND (@Search IS NULL
           OR BusinessName LIKE '%' + @Search + '%'
           OR Aliases LIKE '%' + @Search + '%'
           OR Description LIKE '%' + @Search + '%')
    ORDER BY Category, TermType, BusinessName;
END
GO

-- SP 2: Get by Id
IF OBJECT_ID('ref.sp_SemanticDefinition_Get', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SemanticDefinition_Get;
GO
CREATE PROCEDURE ref.sp_SemanticDefinition_Get
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, TermType, BusinessName, TechnicalName, Description, Aliases,
           Category, SqlExpression, SampleValues, ParentId, IsActive, CreatedAt, UpdatedAt
    FROM ref.SemanticDefinitions
    WHERE Id = @Id;
END
GO

-- SP 3: Save (Insert or Update via MERGE)
IF OBJECT_ID('ref.sp_SemanticDefinition_Save', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SemanticDefinition_Save;
GO
CREATE PROCEDURE ref.sp_SemanticDefinition_Save
    @Id int = NULL,
    @TermType varchar(20),
    @BusinessName nvarchar(200),
    @TechnicalName varchar(100) = NULL,
    @Description nvarchar(1000) = NULL,
    @Aliases nvarchar(500) = NULL,
    @Category varchar(30),
    @SqlExpression nvarchar(500) = NULL,
    @SampleValues nvarchar(500) = NULL,
    @ParentId int = NULL,
    @IsActive bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Id IS NULL
    BEGIN
        INSERT INTO ref.SemanticDefinitions
            (TermType, BusinessName, TechnicalName, Description, Aliases, Category, SqlExpression, SampleValues, ParentId, IsActive)
        VALUES
            (@TermType, @BusinessName, @TechnicalName, @Description, @Aliases, @Category, @SqlExpression, @SampleValues, @ParentId, @IsActive);

        SELECT SCOPE_IDENTITY() AS Id;
    END
    ELSE
    BEGIN
        UPDATE ref.SemanticDefinitions
        SET TermType = @TermType,
            BusinessName = @BusinessName,
            TechnicalName = @TechnicalName,
            Description = @Description,
            Aliases = @Aliases,
            Category = @Category,
            SqlExpression = @SqlExpression,
            SampleValues = @SampleValues,
            ParentId = @ParentId,
            IsActive = @IsActive,
            UpdatedAt = SYSDATETIME()
        WHERE Id = @Id;

        SELECT @Id AS Id;
    END
END
GO

-- SP 4: Smart Search with match scoring
IF OBJECT_ID('ref.sp_SemanticDefinition_Search', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SemanticDefinition_Search;
GO
CREATE PROCEDURE ref.sp_SemanticDefinition_Search
    @Term nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, TermType, BusinessName, TechnicalName, Description, Aliases,
           Category, SqlExpression, SampleValues, ParentId, IsActive, CreatedAt, UpdatedAt,
           CASE
               WHEN BusinessName = @Term THEN 100
               WHEN TechnicalName = @Term THEN 100
               WHEN Aliases LIKE '%' + @Term + '%' THEN 80
               WHEN BusinessName LIKE '%' + @Term + '%' THEN 70
               WHEN Description LIKE '%' + @Term + '%' THEN 50
               ELSE 0
           END AS MatchScore
    FROM ref.SemanticDefinitions
    WHERE IsActive = 1
      AND (BusinessName = @Term
           OR TechnicalName = @Term
           OR Aliases LIKE '%' + @Term + '%'
           OR BusinessName LIKE '%' + @Term + '%'
           OR Description LIKE '%' + @Term + '%')
    ORDER BY MatchScore DESC, BusinessName;
END
GO

-- SP 5: Soft Delete
IF OBJECT_ID('ref.sp_SemanticDefinition_Delete', 'P') IS NOT NULL DROP PROCEDURE ref.sp_SemanticDefinition_Delete;
GO
CREATE PROCEDURE ref.sp_SemanticDefinition_Delete
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ref.SemanticDefinitions
    SET IsActive = 0, UpdatedAt = SYSDATETIME()
    WHERE Id = @Id;
END
GO

-- ============================================================================
-- Verification
-- ============================================================================
SELECT Category, TermType, COUNT(*) AS Cnt
FROM ref.SemanticDefinitions
WHERE IsActive = 1
GROUP BY Category, TermType
ORDER BY Category, TermType;
