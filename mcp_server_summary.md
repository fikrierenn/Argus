# BKM Denetim MCP Server - Veritabanı Yönetim Paneli

## Tarih: 8 Ocak 2026
## Durum: ✅ TAMAMLANDI VE ÇALIŞIYOR

## Özellikler

### 🌐 Web Arayüzü
- **URL**: http://localhost:5001
- Modern Bootstrap 5 tasarımı
- Responsive ve kullanıcı dostu arayüz
- Real-time bağlantı durumu göstergesi

### 📊 Dashboard
- Tablo sayısı: **45 tablo**
- View sayısı: **10 view**
- Stored procedure sayısı: **68 procedure**
- Anlık veritabanı durumu

### 🗃️ Tablo Yönetimi
- Tüm tabloları listeleme (schema.tablo formatında)
- Kayıt sayıları gösterimi
- Tablo verilerini görüntüleme (ilk 100 kayıt)
- Kolon bilgilerini inceleme
- Veri tipleri ve kısıtlamalar

### 👁️ View Yönetimi
- Tüm view'ları listeleme
- View verilerini görüntüleme
- Oluşturma tarihleri

### ⚙️ Stored Procedure Yönetimi
- Tüm stored procedure'leri listeleme
- Parametreli çalıştırma desteği
- JSON formatında parametre girişi

### 🔍 SQL Sorgu Editörü
- Canlı SQL sorgu çalıştırma
- Sadece SELECT sorguları (güvenlik)
- Sonuçları tablo formatında görüntüleme
- Çalışma süresi gösterimi

## API Endpoints

### Temel Endpoints
- `GET /api/database/health` - Bağlantı durumu
- `GET /api/database/tables` - Tüm tablolar
- `GET /api/database/views` - Tüm view'lar
- `GET /api/database/procedures` - Tüm stored procedure'ler

### Tablo İşlemleri
- `GET /api/database/tables/{schema}/{table}/columns` - Kolon bilgileri
- `GET /api/database/tables/{schema}/{table}/data?top=100` - Tablo verisi
- `GET /api/database/tables/{schema}/{table}/count` - Kayıt sayısı

### Sorgu İşlemleri
- `POST /api/database/query` - SQL sorgusu çalıştırma
- `POST /api/database/procedures/{schema}/{procedure}` - SP çalıştırma

## Güvenlik Özellikleri

### ✅ Güvenli Özellikler
- Sadece SELECT sorguları desteklenir
- SQL injection koruması (parameterized queries)
- CORS desteği
- Hata yönetimi ve loglama

### ❌ Kısıtlamalar
- INSERT, UPDATE, DELETE sorgularına izin verilmez
- Maksimum 1000 satır sonuç sınırı
- 30 saniye sorgu timeout'u

## Kullanım Örnekleri

### Hızlı Tablo İnceleme
```
1. http://localhost:5001 adresine git
2. "Tablolar" sekmesine tıkla
3. İstediğin tablonun yanındaki "Görüntüle" butonuna tıkla
```

### SQL Sorgusu Çalıştırma
```sql
-- AI isteklerini kontrol et
SELECT TOP 10 * FROM ai.AiAnalizIstegi WHERE Durum = 'NEW'

-- Risk skorları
SELECT MekanId, COUNT(*) as ToplamKayit, AVG(RiskSkor) as OrtalamaRisk
FROM rpt.RiskUrunOzet_Gunluk 
WHERE KesimGunu >= '2026-01-01'
GROUP BY MekanId
ORDER BY OrtalamaRisk DESC
```

### Stored Procedure Çalıştırma
```json
// Parametreli SP çalıştırma
{
  "MekanId": 4478,
  "StokId": 1691524,
  "KesimTarihi": "2026-01-08"
}
```

## Teknik Detaylar

### Teknoloji Stack
- **Backend**: ASP.NET Core 8.0
- **Database**: SQL Server (Microsoft.Data.SqlClient)
- **ORM**: Dapper
- **Frontend**: HTML5, Bootstrap 5, Vanilla JavaScript
- **API**: RESTful Web API

### Dosya Yapısı
```
src/BkmDenetim.McpServer/
├── Controllers/
│   └── DatabaseController.cs      # API endpoints
├── Services/
│   └── DatabaseService.cs         # Veritabanı işlemleri
├── wwwroot/
│   ├── index.html                 # Ana sayfa
│   └── script.js                  # JavaScript logic
├── Program.cs                     # Uygulama başlatma
├── appsettings.json              # Konfigürasyon
└── BkmDenetim.McpServer.csproj   # Proje dosyası
```

### Bağlantı Bilgileri
- **Server**: 192.168.40.201
- **Database**: BKMDenetim
- **Authentication**: SQL Server Authentication
- **Connection String**: appsettings.json'da tanımlı

## Başlatma

### Manuel Başlatma
```bash
dotnet run --project src/BkmDenetim.McpServer/BkmDenetim.McpServer.csproj --urls "http://localhost:5001"
```

### Batch Dosyası ile
```bash
start_mcp_server.bat
```

## Test Sonuçları

### ✅ Başarılı Testler
- Veritabanı bağlantısı: **BAŞARILI**
- Tablo listeleme: **45 tablo tespit edildi**
- View listeleme: **10 view tespit edildi**
- Stored procedure listeleme: **68 procedure tespit edildi**
- API health check: **200 OK**
- Web arayüzü: **Erişilebilir**
- SQL sorgu çalıştırma: **Çalışıyor**
- Tablo verisi görüntüleme: **Çalışıyor**

### 📊 Performans
- Tablo listeleme: ~100ms
- Sorgu çalıştırma: Sorgu karmaşıklığına bağlı
- Web arayüzü yükleme: ~50ms

### 🔧 Son Düzeltmeler
- JavaScript event handling düzeltildi
- Views ve Procedures endpoint'leri düzeltildi
- Port 5001'e güncellendi (5000 kullanımda)
- Column mapping sorunları çözüldü

## Sonuç

BKM Denetim MCP Server başarıyla oluşturuldu ve çalışır durumda! 

Bu araç sayesinde:
- Veritabanı yapısını kolayca inceleyebilirsiniz
- Tabloları ve view'ları görüntüleyebilirsiniz  
- Stored procedure'leri test edebilirsiniz
- SQL sorguları çalıştırabilirsiniz
- AI Worker Service'in kullandığı tabloları analiz edebilirsiniz

**Web Arayüzü**: http://localhost:5001 🚀