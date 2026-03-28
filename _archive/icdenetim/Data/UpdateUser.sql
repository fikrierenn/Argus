-- Kullanıcı güncelleme: fikri.eren@bkmkitap.com / 123456
-- BCrypt hash (work factor 11) - "123456" için geçerli
-- Farklı hash için: dotnet run -- hash

USE BKMDenetim;
GO

-- Mevcut admin kullanıcısını güncelle (admin@bkmargus.local varsa)
UPDATE Users 
SET 
    Email = N'fikri.eren@bkmkitap.com',
    PasswordHash = N'$2a$11$Tf8z1cXC5NTiHtfBSCdMGuMvjfW41DG9oYkjzB01w6HZMfJzNDmiK',
    FullName = N'Fikri Eren'
WHERE Email = N'admin@bkmargus.local';

-- Şifre sıfırlama (fikri.eren@bkmkitap.com zaten varsa)
UPDATE Users 
SET PasswordHash = N'$2a$11$Tf8z1cXC5NTiHtfBSCdMGuMvjfW41DG9oYkjzB01w6HZMfJzNDmiK'
WHERE Email = N'fikri.eren@bkmkitap.com';

-- Hiç kullanıcı yoksa yeni ekle
IF NOT EXISTS (SELECT 1 FROM Users)
INSERT INTO Users (Email, PasswordHash, FullName, CreatedAt)
VALUES (
    N'fikri.eren@bkmkitap.com',
    N'$2a$11$Tf8z1cXC5NTiHtfBSCdMGuMvjfW41DG9oYkjzB01w6HZMfJzNDmiK',
    N'Fikri Eren',
    GETDATE()
);
GO
