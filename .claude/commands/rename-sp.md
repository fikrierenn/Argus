---
description: "SP referansini C# kodda Turkce'den Ingilizce'ye guncelle"
---

Verilen eski Turkce SP adini yeni Ingilizce adiyla degistir. TUM C# dosyalarinda guncelle:

## ADIMLAR:
1. Grep ile eski SP adinin tum kullanim yerlerini bul
2. Her dosyada string literal'i yeni SP adiyla degistir
3. Dapper parametreleri DEGISMEZ (Turkce kaliyor)
4. Build dogrulama: degisiklik sonrasi dotnet build

## KURALLAR:
- SP parametreleri (@TurkceParam) DEGISMEZ
- Sadece SP adi string literal'i degisir
- Ayni anda ilgili model property'leri de kontrol et

## ORNEK:
Eski: `"ai.sp_Ai_Istek_Liste"` → Yeni: `"ai.sp_AnalysisQueue_List"`

$ARGUMENTS
