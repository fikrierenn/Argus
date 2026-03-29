---
description: "Stored procedure icerigini oku ve analiz et"
---

Verilen SP'nin tanimini oku, analiz et ve Ingilizce tablo/kolon standartlarina uyumunu kontrol et.

1. SP tanimini oku:
   SELECT OBJECT_DEFINITION(OBJECT_ID('$ARGUMENTS'))

2. Kontrol et:
   - Turkce tablo adi var mi? (AyarMekanKapsam, RiskParam, DofKayit, AiAnalizIstegi, RiskUrunOzet_Gunluk, vb.)
   - Turkce kolon adi var mi? (MekanId, AktifMi, OlusturmaTarihi, KesimTarihi, vb.)
   - src.* view'leri haric - bunlar Turkce kalabilir
   - SP parametre adlari Turkce olabilir (proje kurali)
   - datetime2(0) kullanilmis mi yoksa datetime mi?
   - TRY-CATCH var mi?
   - SET NOCOUNT ON var mi?

3. Sorun bulursan duzeltme onerisi sun.

$ARGUMENTS
