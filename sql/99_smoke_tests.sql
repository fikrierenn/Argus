/* 99_smoke_tests.sql
   Kurulum sonrası hızlı test
*/
USE BKMDenetim;
GO

-- 1) kaynak view erişimi
SELECT TOP 5 * FROM src.vw_StokHareket ORDER BY HareketTarihi DESC;

-- 2) mapping eksik tip listesi
SELECT TOP 50 TipId, Cnt=COUNT(*)
FROM src.vw_StokHareket h
LEFT JOIN ref.IrsTipGrupMap m ON m.TipId=h.TipId AND m.AktifMi=1
WHERE h.HareketTarihi >= DATEADD(day,-30,CONVERT(date,SYSDATETIME()))
  AND m.TipId IS NULL
GROUP BY TipId
ORDER BY Cnt DESC;

-- 3) stok ETL (kısa pencere)
EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=30;

-- 4) risk ETL
EXEC log.sp_RiskUrunOzet_Calistir;

-- 5) sağlık kontrol
EXEC log.sp_SaglikKontrol_Calistir;

-- 6) örnek risk raporu
SELECT TOP 50 *
FROM rpt.vw_RiskUrunOzet_Stok
WHERE KesimGunu = CONVERT(date,SYSDATETIME())
  AND DonemKodu='Son30Gun'
ORDER BY RiskSkor DESC, BrutTutar DESC;
