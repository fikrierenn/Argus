---
description: "SQL migration dosyasini DB'ye uygula"
---

Verilen SQL dosyasini BKMDenetim veritabanina uygula.

Kullanim: /db-migrate <dosya_adi_veya_yol>

1. Dosya yolu belirtilmemisse sql/ klasorundeki dosyalari listele
2. sqlcli ile calistir:
   SQLCLI_CONN="Server=192.168.40.201;Database=BKMDenetim;User Id=sa;Password=H33451959*;TrustServerCertificate=True;" dotnet run --project D:/Dev/sqlcli -- script <dosya_yolu> --tolerant
3. Sonucu raporla: kac batch basarili, kac hata
4. Hata varsa hata detaylarini goster ve cozum oner

$ARGUMENTS
