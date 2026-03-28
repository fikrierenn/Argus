# BKMDenetim PRD (V1)

## Amac
ERP stok/evrak hareketlerinden risk sinyali ureten, kaniti saklayan ve DOF surecini baslatan hafif bir denetim kokpiti.

## Kullanicilar
- Denetci (analist)
- Yonetici (rapor izleyici)
- Admin (referans ve sistem ayarlari)

## Kapsam (V1)
- Risk dashboard ve gezgin (read-only)
- Ref yonetimi: IrsTip map, Mekan kapsam, Risk param, Skor agirlik, Kaynak sistem/nesne
- Personel + Kullanici yonetimi ve esleme
- Gece ETL isleri (risk, stok, aylik) ve saglik kontrol
- DOF veri modeli ve temel liste/detay
- Kanitin BKMDenetim'de saklanmasi
- AI LM/LLM akisi + semantik hafiza (Light RAG)

## Kapsam disi (V1)
- Mobil uygulama
- Ucuncu taraf API
- AI otomatik onay/aksiyon
- Gercek zamanli streaming

## Fonksiyonel gereksinimler
- ERP verisi sadece src.* view uzerinden okunur, ERP DB'ye yazilmaz.
- Gunluk tek snapshot kuralina uyulur (Son30Gun, AyBasi).
- Risk ve DOF verisi 5 yil saklanir.
- Ref tablolarinda olusturan/guncelleyen ve tarih alanlari zorunlu.
- AI worker LM kararlarini ai.AiLmSonuc'a yazar.
- Semantik hafiza kapanmis DOF kayitlarindan beslenir.

## Teknik gereksinimler
- Liste ekranlari LAN'da <= 2 sn (<= 500 satir).
- Gece isleri 60 dk icinde tamamlanir.
- Gizli bilgiler sadece env/config ile tutulur.

## Kabul kriterleri
- `log.sp_RiskUrunOzet_Calistir` Son30Gun ve AyBasi satirlari uretir.
- `log.sp_StokBakiyeGunluk_Calistir` son N gunu doldurur.
- IrsTip map kaydi `ref.IrsTipGrupMap` tablosunu gunceller ve UI'da eslesmis gorunur.
- Saglik kontrol PASS/WARN/FAIL dondurur.
- Ref ekranlari ekle/duzenle/soft delete yapar ve audit alanlari dolar.

## Bagimliliklar
- SQL Server uzerinde BKMDenetim DB
- `src` view'lerinin ERP'ye baglanmasi
- Gece job scheduler
- Ollama (embedding + LLM servisleri)
