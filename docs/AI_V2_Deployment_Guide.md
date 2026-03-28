# BKMDenetim AI V2 Dağıtım Rehberi

## 🚀 **Sistem Kurulum Adımları**

### **1. Ön Hazırlık**

#### **Sistem Gereksinimleri**
- **İşletim Sistemi**: Windows Server 2019+ veya Windows 10+
- **Veritabanı**: SQL Server 2019+ 
- **Runtime**: .NET 8.0+
- **Hafıza**: Minimum 8GB RAM (16GB önerilen)
- **Depolama**: Minimum 50GB boş alan
- **CPU**: 4+ çekirdek (8+ önerilen)

#### **Bağımlılıklar**
```bash
# .NET 8.0 Runtime kurulumu
winget install Microsoft.DotNet.Runtime.8

# SQL Server Management Studio (opsiyonel)
winget install Microsoft.SQLServerManagementStudio
```

### **2. Veritabanı Kurulumu**

#### **Adım 1: V2 Şemasını Yükle**
```sql
-- SQL Server Management Studio'da çalıştır
USE BKMDenetim;
GO

-- V2 şemasını yükle
-- sql/15_ai_enhancement_v2_tr.sql dosyasını çalıştır
```

#### **Adım 2: Veri Migrasyonu**
```sql
-- V1'den V2'ye tam migrasyon
EXEC ai.sp_AiMigration_V1toV2 @ComponentName = 'TAM_MIGRASYON';

-- Migrasyon durumunu kontrol et
SELECT * FROM ai.AiMigrationStatus ORDER BY MigrationId DESC;
```

#### **Adım 3: Sistem Sağlık Kontrolü**
```sql
-- Sistem bileşenlerini kontrol et
EXEC ai.sp_AiSystem_HealthCheck;

-- Tablo sayılarını doğrula
SELECT 
    SCHEMA_NAME(t.schema_id) as SchemaName,
    t.name as TableName,
    p.rows as RowCount
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
  AND SCHEMA_NAME(t.schema_id) = 'ai'
ORDER BY SchemaName, TableName;
```

### **3. AI Worker Konfigürasyonu**

#### **Adım 1: Konfigürasyon Dosyalarını Hazırla**
```bash
# Proje klasörüne git
cd src/BkmDenetim.AiWorker

# AI V2 konfigürasyonunu aktif et
copy appsettings.aienhancement.json appsettings.Production.json

# Connection string'i güncelle
notepad appsettings.Production.json
```

#### **Adım 2: Bağlantı Ayarları**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=BKMDenetim;Integrated Security=true;TrustServerCertificate=true;"
  },
  "AiWorkerOptions": {
    "EnableAiEnhancement": true,
    "AiEnhancementVersion": "V2",
    "MaxConcurrentJobs": 3,
    "LogLevel": "Information"
  }
}
```

#### **Adım 3: İş Konfigürasyonunu Doğrula**
```bash
# Job konfigürasyonunu kontrol et
type Jobs\AiEnhancementJobs.json

# ETL export klasörünü oluştur
mkdir C:\BkmDenetim\AI_Export
```

### **4. Servis Kurulumu**

#### **Adım 1: Uygulamayı Derle**
```bash
# Release modunda derle
dotnet build --configuration Release

# Publish et
dotnet publish --configuration Release --output ./publish
```

#### **Adım 2: Windows Servisi Olarak Kur**
```bash
# SC komutu ile servis oluştur
sc create "BkmDenetim.AiWorker" binPath="C:\BkmDenetim\AiWorker\BkmDenetim.AiWorker.exe" start=auto

# Servisi başlat
sc start "BkmDenetim.AiWorker"

# Servis durumunu kontrol et
sc query "BkmDenetim.AiWorker"
```

#### **Adım 3: Alternatif - Konsol Uygulaması Olarak Çalıştır**
```bash
# Geliştirme ortamında
dotnet run --project BkmDenetim.AiWorker

# Üretim ortamında
cd publish
BkmDenetim.AiWorker.exe
```

### **5. ETL Sistemi Kurulumu**

#### **Adım 1: ETL Klasör Yapısını Oluştur**
```bash
# Ana ETL klasörü
mkdir C:\BkmDenetim\ETL

# Alt klasörler
mkdir C:\BkmDenetim\ETL\Export
mkdir C:\BkmDenetim\ETL\Import
mkdir C:\BkmDenetim\ETL\Archive
mkdir C:\BkmDenetim\ETL\Logs
```

#### **Adım 2: ETL İşlemlerini Test Et**
```sql
-- Kaynak dosya oluşturma testi (SQL SP)
EXEC ai.sp_AiEtl_CreateSourceFiles 
    @ExportPath = 'C:\BkmDenetim\ETL\Export\',
    @DateRange = 7,
    @FileFormat = 'JSON';

-- Veri aktarım testi (SQL SP)
EXEC ai.sp_AiEtl_DataTransfer 
    @SourceSystem = 'LEGACY_SYSTEM',
    @TargetSystem = 'AI_ENHANCEMENT_V2',
    @TransferType = 'INCREMENTAL',
    @BatchSize = 100;

-- Veri kalitesi kontrol testi (SQL SP)
EXEC ai.sp_AiEtl_DataQualityCheck @CheckType = 'INCREMENTAL';
```

### **6. İzleme ve Doğrulama**

#### **Adım 1: İş Durumlarını Kontrol Et**
```sql
-- Çalışan işleri görüntüle
SELECT 
    JobName,
    Status,
    StartTime,
    RecordsProcessed,
    Message
FROM ai.AiEtlLog 
WHERE StartTime >= CAST(SYSDATETIME() AS date)
ORDER BY StartTime DESC;

-- Agent pipeline durumları
SELECT 
    PipelineId,
    RequestId,
    Status,
    StartTime,
    AgentSequence,
    OverallConfidence
FROM ai.AiAgentPipeline 
WHERE StartTime >= DATEADD(hour, -24, SYSDATETIME())
ORDER BY StartTime DESC;
```

#### **Adım 2: Performans Metriklerini İzle**
```sql
-- Model performansı
SELECT 
    ModelName,
    AgentType,
    MeasurementDate,
    AverageAccuracy,
    AverageConfidence,
    TotalRequests,
    SuccessfulRequests
FROM ai.AiModelPerformance 
WHERE MeasurementDate >= DATEADD(day, -7, CAST(SYSDATETIME() AS date))
ORDER BY MeasurementDate DESC;

-- Anomali tespitleri
SELECT 
    AnomalyId,
    MekanId,
    AnomalyType,
    Severity,
    AnomalyScore,
    DetectionDate,
    Status
FROM ai.AiAnomalyDetection 
WHERE DetectionDate >= DATEADD(day, -1, SYSDATETIME())
ORDER BY AnomalyScore DESC;
```

#### **Adım 3: Log Dosyalarını Kontrol Et**
```bash
# Windows Event Log'ları kontrol et
eventvwr.msc

# Uygulama log dosyalarını kontrol et
type C:\BkmDenetim\AiWorker\Logs\*.log

# ETL log dosyalarını kontrol et
type C:\BkmDenetim\ETL\Logs\*.log
```

### **7. Güvenlik ve Yetkilendirme**

#### **Adım 1: Veritabanı Yetkileri**
```sql
-- AI Worker için kullanıcı oluştur
CREATE LOGIN [BkmDenetim_AiWorker] WITH PASSWORD = 'GüçlüŞifre123!';
CREATE USER [BkmDenetim_AiWorker] FOR LOGIN [BkmDenetim_AiWorker];

-- Gerekli yetkileri ver
ALTER ROLE db_datareader ADD MEMBER [BkmDenetim_AiWorker];
ALTER ROLE db_datawriter ADD MEMBER [BkmDenetim_AiWorker];
GRANT EXECUTE ON SCHEMA::ai TO [BkmDenetim_AiWorker];
```

#### **Adım 2: Dosya Sistemi Yetkileri**
```bash
# ETL klasörü için yetki ver
icacls "C:\BkmDenetim\ETL" /grant "BkmDenetim_AiWorker:(OI)(CI)F"

# Log klasörü için yetki ver
icacls "C:\BkmDenetim\AiWorker\Logs" /grant "BkmDenetim_AiWorker:(OI)(CI)F"
```

### **8. Yedekleme ve Kurtarma**

#### **Adım 1: Veritabanı Yedekleme**
```sql
-- Tam yedekleme
BACKUP DATABASE BKMDenetim 
TO DISK = 'C:\Backup\BKMDenetim_AI_V2_Full.bak'
WITH FORMAT, INIT, COMPRESSION;

-- Log yedekleme (her 15 dakikada)
BACKUP LOG BKMDenetim 
TO DISK = 'C:\Backup\BKMDenetim_AI_V2_Log.trn'
WITH COMPRESSION;
```

#### **Adım 2: Konfigürasyon Yedekleme**
```bash
# Konfigürasyon dosyalarını yedekle
xcopy "C:\BkmDenetim\AiWorker\*.json" "C:\Backup\Config\" /Y

# ETL verilerini arşivle
robocopy "C:\BkmDenetim\ETL\Export" "C:\Backup\ETL\Export" /MIR /R:3 /W:10
```

### **9. Sorun Giderme**

#### **Yaygın Sorunlar ve Çözümleri**

**Sorun**: İşler çalışmıyor
```bash
# Servis durumunu kontrol et
sc query "BkmDenetim.AiWorker"

# Log dosyalarını incele
type C:\BkmDenetim\AiWorker\Logs\*.log | findstr "ERROR"

# Veritabanı bağlantısını test et
sqlcmd -S localhost -d BKMDenetim -Q "SELECT SYSDATETIME()"
```

**Sorun**: ETL işlemleri başarısız
```sql
-- ETL hatalarını kontrol et
SELECT * FROM ai.AiEtlLog WHERE Status = 'BASARISIZ' ORDER BY StartTime DESC;

-- Veri kalitesi sorunlarını kontrol et
SELECT * FROM ai.AiDataQualityIssue WHERE Status = 'ACIK' ORDER BY DetectedDate DESC;
```

**Sorun**: Yüksek kaynak kullanımı
```sql
-- Çalışan işleri kontrol et
SELECT COUNT(*) as RunningJobs FROM ai.AiAgentPipeline WHERE Status = 'CALISIYOR';

-- Hafıza kullanımını kontrol et
SELECT 
    MemoryLayer,
    COUNT(*) as EmbeddingCount,
    AVG(AccessCount) as AvgAccessCount
FROM ai.AiMultiModalEmbedding 
WHERE IsActive = 1
GROUP BY MemoryLayer;
```

### **10. Bakım ve Güncelleme**

#### **Günlük Bakım**
```sql
-- Sistem sağlık kontrolü
EXEC ai.sp_AiSystem_HealthCheck;

-- Hafıza katmanı bakımı
EXEC ai.sp_AiMemory_LayerMaintenance;
```

#### **Haftalık Bakım**
```sql
-- Embedding bakımı
EXEC ai.sp_AiEmbedding_Maintenance @BatchSize = 1000;

-- Model performans güncelleme
EXEC ai.sp_AiModel_PerformanceUpdate;
```

#### **Aylık Bakım**
```sql
-- Eski log kayıtlarını temizle
DELETE FROM ai.AiEtlLog WHERE StartTime < DATEADD(month, -3, SYSDATETIME());

-- Arşivlenmiş embedding'leri temizle
DELETE FROM ai.AiMultiModalEmbedding 
WHERE IsActive = 0 AND UpdatedDate < DATEADD(month, -6, SYSDATETIME());
```

---

## 🎯 **Başarı Kriterleri**

Sistem başarıyla kurulduğunda:
- ✅ Tüm AI işleri zamanında çalışıyor
- ✅ ETL işlemleri günlük olarak tamamlanıyor  
- ✅ Veri kalitesi skoru %85+ seviyesinde
- ✅ Agent pipeline'ları 5 dakika içinde tamamlanıyor
- ✅ Anomali tespiti günde en az 1 kez çalışıyor
- ✅ Model performans metrikleri günlük güncelleniyor

## 📞 **Destek ve İletişim**

**Teknik Destek**: ai-admin@bkm.com  
**ETL Destek**: etl-admin@bkm.com  
**Sistem Yöneticisi**: sistem-admin@bkm.com  

**Acil Durum**: 7/24 on-call destek mevcut

---

**Hazırlayan**: AI Geliştirme Ekibi  
**Tarih**: Ocak 2026  
**Versiyon**: 1.0  
**Son Güncelleme**: Dağıtım öncesi final versiyon