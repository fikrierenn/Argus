# TODO

[x] Ref ekranlari icin ortak duzen
Tanim: Tum Ref tablarini ayni ekle/duzenle/soft delete akisi ile standardize et.
Kabul kriteri:
- Kaydet/Guncelle/Vazgec butonlari tum tablarda ayni gorunur.
- Anahtar alanlar duzenle modunda readonly olur.
- Validasyon hem ustte hem alan yaninda gorunur.
Test notu: Her Ref tabinda bir kaydi duzenle, kaydet, vazgec.
Tahmin: 4s

[x] IrsTip map ekranini sadele
Tanim: Eslestirme tablosu mantigi + edit panel + toplu kaydetme.
Kabul kriteri:
- Eksik-only filtre ve arama birlikte calisir.
- Tip secince mevcut map panelde gorunur.
- Toplu kaydetme birden cok TipId icin kaydeder.
Test notu: Bir Tip map et, yenile, ref.IrsTipGrupMap kontrol et.
Tahmin: 4s

[ ] Personel entegrasyon log sayfasi
Tanim: log.sp_PersonelEntegrasyon_* verisini ozet + liste olarak goster.
Kabul kriteri:
- Ozet kart son calisma ve sayilari gosterir.
- Log listesi top N satir gosterir.
- Bos listeyi hata vermeden gosterir.
Test notu: SP'leri elle calistirip sayfayi yenile.
Tahmin: 4s

[ ] Kullanici-Personel baglanti yonetimi
Tanim: ref.KullaniciPersonel icin liste + kapat + gunsonu kapat.
Kabul kriteri:
- Aktif/pasif baglantilar listede gorunur.
- Kapat butonu ref.sp_KullaniciPersonel_Kapat calistirir.
- Gunsonu kapat admin icin mevcut olur.
Test notu: Baglanti olustur, kapat, BitisTarihi doldu mu bak.
Tahmin: 5s

[ ] Footer DB baglanti durumu
Tanim: DB ping ile yesil/kirmizi durum ve hover'da DB adi goster.
Kabul kriteri:
- Baglanti acilirsa yesil, acilmazsa kirmizi.
- DB adi/Server hover ile gorunur.
- Hata sayfayi bozmaz.
Test notu: SQL servisini durdur, sayfayi yenile.
Tahmin: 3s

[ ] Admin/ref ekranlari icin auth
Tanim: Ref/Yonetim ekranlarini admin rolune sinirla.
Kabul kriteri:
- Auth yoksa login'e yonlendirir.
- Admin olmayan Ref/Yonetim goremez.
- Admin tum ekranlari gorur.
Test notu: Iki kullanici ile dene.
Tahmin: 5s

[ ] AI Worker LM + semantik hafiza
Tanim: BkmDenetim.AiWorker ile LM karar + Light RAG (Ollama mxbai-embed-large) benzerlik kontrolu.
Kabul kriteri:
- ai.sp_Ai_Istek_Al ile NEW istekler cekilir.
- ai.AiLmSonuc yazilir, istek durumu LM_DONE/LLM_QUEUED olur.
- Semantik benzerlik > 0.85 ise LLM zorunlu olur.
Test notu: Kapali DOF kaydi ile benzer risk uret, notu gor.
Tahmin: 6s

[ ] Semantik hafiza vektor sync
Tanim: Kapanmis DOF + dokuman notlarini vektorlestirip ai.AiGecmisVektorler'e yaz (Ollama).
Kabul kriteri:
- KAPANDI durumundaki DOF vektorlere eklenir.
- Kritik etiketli kayitlar similarity kontrolunde kullanilir.
Test notu: Bir DOF kapat, worker sync tetikle.
Tahmin: 4s

[ ] LLM queue isleme
Tanim: LLM_QUEUED istekleri Ollama llama3 (low RAM: phi3) ile isleyip ai.AiLlmSonuc yaz.
Kabul kriteri:
- LLM_QUEUED kayitlar LLM_DONE olur.
- ai.AiLlmSonuc alanlari dolu gelir.
Test notu: Tek istek ile prompt/response kontrol et.
Tahmin: 6s
