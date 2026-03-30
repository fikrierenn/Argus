---
description: "C# property rename — model, service, razor hepsini guncelle"
---

Verilen Turkce property adini Ingilizce'ye cevir. TUM dosyalarda guncelle:

## ADIMLAR:
1. Grep ile tum kullanim yerlerini bul (*.cs, *.cshtml)
2. Model dosyasinda property adini degistir
3. Service/Repository dosyalarinda referanslari guncelle
4. Razor view'larda @Model.Property referanslarini guncelle
5. Dapper anonymous object'lerde dikkat: SP parametreleri TURKCE kalir
   - `new { TurkceParam = row.EnglishProperty }` seklinde

## KURALLAR:
- src.vw_* view'lardan gelen property'ler TURKCE KALIR (MekanAd, UrunKod, UrunAd)
- dof.DofKayit tablosundan gelen property'ler TURKCE KALIR
- SP parametreleri (@TurkceParam) DEGISMEZ
- Sadece C# property adi ve Razor referansi degisir

$ARGUMENTS
