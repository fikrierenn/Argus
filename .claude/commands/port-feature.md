---
description: "IcDenetim arsivinden BkmArgus.Web'e ozellik port et"
---

_archive/icdenetim/ dizininden belirtilen ozelligi BkmArgus.Web/Features/ altina port et.

## PORT ADIMLARI:

1. **Kaynak kodu oku:** _archive/icdenetim/ altindaki ilgili dosyalari bul
   - Pages/*.cshtml + .cshtml.cs
   - Services/*.cs (ilgili servisler)
   - Models/*.cs (ilgili modeller)

2. **Hedef belirle:** BkmArgus.Web/Features/<ModulAdi>/
   - Feature-based klasor yapisi (RiskAnaliz pattern)

3. **Donustur:**
   - Namespace: BkmArgus -> BkmArgus.Web
   - Veri erisimi: Dapper inline SQL -> SP cagrisi (audit.sp_* kullan)
   - SqlDb.cs pattern'ini kullan (BkmArgus.Web/Data/SqlDb.cs)
   - UI: Mevcut BkmArgus.Web Tailwind/CSS pattern'ini takip et
   - Auth: Sayfaya [Authorize] ekle (RBAC hazir olunca)

4. **SP eslesmesi:**
   | Eski (inline SQL) | Yeni (SP) |
   |---|---|
   | SELECT * FROM Audits | audit.sp_Audit_List |
   | INSERT INTO Audits | audit.sp_Audit_Insert |
   | vb. | vb. |

5. **Build ve test:** dotnet build && calistir

Port edilecek ozellik: $ARGUMENTS
