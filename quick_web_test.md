# Web Installer Test Rehberi

## 🚀 Hızlı Test

1. **Installer'ı başlat:**
   ```bash
   dotnet run --project src/BkmDenetim.Installer/BkmDenetim.Installer.csproj
   ```

2. **Menüden seç:**
   - "Web Interface (Detaylı Kurulum)" seçeneğini seç

3. **Tarayıcıda test et:**
   - Otomatik olarak http://localhost:5555 açılacak
   - Sistem durumu kartını kontrol et
   - Console'da hata mesajları var mı kontrol et (F12)

## 🔧 Düzeltilen Sorunlar

### JavaScript Hatası Düzeltildi:
- ✅ `status.Schemas` undefined hatası çözüldü
- ✅ Güvenli erişim için default değerler eklendi
- ✅ Console debug logları eklendi
- ✅ API response format kontrolü eklendi

### Static Files Düzeltildi:
- ✅ wwwroot path'i düzeltildi
- ✅ File provider ayarlandı
- ✅ 404 handling eklendi

## 📊 Beklenen Sonuç

Web arayüzünde şunları göreceksiniz:
- ✅ Sistem durumu kartı
- ✅ Veritabanı bağlantı durumu
- ✅ Şema listesi (src, ref, rpt, dof, ai, log, etl)
- ✅ Stored procedure sayıları
- ✅ Kurulum seçenekleri (Tam/Seçmeli)
- ✅ Gerçek zamanlı log konsolu

## 🐛 Sorun Giderme

Eğer hala hata alıyorsanız:

1. **Console'da F12 açın** ve Network/Console tablarını kontrol edin
2. **API endpoint'ini test edin:** http://localhost:5555/api/status
3. **Log mesajlarını kontrol edin** installer console'unda

## 🎯 Test Adımları

1. Sistem durumu kartının yeşil olduğunu kontrol edin
2. "Tam Kurulum" kartına tıklayın
3. "Kurulumu Başlat" butonunun aktif olduğunu kontrol edin
4. Log konsolunda mesajların göründüğünü kontrol edin