/* =====================================================================
   55_semantic_layer_seed.sql — Semantik katman baslangic bilgisi
   Tarih   : 2026-08-20
   Bagimli : 53_semantic_layer.sql, 54_semantic_layer_sps.sql
   Amac    : BkmArgus'un bilinen sema gerceklerini semantik katmana yazar.
             Kaynak: CLAUDE.md + canli sema dogrulamasi (2026-08-20).
   Not     : Idempotent — upsert SP'leri uzerinden.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   AI HINTS — her sorgu/analiz uretiminde gecerli
   --------------------------------------------------------------------- */
DELETE FROM sem.AiHints WHERE Scope IN ('global', 'sql', 'ai');
GO

INSERT INTO sem.AiHints (Scope, Severity, HintText) VALUES
 ('global','kritik', N'src.* view''lari ERP soyutlamasidir — ASLA degistirilmez, kolonlari yeniden adlandirilmaz. SP icinde alias kullan.'),
 ('global','kritik', N'Tablo/kolon adlari INGILIZCE PascalCase; SP parametreleri TURKCE (@MekanId, @BaslangicTarih). Ikisini karistirma.'),
 ('sql',   'kritik', N'GETDATE() KULLANMA -> SYSDATETIME(). datetime KULLANMA -> datetime2(0).'),
 ('sql',   'kritik', N'Miktar/stok decimal(18,3), para decimal(18,4). float/real YASAK.'),
 ('sql',   'uyari',  N'SELECT * yasak — kolonlari acikca yaz.'),
 ('sql',   'uyari',  N'SARGable WHERE: YEAR(SnapshotDate)=2026 yerine SnapshotDate >= ''20260101'' AND < ''20270101''.'),
 ('sql',   'kritik', N'rpt.DailyProductRisk PK = SnapshotDate + LocationId + ProductId + PeriodCode. SnapshotDate GUN seviyesinde (saat yok) yazilir.'),
 ('sql',   'uyari',  N'SnapshotDay PERSISTED computed kolondur (SnapshotDate''ten turer) — dogrudan yazilamaz/rename edilemez.'),
 ('sql',   'uyari',  N'audit.AuditResults.RiskScore ve RiskLevel PERSISTED computed — dogrudan UPDATE edilemez.'),
 ('sql',   'kritik', N'ehAltDepo = 0 kurali (P0). Sifir disi deger sessizce filtrelenmez, etl.DataQualityIssues''a alarm yazilir.'),
 ('sql',   'uyari',  N'Yazma yapan SP: SET NOCOUNT ON + SET XACT_ABORT ON + BEGIN TRY/CATCH + acik transaction. Is kurali hatasi THROW 50000-59999 araliginda, mesaj TURKCE.'),
 ('ai',    'kritik', N'LLM sayisal deger URETMEZ. Risk skoru/tutar/adet deterministik katmandan (SQL) gelir; LLM yalnizca anlati/gerekce yazar.'),
 ('ai',    'kritik', N'AI onerir, INSAN karar verir. AI kendi basina DOF acmaz, denetim kapatmaz, durum degistirmez.'),
 ('ai',    'uyari',  N'Kademeli maliyet: LM Rules -> Semantic Memory (cosine > 0.85) -> LLM. LLM son caredir.'),
 ('ai',    'uyari',  N'Kapali LLM saglayicisi sessizce atlanir, exception atmaz. API key yoksa saglayici kapali sayilir.');
GO

/* ---------------------------------------------------------------------
   DATABASES
   --------------------------------------------------------------------- */
MERGE sem.Databases AS t
USING (VALUES
  ('BKMDenetim',  N'BkmArgus ana veritabani — denetim, risk, DOF, AI', N'Yerel (SYSDATETIME), datetime2(0)', NULL, NULL,
   N'8 sema: src(view-only) ref audit rpt dof ai log etl + sem(semantik katman). SQL Server 2019.', 1.00, N'Canli dogrulama 2026-08-20 — sys.schemas/sys.tables sayimi'),
  ('DerinSISBkm', N'ERP kaynak sistemi (ayni sunucu, cross-DB)', N'ERP Turkce kolon adlari', NULL, NULL,
   N'YALNIZCA src.* view''lari uzerinden erisilir. SP icinde dogrudan DerinSISBkm.dbo.X yazma YASAK.', 1.00, N'CLAUDE.md mimari karari + 53 nolu migration')
) AS s (DbName, Role, DateFormat, CompatLevel, Unavailable, Note, Confidence, Evidence)
ON t.DbName = s.DbName
WHEN MATCHED THEN UPDATE SET Role = s.Role, DateFormat = s.DateFormat, Note = s.Note,
     Confidence = s.Confidence, Evidence = s.Evidence, LastVerifiedAt = CAST(SYSDATETIME() AS date), UpdatedAt = SYSDATETIME()
WHEN NOT MATCHED THEN INSERT (DbName, Role, DateFormat, CompatLevel, Unavailable, Note, Confidence, Evidence, LastVerifiedAt)
     VALUES (s.DbName, s.Role, s.DateFormat, s.CompatLevel, s.Unavailable, s.Note, s.Confidence, s.Evidence, CAST(SYSDATETIME() AS date));
GO

/* ---------------------------------------------------------------------
   ENTITIES — omurga tablolar
   --------------------------------------------------------------------- */
EXEC sem.sp_Entity_Upsert 'rpt.DailyProductRisk', 'BKMDenetim', 'rpt', 'DailyProductRisk', 'TABLE',
     'SnapshotDate,LocationId,ProductId,PeriodCode',
     'SnapshotDate,SnapshotDay,LocationId,ProductId,PeriodCode,RiskScore,RiskLevel',
     N'Bir satir = bir gun + bir mekan + bir urun + bir periyot. Gunde TEK snapshot; yeni kayit eskisini DEGISTIRIR.',
     N'43 kolon. SnapshotDay PERSISTED computed (SnapshotDate bagimli) — rename icin DROP+ADD gerekir. En buyuk tablo (~66k satir/gun).',
     1.00, N'Canli dogrulama 2026-08-20: 65.960 satir. PK''ya PeriodCode eklenmesi commit ebceeeb ile duzeltildi.';

EXEC sem.sp_Entity_Upsert 'audit.Audits', 'BKMDenetim', 'audit', 'Audits', 'TABLE', 'Id',
     'Id,LocationId,AuditDate,Status,CreatedByUserId',
     N'Bir satir = bir saha denetimi.',
     N'audit.AuditResults bu tabloya ON DELETE CASCADE bagli — denetim silinince sonuclar da silinir.',
     1.00, N'Canli dogrulama 2026-08-20';

EXEC sem.sp_Entity_Upsert 'audit.AuditResults', 'BKMDenetim', 'audit', 'AuditResults', 'TABLE', 'Id',
     'Id,AuditId,AuditItemId,RiskScore,RiskLevel',
     N'Bir satir = bir denetimdeki bir kontrol maddesinin sonucu.',
     N'RiskScore ve RiskLevel PERSISTED computed kolonlardir — dogrudan UPDATE edilemez.',
     1.00, N'CLAUDE.md gotchas + canli dogrulama 2026-08-20';

EXEC sem.sp_Entity_Upsert 'dof.Findings', 'BKMDenetim', 'dof', 'Findings', 'TABLE', 'Id',
     'Id,LocationId,Status,Priority,DueDate,CreatedByUserId',
     N'Bir satir = bir DOF bulgusu. Iki kanal (ERP risk + saha denetimi) burada birlesir.',
     N'Durum gecisleri dof.sp_Finding_Transition SP''sinde merkezi — UI''da dagitilmis if/else YAZMA.',
     0.95, N'Canli dogrulama 2026-08-20: 84 satir, dof.StatusHistory 104 satir';

EXEC sem.sp_Entity_Upsert 'src.vw_StokHareket', 'DerinSISBkm', 'src', 'vw_StokHareket', 'VIEW', NULL,
     'ehMekanId,ehStokId,ehAltDepo,ehTip,ehTarih,ehMiktar',
     N'Bir satir = bir ERP stok hareketi.',
     N'DOKUNULMAZ. ERP Turkce kolon adlari tasir; SP icinde alias zorunlu: ehMekanId AS LocationId, ehStokId AS ProductId. ehAltDepo=0 P0 kurali.',
     1.00, N'CLAUDE.md mimari karari — src.* view''lari degistirilmez';

EXEC sem.sp_Entity_Upsert 'ref.SemanticDefinitions', 'BKMDenetim', 'ref', 'SemanticDefinitions', 'TABLE', 'Id',
     'TermType,BusinessName,TechnicalName,Aliases,Category',
     N'Bir satir = bir is terimi <-> teknik ad eslesmesi.',
     N'IS sozlugu. sem.* ise SEMA sozlugudur — ikisi tamamlayici, ayni sey degil.',
     0.90, N'Canli dogrulama 2026-08-20: 31 satir';

EXEC sem.sp_Entity_Upsert 'ai.Skills', 'BKMDenetim', 'ai', 'Skills', 'TABLE', 'SkillId',
     'SkillId,Name,Category,TriggerMode,CurrentVersion,IsActive',
     N'Bir satir = bir AI skill tanimi. Prompt''lar ai.SkillVersions''ta versiyonlu.',
     N'audit.Skills FARKLI tablodur (denetim yetkinlik alanlari) — karistirma.',
     1.00, N'2026-08-20 migration 51 ile olusturuldu, migration 52 ile 10 denetim skill''i seed edildi';
GO

/* ---------------------------------------------------------------------
   BRIDGES — kritik join''ler
   --------------------------------------------------------------------- */
EXEC sem.sp_Bridge_Upsert 'risk-mekan',
     'rpt.DailyProductRisk.LocationId', 'ref.LocationSettings.LocationId',
     N'JOIN ref.LocationSettings ls ON ls.LocationId = r.LocationId',
     'bkmdenetim', '1-N',
     N'Risk snapshot -> mekan tanimi. Mekan adi buradan gelir (Insight location name fix, commit 501aa4b).',
     1.00, N'Canli dogrulama 2026-08-20';

EXEC sem.sp_Bridge_Upsert 'erp-risk-mekan',
     'src.vw_StokHareket.ehMekanId', 'ref.LocationSettings.LocationId',
     N'JOIN ref.LocationSettings ls ON ls.LocationId = sh.ehMekanId',
     'crossdb', 'N-1',
     N'ERP hareket -> BkmArgus mekan. ERP Turkce kolonu alias''lanir: sh.ehMekanId AS LocationId.',
     0.95, N'ETL SP''lerinde kullanilan standart desen — 2026-08-20 dogrulandi';

EXEC sem.sp_Bridge_Upsert 'dof-audit',
     'dof.Findings.SourceAuditId', 'audit.Audits.Id',
     N'LEFT JOIN audit.Audits a ON a.Id = f.SourceAuditId',
     'bkmdenetim', 'N-1',
     N'DOF bulgusu -> kaynak saha denetimi. NULL ise bulgu ERP risk kanalindan gelmis demektir (iki kanal ayrimi).',
     0.70, N'sql/43_audit_to_dof_pipeline.sql — kolon adi canli sema ile teyit edilmeli',
     'teyit bekliyor';

EXEC sem.sp_Bridge_Upsert 'dof-gecmis',
     'dof.StatusHistory.FindingId', 'dof.Findings.Id',
     N'JOIN dof.StatusHistory h ON h.FindingId = f.Id ORDER BY h.CreatedAt',
     'bkmdenetim', '1-N',
     N'DOF -> durum gecis gecmisi. SLA hesabi ve eskalasyon izi buradan.',
     0.90, N'Canli dogrulama 2026-08-20: 104 satir, 84 bulgu';

EXEC sem.sp_Bridge_Upsert 'skill-surum',
     'ai.SkillExecutions.SkillId', 'ai.Skills.SkillId',
     N'JOIN ai.Skills s ON s.SkillId = e.SkillId LEFT JOIN ai.SkillVersions v ON v.SkillId = e.SkillId AND v.VersionNo = e.SkillVersionNo',
     'bkmdenetim', 'N-1',
     N'Calistirma -> skill + kullanilan prompt surumu. Hangi ciktinin hangi prompt''la uretildigi bu koprüden izlenir.',
     1.00, N'2026-08-20 migration 51 ile kuruldu (SkillVersionNo kolonu eklendi)';
GO

/* ---------------------------------------------------------------------
   CODE SETS
   --------------------------------------------------------------------- */
EXEC sem.sp_CodeSet_Upsert 'audit.Users.RoleCode', N'Kullanici Rolu', NULL, NULL,
     N'DB varsayilani DENETCI. C# karsiligi: BkmArgus.Web.Security.Roles.', 1.00,
     N'sql/35_migration_auth.sql + Security/Roles.cs — 2026-08-20';
EXEC sem.sp_CodeValue_Upsert 'audit.Users.RoleCode', 'ADMIN',   N'Yonetici (tam yetki)', N'Ref/Yonetim/Ayarlar ekranlari';
EXEC sem.sp_CodeValue_Upsert 'audit.Users.RoleCode', 'YONETICI',N'Birim yoneticisi',      N'AI/Korelasyon ekranlari, LLM tetikleme';
EXEC sem.sp_CodeValue_Upsert 'audit.Users.RoleCode', 'DENETCI', N'Denetci (varsayilan)',  N'Dashboard/Risk/DOF/Denetim';

EXEC sem.sp_CodeSet_Upsert 'rpt.DailyProductRisk.PeriodCode', N'Risk Periyodu', NULL, NULL,
     N'PK''nin parcasi — ayni gun farkli periyotlar yan yana durur. Eksikse periyotlar birbirini ezer.', 0.90,
     N'Canli dogrulama 2026-08-20 + commit ebceeeb';
EXEC sem.sp_CodeValue_Upsert 'rpt.DailyProductRisk.PeriodCode', 'Son30Gun', N'Son 30 gun', NULL;
EXEC sem.sp_CodeValue_Upsert 'rpt.DailyProductRisk.PeriodCode', 'Son90Gun', N'Son 90 gun', NULL;

EXEC sem.sp_CodeSet_Upsert 'ai.SkillExecutions.Status', N'AI Calistirma Durumu', NULL, NULL,
     N'Kuyruk durumu. Kapali saglayici nedeniyle atlanan is FAILED degil SKIPPED olmali.', 0.80,
     N'AiWorker kod incelemesi 2026-08-20';
EXEC sem.sp_CodeValue_Upsert 'ai.SkillExecutions.Status', 'PENDING', N'Beklemede', NULL;
EXEC sem.sp_CodeValue_Upsert 'ai.SkillExecutions.Status', 'RUNNING', N'Calisiyor', NULL;
EXEC sem.sp_CodeValue_Upsert 'ai.SkillExecutions.Status', 'DONE',    N'Tamamlandi', NULL;
EXEC sem.sp_CodeValue_Upsert 'ai.SkillExecutions.Status', 'FAILED',  N'Basarisiz', N'Gercek hata';
GO

/* ---------------------------------------------------------------------
   METRICS — tuzaklariyla birlikte
   --------------------------------------------------------------------- */
EXEC sem.sp_Metric_Upsert 'risk_skoru', N'Urun Risk Skoru',
     N'rpt.DailyProductRisk.RiskScore — ref.RiskScoreWeights agirliklariyla, ref.RiskParameters esiklerine gore SQL katmaninda hesaplanir.',
     N'Aktif risk flag''lerinin agirlikli toplami, 0-100 araligina normalize edilir.',
     N'TUZAK 1: LLM bu skoru URETMEZ, sadece aciklar. TUZAK 2: Agirliklar (ref.RiskScoreWeights) degisirse GECMIS snapshot''lar yeniden hesaplanmaz — donemler arasi karsilastirma yanilticidir. TUZAK 3: Skor mekan buyuklugune gore normalize DEGILDIR; buyuk magazada 60 normalken kucukte anormal olabilir.',
     'puan (0-100)', 0.85,
     N'ref.RiskScoreWeights 10 satir, ref.RiskParameters 7 satir — canli dogrulama 2026-08-20';

EXEC sem.sp_Metric_Upsert 'dof_sla_gun', N'DOF SLA Gun Sayisi',
     N'dof.Findings.DueDate ile dof.StatusHistory gecis kayitlari.',
     N'Acilis ile kapanis arasindaki gun farki; beklemede gecen sure duraklatilmali.',
     N'TUZAK 1: SLA saatinin hangi statude DURDUGU tanimlanmadiysa metrik yalan soyler. TUZAK 2: Is gunu mu takvim gunu mu belirsiz — tatil takvimi yok. TUZAK 3: SLA kurali degisirse gecmis kayitlar hangi kuralla olculuyor? Snapshot alinmiyorsa gecmis rapor degisir.',
     'gun', 0.50,
     N'dof.StatusHistory yapisi var ama duraklatma kurali kodda dogrulanmadi — 2026-08-20',
     'teyit bekliyor';

EXEC sem.sp_Metric_Upsert 'tekrar_eden_bulgu', N'Tekrar Eden Bulgu',
     N'audit.sp_Analysis_DetectRepeats + audit.AuditResults gecmisi.',
     N'Ayni mekan + ayni kontrol maddesi icin birden fazla donemde basarisiz sonuc.',
     N'TUZAK: "Tekrar" tanimi pencereye baglidir (12 ay mi, 3 denetim mi). Pencere degisirse sayi degisir — raporda pencereyi mutlaka belirt.',
     'adet', 0.70,
     N'audit.sp_Analysis_DetectRepeats mevcut — pencere parametresi kodda dogrulanmadi',
     'teyit bekliyor';
GO

/* ---------------------------------------------------------------------
   GOLDEN SQL
   --------------------------------------------------------------------- */
EXEC sem.sp_Query_Upsert 'mekan-bazli-ortalama-risk',
     N'Mekan bazinda ortalama risk skoru (belirli periyot)',
     N'SELECT r.LocationId, ls.Description AS MekanAdi, COUNT(*) AS UrunSayisi, AVG(r.RiskScore) AS OrtRisk
FROM rpt.DailyProductRisk r
LEFT JOIN ref.LocationSettings ls ON ls.LocationId = r.LocationId
WHERE r.PeriodCode = ''Son30Gun''
  AND r.SnapshotDate = (SELECT MAX(SnapshotDate) FROM rpt.DailyProductRisk WHERE PeriodCode = ''Son30Gun'')
GROUP BY r.LocationId, ls.Description',
     'risk_skoru', 'risk-mekan',
     N'PeriodCode filtresi ZORUNLU — yoksa periyotlar toplanip ortalama bozulur.',
     0.90, N'Canli calistirildi 2026-08-20 — 65.960 satirlik veri uzerinde';

EXEC sem.sp_Query_Upsert 'acik-dof-sla-asimi',
     N'Acik DOF''lar icinde SLA suresi asilmis olanlar',
     N'SELECT f.Id, f.LocationId, ls.Description AS MekanAdi, f.Status, f.DueDate,
       DATEDIFF(day, f.DueDate, CAST(SYSDATETIME() AS date)) AS GecikmeGun
FROM dof.Findings f
LEFT JOIN ref.LocationSettings ls ON ls.LocationId = f.LocationId
WHERE f.Status NOT IN (''KAPANDI'', ''IPTAL'')
  AND f.DueDate < CAST(SYSDATETIME() AS date)',
     'dof_sla_gun', 'risk-mekan',
     N'Statu kod kumesi canli veriyle teyit edilmeli (KAPANDI/IPTAL degerleri).',
     0.60, N'Yapisal olarak dogru, statu degerleri canli teyit bekliyor — 2026-08-20',
     NULL, NULL;
GO

/* ---------------------------------------------------------------------
   Dogrulama
   --------------------------------------------------------------------- */
SELECT 'Databases' AS Katman, COUNT(*) AS Adet FROM sem.Databases
UNION ALL SELECT 'Entities',  COUNT(*) FROM sem.Entities
UNION ALL SELECT 'Bridges',   COUNT(*) FROM sem.Bridges
UNION ALL SELECT 'CodeSets',  COUNT(*) FROM sem.CodeSets
UNION ALL SELECT 'CodeValues',COUNT(*) FROM sem.CodeValues
UNION ALL SELECT 'Metrics',   COUNT(*) FROM sem.Metrics
UNION ALL SELECT 'Queries',   COUNT(*) FROM sem.Queries
UNION ALL SELECT 'AiHints',   COUNT(*) FROM sem.AiHints;
GO

PRINT '55_semantic_layer_seed.sql tamamlandi.';
GO
