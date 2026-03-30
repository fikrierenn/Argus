-- ============================================================================
-- FAZ 2 Column Rename - FK/PK ID columns (Turkish → English)
-- ============================================================================

PRINT '=== FK/PK Column Rename Start ===';

-- ref.TransactionTypeMap: TipId → TypeId
IF COL_LENGTH('ref.TransactionTypeMap', 'TipId') IS NOT NULL
    EXEC sp_rename 'ref.TransactionTypeMap.TipId', 'TypeId', 'COLUMN';
GO

-- ref.Personnel: PersonelId → PersonnelId
IF COL_LENGTH('ref.Personnel', 'PersonelId') IS NOT NULL
    EXEC sp_rename 'ref.Personnel.PersonelId', 'PersonnelId', 'COLUMN';
GO

-- ref.Users: KullaniciId → UserId
IF COL_LENGTH('ref.Users', 'KullaniciId') IS NOT NULL
    EXEC sp_rename 'ref.Users.KullaniciId', 'UserId', 'COLUMN';
GO

-- ref.Users: PersonelId → PersonnelId
IF COL_LENGTH('ref.Users', 'PersonelId') IS NOT NULL
    EXEC sp_rename 'ref.Users.PersonelId', 'PersonnelId', 'COLUMN';
GO

-- ref.UserPersonnelMap: BaglantiId → LinkId
IF COL_LENGTH('ref.UserPersonnelMap', 'BaglantiId') IS NOT NULL
    EXEC sp_rename 'ref.UserPersonnelMap.BaglantiId', 'LinkId', 'COLUMN';
GO

-- ref.UserPersonnelMap: KullaniciId → UserId
IF COL_LENGTH('ref.UserPersonnelMap', 'KullaniciId') IS NOT NULL
    EXEC sp_rename 'ref.UserPersonnelMap.KullaniciId', 'UserId', 'COLUMN';
GO

-- ref.UserPersonnelMap: PersonelId → PersonnelId
IF COL_LENGTH('ref.UserPersonnelMap', 'PersonelId') IS NOT NULL
    EXEC sp_rename 'ref.UserPersonnelMap.PersonelId', 'PersonnelId', 'COLUMN';
GO

PRINT '=== FK/PK Column Rename Complete ===';
GO
