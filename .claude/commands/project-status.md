---
description: "Proje durumunu kontrol et - build, DB, migration status, git"
---

BkmArgus projesinin tam durumunu kontrol et:

1. **Git durumu:**
   cd D:/Dev/BkmArgus && git log --oneline -5 && git status --short

2. **Build durumu:**
   cd D:/Dev/BkmArgus && dotnet build BkmArgus.sln 2>&1 | tail -5

3. **DB baglanti:**
   SQLCLI_CONN="Server=192.168.40.201;Database=BKMDenetim;User Id=sa;Password=H33451959*;TrustServerCertificate=True;" dotnet run --project D:/Dev/sqlcli -- baglanti

4. **Tablo sayisi (schema bazli):**
   SELECT s.name AS Sch, COUNT(*) AS Tablo FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id WHERE s.name NOT IN ('sys') GROUP BY s.name ORDER BY s.name

5. **SP sayisi (schema bazli):**
   SELECT s.name AS Sch, COUNT(*) AS SP FROM sys.procedures p JOIN sys.schemas s ON p.schema_id=s.schema_id GROUP BY s.name ORDER BY s.name

6. **Migration durumu:**
   docs/MASTER_PLAN.md'yi oku ve hangi FAZ'da oldugunu belirt.

7. **Memory durumu:**
   Memory dosyasini oku: C:\Users\fikri.eren\.claude\projects\D--Dev-icdenetim\memory\project_current_state.md

Sonuclari ozet tablo olarak sun.
