# Kodlama Disiplini Kuralları

Bu dosya, BkmArgus projesinin kod yazımı, kalitesi, güvenlik kuralları ve yorum satırı standartlarını tanımlar. Kodun temiz, okunabilir ve güvenli kalması için bu disiplin kurallarına uyulması zorunludur.

---

## 1. Kod İçi Türkçe Yorum Satırı Standardı (ZORUNLU)

Tüm `.cs` ve `.cshtml.cs` dosyalarında **Türkçe yorum** yazılması zorunludur.

### Yorum Yazılacak Alanlar ve Kurallar:
1.  **Metot Başları:** Her metodun en başında ne iş yaptığını açıklayan 1-2 satırlık açıklayıcı yorum bulunmalıdır.
2.  **İş Kuralları (Business Rules):** Kritik kontrol noktalarında hangi iş kuralının uygulandığı belirtilmelidir (`// İş kuralı: Negatif stok kontrolü yapılır`).
3.  **Karmaşık SQL Sorguları:** Sorgunun amacı ve varsa JOIN/FIFO öncelikleri açıklanmalıdır.
4.  **Transaction ve Guard Clause'lar:** Erken dönüşlerin (`return`) ve transaction bloklarının amacı belirtilmelidir.
5.  **İngilizce Yorum Yasağı:** Kod içinde İngilizce açıklama satırı yazılmamalıdır.

---

## 2. 80 Satır Eşiği ve Refactoring

1.  **Metot Uzunluk Sınırı (80 Satır):**
    *   Bir C# metodu (örneğin bir `OnPostAsync` veya helper metot) süslü parantezler dahil **80 satırı** aşmamalıdır.
    *   **Aksiyon:** 80 satırı aşan metotlar, mantıksal alt parçalara ayrıştırılarak `private` helper metotlara çıkarılmalıdır.
2.  **Drive-by Refactoring Yasağı:**
    *   Üzerinde çalışılan görevle ilgisi olmayan, spekülatif veya keyfi refactoring'ler (kod sadeleştirmeleri, altyapı değişiklikleri) yapılamaz.
    *   Yalnızca görev kapsamında değiştirilen kodlar temizlenir ve kurallara uygun hale getirilir.

---

## 3. Guard Clauses (Erken Dönüş)

*   Kod yazımında iç içe geçmiş `if` bloklarından (nested if) kaçınılmalıdır.
*   Geçersiz koşullar, yetki kontrolleri ve null durumlar metodun en başında **Guard Clause** kullanılarak elenmeli ve metottan erken dönülmelidir (`return`, `NotFound()`, `BadRequest()`).
*   Örnek:
    ```csharp
    // Is kurali: denetim yoksa islem yapilmaz
    var audit = await _db.QuerySingleAsync<AuditRow>("audit.sp_Audit_Get", new { DenetimId = id });
    if (audit is null) return NotFound();

    // Is kurali: tamamlanmis denetim tekrar finalize edilemez
    if (audit.Status == AuditStatus.Tamamlandi) return BadRequest("Denetim zaten tamamlanmis.");
    ```

---

## 4. Güvenlik — Kullanıcı Girdisi Değerlendirme

*   `DataTable.Compute()` ve `eval` benzeri dinamik değerlendirme **yasak** (formül/SQL injection).
*   Risk parametreleri (`ref.RiskParameters`, `ref.RiskScoreWeights`) kullanıcı tarafından düzenlenebilir — bu değerler hesaplamada **sayısal parametre** olarak kullanılır, ifade olarak değerlendirilmez.
*   Dinamik kolon/tablo adı gerekiyorsa **beyaz liste** zorunlu.

---

## 5. Domain Danışmanına Danışma (ZORUNLU)

İş bir danışman alanına giriyorsa üretmeden **ÖNCE** eşleşen danışmana danışılır (`.claude/rules/advisor-skills.md`). Danışılmadan yazılan risk-skorlama / ETL / AI / denetim işi **eksik** sayılır.

| Konu | Danışman |
|---|---|
| Risk skorlama, eşik, ağırlık, eskalasyon | `bkmargus-risk-model` (skill) |
| ETL / snapshot / veri kalitesi | `bkmargus-etl` (skill) |
| AI katmanı, prompt, skill, sağlayıcı | `bkmargus-ai-worker` (skill) |
| SP / migration / şema | `bkmargus-sp-first` · `sql-migration-writer` |
| Denetim süreci, DÖF, SLA | `denetim-surec-danismani` (agent) |
| Ekran akışı / UX | `screen-ux-standard` (skill) |
| Yüksek belirsizlik + yüksek maliyet karar | `llm-council` (skill) |
