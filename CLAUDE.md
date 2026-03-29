# BkmArgus — AI-Powered Audit & Risk Intelligence Platform

## Overview
BKM Kitap unified audit and risk management platform. Two data channels:
1. **ERP Risk Analysis**: Automated risk signals from stock/document movements (nightly ETL from DerinSISBkm)
2. **Field Audit**: Auditor visits stores/cafes, fills checklist, takes photos, triggers AI analysis

## Quick Start
```bash
# Build all projects
dotnet build BkmArgus.sln

# Run web app (port 5169)
dotnet run --project src/BkmArgus.Web --urls "http://0.0.0.0:5169"

# Run AI worker
dotnet run --project src/BkmArgus.AiWorker

# Run installer (setup wizard)
dotnet run --project src/BkmArgus.Installer

# Run MCP schema server
dotnet run --project src/BkmArgus.McpServer

# SQL CLI (separate tool at D:\Dev\sqlcli)
SQLCLI_CONN="Server=192.168.40.201;Database=BKMDenetim;..." dotnet run --project D:/Dev/sqlcli -- tablolar
```

## Tech Stack
- **Web**: ASP.NET Core Razor Pages (.NET 10), Dapper, SP-first
- **DB**: SQL Server 2019 (BKMDenetim), 8 schemas
- **AI**: LM Rules (deterministic) -> Semantic Memory (Ollama mxbai-embed-large) -> LLM (Gemini/Claude/Ollama)
- **Worker**: BkmArgus.AiWorker (BackgroundService, polling queue)
- **Installer**: Console + Web UI (port 5555)
- **MCP**: BkmArgus.McpServer (REST API for schema extraction)
- **Migration**: SchemaManagement.Library (DbUp)

## Project Structure
```
D:\Dev\BkmArgus\
├── BkmArgus.sln              (3 projects in solution)
├── CLAUDE.md                  (this file)
├── sql/                       (all SQL: schemas, tables, SPs, seeds, migrations)
│   ├── 00_create_db.sql ... 15_ai_enhancement_v2.sql (base schema)
│   ├── 20_migration_audit.sql   (audit schema + tables)
│   ├── 21_sps_audit.sql         (audit CRUD + analysis SPs)
│   └── 22_sps_audit_dashboard.sql (audit reporting SPs)
├── docs/                      (architecture, plans, PRD, algorithms)
├── _archive/icdenetim/        (original IcDenetim code - reference only)
└── src/
    ├── BkmArgus.Web/          (Razor Pages, Features/ folder structure)
    ├── BkmArgus.AiWorker/     (AI background worker, Jobs/, LlmService, LmRules)
    ├── BkmArgus.Installer/    (database setup wizard)
    ├── BkmArgus.McpServer/    (schema extraction REST API)
    └── SchemaManagement.Library/ (DbUp migration wrapper)
```

## Database Schema (8 schemas, 40 tables, ALL ENGLISH)

### src — ERP Abstraction (DO NOT MODIFY - ERP dependent)
Views only: `vw_StokHareket`, `vw_EvrakBaslik`, `vw_EvrakDetay`, `vw_IrsTip`, `vw_Mekan`, `vw_Urun`
Source: DerinSISBkm (same server, cross-DB queries)

### ref — Reference/Mapping (9 tables)
`LocationSettings`, `TransactionTypeMap`, `RiskParameters`, `RiskScoreWeights`, `SourceSystems`, `SourceObjects`, `Personnel`, `Users`, `UserPersonnelMap`

### audit — Field Audit (10 tables)
`Users`, `Audits`, `AuditItems`, `AuditResults`, `AuditResultPhotos`, `CorrectiveActions`, `Skills`, `SkillVersions`, `AiAnalyses`, `AuditLog`

### rpt — Report Snapshots (3 tables)
`DailyProductRisk` (43 columns, daily risk snapshot), `MonthlyProductRisk`, `DailyStockBalance`

### dof — DOF Process (5 tables)
`Findings`, `FindingDetails`, `Actions`, `Evidence`, `StatusHistory`

### ai — AI Analysis (8 tables)
`AnalysisQueue`, `SemanticVectors`, `LlmResults`, `AgentConfig`, `AgentExecutions`, `AgentPipelines`, `PredictionModels`, `RiskPredictions`

### log — Execution Logs (3 tables)
`RiskEtlRuns`, `StockEtlRuns`, `PersonnelIntegrationLog`

### etl — ETL Staging (6 tables)
`SalesStaging`, `StockMovementStaging`, `StockStaging`, `DataQualityIssues`, `EtlRuns`, `SyncStatus`

## Naming Convention (CRITICAL)
| Element | Rule | Example |
|---------|------|---------|
| Table names | English, PascalCase | `DailyProductRisk`, `AnalysisQueue` |
| Column names | English, PascalCase | `LocationId`, `RiskScore`, `IsActive` |
| Boolean columns | `Is` prefix | `IsActive`, `IsSystemic`, `IsCritical` |
| Date columns | `At` or `Date` suffix | `CreatedAt`, `SnapshotDate`, `DueDate` |
| FK columns | `Id` suffix | `LocationId`, `ProductId`, `CreatedByUserId` |
| Audit columns | Standard set on ALL tables | `CreatedAt`, `UpdatedAt`, `CreatedByUserId`, `UpdatedByUserId` |
| SP names | `schema.sp_Entity_Action` | `audit.sp_Audit_List`, `dof.sp_Finding_Create` |
| SP parameters | **Turkish** with `@` prefix | `@MekanId`, `@BaslangicTarih`, `@DenetimId` |
| View names | `schema.vw_Name` | `rpt.vw_RiskDashboard` |
| Index names | `IX_Table_Columns` | `IX_DailyProductRisk_SnapshotDate` |
| PK names | `PK_Table` | `PK_DailyProductRisk` |
| FK names | `FK_Child_Parent` | `FK_Actions_Findings` |
| src views | **DO NOT RENAME** | ERP Turkish columns, alias in SPs |

## Coding Rules
- **SP-first**: ALL data access through stored procedures (no inline SQL in web layer)
- **Dapper only**: No Entity Framework, no LINQ-to-SQL
- **datetime2(0)**: Never use `datetime`. Always `SYSDATETIME()` not `GETDATE()`
- **TRY-CATCH**: Every SP must have error handling
- **Idempotent migrations**: `IF OBJECT_ID IS NULL` / `IF COL_LENGTH IS NOT NULL` patterns
- **No string concat in SQL**: Parametrized SPs only
- **Config priority**: env var > appsettings.json > defaults
- **Secrets**: NEVER in code. Use env var `BKM_DENETIM_CONN` or `appsettings.json`
- **File upload**: image only, max 5MB, validate type
- **src views rule**: Never modify src views. Alias ERP Turkish columns in SPs:
  ```sql
  SELECT sh.ehMekanId AS LocationId, sh.ehStokId AS ProductId FROM src.vw_StokHareket sh
  ```

## Key SP Commands
```sql
-- ETL (nightly)
EXEC log.sp_RiskUrunOzet_Calistir;
EXEC log.sp_StokBakiyeGunluk_Calistir @GeriyeDonukGun=120;
EXEC log.sp_AylikKapanis_Calistir;

-- Health check
EXEC log.sp_SaglikKontrol_Calistir;

-- Audit analysis pipeline (after finalization)
EXEC audit.sp_Analysis_FullPipeline @AuditId=X;

-- Audit CRUD
EXEC audit.sp_Audit_List @Top=50;
EXEC audit.sp_Audit_Get @AuditId=1;
EXEC audit.sp_Audit_Finalize @AuditId=1;

-- Dashboard
EXEC audit.sp_Dashboard_FieldAudit_Kpi;
EXEC audit.sp_Dashboard_TopRiskFindings @Top=10;
```

## AI Architecture
```
Request → LM Rules (fast, deterministic)
  → Semantic Memory (Ollama mxbai-embed-large, cosine similarity > 0.85)
  → LLM Queue (Gemini primary → Claude fallback → Ollama local)
  → Result stored in ai.AnalysisQueue / ai.LlmResults
```

## DB Connection
- **Dev server**: 192.168.40.201 (SQL Server 2019)
- **Database**: BKMDenetim
- **ERP**: DerinSISBkm (same server, cross-DB)
- **Env var**: `BKM_DENETIM_CONN` or `ConnectionStrings:BkmArgus`
- **Claude API**: `Claude__ApiKey` in env or appsettings

## Gotchas
- `rpt.DailyProductRisk.SnapshotDay` is a PERSISTED computed column (depends on SnapshotDate) - cannot rename directly, must DROP+ADD
- `audit.AuditResults.RiskScore` and `RiskLevel` are PERSISTED computed columns
- `audit.AuditResults` has ON DELETE CASCADE from `audit.Audits`
- `src.*` views use ERP Turkish column names - NEVER rename these
- SP parameters are Turkish even though tables/columns are English
- `ref.Users` and `audit.Users` are SEPARATE tables (ref=ERP users, audit=login users)
- Snapshot rule: ONE risk snapshot per day per location/product (new replaces old)
- Stock quantities: `decimal(18,3)`, NEVER float
- `ehAltDepo=0` only (P0 rule, non-zero triggers alarm)

## Migration Status
- FAZ 0: Project setup, Git init ✅
- FAZ 1: DB standardization (Turkish→English, dbo→audit) ✅
- FAZ 2: SP update + C# code alignment ← NEXT
- FAZ 3: RBAC + Auth
- FAZ 4: Missing features (DOF state machine, notifications, correlation, export)
- FAZ 5: Test + deploy
