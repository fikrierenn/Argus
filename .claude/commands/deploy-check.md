---
description: "Deployment oncesi kontrol listesi"
---

Deployment oncesi tum kontrolleri yap:

## 1. BUILD
```bash
cd D:/Dev/BkmArgus && dotnet build BkmArgus.sln
```
0 hata olmali.

## 2. DB MIGRATION
- Yeni SQL dosyalari var mi? (sql/ klasorunde)
- Uygulanmamis migration var mi?
- Schema dogrulama scripti calistir (MASTER_PLAN.md'deki)

## 3. GIT
```bash
git status
git log --oneline -5
```
- Commit edilmemis degisiklik var mi?
- Son commit aciklamasi yeterli mi?

## 4. KONFIGÜRASYON
- .env dosyasi mevcut mu?
- Connection string dogru mu?
- Claude API key set mi?
- BKM_DENETIM_CONN env var set mi?

## 5. SP UYUMU
- C# kodundaki SP adlari DB'deki SP adlariyla eslesyor mu?
- Turkce SP adi referansi kalmis mi?

## 6. GUVENLIK
- .env git'e eklenmemis mi? (.gitignore kontrol)
- Hardcoded secret var mi? (grep -r "Password\|ApiKey\|Secret" src/ --include="*.cs")
- SQL injection riski var mi?

Sonuclari tablo olarak raporla. FAIL olan varsa belirt.
