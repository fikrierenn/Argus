/* 00_create_db.sql
   BKMDenetim veritabanını oluşturur (aynı SQL Server instance üzerinde).
*/
IF DB_ID(N'BKMDenetim') IS NULL
BEGIN
    CREATE DATABASE BKMDenetim;
END
GO
