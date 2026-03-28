# AI Risk Analiz (LM -> LLM + Semantik Hafiza)

## Amac
Riskleri sadece hesaplamak degil, kok neden hipotezi, kanit paketi ve DOF taslagi uretmek. LM hizli karar verir, LLM derin analiz yapar. Ek olarak LM, gecmiste kapanmis DOF/Risk kayitlariyla benzerlik arayarak oncelik ve LLM karari alir (Light RAG).

## Katmanlar
1) LM (Fast Lane)
- Rule-based karar
- EvidencePlan (BASIC/MOVE50/FULL)
- LLM gerekli mi?
- Semantik hafiza kontrolu (cosine similarity)

2) LLM (Deep Lane)
- Kok neden hipotezleri
- Dogrulama adimlari
- DOF taslagi
- Yonetici ozeti

## Semantik Hafiza (Light RAG)
- Model: mxbai-embed-large (Ollama /api/embeddings)
- Vektor uretimi: EmbeddingService (Ollama HTTP)
- Kaynak: Kapanmis DOF + onayli risk kayitlari + dokuman notlari (kural seti, runbook)
- Dokumanlar docs/ altindan okunur, Baslik alaninda "DOC:" prefixi kullanilir.
- Dokuman vektorleri AiGecmisVektorler'e negatif RiskId ile yazilir (DofId NULL).
- Esik: similarity > 0.85 ve Kritik kayit ise LLM zorunlu, oncelik 100
- Not: ai.AiGecmisVektorler RiskId alani DOF icin DofId ile doldurulur.
- Embedding endpoint: http://localhost:11434/api/embeddings
- Top 3 benzer kayit LLM promptuna RagEvidence olarak eklenir.

## Veri Modeli (ai)
- ai.AiAnalizIstegi: kuyruk + EvidencePlan + LmNot
- ai.AiLmSonuc: LM karari
- ai.AiLlmSonuc: LLM ciktilari
- ai.AiGecmisVektorler: semantik hafiza vektorleri
- ai.AiGeriBildirim: denetci dogrulama/geri bildirim

## Worker Akisi (BkmDenetim.AiWorker)
1) ai.sp_Ai_Istek_Al ile NEW istekleri cek
2) ai.sp_Ai_RiskOzet_Getir ile risk ozetini al
3) LM kararini uret
4) Semantik hafiza kontrolu (kritik benzerlik varsa oncelik=100, LLM=TRUE)
5) ai.AiLmSonuc yaz
6) ai.sp_Ai_Istek_Guncelle ile Durum guncelle
7) Kapanmis DOF kayitlarindan vektorleri sync et

## LLM Modeli (Ollama)
- Varsayilan: llama3
- Dusuk RAM: phi3.5
- Alternatif: mistral, gemma2
- Endpoint: http://localhost:11434/api/generate

## Konfigurasyon (AiWorker)
- AiWorker:OllamaBaseUrl
- AiWorker:EmbeddingModel (mxbai-embed-large)
- AiWorker:LlmModel (llama3) / AiWorker:LlmModelLowRam (phi3.5)
- AiWorker:DocsEnabled, DocsPath, DocsMaxChars, DocsSnippetChars

Embedding ornek:
curl http://localhost:11434/api/embeddings -d "{\"model\":\"mxbai-embed-large\",\"prompt\":\"DOF kok neden analizi\"}"

## Notlar
- LLM ciktilari tamamlandiginda dof kaydi otomatik TASLAK acilabilir.
- EvidenceJson LLM icin paketlenir, ham milyon satir gonderilmez.
