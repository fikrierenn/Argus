# BKMDenetim Paket (V1) – Kurulum

## Kurulum sırası
1. `sql/00_create_db.sql`
2. `sql/01_schemas.sql`
3. `sql/02_tables.sql`
4. `sql/03_views_src.sql`  (DerinSIS DB adı farklıysa burada düzelt)
5. `sql/07_seed.sql`       (mekan listesi + tip mapping + eşikler)
6. `sql/04_sps_etl.sql`
7. `sql/05_views_reports.sql`
8. `sql/06_healthcheck_sp.sql`
9. `sql/99_smoke_tests.sql`

## Job komutları
- Risk: `EXEC log.sp_RiskUrunOzet_Calistir;`
- Stok: `EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=120;`
- Sağlık: `EXEC log.sp_SaglikKontrol_Calistir;`
- Aylık: `EXEC log.sp_AylikKapanis_Calistir;`

## Notlar
- Tip mapping eksikse sağlık kontrol WARN verir; `ref.IrsTipGrupMap` tamamlanmalı.
- Mekan kapsamı: `ref.AyarMekanKapsam` tablosu.

Tarih: 2025-12-28
