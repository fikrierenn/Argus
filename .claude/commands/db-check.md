---
description: "Database sagligi kontrol et - tablolar, SP'ler, veri durumu"
---

BKMDenetim veritabaninin sagligini kontrol et.

1. sqlcli ile baglanti test et:
   SQLCLI_CONN="Server=192.168.40.201;Database=BKMDenetim;User Id=sa;Password=H33451959*;TrustServerCertificate=True;" dotnet run --project D:/Dev/sqlcli -- baglanti

2. Tum tablolari listele (schema bazli):
   SELECT s.name + '.' + t.name AS Tablo FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id ORDER BY s.name, t.name

3. Tum SP'leri listele:
   SELECT s.name + '.' + p.name AS SP FROM sys.procedures p JOIN sys.schemas s ON p.schema_id=s.schema_id ORDER BY s.name, p.name

4. Satir sayilarini kontrol et:
   Ozellikle audit.Audits, audit.AuditResults, dof.Findings, ai.AnalysisQueue

5. Saglik kontrolu calistir:
   EXEC log.sp_HealthCheck_Run (veya eski adi log.sp_SaglikKontrol_Calistir)

Sonuclari ozet tablo olarak goster. Sorun varsa belirt.
