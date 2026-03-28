# BKMDenetim Plan (V1)

## Milestones
M1 Ref temeli (IrsTip map, Mekan kapsam, Risk param, Skor agirlik)
M2 Yonetim (personel/kullanici, esleme, entegrasyon log)
M3 Risk dashboard ve gezgin
M4 AI ozet stub + geri bildirim
M5 DOF sureci
M6 Raporlar (aylik, saglik, export)
M7 AI worker + semantik hafiza

## Bagimliliklar
- BKMDenetim DB kurulu ve semalar hazir
- `src` view'leri ERP'ye map edilmis
- Gece job scheduler
- Ollama kurulu (mxbai-embed-large, llama3/phi3)

## Risk log
- R1 IrsTip map eksigi -> metrik hatasi; saglik WARN + zorunlu map
- R2 Gecmis duzeltme -> drift; backfill pencere + gun toplam kontrolu
- R3 Auth gecikirse admin riski; gecici erisim kural

## Done tanimi
- PRD kabul kriterleri saglandi.
- ARCH/ALGO/PLAN dokumanlari guncel.
- TODO listesi guncel.
- Smoke test SP'leri hatasiz calisti.
