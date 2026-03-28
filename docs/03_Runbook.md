# Runbook (V1)

## Gece Job’ları
### 1) Risk ETL
- Job: `BKMDenetim_Risk_ETL`
- Saat: 03:30
- Komut:
  - `EXEC log.sp_RiskUrunOzet_Calistir @MekanCSV=NULL, @ToplamYaz=0;`

### 2) Stok Bakiye ETL
- Job: `BKMDenetim_Stok_ETL`
- Saat: 04:00
- Komut:
  - `EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=120, @MekanCSV=NULL;`

### 3) Aylık Kapanış
- Job: `BKMDenetim_AylikKapanis`
- Saat: Ayın 1’i 05:00 (veya senin kapanış takvimin)
- Komut:
  - `EXEC log.sp_AylikKapanis_Calistir @DonemAy=NULL;`  -- NULL ise “geçen ay”

## Sabah Sağlık Kontrolü
Tek sorgu:
- `EXEC log.sp_SaglikKontrol_Calistir;`

Çıktı kolonları:
- KontrolKodu, Seviye, Durum(PASS/WARN/FAIL), Detay, SayisalDeger, TarihDeger

## Operasyon Notları
- “Geç kalmış evrak düzeltmesi” normaldir; 120 gün pencere bu yüzden var.
- Eğer 120 gün yetmezse pencere parametreli. “Son 2 ay düzeltiliyor” diyorsan 120 iyidir; “geçen yıl düzeltiliyor” diyorsan 365’e çekersin.
- DÖF kayıtları **silinmez**. Risk snapshot sil-yaz olabilir; DÖF kanıt tablosu ayrı olduğu için bulgu kaybolmaz.

## AI Worker
- Calistirma: dotnet run --project src/BkmDenetim.AiWorker
- Env: BKM_DENETIM_CONN (varsa)
- Ollama: http://localhost:11434
- Embedding: ollama pull mxbai-embed-large
- LLM: ollama run llama3 (low RAM icin: ollama run phi3.5)
- Kuyruk olusturma: EXEC ai.sp_Ai_Istek_Olustur @Top=200, @KesimGunu=NULL, @MinSkor=80;
