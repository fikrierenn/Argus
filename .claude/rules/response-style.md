# Yanıt Stili Kuralları

## Özlülük — Birinci Kural

**Uzun açıklama yasak.** Her yanıt olabildiğince kısa olmalı:

- Değişiklik tek satırda özetlenebiliyorsa paragraf yazma
- "Şimdi X yapıyorum, ardından Y, sonra Z" sıralaması yapma — sadece yap
- Tamamlanan iş için tekrar anlatım yapma — diff zaten gösteriyor
- Seçenekler sunmak gerekiyorsa en fazla 2-3 madde, her biri 1 cümle

## Yasak Kalıplar

- "Mükemmel, harika bir yaklaşım..." — iltifat yok
- "Özet olarak şunları yaptım: ..." — oturum sonu handoff dışında özet yok
- "Şimdi X adımına geçiyorum..." — adım duyurusu yok, direkt geç
- "Bunu yapabilirim, ama önce şunu belirteyim..." — belirtme, yap
- Bullet-point ile madde madde "ne yaptım" listesi (→ sadece sonuç ve "ne sıra" bilgisi)

## İzin Verilen

- Tek cümle durum güncellemesi: "Build yeşil, Faz 4'e geçiyorum."
- Kritik bulgu: "X'te silent failure var, düzeltiyorum."
- Onay gerektiren karar: "X'i silmek üzereyim, devam edeyim mi?"
- Oturum sonu handoff özeti (`/handoff` skill — bu kurala tabi değil)
- Tier 3 plan özeti (plan-first.md gereği)

## Caveman Mode

Kullanıcı `/caveman` veya `CAVEMAN MODE ACTIVE` enjekte ederse:
- Article ve filler kelimeler düş ("the", "a", "şu an", "aslında", "basitçe")
- Kısa cümle/fragment OK
- Technical term aynen kalır
- Kod blokları aynen kalır
- Hata mesajları tırnak içinde aynen alıntılanır

## Ölçüt

Kullanıcı cevabı okumadan tool call sonucuna bakıp ne olduğunu anlayabiliyorsa → metin fazladır.

---

## Araç Kullanımında Token Disiplini (kullanıcı talebi 2026-08-26)

Bu oturumda token'ın büyük kısmını **araç çıktısı** yedi: tam dosya okumaları,
build logları, tarayıcı dökümleri, doğrulamada dönen ham HTML. Dil seçimi
ikincil ama bedava kazanç.

| Ne | Dil | Gerekçe |
|---|---|---|
| Alt-ajan görev tanımı + rapor | **İngilizce** | Yalnız ana ajana döner, kullanıcı görmez |
| Kod içi yorum | **Türkçe** | `coding-discipline.md` zorunlu |
| Kullanıcı yanıtı | **Türkçe** | Kullanıcının dili |
| Diğer oturumlara mesaj | Türkçe | Karşı tarafta insan okuyor |
| Commit mesajı | Türkçe, **kısa** | Ölçüm + karar; anlatı yok |

**Araç çağrısı kuralları:**

1. **Dosyayı bir kez oku.** "changed on disk" bildirimi geldiğinde dosyayı
   yeniden okuma — bildirimdeki içerik güncel durumdur.
2. **Tam dosya değil ilgili bölge.** `sed -n 'A,Bp'` veya `grep -n -A/-B`;
   500 satırlık dosyayı KPI adı için baştan sona okumak yasak.
3. **Doğrulamada sayı bas, gövde basma.** HTML/JSON çıktısını olduğu gibi
   dökmek yerine `grep -c` / `python` ile say ve özet bas.
4. **Build çıktısını süz.** `| grep -E "error|başarı"` — 40 satır uyarı
   dökümü bilgi taşımıyor.
5. **Commit gövdesi:** ne değişti + ölçüm + karar gerekçesi. Aynı şeyi üç
   farklı cümleyle anlatma.
6. **Ajan promptunda kural dosyasını kopyalama** — "şu dosyayı oku" yeter.
