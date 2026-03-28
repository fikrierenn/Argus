# BKMDenetim Algoritmalar (V1)

## Risk snapshot akisi
Girdi: `src.vw_StokHareket` (opsiyonel `src.vw_Evrak*`)

Adimlar:
1) `ref.AyarMekanKapsam` ile mekan filtrele
2) Donemleri olustur: Son30Gun ve AyBasi
3) ehTip -> GrupKodu eslestir (aktif map)
4) Net/brut adet ve tutar metriklerini uret
5) Flag kurallarini hesapla (docs/02_RiskKurallari.md)
6) Agirlikli RiskSkor hesapla, 100 ile sinirla
7) En fazla 5 cumlelik RiskYorum olustur
8) `rpt.RiskUrunOzet_Gunluk` tablosuna yaz (gunluk tek snapshot)

## Stok bakiye akisi
1) Son N gunu oku
2) `ehAltDepo = 0` filtrele
3) Gun/mekan/stok bazinda `ehAdetN` topla
4) `rpt.StokBakiyeGunluk` tablosuna yaz

## Join kural
Risk kesimi D ise stok bakiyesi D-1 ile join edilir.

## Mapping kural
- Map olmayan tip "eksik" sayilir.
- Kaydetme TipId bazinda update/insert yapar.

## DOF akisi (V1)
TASLAK -> ACIK -> AKSIYONDA -> KAPANDI (manuel gecis).
Kanitlar append-only, silinmez.

Referans: docs/00_GenelBakis.md, docs/02_RiskKurallari.md, docs/03_Runbook.md.

## AI akisi (LM -> LLM)
1) ai.AiAnalizIstegi kuyrugu (NEW)
2) LM karar: RootCauseClass + EvidencePlan + LLM gerekli mi?
3) Semantik hafiza: Ollama mxbai-embed-large ile benzerlik > 0.85 ve kritik ise oncelik=100, LLM=TRUE
3b) RAG evidence: top 3 benzer kayit LLM promptuna eklenir
4) ai.AiLmSonuc yaz
5) Durum: LLM_QUEUED veya LM_DONE
6) LLM sonucunda DOF taslagi olustur (planli)
