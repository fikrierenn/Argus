# NN — <Başlık>

**Tier:** 3 · **Durum:** taslak | onaylandı | uygulanıyor | tamamlandı
**Tarih:** YYYY-MM-DD · **Sahip:** <kim>

## Problem

<Ne bozuk / ne eksik. Kanıtla — dosya:satır, SQL çıktısı, ekran.>

## Kapsam

**Dahil:** <net sınır>
**Hariç:** <bilerek dışarıda bırakılan — sonradan "bu da olmalıydı" tartışmasını keser>

## Reddedilen alternatifler (en az 2)

| Alternatif | Neden reddedildi |
|---|---|
| | |
| | |

## Tasarım

<Dokunulacak dosyalar (tam yol), yeni dosyalar, SP değişiklikleri, şema migration, veri akışı.>

BkmArgus kısıtları — her biri için "uyuyor mu":
- [ ] SP-first (Web'de inline SQL yok)
- [ ] Türkçe SP parametresi ↔ İngilizce kolon
- [ ] `src.*` view'a dokunulmuyor
- [ ] `rpt.*` snapshot idempotency korunuyor
- [ ] Yeni sayfa/endpoint'te `[Authorize]` + gerekiyorsa policy
- [ ] AI varsa: kademeli maliyet + halüsinasyon kapısı + insan onayı

## 5 lens (her biri 1 cümle)

- 🔴 **Contrarian:** Fatal hata nerede olabilir?
- 🔵 **First Principles:** Yanlış soruyu mu soruyoruz?
- 🟢 **Expansionist:** Daha büyük fırsat kaçıyor mu?
- ⚪ **Outsider:** Yabancı biri neyi garip bulurdu?
- 🟡 **Executor:** Pazartesi sabahı ilk adım ne?

## Riskler

| Risk | Etki | Önlem |
|---|---|---|

## Adımlar

- [ ] Faz 1 — <şema/migration>
- [ ] Faz 2 — <backend>
- [ ] Faz 3 — <UI>
- [ ] Faz 4 — <test + smoke>

Her faz sonunda `phase-review-gate.md` zinciri.

## Bitiş kriteri (kanıtlanabilir)

- [ ] <ölçülebilir sonuç, "çalışıyor" değil>

## Geri alma

<Nasıl geri alınır. Migration varsa rollback SQL.>
