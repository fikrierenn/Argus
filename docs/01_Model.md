# Veri Modeli (Özet)

## Şemalar
- **src** : ERP soyutlama view’leri (BKMDenetim'in tek bağımlılığı)
- **ref** : mapping / kapsam
- **rpt** : rapor/özet tabloları
- **dof** : DÖF süreç tabloları
- **ai**  : AI analiz istek/sonuç/geri bildirim
- **log** : çalışma logları ve sağlık kontrolleri

## rpt.RiskUrunOzet_Gunluk
**Amaç:** Risk sinyallerinin günlük snapshot’ı.  
**PK:** (KesimTarihi, DonemKodu, MekanId, StokId)

**Önemli kolonlar**
- KesimTarihi (datetime) – job snapshot zamanı
- KesimGunu (date, persisted) – *günde tek snapshot* kuralı için
- DonemKodu (varchar(10)) – Son30Gun / AyBasi
- MekanId (int), StokId (int)
- NetAdet / NetTutar (decimal) – SUM(ehAdetN/ehTutarN)
- BrutAdet / BrutTutar (decimal) – SUM(ABS(...))
- Grup bazlı metrikler (Alis*, Satis*, Iade*, Transfer*, Sayim*, Duzeltme*, IcKullanim*, BozukIade* …)
- Flag’ler (bit)
- RiskSkor (int)
- RiskYorum (nvarchar(500))

## rpt.StokBakiyeGunluk
**Amaç:** Her gün için bakiye (P0: yalnız miktar).  
**PK:** (Tarih, MekanId, StokId)

- Tarih (date) – hrkTarih esas
- MekanId (int)
- StokId (int)
- StokMiktar (decimal(18,3))

> AltDepo P0’da sadece 0 sayılıyor; kaynaktan filtreleniyor.

## rpt.RiskUrunOzet_Aylik
**Amaç:** Kapanış snapshot’ı. MoM/YoY bu tablodan.  
**PK:** (DonemAy, DonemKodu, MekanId, StokId)

- DonemAy (int) – 202512 gibi
- KesimTarihi (datetime) – ay kapanış zamanı
- metrik/flag/skor aynı mantık

## dof.DofKayit
**Amaç:** DÖF ana kayıt. Riskten bağımsız açılabilir.

Önerilen alanlar
- DofId (bigint, identity)
- DofImza (varchar(120), unique) – standard imza
- KaynakSistemKodu (varchar(30)) - ref.KaynakSistem (secimli)
- KaynakNesneKodu (varchar(50)) - ref.KaynakNesne (secimli)
- KaynakAnahtar (varchar(120)) - Or: KesimTarihi|Donem|Mekan|Stk
- Baslik, Aciklama
- RiskSeviyesi (tinyint), SLA_HedefTarih (date)
- Durum (varchar(20)) – TASLAK/ACIK/AKSIYONDA/KAPANDI/RED
- Olusturan, Sorumlu, Onayci
- OlusturanKullaniciId, SorumluPersonelId, OnayciPersonelId
- OlusturmaTarihi, GuncellemeTarihi

## dof.DofBulgu / dof.DofAksiyon / dof.DofKanit
- Bulgu: kök neden hipotezleri + bulgu metrikleri
- Aksiyon: yapılacak iş + sorumlu + bitiş tarihi + gerçekleşen
- Kanıt: dosya yolu / SQL çıktısı / ekran görüntüsü; “silinmez”

## ai.AiAnalizIstegi / ai.AiAnalizSonucu
- İstek: Hangi risk kaydı? Hangi prompt şablonu? Öncelik?
- Sonuç: “kök neden”, “önerilen aksiyon”, “güven” + kısa özet
- Geri bildirim: “Doğru/yanlış” etiketleri (model iyileştirme)

## log tabloları
- log.RiskCalismaLog: her gece risk ETL kaydı
- log.StokCalismaLog: her gece stok ETL kaydı
- log.sp_SaglikKontrol_Calistir: sabah tek ekran

## ref.KaynakSistem / ref.KaynakNesne
- DOF icin KaynakSistem ve KaynakNesne secimli olmalidir.
- Rapor kalitesi icin serbest metin yerine referans kullanilir.

## ref (audit)
- Tum ref tablolarinda OlusturanKullaniciId, GuncelleyenKullaniciId, OlusturmaTarihi, GuncellemeTarihi bulunur.

## ref.Personel / ref.Kullanici / ref.KullaniciPersonel
- Personel hiyerarsi UstPersonelId ile kurulur.
- Kullanici kayitlari personel ile eslenir.
- KullaniciPersonel eslemeleri is cikisinda BitisTarihi ile kapatilir.

## ai (ek tablolar)
- ai.AiLmSonuc: LM karar cikisi (RootCauseClass, EvidencePlan, LLM gerekli mi?)
- ai.AiLlmSonuc: LLM cikisi (hipotezler, dogrulama adimlari, dof taslagi, yonetici ozeti)
- ai.AiGecmisVektorler: semantik hafiza vektor tablosu
