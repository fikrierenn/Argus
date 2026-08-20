# Faz Kapanış Kontrol Kapısı (Phase Review Gate)

Her Tier 3 planın her fazı bitmeden commit atılmaz. Aşağıdaki zincir **sırayla** çalıştırılır.

## Zorunlu Kontrol Zinciri

### 1. Build (her faz)
```
Agent: build-validator | model: haiku
```
- 0 hata, 0 uyarı şart. Tek hata varsa commit yok.

### 2. Kod İnceleme (her faz)
```
Agent: code-reviewer | model: sonnet
```
- Türkçe yorum eksikliği, 80 satır aşımı / 300-500 satır dosya, guard clause, magic string, `[Authorize]` policy eksikliği.
- HIGH/CRITICAL bulgu varsa → düzelt, tekrar build.

### 3. SQL/SP İnceleme (SP veya şema değiştiyse)
```
Agent: sql-sp-reviewer | model: opus
```
- Transaction atomikliği (SET XACT_ABORT + BEGIN/COMMIT/ROLLBACK).
- THROW kod aralığı (50000-59999).
- Türkçe parametre ↔ İngilizce kolon sözleşmesi (C# anonymous object ile birebir eşleşme).
- Snapshot idempotency (`rpt.*` — iki kez çalışınca aynı sonuç).
- `src.*` view dokunulmazlığı, persisted computed kolon tuzağı.
- Tip kuralları (`datetime2(0)`, `decimal(18,3)`, `SYSDATETIME()`), SARGable WHERE.
- CRITICAL bulgu varsa → düzelt, tekrar build.

### 3.5 Fresh-DB Migrate Testi (sql/ altinda migration degistiyse) — ZORUNLU RITUEL

**Neden:** Dev DB'de objeler tarihsel olarak elle uygulanmis olabilir → `sql/` zinciri eksik olsa bile dev CALISIR ama **temiz kurulum PATLAR**. Mevcut DB'ye migration kosmak bu farki GIZLER. Tek guvenilir kanit: sifirdan bos DB.

```bash
# 1. Bos test DB
SQLCLI_CONN="$BKM_DENETIM_CONN" dotnet run --project D:/Dev/sqlcli -- query   "IF DB_ID('BKMDenetim_FreshTest') IS NOT NULL BEGIN ALTER DATABASE BKMDenetim_FreshTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE BKMDenetim_FreshTest; END; CREATE DATABASE BKMDenetim_FreshTest"

# 2. sql/ zincirini sirayla uygula (00 -> 99)
for f in sql/[0-9]*.sql; do
  SQLCLI_CONN="Server=<srv>;Database=BKMDenetim_FreshTest;..." dotnet run --project D:/Dev/sqlcli -- script "$f" || echo "FAIL: $f"
done

# 3. Beklenen objeleri dogrula (OBJECT_ID NULL degil) — ozellikle yeni SP/tablo
# 4. DROP DATABASE BKMDenetim_FreshTest (SINGLE_USER ile)
```

- **0 fail + beklenen tum obje mevcut** olmadan faz kapanmaz.
- Patladiysa ilk fail eden script = eksik bagimlilik/sira. Duzelt, tekrar.
- **DerinSISBkm bagimliligi:** `src.*` view'lari cross-DB'dir; fresh test DB'de ERP erisimi yoksa view olusur ama sorgu patlar — bu beklenen, sadece obje varligini dogrula.

### 4. Güvenlik İnceleme (yeni PageModel veya SP varsa)
```
Agent: security-reviewer | model: opus
```
- SQL injection, IDOR, mass assignment, secret leakage, open redirect.
- Confidence ≥ 80 kritik bulgu varsa → düzelt.

### 5. Manuel Smoke (her faz — atlanamaz)

"Derlendi / 0 hata" YETMEZ. Neye dokunulduysa ona gore kanit:

| Dokunulan | Smoke kaniti |
|---|---|
| SP / migration | Gercek veriyle `EXEC` + donen satir sayisi/degeri ciktisiyla goster |
| ETL | Dar tarih araliginda calistir → satir sayisi once/sonra + **iki kez calistir, sonuc degismesin** (idempotency) |
| Razor ekran | `preview_*` ile boot + HTTP 200 + etkilesim + 0 konsol hatasi |
| RBAC | Iki farkli rolle dene — yetkisiz kullanici 403/AccessDenied almali |
| AI job/skill | Gercek kayitta calistir → `ai.AgentExecutions` / `ai.LlmResults` satirini goster |

Sonucu **ciktiyla** raporla (yesil/kirmizi). Kirmiziysa soyle, gizleme.

## Gecmis Dersler (neden zorunlu)

| Olay | Nasil yakalandi | Erken yakalansaydi |
|---|---|---|
| `rpt.DailyProductRisk` PK'da `PeriodCode` yoktu → ETL mukerrer/eksik | Canli veri sayimi | sql-sp-reviewer (snapshot idempotency) |
| `SnapshotDate` saatli yaziliyordu → gunluk snapshot kurali kirildi | ETL ciktisi | sql-sp-reviewer |
| `ai.sp_ProactiveInsight_List` yanlis SP adi | Runtime hata | build sonrasi smoke |
| AI SP kolon adlari canli semayla uyusmuyordu | Runtime | db-schema-checker |
| Gemini/Claude API key commit'e girdi | Manuel inceleme | pre-commit hook (§sir taramasi) |
| RBAC yoktu — DENETCI tum ekranlari goruyordu | Manuel inceleme | security-reviewer |

## Kısayol (paralel çalıştır)

Bağımsız kontroller tek mesajda paralel Agent çağrısıyla çalıştırılır:
```
code-reviewer (sonnet) + sql-sp-reviewer (opus) + security-reviewer (opus)  → paralel
build-validator (haiku)                                                        → önce
fresh-DB migrate testi (§3.5)                                                  → migrate/schema/db_objects değiştiyse
smoke                                                                          → en son
```

## İstisnalar

- **Tier 1/2 iş:** build-validator yeterli (reviewer'lar opsiyonel).
- **Sadece dokümantasyon/plan değişikliği:** hiçbiri zorunlu değil.
- **Kullanıcı "hızlıca geç" derse:** atlanan kontrol commit mesajına `[review-skipped: <gerekçe>]` notu + TODO.md'ye borç satırı.

## İlişkili

- `.claude/rules/plan-first.md` — Tier sistemi
- `.claude/rules/test-discipline.md` — test koşumu
- `.claude/rules/sql-conventions.md` — SP standartları
- `.claude/rules/etl-discipline.md` — snapshot/idempotency kanitlari
- `.claude/rules/ai-layer.md` — AI hatti dogrulamasi
