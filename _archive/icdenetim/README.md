# İç Denetim Sistemi

ASP.NET Core Razor Pages + SQL Server + Dapper ile iç denetim yönetim sistemi.

## Kurulum

### 1. Veritabanı

SQL Server'da `Data/Schema.sql` dosyasını çalıştırın:

```bash
sqlcmd -S . -d master -i Data/Schema.sql
```

veya SSMS üzerinden `master` veritabanına bağlanıp script'i çalıştırın.

### 2. Bağlantı Dizesi

- **Development:** `appsettings.Development.json` varsayılan olarak LocalDB kullanır: `Server=(localdb)\mssqllocaldb`
- **Production:** `appsettings.json` içinde `Server=.` veya SQL Server adresinizi belirtin

### 3. Çalıştırma

```bash
dotnet run
```

**Ağdan erişim (telefon/tablet ile):**
```bash
dotnet run --launch-profile Network
```
veya Visual Studio/Cursor'da profil olarak **Network** seçin. Uygulama `http://0.0.0.0:5169` üzerinden dinler. Diğer cihazlardan erişim için:
- Bilgisayarın IP adresini öğrenin: `ipconfig` (Windows) veya `hostname -I` (Linux)
- Tarayıcıda açın: `http://[BILGISAYAR_IP]:5169` (örn: `http://192.168.1.100:5169`)
- Windows Güvenlik Duvarı portu engelliyorsa: Gelişmiş güvenlik duvarı → Gelen kurallar → Yeni kural → Bağlantı noktası 5169 (TCP)

İlk çalıştırmada admin kullanıcısı otomatik oluşturulur:
- **E-posta:** fikri.eren@bkmkitap.com
- **Şifre:** 123456

### 4. Denetim Maddeleri

Denetim maddeleri boşsa önce **Denetim Maddeleri** sayfasından madde ekleyin veya Excel'den import edin.

## Sayfalar

- **Denetimler** - Denetim listesi, yeni denetim oluşturma, düzenleme (EVET/HAYIR), fotoğraf ekleme
- **Denetim Maddeleri** - Master madde listesi (CRUD)
- **Raporlar** - Özet rapor, karne raporları
