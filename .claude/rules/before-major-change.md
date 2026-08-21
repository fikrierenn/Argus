# Büyük Değişiklik Öncesi Kurallar

Bu dosya, BkmArgus projesinde yapılacak büyük çaplı kod, rota veya veritabanı şeması değişikliklerinden (refactoring, dosya silme, yeniden adlandırma, tablo değişiklikleri vb.) önce yapılması gereken kontrolleri tanımlar. Beklenmeyen derleme ve çalışma zamanı hatalarını (runtime errors) önlemek için bu kurallara uyulması zorunludur.

---

## 1. Referans Arama ve Doğrulama

Büyük bir değişiklik yapmadan önce, etkilenecek tüm dosya ve referanslar `grep_search` kullanılarak taranmalıdır:

1.  **Metot / Sınıf Silme veya Yeniden Adlandırma (Rename):**
    *   Değiştirilecek sınıf veya metot adının tüm projede nerelerde kullanıldığı (`Features/`, `Lib/` klasörleri dahil) sorgulanmalıdır.
2.  **Model / DTO Değişiklikleri:**
    *   Veritabanı tablosundaki bir kolon adı veya DTO property'si değiştirildiğinde, bu property'yi kullanan tüm PageModel (`.cshtml.cs`) ve View (`.cshtml`) dosyaları bulunmalı ve güncellenmelidir.
3.  **Rota (Route) Kaldırma veya Değiştirme:**
    *   Razor Page URL yapısı veya sayfa yönlendirmesi (`RedirectToPage`) değiştirilmeden önce, eski rotayı çağıran form `action` etiketleri, `a href` linkleri ve yönlendirme komutları güncellenmelidir.

---

## 2. Şema ve Migration Değişiklikleri

Veritabanında yapılacak şema güncellemelerinden önce:

1.  **Geriye Dönük Uyumluluk (Backward Compatibility):**
    *   Silinecek veya değiştirilecek kolonun mevcut canlı sistemlerde veri kaybına yol açıp açmayacağı değerlendirilmelidir.
    *   Eğer bir kolon ikiye bölünecekse veya tipi değişecekse, veriyi dönüştüren geçici bir migration script'i tasarlanmalıdır.
2.  **Stored Procedure ve View Etkisi:**
    *   Tablo şeması değiştiğinde, o tabloyu okuyan Stored Procedure (`sql/db_objects.sql`) ve SQL View tanımları güncellenmelidir. `CREATE OR ALTER` ile bu nesneler veritabanına yeniden yüklenmelidir.

---

## 3. Güvenli Aşamalı Geçiş Planı

Büyük çaplı değişikliklerde tek bir devasa commit yerine **aşamalara bölünmüş (incremental)** geçiş planı uygulanmalıdır:

1.  **Aşama 1 (Veritabanı):** Önce veritabanı şeması ve nesneleri güncellenir.
2.  **Aşama 2 (DTO & Core):** `Lib/` altındaki ortak sınıflar ve DTO'lar yeni şemaya göre güncellenir.
3.  **Aşama 3 (PageModels & Lojik):** Backend lojikleri ve PageModel sınıfları adapte edilir.
4.  **Aşama 4 (Views & Arayüz):** Arayüzler (`.cshtml`) ve JavaScript kodları yenilenir.
5.  **Aşama 5 (Doğrulama):** `dotnet build` çalıştırılarak 0 hata ve 0 uyarı alındığı doğrulanır.

---

## 4. İlk Dokunuş Kuralı — Fact-Force Gate (ECC pattern)

**Bir dosyayı bu oturumda İLK KEZ değiştirmeden önce** (Edit/Write):
1. Dosyayı OKU (en azından değiştireceğin bölge + çevre 50 satır).
2. Feature klasöründeki benzer dosyaya bak — pattern'i taklit et (kendi stilini dayatma).
3. SP/SQL değişikliğiyse `sql/db_objects.sql`'de mevcut tanımı oku.
4. Emin olmadığın davranışı varsayma — Grep ile çağıranları tara.

**Gerekçe:** Okumadan yapılan ilk edit, var olan pattern'i kırar ve sessiz regresyon üretir. "Dosya küçük, direkt yazarım" istisna değildir.

---

## 5. Şema Varsayma — SOR (2026-08-21 dersi)

Bir DB nesnesine referans veren SQL veya C# yazmadan **önce** gerçek şemayı sorgula. Tahmin etme.

Tek oturumda dört kez varsayıp dört kez yanıldık:

| Varsayım | Gerçek | Sonuç |
|---|---|---|
| `audit.AuditItems.Title` var | Kolon `ItemText` | Migration patladı |
| `sys.columns.max_length = 400` → 400 karakter | **Bayt** cinsinden; nvarchar'da 200 karakter | "String or binary data truncated" |
| `ai.LlmResults.PromptText` opsiyonel | `NOT NULL` | Her yazma başarısız |
| SP çağrılarını regex ile konumdan eşleştir | Ollama metoduna Gemini adı yazıldı | Yanlış sağlayıcı kaydı |

**Kural:** aşağıdakileri yazmadan önce sorgula —

```sql
-- Kolon adlari, tipleri, NULL kabulu, GERCEK karakter uzunlugu
SELECT c.name, ty.name AS Tip,
       CASE WHEN ty.name LIKE 'n%char' THEN c.max_length/2 ELSE c.max_length END AS Karakter,
       c.is_nullable, dc.definition AS Varsayilan
FROM sys.columns c
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
WHERE c.object_id = OBJECT_ID('sema.Tablo')
ORDER BY c.column_id;
```

`nvarchar`/`nchar` için `max_length` **bayttır** — karakter sayısı yarısıdır. `varchar` için eşittir. `-1` = `max`.

SP değiştirmeden önce mevcut tanımı oku:
```sql
SELECT m.definition FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id WHERE o.name = 'sp_Adi';
```

**Regex ile toplu kod değişikliği yasak** — birden fazla çağrı noktası varsa her birini ayrı ayrı, kapsayan metodu doğrulayarak değiştir. Konumdan eşleştirme sessiz yanlış üretir.
