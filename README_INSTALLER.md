# BKM Denetim AI V2 Installer

Bu installer, BKM Denetim AI V2 Enhancement System'i otomatik olarak kurmak için geliştirilmiştir.

## 🚀 Özellikler

### Console Installer (Hızlı Kurulum)
- ✅ Renkli ve interaktif console arayüzü
- ✅ Gerçek zamanlı kurulum logları
- ✅ Tam kurulum ve seçmeli kurulum seçenekleri
- ✅ Otomatik sistem durumu kontrolü
- ✅ Kurulum doğrulaması

### Web Interface (Detaylı Kurulum)
- 🌐 Modern web tabanlı arayüz
- 📊 Gerçek zamanlı sistem durumu dashboard'u
- 🎯 Bileşen bazlı seçmeli kurulum
- 📝 Detaylı kurulum logları
- ✅ Otomatik tarayıcı açma

## 📦 Kurulum Bileşenleri

1. **Şemalar** - Veritabanı şemalarını oluşturur (src, ref, rpt, dof, ai, log, etl)
2. **Tablolar** - AI ve ETL tablolarını oluşturur
3. **ETL System** - ERP entegrasyon stored procedure'larını kurar
4. **AI V2 System** - AI enhancement sistemini kurar

## 🛠️ Kullanım

### Console Installer
```bash
cd src/BkmDenetim.Installer
dotnet run
```

Kurulum seçenekleri:
- **Console (Hızlı Kurulum)** - Terminal tabanlı hızlı kurulum
- **Web Interface (Detaylı Kurulum)** - Tarayıcı tabanlı detaylı kurulum
- **Sistem Durumu Kontrolü** - Mevcut kurulumu kontrol eder

### Web Installer
Web installer seçildiğinde otomatik olarak http://localhost:5555 adresinde açılır.

## 📋 Sistem Gereksinimleri

- .NET 8.0 SDK
- SQL Server (mevcut BKMDenetim veritabanı)
- Windows işletim sistemi

## 🔧 Konfigürasyon

Bağlantı ayarları `appsettings.json` dosyasında tanımlıdır:

```json
{
  "ConnectionStrings": {
    "BkmDenetim": "Server=192.168.40.201;Database=BKMDenetim;User Id=sa;Password=***;TrustServerCertificate=True"
  }
}
```

## 📊 Kurulum Sonrası

Kurulum tamamlandıktan sonra:

1. ✅ Tüm şemalar oluşturulur
2. ✅ AI ve ETL tabloları hazır olur
3. ✅ Stored procedure'lar kurulur
4. ✅ AI Worker servisi başlatılabilir

## 🔍 Sorun Giderme

### Yaygın Hatalar

**JSON_OBJECT hatası**: SQL Server 2022 öncesi sürümlerde normal, sistem çalışmaya devam eder.

**Bağlantı hatası**: `appsettings.json` dosyasındaki bağlantı bilgilerini kontrol edin.

**İzin hatası**: SQL Server kullanıcısının gerekli izinlere sahip olduğundan emin olun.

### Log Kontrolü

Console installer detaylı loglar sağlar:
- ✅ Başarılı işlemler yeşil
- ❌ Hatalar kırmızı  
- ℹ️ Bilgi mesajları mavi

## 🎯 Sonraki Adımlar

Kurulum tamamlandıktan sonra:

1. AI Worker servisini başlatın
2. Job konfigürasyonlarını kontrol edin
3. Sistem sağlık kontrollerini çalıştırın

## 📞 Destek

Kurulum sorunları için sistem loglarını kontrol edin ve gerekirse teknik destek ile iletişime geçin.