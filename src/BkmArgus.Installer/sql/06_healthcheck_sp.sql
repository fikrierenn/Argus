/* 06_healthcheck_sp.sql */
USE BKMDenetim;
GO

IF OBJECT_ID(N'log.sp_SaglikKontrol_Calistir', N'P') IS NOT NULL DROP PROCEDURE log.sp_SaglikKontrol_Calistir;
GO
CREATE PROCEDURE log.sp_SaglikKontrol_Calistir
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Bugun date = CONVERT(date,SYSDATETIME());
    DECLARE @Dun date = DATEADD(day,-1,@Bugun);

    DECLARE @t TABLE
    (
        KontrolKodu   varchar(60) NOT NULL,
        Seviye        tinyint NOT NULL,              -- 1=kritik,2=orta,3=bilgi
        Durum         varchar(10) NOT NULL,          -- PASS/WARN/FAIL
        Detay         nvarchar(400) NULL,
        SayisalDeger  decimal(18,3) NULL,
        TarihDeger    datetime2(0) NULL
    );

    /* 1) Risk job son durum */
    INSERT INTO @t
    SELECT
        'RISK_JOB_SON',
        1,
        Durum = CASE WHEN x.Durum='SUCCESS' AND x.BitisZamani >= DATEADD(hour,-24,SYSDATETIME()) THEN 'PASS'
                     WHEN x.Durum='SUCCESS' THEN 'WARN'
                     ELSE 'FAIL' END,
        Detay = CONCAT('Durum=',x.Durum,'; Hata=',COALESCE(x.Hata,'')),
        SayisalDeger = x.SureMs,
        TarihDeger = x.BitisZamani
    FROM (
        SELECT TOP 1 Durum, BitisZamani, SureMs, Hata
        FROM log.RiskCalismaLog
        ORDER BY LogId DESC
    ) x;

    /* 2) Stok job son durum */
    INSERT INTO @t
    SELECT
        'STOK_JOB_SON',
        1,
        Durum = CASE WHEN x.Durum='SUCCESS' AND x.BitisZamani >= DATEADD(hour,-24,SYSDATETIME()) THEN 'PASS'
                     WHEN x.Durum='SUCCESS' THEN 'WARN'
                     ELSE 'FAIL' END,
        Detay = CONCAT('Durum=',x.Durum,'; Pencere=',COALESCE(CONVERT(varchar(10),x.HedefBaslangic,120),''),'..',COALESCE(CONVERT(varchar(10),x.HedefBitis,120),''),' ; Hata=',COALESCE(x.Hata,'')),
        SayisalDeger = x.SureMs,
        TarihDeger = x.BitisZamani
    FROM (
        SELECT TOP 1 Durum, BitisZamani, SureMs, HedefBaslangic, HedefBitis, Hata
        FROM log.StokCalismaLog
        ORDER BY LogId DESC
    ) x;

    /* 3) Bugün risk üretildi mi? */
    INSERT INTO @t
    SELECT
        'RISK_BUGUN_VAR_MI',
        1,
        Durum = CASE WHEN c.cnt>0 THEN 'PASS' ELSE 'FAIL' END,
        Detay = CONCAT('KesimGunu=',CONVERT(varchar(10),@Bugun,120),' ; satir=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (SELECT cnt=COUNT(*) FROM rpt.RiskUrunOzet_Gunluk WHERE KesimGunu=@Bugun AND DonemKodu='Son30Gun') c;

    /* 4) Dün stok bakiyesi var mı? (en azından kayıt tarihi) */
    INSERT INTO @t
    SELECT
        'STOK_DUN_VAR_MI',
        1,
        Durum = CASE WHEN mx.MaxTarih>=@Dun THEN 'PASS' ELSE 'WARN' END,
        Detay = CONCAT('MaxTarih=',COALESCE(CONVERT(varchar(10),mx.MaxTarih,120),'NULL')),
        SayisalDeger = NULL,
        TarihDeger = CAST(mx.MaxTarih AS datetime2(0))
    FROM (SELECT MaxTarih=MAX(Tarih) FROM rpt.StokBakiyeGunluk) mx;

    /* 5) Kaynakta AltDepo!=0 var mı? (son 7 gün) */
    INSERT INTO @t
    SELECT
        'ALTDEPO_SAPMA_7GUN',
        2,
        Durum = CASE WHEN c.cnt=0 THEN 'PASS' ELSE 'WARN' END,
        Detay = CONCAT('AltDepo!=0 satir=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (
        SELECT cnt=COUNT(*)
        FROM src.vw_StokHareket
        WHERE HareketTarihi >= DATEADD(day,-7,CONVERT(date,SYSDATETIME()))
          AND AltDepoId<>0
    ) c;

    /* 6) Tip mapping eksik mi? (son 30 gün) */
    INSERT INTO @t
    SELECT
        'TIP_MAP_EKSIK_30GUN',
        2,
        Durum = CASE WHEN c.cnt=0 THEN 'PASS' ELSE 'WARN' END,
        Detay = CONCAT('Map yok tip adedi=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (
        SELECT cnt=COUNT(DISTINCT h.TipId)
        FROM src.vw_StokHareket h
        LEFT JOIN ref.IrsTipGrupMap m ON m.TipId=h.TipId AND m.AktifMi=1
        WHERE h.HareketTarihi >= DATEADD(day,-30,CONVERT(date,SYSDATETIME()))
          AND m.TipId IS NULL
    ) c;

    /* 7) Unique index ihlali var mı? (teoride yok) */
    INSERT INTO @t
    SELECT
        'RISK_DUP_KESIM',
        1,
        Durum = CASE WHEN c.cnt=0 THEN 'PASS' ELSE 'FAIL' END,
        Detay = CONCAT('dup satir=',c.cnt),
        SayisalDeger = c.cnt,
        TarihDeger = NULL
    FROM (
        SELECT cnt=COUNT(*)
        FROM (
            SELECT KesimGunu, DonemKodu, MekanId, StokId, n=COUNT(*)
            FROM rpt.RiskUrunOzet_Gunluk
            WHERE KesimGunu=@Bugun
            GROUP BY KesimGunu, DonemKodu, MekanId, StokId
            HAVING COUNT(*)>1
        ) d
    ) c;

    SELECT * FROM @t ORDER BY Seviye, CASE Durum WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END, KontrolKodu;
END
GO
