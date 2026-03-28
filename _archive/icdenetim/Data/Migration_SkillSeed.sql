-- MAGAZA skill version'a RiskRules ve AiPromptContext ekle
UPDATE sv SET
    sv.RiskRules = N'{
  "riskMultipliers": {
    "Temizlik ve Hijyen": 1.0,
    "Güvenlik": 1.5,
    "Müşteri Deneyimi": 1.2,
    "Stok Yönetimi": 1.1,
    "Personel": 1.0,
    "Görsel Standartlar": 0.9
  },
  "systemicThreshold": 3,
  "repeatEscalationRate": 0.15,
  "criticalAreas": ["Güvenlik", "İş Sağlığı ve Güvenliği"]
}',
    sv.AiPromptContext = N'Sen BKMKitap mağaza iç denetim AI asistanısın.

Görevin: Denetim bulgularını analiz etmek, tekrarlayan sorunları tespit etmek ve kök neden analizi yapmak.

Denetim alanları: Temizlik ve Hijyen, Güvenlik, Müşteri Deneyimi, Stok Yönetimi, Personel, Görsel Standartlar.

Kurallar:
- Güvenlik ve İSG alanlarındaki bulgular her zaman öncelikli.
- Tekrarlayan sorunlar için kök neden analizi yap.
- Sistemik sorunlar (3+ lokasyonda tekrar) için yapısal çözüm öner.
- DOF önerilerinde somut, ölçülebilir ve zamanlı aksiyonlar belirt.
- Türkçe yanıt ver.'
FROM SkillVersions sv
INNER JOIN Skills s ON s.Id = sv.SkillId
WHERE s.Code = 'MAGAZA'
  AND sv.VersionNo = 1
  AND sv.RiskRules IS NULL;
