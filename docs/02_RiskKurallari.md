# Risk Kuralları (V1)

## Dönemler
- **Son30Gun:** KesimTarihi’nden geriye 30 gün (hrkTarih esas)
- **AyBasi:** İçinde bulunulan ayın başından KesimTarihi’ne kadar

> Not: Aynı ürün/mekân için Son30Gun varsa RiskYorum’da AyBasi aynı flag’i yazılmaz (Son30Gun baskın).

## Net / Brüt
- NetAdet = SUM(ehAdetN)
- BrütAdet = SUM(ABS(ehAdetN))
- NetTutar = SUM(ehTutarN)
- BrütTutar = SUM(ABS(ehTutarN))

## Grup metrikleri
`ref.IrsTipGrupMap` ile ehTip → GrupKodu eşlenir. Her grup için net/brüt adet/tutar tutulur.

Örnek grup kodları:
- ALIS, SATIS, IADE_MUSTERI, TRANSFER, SAYIM, DUZELTME, ICKULLANIM, BOZUK_IMHA, DIGER

## Flag seti (öneri)
Aşağıdaki eşikler V1’de **parametre tablosundan** okunur (hardcode değil).

### FlagVeriKalite
- Kural: `ehAdetN = 0 AND ehTutarN <> 0` satır sayısı > 0
- Amaç: tutarsız kayıt yakalamak

### FlagGirissizSatis
- Kural: `SatisBrutAdet > 0 AND AlisBrutAdet = 0` (dönem içinde)
- Amaç: yanlış eşleşme / transfer / kayıt eksikliği

### FlagOluStok
- Kural: `AlisBrutAdet > 0 AND SatisBrutAdet = 0` (veya stok var ama satış yok)
- Not: stok ile birlikte yorumlanır (stok join)

### FlagNetBirikim
- Kural: `NetAdet` (veya NetTutar) belirli eşik üzerinde pozitif birikim
- Amaç: birikmiş stok / şişme

### FlagIadeYuksek
- Kural: IadeOraniYuzde > X
- IadeOraniYuzde = (MusteriIadeBrutTutar) / (SatisBrutTutar) * 100
- Musteri iade seti: (3,5,101) vb. (map tablosu üzerinden)

### FlagBozukIadeYuksek
- Kaynak: BOZUK_IMHA grubu veya tip seti (örn 93)
- Kural: BozukBrutAdet > A veya BozukBrutTutar > B

### FlagSayimDuzeltmeYuk
- Kural: SayimBrutAdet + DuzeltmeBrutAdet > eşik
- Amaç: sayım/manuel düzeltme yoğunluğu

### FlagSirketIciYuksek
- Kural: IcKullanimBrutTutar > eşik
- Amaç: iç tüketim/şube içi kullanım

### FlagHizliDevir
- Kural: dönem içinde AlisBrutAdet > 0 AND SatisBrutAdet / AlisBrutAdet > eşik
- Emniyet: “giriş varlığı” şartı

### FlagSatisYaslanma
- Kural: son satış tarihi çok eski + stok/birikim var (opsiyon: StokBakiyeGunluk > 0)
- Hesap: `SatisYasiGun = KesimTarihi - SonSatisTarihi`

## RiskSkor (0–100)
- Her flag puan getirir (ağırlıklar ref tablosunda).
- Ek puan: birikim büyüklüğü (NetAdet/NetTutar bandı).
- Normalize: `min(100, ToplamPuan)`.

## RiskYorum (en fazla 5 cümle)
- Öncelik sırası: VeriKalite > GirissizSatis > OluStok > NetBirikim > IadeYuksek > BozukIadeYuksek > …  
- Aynı flag iki kez yazılmaz; Son30Gun varsa AyBasi yazılmaz.
- Format: `KısaNeden: metrik=... (Son30Gun)` | ...