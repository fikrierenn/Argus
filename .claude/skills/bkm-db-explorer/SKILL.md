---
name: bkm-db-explorer
description: BKM kurumsal veritabanlarında (DerinSIS*, BKMDATA, EncoreMerkez, BKM, master) tablo/kolon/SP keşfi yapar. "PDKS'de hangi şube tablosu var?", "DerinSIS'te satış kalemi nasıl tutulur?", "BKM_GENEL'de IK personel tablosu?" gibi soruları yanıtlar. PDKS/DerinSIS/IK heterojen şube kavramına dikkat eder.
---

# BKM DB Explorer

## Ne zaman tetiklenir

- "X DB'de Y tablo/kolon var mı?"
- "Z parametresi hangi sistemde tanımlı?"
- "Yeni FilterDefinition.OptionsQuery yazacağım, şu DB'de uygun tablo bul"
- Plan 14 Faz B (IK sube), Plan 16 vNext modül keşif, Plan 26 MetricEngine entity discovery
- "DerinSIS / Encore / BKM_GENEL şemada gez"
- Subagent prompt'u içinde "BKM DB keşfi" gerektiğinde

## Kritik bağlam

**BKM şube heterojenliği** (`memory/project_bkm_sube_heterogen.md`):
"Şube" / "mağaza" / "lokasyon" kavramı her sistemde farklı tablo + farklı kod. Tek "global şube tablosu" yok.

| Sistem | DB | Şube/lokasyon ipucu |
|---|---|---|
| **PDKS** | dbo schema, ana DB | `dbo.sp_PdksPano` parametreleri (FmTop, GecTop, sube_Filtre, bolum_Filtre) |
| **DerinSIS Satış** | DerinSISBkm | `bkm.sp_SatisPano` + `bkm.UrunBilgi`, `posMagaza` (YonetIQ MetricEngine'den) |
| **DerinSIS CRM** | DerinSISBkmCrm | müşteri tabanlı |
| **DerinSIS Web** | DerinSISBkmWeb | web sipariş/sepet |
| **BKM_GENEL** | DerinSISBkmCrm/Web ya da ayrı (kontrol et) | IK personel/sube — Plan 14 Faz B keşfedecek |
| **BKMDATA** | BKMDATA | genel işletme verisi |
| **EncoreMerkez** | EncoreMerkez | muhasebe/finans tahmini |
| **BkmArgus** | BkmArgus DB | uygulama metadata + UserDataFilter (allowlist DIŞINDA — MCP yerine SSMS) |

**MCP allowlist:** master, DerinSIS{,BkmCrm,BkmWeb}, BKMDATA, EncoreMerkez, BKM. BkmArgus DB + IK Zirve DB + diğer kurumsal DB'ler allowlist'te **yok**.

**Allowlist dışı DB'ler için sqlcli kullan** (`D:/Dev/sqlcli/`):
```bash
cd D:/Dev/sqlcli
dotnet run -- query "SELECT ..." --conn "Server=...;Database=...;..."
# veya sqlcli.json (parent dizinde aranır, D:/Dev/reporthub/sqlcli.json gitignored)
dotnet run -- query "SELECT ..."
# BkmArgus connection sqlcli.json'da, alternatif DB için --conn override
dotnet run -- query "..." --conn "Server=ZirveServer;Database=ZirveDB;..."
```

sqlcli read-only varsayılan **DEĞİL** — `query` komutu UPDATE/INSERT/DELETE de çalıştırır. **Sadece SELECT için kullan**, mutasyon migration'ı için ayrı migration dosyası yaz + kullanıcı onayı + sql-migration-writer skill'ine bak.

## Tipik keşif workflow

### 1. Tablo keşfi — bulduğun şeyi doğrula, varsayma

```sql
-- Genel ad araması
SELECT name, OBJECT_SCHEMA_NAME(object_id)+'.'+name AS qname
  FROM <DBADI>.sys.tables
 WHERE name LIKE '%<arama_kelime>%';
```

`mcp__sqlserver__sql_browse_schema` veya `mcp__sqlserver__sql_search_columns` öncelik. `sys.tables` doğrudan sorgu fallback.

### 2. Kolon haritası

```sql
-- INFORMATION_SCHEMA describe_table'dan daha güvenilir (memory: feedback_information_schema_over_describe.md)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
  FROM <DBADI>.INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_SCHEMA = '<schema>' AND TABLE_NAME = '<tablo>';
```

### 3. Örnek satır

```sql
SELECT TOP 5 * FROM <DBADI>.<schema>.<tablo>;
```
veya `mcp__sqlserver__sql_sample_data`.

### 4. SP imzası

```sql
SELECT name, type_desc, OBJECT_DEFINITION(object_id) AS body
  FROM <DBADI>.sys.objects
 WHERE type_desc IN ('SQL_STORED_PROCEDURE', 'SQL_INLINE_TABLE_VALUED_FUNCTION', 'SQL_TABLE_VALUED_FUNCTION')
   AND name LIKE '%<arama>%';
```

`mcp__sqlserver__sql_describe_table` SP için yetersiz; `OBJECT_DEFINITION` direkt source verir.

### 5. FK ilişkileri

```sql
-- INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS + KEY_COLUMN_USAGE join
-- Veya mcp__sqlserver__sql_relationships
```

## Her keşif sonrası raporlanacaklar

1. **Aday tablo + kolon listesi** (kanonik PK + label kolonu)
2. **Örnek 5 satır** (gerçek veri formatı)
3. **Diğer sistemlerle bağlantı** varsa (örn. PDKS sube ID'si IK sube ID'siyle eşleşiyor mu — **eşleşmez varsay**, kontrol et)
4. **OptionsQuery taslağı** — BkmArgus FilterDefinition için canonical `(Id, Label)` projection
5. **Risk notu** — sube/personel heterojenliği, cross-DB join, LIKE arama gerekliliği

## Yaygın yanılgılar (KAÇIN)

- ❌ Tablo adı tahmini (`bkm.SubeListe` varsayma — gerçek schema'yı doğrula)
- ❌ `sys.parameters.has_default_value` güveni (memory: `feedback_paramschema_sp_eksiklik.md` — yanıltıcı, T-SQL default'ları doğru göstermez, source'a bak)
- ❌ MCP `describe_table` kolon length kabulu (memory: `feedback_information_schema_over_describe.md` — INFORMATION_SCHEMA daha güvenilir)
- ❌ "Şube ID'si tüm sistemlerde aynı" varsayımı — heterojen
- ❌ BkmArgus DB için MCP kullanmaya çalışmak — allowlist'te yok

## Çıktı format şablonu

```markdown
## BKM DB Keşfi: <konu>

### Aday tablolar
| DB.Schema.Table | Açıklama | Satır tahmini |
|---|---|---|
| BKM_GENEL.dbo.PersonelMaster | IK ana personel | ~5K |

### Kanonik kolonlar
- PK: `PersonelKodu` (varchar 20)
- Label: `AdiSoyadi` (varchar 100)
- Sube FK: `SubeId` → `BKM_GENEL.dbo.SubeListe`

### Örnek satır (anonimleştirilmiş)
...

### OptionsQuery taslağı
```sql
SELECT Id = SubeId, Label = SubeAdi
  FROM BKM_GENEL.dbo.SubeListe
 WHERE IsActive = 1
 ORDER BY SubeAdi;
```

### Risk / dikkat
- Sube ID'si **PDKS sistem ID'si DEĞİLDİR** — ayrı UserDataFilter satırı gerekli
- ...
```

## İlişkili memory + rule

- `memory/project_bkm_sube_heterogen.md` — kanonik kaynak
- `memory/feedback_information_schema_over_describe.md`
- `memory/feedback_paramschema_sp_eksiklik.md`
- `memory/project_dashboard_config_named_contract.md`
- `memory/feedback_db_update_where_zorunlu.md` — UPDATE öncesi WHERE + SELECT zorunlu

## Tools

`mcp__sqlserver__*` — sql_query, sql_browse_schema, sql_describe_table, sql_search_columns, sql_sample_data, sql_relationships, sql_table_stats, sql_index_analysis, sql_recent_errors. `Read` (mevcut SP source dosyaları için), `Grep` (BkmArgus kod tarafında SP referansları).
