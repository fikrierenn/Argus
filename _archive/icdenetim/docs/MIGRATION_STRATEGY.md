# IcDenetim Veritabani Migration Stratejisi

## 1. Mevcut Durum (Baseline)

Baslangic semasi 5 temel tablodan olusur:

| Tablo | Aciklama |
|---|---|
| **Users** | Kullanici hesaplari (email, sifre, ad) |
| **AuditItems** | Master madde listesi (kontrol sorulari, risk bilgileri) |
| **Audits** | Denetim kayitlari (lokasyon, tarih, denetci) |
| **AuditResults** | Madde sonuclari - snapshot olarak saklanir |
| **AuditResultPhotos** | Sonuclara eklenen fotograf dosyalari |

Iliskiler:
- Audits.AuditorId -> Users.Id
- AuditResults.AuditId -> Audits.Id (CASCADE DELETE)
- AuditResultPhotos.AuditResultId -> AuditResults.Id (CASCADE DELETE)

Baseline sonrasi eklenen alanlar (Schema.sql icerisinde):
- `AuditItems.LocationType` (NVARCHAR(20), DEFAULT 'Magaza')
- `Audits.IsFinalized` (BIT, DEFAULT 0)
- `Audits.FinalizedAt` (DATETIME2, NULL)

## 2. Hedef Durum

Baseline tablolarina ek olarak su tablolar eklenir:

| Tablo | Migration Dosyasi | Aciklama |
|---|---|---|
| **Skills** | Migration_Skills.sql | Denetim yetkinlik tanimlari (Magaza Denetimi, Depo vb.) |
| **SkillVersions** | Migration_Skills.sql | Skill versiyon gecmisi, risk kurallari, AI prompt context |
| **CorrectiveActions** | Migration_CorrectiveActions.sql | DOF kayitlari (duzeltici/onleyici faaliyetler) |
| **AiAnalyses** | Migration_AiInfrastructure.sql | AI analiz sonuclari ve uyarilari |
| **AuditLog** | Migration_AuditLog.sql | Tum veri degisikliklerinin iz kaydi |

Mevcut tablolara eklenen alanlar:

| Tablo | Alan | Migration | Aciklama |
|---|---|---|---|
| AuditItems | SkillId (INT NULL) | Migration_Skills.sql | Hangi skill'e ait oldugu |
| AuditResults | FirstSeenAt (DATETIME2 NULL) | Migration_DataIntelligence.sql | Ilk basarisizlik tarihi |
| AuditResults | LastSeenAt (DATETIME2 NULL) | Migration_DataIntelligence.sql | Son basarisizlik tarihi |
| AuditResults | RepeatCount (INT, DEFAULT 0) | Migration_DataIntelligence.sql | Tekrar sayisi |
| AuditResults | IsSystemic (BIT, DEFAULT 0) | Migration_DataIntelligence.sql | Sistemik sorun mu |

## 3. Migration Calistirma Sirasi

Tum migration'lar `DbMigration.RunMigrationsAsync()` tarafindan uygulama baslatildiginda otomatik olarak calistirilir. Sira kritiktir cunku tablolar arasi bagimliliklar vardir:

```
1. Audits: IsFinalized, FinalizedAt  (kolon ekleme - bagimsiz)
2. AuditItems: LocationType           (kolon ekleme - bagimsiz)
3. Migration_Skills.sql               (Skills, SkillVersions tablolari + AuditItems.SkillId)
4. Migration_CorrectiveActions.sql    (AuditResults ve Audits'e bagli)
5. Migration_AuditLog.sql             (bagimsiz - herhangi bir tabloya FK yok)
6. Migration_AiInfrastructure.sql     (bagimsiz - herhangi bir tabloya FK yok)
7. Data Intelligence alanlari         (AuditResults kolon eklemeleri)
```

### Neden bu sira?
- Skills tablosu olusturulmadan AuditItems.SkillId FK eklenemez (adim 3)
- CorrectiveActions tablosu AuditResults ve Audits'e FK icerdigi icin bu tablolarin mevcut olmasi gerekir (adim 4)
- AuditLog ve AiAnalyses bagimsiz tablolardir, sira onemli degil (adim 5-6)
- Data Intelligence alanlari AuditResults tablosuna kolon ekler, tablo zaten mevcut olmalidir (adim 7)

## 4. Geriye Uyumluluk

Migration stratejisi mevcut verileri ve is akislarini bozmamak icin su kurallara uyar:

### 4.1 Nullable FK'lar
- `AuditItems.SkillId` **NULLABLE** olarak eklenir
- Mevcut maddeler SkillId = NULL ile calismaya devam eder
- Migration sirasinda varsayilan 'MAGAZA' skill'ine atanirlar (asagida bkz. Veri Migrasyon)

### 4.2 Default Degerler
- `AuditResults.RepeatCount` DEFAULT 0 ile eklenir - mevcut satirlar 0 alir
- `AuditResults.IsSystemic` DEFAULT 0 ile eklenir - mevcut satirlar false alir
- `AuditResults.FirstSeenAt` ve `LastSeenAt` NULL olarak eklenir - mevcut satirlar NULL kalir

### 4.3 Dokunulmayan Yapilar
- Mevcut kolonlar **silinmez** veya **tip degistirilmez**
- Mevcut FK iliskileri **degistirilmez**
- `AuditResults.AuditId -> Audits.Id` CASCADE DELETE aynen kalir
- `AuditResultPhotos.AuditResultId -> AuditResults.Id` CASCADE DELETE aynen kalir

### 4.4 Idempotent Migration
Tum migration script'leri `IF NOT EXISTS` kontrolleri icerir:
- Tablo varsa tekrar olusturulmaz
- Kolon varsa tekrar eklenmez
- Index varsa tekrar olusturulmaz
- Uygulama her basladiginda guvenle calisabilir

## 5. Veri Migrasyon (Data Migration)

### 5.1 Varsayilan Skill Atamasi
`Migration_Skills.sql` icerisinde:

1. 'MAGAZA' kodlu bir Skill kaydi olusturulur (yoksa)
2. Bu skill icin VersionNo=1 olan bir SkillVersion olusturulur
3. `AuditItems` tablosunda `SkillId IS NULL` olan tum maddeler bu skill'e atanir

Bu sayede mevcut tum maddeler otomatik olarak "Magaza Denetimi" skill'ine baglanir.

### 5.2 LocationType Normalizasyonu
`DbMigration.cs` icerisinde:
- `Kafe` ve `Herikisi` degerlerine sahip maddeler `Magaza` olarak guncellenir
- Kafe destegi kaldirilmistir, tum maddeler tek tip olarak calisir

## 6. Gelecek Evrim: Findings Soyutlama Katmani

### Mevcut Durum
`AuditResults` tablosu hem madde snapshot'ini hem de sonuc bilgisini birlikte tutar. Bu tablo hem "denetim maddesi" hem de "bulgu" gorevini gorur.

### Hedef Mimari
AuditResults tablosu fiziksel olarak degistirilmez, ancak uzerine bir soyutlama katmani eklenir:

```
AuditResults (fiziksel tablo - degismez)
    |
    v
IFindingsService (soyutlama katmani)
    |
    +-- GetFindingsForAudit(auditId)     -> AuditResults satirlarini Finding DTO'ya donusturur
    +-- GetFindingHistory(auditItemId)   -> Ayni maddenin tum denetimlerdeki gecmisi
    +-- GetSystemicFindings()            -> 3+ lokasyonda tekrar eden bulgular
    +-- GetFindingWithContext(id)        -> Tekrar sayisi, trend, AI analizi dahil
```

### Neden Soyutlama?
- AuditResults tablosu fiziksel olarak snapshot gorevini gormeye devam eder
- Findings servisi ustune eklenen is mantigi (tekrar hesaplama, sistemik tespit) burada yasar
- Ileride `Findings` ayri bir tablo olursa, sadece servis implementasyonu degisir
- Tuketici kod (Page Model'lar, Dashboard, API) servis arayuzune baglidir, tabloya degil

### Gecis Plani
1. **Faz 1 (Mevcut):** AuditResults + Data Intelligence alanlari (RepeatCount, IsSystemic)
2. **Faz 2:** IFindingsService olusturulur, AuditResults verisini zenginlestirilmis Finding DTO olarak sunar
3. **Faz 3 (Opsiyonel):** Findings ayri tabloya tasinabilir, servis implementasyonu guncellenir

## 7. Manuel Migration

Otomatik migration disinda, migration script'leri manuel olarak da calistirilabilir:

```bash
# Tum migration'lari sirayla calistir
sqlcmd -S . -d IcDenetim -i Data\Migration_Skills.sql
sqlcmd -S . -d IcDenetim -i Data\Migration_CorrectiveActions.sql
sqlcmd -S . -d IcDenetim -i Data\Migration_AuditLog.sql
sqlcmd -S . -d IcDenetim -i Data\Migration_AiInfrastructure.sql
sqlcmd -S . -d IcDenetim -i Data\Migration_DataIntelligence.sql
```

Not: Manuel calistirmada GO ayraclari SSMS ve sqlcmd tarafindan desteklenir. `DbMigration.cs` ise GO'lari kendisi parse ederek Dapper uzerinden calistirir.
