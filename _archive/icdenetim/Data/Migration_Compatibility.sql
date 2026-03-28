-- =====================================================================
-- Compatibility Layer: BkmArgus (EN) <-> RiskAnaliz (TR)
-- RiskAnaliz SP'leri bu view'lari kullanabilir
-- BkmArgus kodu dbo.Users'i kullanmaya devam eder
-- =====================================================================

-- Ensure ref schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')
    EXEC('CREATE SCHEMA ref');
GO

-- Ensure dof schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dof')
    EXEC('CREATE SCHEMA dof');
GO

-- =====================================================================
-- ref.vw_Kullanici_Compat -> reads from dbo.Users
-- =====================================================================
IF OBJECT_ID('ref.vw_Kullanici_Compat', 'V') IS NOT NULL
    DROP VIEW ref.vw_Kullanici_Compat;
GO

CREATE VIEW ref.vw_Kullanici_Compat AS
SELECT
    Id AS KullaniciId,
    Email AS KullaniciAdi,
    Id AS PersonelId,
    'ADMIN' AS RolKodu,
    CAST(1 AS BIT) AS AktifMi,
    NULL AS SonGirisTarihi,
    NULL AS OlusturanKullaniciId,
    NULL AS GuncelleyenKullaniciId,
    CreatedAt AS OlusturmaTarihi,
    CreatedAt AS GuncellemeTarihi
FROM dbo.Users;
GO

-- =====================================================================
-- ref.vw_Personel_Compat -> reads from dbo.Users (simplified)
-- =====================================================================
IF OBJECT_ID('ref.vw_Personel_Compat', 'V') IS NOT NULL
    DROP VIEW ref.vw_Personel_Compat;
GO

CREATE VIEW ref.vw_Personel_Compat AS
SELECT
    Id AS PersonelId,
    'P' + RIGHT('000' + CAST(Id AS VARCHAR(10)), 3) AS PersonelKodu,
    FullName AS Ad,
    '' AS Soyad,
    '' AS Unvan,
    '' AS Birim,
    NULL AS UstPersonelId,
    Email AS Eposta,
    NULL AS Telefon,
    CAST(1 AS BIT) AS AktifMi,
    NULL AS OlusturanKullaniciId,
    NULL AS GuncelleyenKullaniciId,
    CreatedAt AS OlusturmaTarihi,
    CreatedAt AS GuncellemeTarihi
FROM dbo.Users;
GO

-- =====================================================================
-- Sync BkmArgus users into ref.Kullanici (if table exists)
-- IDENTITY_INSERT handling for KullaniciId
-- Idempotent: only inserts missing rows
-- =====================================================================
IF OBJECT_ID('ref.Kullanici', 'U') IS NOT NULL
BEGIN
    SET IDENTITY_INSERT ref.Kullanici ON;

    MERGE ref.Kullanici AS target
    USING (
        SELECT Id, Email, CreatedAt FROM dbo.Users
    ) AS source (KullaniciId, KullaniciAdi, OlusturmaTarihi)
    ON target.KullaniciId = source.KullaniciId
    WHEN NOT MATCHED THEN
        INSERT (KullaniciId, KullaniciAdi, RolKodu, AktifMi, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (source.KullaniciId, source.KullaniciAdi, 'ADMIN', 1, source.OlusturmaTarihi, source.OlusturmaTarihi)
    WHEN MATCHED THEN
        UPDATE SET KullaniciAdi = source.KullaniciAdi, GuncellemeTarihi = source.OlusturmaTarihi;

    SET IDENTITY_INSERT ref.Kullanici OFF;
END
GO

-- =====================================================================
-- Sync BkmArgus users into ref.Personel (if table exists)
-- IDENTITY_INSERT handling for PersonelId
-- =====================================================================
IF OBJECT_ID('ref.Personel', 'U') IS NOT NULL
BEGIN
    SET IDENTITY_INSERT ref.Personel ON;

    MERGE ref.Personel AS target
    USING (
        SELECT Id, FullName, Email, CreatedAt FROM dbo.Users
    ) AS source (PersonelId, Ad, Eposta, OlusturmaTarihi)
    ON target.PersonelId = source.PersonelId
    WHEN NOT MATCHED THEN
        INSERT (PersonelId, PersonelKodu, Ad, Soyad, Eposta, AktifMi, OlusturmaTarihi, GuncellemeTarihi)
        VALUES (source.PersonelId, 'P' + RIGHT('000' + CAST(source.PersonelId AS VARCHAR(10)), 3), source.Ad, '', source.Eposta, 1, source.OlusturmaTarihi, source.OlusturmaTarihi)
    WHEN MATCHED THEN
        UPDATE SET Ad = source.Ad, Eposta = source.Eposta, GuncellemeTarihi = source.OlusturmaTarihi;

    SET IDENTITY_INSERT ref.Personel OFF;
END
GO

-- =====================================================================
-- dof.vw_DofKayit_Compat -> reads from dbo.CorrectiveActions
-- RiskAnaliz DOF SP'leri bu view ile BkmArgus verilerini gorebilir
-- =====================================================================
IF OBJECT_ID('dbo.CorrectiveActions', 'U') IS NOT NULL
BEGIN
    IF OBJECT_ID('dof.vw_DofKayit_Compat', 'V') IS NOT NULL
        EXEC('DROP VIEW dof.vw_DofKayit_Compat');

    EXEC('
    CREATE VIEW dof.vw_DofKayit_Compat AS
    SELECT
        CAST(Id AS BIGINT) AS DofId,
        ''CA-'' + CAST(Id AS VARCHAR(10)) AS DofImza,
        ''ICDENETIM'' AS KaynakSistemKodu,
        ''AUDIT'' AS KaynakNesneKodu,
        CAST(AuditId AS VARCHAR(20)) AS KaynakAnahtar,
        Title AS Baslik,
        Description AS Aciklama,
        CASE Priority
            WHEN ''Critical'' THEN 4
            WHEN ''High'' THEN 3
            WHEN ''Medium'' THEN 2
            ELSE 1
        END AS RiskSeviyesi,
        DueDate AS SLA_HedefTarih,
        CASE Status
            WHEN ''Open'' THEN ''ACIK''
            WHEN ''InProgress'' THEN ''DEVAM''
            WHEN ''Closed'' THEN ''KAPALI''
            WHEN ''Rejected'' THEN ''REDDEDILDI''
            ELSE Status
        END AS Durum,
        NULL AS Olusturan,
        Department AS Sorumlu,
        NULL AS Onayci,
        NULL AS OlusturanKullaniciId,
        AssignedToUserId AS SorumluPersonelId,
        ClosedBy AS OnayciPersonelId,
        CreatedAt AS OlusturmaTarihi,
        CreatedAt AS GuncellemeTarihi
    FROM dbo.CorrectiveActions
    ');
END
GO

-- =====================================================================
-- AI compatibility note:
-- dbo.AiAnalyses = BkmArgus insight store
-- ai.AiAnalizIstegi = RiskAnaliz request queue (if exists)
-- These serve different purposes and BOTH stay as-is.
-- No merge needed - they complement each other.
-- =====================================================================
