---
description: "Audit analysis pipeline'ini test et - DB uzerinde"
---

Audit analysis pipeline'ini DB uzerinde test et:

1. **Test verisi olustur (yoksa):**
   - audit.Audits'e test denetimi ekle (TEST_ prefix)
   - audit.AuditResults'e basarisiz sonuclar ekle
   - 3 farkli lokasyonda ayni maddeyi basarisiz yap (sistemik test)

2. **Pipeline calistir:**
   EXEC audit.sp_Analysis_FullPipeline @AuditId=<test_audit_id>

3. **Dogrula:**
   - RepeatCount dogru mu? (ayni madde + ayni lokasyon + onceki denetimler)
   - IsSystemic dogru mu? (3+ lokasyonda basarisiz)
   - FirstSeenAt/LastSeenAt set mi?
   - DOF effectiveness check calisti mi?
   - ai.AnalysisQueue'ya kayit eklendi mi?

4. **Sonuclari raporla:**
   | Test | Beklenen | Gerceklesen | Durum |
   |------|----------|-------------|-------|

5. **Temizle (opsiyonel):**
   Test verilerini sil (TEST_ prefix'li kayitlar)

$ARGUMENTS
