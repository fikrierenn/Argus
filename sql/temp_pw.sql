UPDATE audit.Users SET PasswordHash = '$2a$11$Re3a8.tR.YCEcs7mfIzT0eaM9CgH7PPR5OxxyPv4EaL9QTulUrkym', IsLocked=0, FailedLoginCount=0, MustChangePassword=0 WHERE Username='admin';
SELECT Username, LEFT(PasswordHash,7) AS Pfx, LEN(PasswordHash) AS Len FROM audit.Users WHERE Username='admin';
