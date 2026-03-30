---
description: "dotnet build calistir, hatalari analiz et ve duzelt"
---

BkmArgus projesini build et ve sonuclari raporla:

## ADIMLAR:
1. `dotnet build D:/Dev/BkmArgus/BkmArgus.sln` calistir
2. Hata varsa:
   - Her hatayi listele (dosya:satir — hata mesaji)
   - Property rename hatalariysa: eski/yeni mapping'e gore duzelt
   - Missing reference hatalariysa: eksik using ekle
   - SP string hatalariysa: yeni SP adiyla guncelle
3. Tekrar build et
4. 0 hata olana kadar tekrarla
5. Warning'leri de raporla (ama fix zorunlu degil)

$ARGUMENTS
