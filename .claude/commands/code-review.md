---
description: "Kod inceleme - BkmArgus standartlarina uyum kontrolu"
---

Verilen dosya veya dizini BkmArgus kodlama standartlarina gore incele:

## KONTROL LISTESI:

### SQL/SP Kontrolleri:
- [ ] Tablo/kolon adlari Ingilizce mi? (Turkce referans var mi?)
- [ ] SP parametre adlari Turkce mi? (proje kurali)
- [ ] datetime2(0) kullanilmis mi? (datetime YASAK)
- [ ] SYSDATETIME() kullanilmis mi? (GETDATE YASAK)
- [ ] SET NOCOUNT ON var mi?
- [ ] TRY-CATCH var mi?
- [ ] String concat ile SQL olusturulmus mu? (YASAK - parametreli SP kullan)
- [ ] src.* view'leri degistirilmis mi? (YASAK)

### C# Kontrolleri:
- [ ] Namespace BkmArgus.* mi?
- [ ] SP-first: Inline SQL yerine SP cagrisi mi?
- [ ] Dapper kullanilmis mi? (EF Core YASAK)
- [ ] IConfiguration/env var ile secret yonetimi?
- [ ] File upload validasyonu var mi? (image only, max 5MB)
- [ ] Async/await dogru kullanilmis mi?

### Genel:
- [ ] CLAUDE.md naming convention'a uygun mu?
- [ ] Gereksiz yorum/debug kodu var mi?
- [ ] Error handling yeterli mi?

Dosya/dizin: $ARGUMENTS
