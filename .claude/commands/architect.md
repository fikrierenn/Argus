---
description: "Mimari tasarim ve analiz - yeni ozellik veya degisiklik icin"
---

Kullanicinin istedigini mimari perspektiften analiz et:

## ANALIZ ADIMLARI:

1. **Mevcut Durum:** Istenen ozellik/degisiklik icin mevcut kodu/DB'yi tara
   - Hangi schema/tablo etkilenir?
   - Hangi SP'ler degisir?
   - Hangi C# servisleri etkilenir?

2. **Etki Analizi:**
   - Bagimliliklari belirle (FK, SP referanslari, C# kullanimi)
   - Breaking change var mi?
   - Geriye uyumluluk gerekli mi?

3. **Cozum Tasarimi:**
   - DB degisiklikleri (yeni tablo/kolon/SP)
   - C# kod degisiklikleri (yeni servis/model/sayfa)
   - UI degisiklikleri
   - Migration stratejisi

4. **Uygulama Plani:**
   - Adim adim uygulama sirasi
   - Paralel yapilabilecek isler
   - Test stratejisi
   - Rollback plani

5. **CLAUDE.md ve MASTER_PLAN.md guncelleme gerekli mi?**

## KURALLAR:
- SP-first: Veri erisimi SP uzerinden
- Naming convention: CLAUDE.md'deki kurallara uy
- Ingilizce tablo/kolon, Turkce SP parametre
- datetime2(0), SYSDATETIME()
- Mevcut pattern'leri takip et

Istek: $ARGUMENTS
