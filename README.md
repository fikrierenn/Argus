# BKM Argus

**AI-Orchestrated Audit & Risk Intelligence Platform**

BKMKitap ic denetim ve risk yonetim platformu. ERP risk analizi + saha denetim + AI karar motoru.

![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)
![SQL Server](https://img.shields.io/badge/SQL%20Server-2019-CC2927?logo=microsoftsqlserver)
![Tailwind CSS](https://img.shields.io/badge/Tailwind-3.x-06B6D4?logo=tailwindcss)
![License](https://img.shields.io/badge/license-private-gray)

---

## Ozellikler

### ERP Risk Analizi
- Nightly ETL ile stok/hareket verisi toplama (DerinSISBkm)
- 11 risk flag'i ile otomatik puanlama (Probability x Impact matrisi)
- Gunluk/aylik risk snapshot'lari
- Filtrelenebilir risk gezgini + Excel export

### Saha Denetim
- Magaza/kafe denetim checklist'i (EVET/HAYIR)
- Mobile-first denetim formu (accordion, touch-friendly)
- Foto kanitlari yukleme
- Kesinlestirme → otomatik analiz pipeline
- Tekrar eden / sistemik bulgu tespiti
- Magaza karnesi + trend raporlari

### AI Karar Motoru
- **Layer 1:** Kural tabanli (LmRules) — deterministik, hizli
- **Layer 2:** Semantic memory (Ollama mxbai-embed-large) — benzerlik eslestirme
- **Layer 3:** LLM zinciri (Gemini → Claude → Ollama) — narrative analiz
- **Layer 4:** Agent pipeline — coklu agent orkestrasyon

### DOF Yonetimi
- Kanban board (Taslak → Acik → Inceleme → Kapandi)
- SLA takibi + sorumluluk atama
- Etkinlik degerlendirme

### Yetkilendirme
- Cookie auth (BCrypt, 7 gun sliding)
- Rol bazli erisim (ADMIN, YONETICI, DENETCI)
- Ilk giris zorunlu sifre degisimi
- 5 basarisiz giris → hesap kilidi
- Login history (IP + UserAgent)

---

## Hizli Baslangic

```bash
# Build
dotnet build BkmArgus.sln

# Web (port 5169)
dotnet run --project src/BkmArgus.Web --urls "http://0.0.0.0:5169"

# AI Worker
dotnet run --project src/BkmArgus.AiWorker

# Installer (setup wizard, port 5555)
dotnet run --project src/BkmArgus.Installer
```

**Varsayilan giris:** `admin` / (ilk giriste sifre degistirme zorunlu)

---

## Teknoloji

| Katman | Teknoloji |
|--------|-----------|
| Backend | ASP.NET Core Razor Pages (.NET 10) |
| ORM | Dapper (SP-first, no EF) |
| DB | SQL Server 2019 (8 schema, 40+ tablo) |
| AI | LM Rules + Semantic Memory + LLM (Gemini/Claude/Ollama) |
| Worker | BackgroundService + Job Scheduler |
| Frontend | Tailwind CSS, vanilla JS |
| Auth | Cookie + BCrypt |

---

## Proje Yapisi

```
BkmArgus/
├── src/
│   ├── BkmArgus.Web/          # Razor Pages (17 sayfa)
│   │   ├── Features/          # Sayfa modulleri
│   │   │   ├── Account/       # Login, Logout, ChangePassword
│   │   │   ├── Audit/         # Denetim CRUD (6 sayfa)
│   │   │   ├── Dashboard/     # ERP Risk + Saha Denetim tab'lari
│   │   │   ├── Risk/          # Filtrelenebilir risk gezgini
│   │   │   ├── Dof/           # DOF Kanban board
│   │   │   ├── Ai/            # AI kuyruk + sonuc detay
│   │   │   ├── Ref/           # 8 tab referans yonetimi
│   │   │   ├── Yonetim/       # Personel entegrasyon
│   │   │   └── Ayarlar/       # Kullanici + sistem ayarlari
│   │   └── Services/          # AuthService
│   ├── BkmArgus.AiWorker/     # AI background worker
│   │   ├── Jobs/              # RiskPrediction, AgentPipeline
│   │   ├── LmRules.cs         # Kural motoru
│   │   ├── LlmService.cs      # Gemini/Claude/Ollama
│   │   └── SemanticMemoryService.cs
│   ├── BkmArgus.Installer/    # DB setup wizard
│   └── SchemaManagement.Library/
├── sql/                        # 37 SQL dosyasi
│   ├── 00-15: Base schema + SPs
│   ├── 20-22: Audit schema + SPs
│   ├── 30-32: English SP migrations
│   ├── 33-34: Column rename migrations
│   └── 35-37: Auth tables + SPs
├── docs/                       # Mimari dokumantasyon
└── CLAUDE.md                   # AI asistan rehberi
```

---

## Veritabani Semalari

| Schema | Tablo | Amac |
|--------|-------|------|
| `src` | 6 view | ERP abstraction (DerinSISBkm) |
| `ref` | 9 tablo | Referans/mapping verileri |
| `audit` | 10 tablo | Saha denetim + kullanicilar |
| `rpt` | 3 tablo | Risk snapshot'lari |
| `dof` | 5 tablo | DOF surec yonetimi |
| `ai` | 8 tablo | AI analiz + semantic memory |
| `log` | 3 tablo | ETL + login log'lari |
| `etl` | 6 tablo | ETL staging |

---

## Ortam Degiskenleri

| Degisken | Aciklama |
|----------|----------|
| `BKM_DENETIM_CONN` | SQL Server connection string |
| `Claude__ApiKey` | Anthropic Claude API key |
| `AiWorker__LlmProvider` | Tercih edilen LLM (gemini/claude/ollama) |

---

## Gelistirme Notlari

- Tum veri erisimi SP uzerinden (inline SQL yok, web katmaninda)
- SP parametre adlari Turkce (`@MekanId`, `@KesimTarihi`)
- Tablo/kolon adlari Ingilizce (`LocationSettings`, `RiskScore`)
- `src.*` view'lari DEGISTIRMEZ — ERP bagimliligi
- `datetime2(0)` kullan, `datetime` degil
- `SYSDATETIME()` kullan, `GETDATE()` degil
- sqlcli araci: `D:\Dev\sqlcli` (migration + query)

---

*BKMKitap Ic Denetim Birimi - 2026*
