# Güvenlik İlkeleri (BkmArgus)

Her değişiklikte uygulanacak defansif ilkeler. `paths:` yok — compact sonrası bile kalmalı.

## Mutlak Kurallar

1. **SQL Injection:** Tüm erişim SP + `CommandType.StoredProcedure` + named parameter. SP içinde dinamik SQL kaçınılmazsa `sp_executesql` + parametre; string birleştirme **YASAK**. Detay: `sql-conventions.md §3`.

2. **XSS:** Razor'da `@Html.Raw(userInput)` **YASAK**. Kullanıcı verisi daima `@variable` (auto-escape). Chart/JSON gömerken `System.Text.Json` + `JsonSerializer.Serialize` çıktısını `@Html.Raw` ile basmak yerine `<script type="application/json">` bloğuna yazıp JS'te `JSON.parse` et.

3. **CSRF:** Her `<form method="post">` Razor Pages otomatik antiforgery token alır — `asp-page-handler` ile kullan. Minimal API POST endpoint'leri (`/api/...`) `RequireAuthorization()` + aynı-origin fetch ile korunur; yeni endpoint eklerken CSRF vektörünü gerekçelendir.

4. **RBAC — sadece authentication YETMEZ.**
   - Roller: `Roles.Admin` (ADMIN) · `Roles.Yonetici` (YONETICI) · `Roles.Denetci` (DENETCI, DB varsayılanı)
   - Politikalar: `Policies.AdminOnly` · `Policies.YonetimVeUstu`
   - **Yeni sayfa eklerken varsayılan `@attribute [Authorize]`; yönetimsel/maliyetli ekran ise mutlaka policy ekle.**
   - Yetki kapısı **sayfa/endpoint seviyesinde** zorlanır; menüyü gizlemek yetki değildir (sadece UX).
   - Mevcut dağılım: Ref/Yonetim/Ayarlar → `AdminOnly`; Ai/Correlation + `/api/ai/skill/execute` → `YonetimVeUstu`.

5. **Sır/şifre yönetimi:**
   - Connection string ve API key → `BKM_DENETIM_CONN` ortam değişkeni **veya** `appsettings.Local.json` (gitignore'lu).
   - Takipli `appsettings.json` içinde plain-text şifre/anahtar **YASAK** — boş string bırakılır.
   - `.claude/settings.local.json` git'e girmez (izin listesinde connection string taşır).
   - Sır git geçmişine kaçtıysa: **anahtarı iptal et + rotate et**, sadece dosyadan silmek yetmez.

6. **Cookie güvenlik flag'leri** (`Program.cs`):
   ```csharp
   options.Cookie.HttpOnly     = true;
   options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
   options.Cookie.SameSite     = SameSiteMode.Lax;   // OAuth/dış redirect yoksa Strict'e çekilebilir
   ```

7. **Exception sızıntısı:** Kullanıcıya `ex.Message` gösterme — SqlException connection string sızdırır. Tek istisna: SP'nin `THROW 5xxxx` ile ürettiği Türkçe iş kuralı mesajı (`error-handling.md`).

8. **Kullanıcı sayımı (enumeration):** Login hatası tek tip — "Kullanici adi veya sifre hatali." "Kullanıcı bulunamadı" vs "şifre hatalı" ayrımı yapma.

9. **Password hashing:** BCrypt (`BCrypt.Net-Next`). Custom hash yazma, MD5/SHA1 yasak. Varsayılan admin şifresi kodda/UI'da **hardcoded olamaz** — ilk girişte `MustChangePassword` akışı zorunlu.

10. **Dosya yükleme:**
    - Uzantı beyaz listesi + boyut limiti **zorunlu** (mevcut: 10MB, `dof.Attachments`).
    - Dosya adı sunucuda **yeniden üretilir** (`{Id}_{Guid:N}{ext}`) — kullanıcı adı kullanılmaz (path traversal).
    - `wwwroot/uploads/` altındaki dosyalar **statik servis edilir** = auth'suz erişilebilir. Gizli belge yükleniyorsa auth-gated download handler yaz, `wwwroot` altına koyma.
    - MIME/içerik doğrulaması uzantı kontrolünün yerine geçmez; ikisi birlikte.

11. **Mass assignment:** PageModel'de `[BindNever]` kritik alanlarda (`Id`, `CreatedByUserId`, `Status`, `IsActive`). DTO/`record` bind et, DB satırını değil.

12. **Open redirect:** `LocalRedirect` kullanılıyor (iyi). Ham `Redirect(returnUrl)` yazarsan ek kontrol: `returnUrl.StartsWith("/") && !returnUrl.StartsWith("//")`.

13. **IDOR:** `dofId` / `auditId` / `executionId` alan her handler kaydın **çağıran kullanıcıya görünür olduğunu** SP seviyesinde doğrulamalı. `WHERE Id = @Id` yetmez — rol/mekan kapsamı da kontrol edilmeli.

14. **DB hesabı:** Uygulama `sa` ile bağlanmaz. Kendi login'i + yalnız gerekli şemalarda `EXECUTE` (bkz. `architecture.md §5` şema sorumlulukları).

## Audit Log Kapsamı

`audit.AuditLog` tablosuna yazılması zorunlu aksiyonlar:

- Login / logout / başarısız login (mevcut: `audit.sp_Auth_LoginFail` / `_LoginSuccess`)
- Şifre değişimi, hesap kilitleme
- Kullanıcı-rol create/update/delete
- Denetim finalize, DÖF durum geçişi, DÖF kapatma
- Referans tanım değişikliği (`ref.*`)
- ETL manuel tetikleme
- AI skill çalıştırma (maliyet izi) + AI insight onay/red
- Excel export

Loglanmazsa: bilmeyiz → audit gap.

## Security Review Ritüeli

1. **Yazım sırasında:** bu dosyayı uygula (proaktif)
2. **Commit öncesi:** `security-reviewer` ajanı (`.claude/agents/security-reviewer.md`)
3. **Büyük değişiklik sonrası:** `code-reviewer` + `security-reviewer` + `sql-sp-reviewer` paralel

## İlişkili

- `.claude/rules/sql-conventions.md` — parametreli sorgu, SP THROW
- `.claude/rules/error-handling.md` — mesaj sızıntısı
- `.claude/rules/architecture.md` — şema yazma hakları
- `.claude/agents/security-reviewer.md` — otomatik denetleyici
