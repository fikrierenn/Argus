# BKMDenetim – Risk + DÖF + Aylık Kapanış + AI (V1)

**Amaç:** DerinSIS (ve yarın başka ERP) kaynaklı stok/evrak hareketlerinden **risk sinyali üretmek**, bulguları **DÖF** sürecine bağlamak, kanıtları saklamak ve aylık/yıllık analizleri yapmak.

**Prensipler (kilit kararlar):**
1. **ERP ayrı, Denetim ayrı:** Kaynak ERP tabloları değişse bile BKMDenetim çalışmalı. Bu yüzden ERP’ye doğrudan iş mantığı bağlamıyoruz; sadece `src.*` görünümleri üzerinden okuyoruz.
2. **Tek DB:** Denetim, risk, DÖF, kanıt, AI notları **tek veritabanında** (BKMDenetim) yaşar. ERP (DerinSISBkm) ayrı DB’dir.
3. **Gece job = hesaplama:** Gece sadece özet/flag üretir. Raporlar mümkün olduğunca canlı (view/SP) okunur.
4. **Snapshot disiplini:** Risk özetinde **günde tek snapshot** (KesimGünü) kuralı vardır. Yenisi gelirse eskisi sil-yaz.
5. **İşaret kuralı:** `irsHrk.ehAdetN` ve `irsHrk.ehTutarN` **işaretlidir**. Giriş `+`, çıkış `-`.
6. **AltDepo (P0):** Sistem sadece `ehAltDepo=0` kabul eder (emniyet sibobu: non-zero alarm üretir).
7. **MekanId=0 yok:** Toplam satır DB’de tutulmaz. Toplamlar rapor katmanında hesaplanır (transfer double hatası burada tekleştirilir).
8. **Stok bakiyesi (P0):** Sadece miktar. `decimal(18,3)`; `float` yasak.
9. **Geç kalmış düzeltme:** Trigger yok. Gece job **geriye dönük pencere** ile yeniden yazar + “gün toplamı kıyas” kontrolü ile sapmayı yakalar.

---

## Bileşenler

### 1) Kaynak Soyutlama (src şeması)
ERP hangi tabloyu kullanırsa kullansın, BKMDenetim şu 3 görünüme bakar:
- `src.vw_StokHareket`  → stok hareket satırı (bugün `DerinSISBkm.dbo.irsHrk`)
- `src.vw_EvrakBaslik`  → evrak başlık (bugün `DerinSISBkm.dbo.irs`)
- `src.vw_EvrakDetay`   → evrak detay (bugün `DerinSISBkm.dbo.irsAyr`)
- Opsiyonel zenginleştirme: `src.vw_Urun`, `src.vw_Mekan` (ERP’de nereden geliyorsa)

ERP değişince **sadece bu view’leri** yeniden yazarsın; rapor/ETL/döf etkilenmez.

### 2) Referans / Mapping (ref şeması)
- `ref.IrsTipGrupMap` : `ehTip → GrupKodu` (Satış, Alış, Transfer, İade, Sayım, Düzeltme, İçKullanım, Bozuk/İmha vs.)
- `ref.AyarMekanKapsam` : hangi mekânlar kapsama giriyor (job parametresi yerine kalıcı liste)

### 3) Rapor Katmanı (rpt şeması)
- `rpt.RiskUrunOzet_Gunluk` : (KesimTarihi, DonemKodu, MekanId, StokId) bazında net/brüt metrik + flag + skor + yorum.
- `rpt.StokBakiyeGunluk` : (Tarih, MekanId, StokId) bazında bakiyeler (P0: sadece miktar).
- `rpt.RiskUrunOzet_Aylik` : aylık kapanış snapshot (MoM/YoY için tek gerçek).

### 4) DÖF Katmanı (dof şeması)
Riskten bağımsız açılabilir. Yarın ERP değişse bile DÖF çalışır.
- `dof.DofKayit` (ana kayıt)
- `dof.DofBulgu` (bulgular / kök neden)
- `dof.DofAksiyon` (aksiyonlar)
- `dof.DofKanit` (kanıt / ek / SQL çıktısı / ekran görüntüsü yolu)
- `dof.DofDurumGecmis` (audit trail)

### 5) AI Katmanı (ai şeması)
API şart değil; batch ile de olur.
- `ai.AiAnalizIstegi` (hangi risk kaydı analiz edilecek)
- `ai.AiAnalizSonucu` (LLM çıktısı: kök neden hipotezi, öneri, güven skoru, özet)
- `ai.AiGeriBildirim` (senin onayın/itirazın; modelin öğrenmesi için etiket)

### 6) Log & Sağlık (log şeması)
- `log.CalismaLog` (Risk ETL)
- `log.StokCalismaLog` (Stok ETL)
- `log.SaglikKontrolSonuc` (isteğe bağlı; ya tabloya yazarsın ya sadece resultset dönersin)

---

## Akışlar (V1)

### A) Gece Risk ETL
1. Kapsamdaki mekân listesi: `ref.AyarMekanKapsam`
2. Donemler: `Son30Gun`, `AyBasi`
3. Kaynak: `src.vw_StokHareket`
4. Üretim: `rpt.RiskUrunOzet_Gunluk` → **sil-yaz** (gün/period/mekan)
5. Flag + skor + RiskYorum (max 5 cümle)

### B) Gece Stok Bakiye ETL
1. Kaynak: `src.vw_StokHareket`
2. Pencere: varsayılan **120 gün** geriye yaz (parametreli)
3. Çıktı: `rpt.StokBakiyeGunluk` (Tarih = hrkTarih baz alınır)
4. Sağlık: gün toplamı kıyas → sapma varsa “geç düzeltme var” alarmı

### C) Join standardı (Risk ↔ Stok)
Risk kesimi sabah 03:30 civarı ise:
- Risk satırı `KesimTarihi = D`
- Stok bakiyesi `Tarih = D-1` ile join (operasyonel “kesim öncesi bakiye”)

### D) Aylık Kapanış
- Ay kapanış günü/saatinde `rpt.RiskUrunOzet_Aylik` tek snapshot alır.
- MoM/YoY/trend **sadece aylık tablodan**.

---

## Not: Transfer hareketleri ve “double” meselesi
- Mekân bazında transferde hem giriş hem çıkış bacağı vardır; bu normal.
- Toplam raporda transferi **teklemek** için rapor katmanında `BrütTransfer = SUM(CASE WHEN NetAdet>0 THEN NetAdet ELSE 0 END)` mantığı uygulanır.
- Bu nedenle **MekanId=0 toplam satır** tutmuyoruz; rapor view’leri topluyor.

---

## Sabah Checklist (tek sorgu)
`log.sp_SaglikKontrol_Calistir` tek resultset verir: PASS/WARN/FAIL, sayısal değer, tarih değer.

> Bu doküman “kodlanabilir” tasarımdır. SQL dosyaları `sql/` klasöründe.

## AI (LM -> LLM + Semantik Hafiza)
- LM hizli karar verir, LLM derin analiz uretir.
- Semantik hafiza kapanmis DOF kayitlarindan vektor ureterek benzerlik kontrolu yapar.
- Detay: docs/04_AI_Risk_Analiz.md
