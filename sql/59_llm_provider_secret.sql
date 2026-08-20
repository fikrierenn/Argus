-- ============================================================================
-- 59 — LLM saglayici anahtarinin sifreli saklanmasi
--
-- 58'de anahtar yalniz ADIYLA tutuluyordu (ApiKeyRef) ve deger ortam
-- degiskeninden cozuluyordu. Yonetim ekranindan anahtar girilebilmesi icin
-- ikinci bir yol ekleniyor: deger AES-GCM ile sifrelenip burada saklanir.
--
-- Kurallar:
--   * Duz metin anahtar ASLA yazilmaz — yalniz ApiKeyEncrypted (base64 sifreli).
--   * Ana anahtar (BKM_SECRET_KEY) veritabaninda DEGIL; ortam degiskeni veya
--     appsettings.Local.json'da durur. DB yedegi tek basina anahtarlari acmaz.
--   * Cozme yalniz sunucu tarafinda; hicbir SP ve hicbir ekran duz degeri
--     geri dondurmez. sp_LlmProvider_List anahtarin VARLIGINI bildirir, degerini degil.
--   * ApiKeyRef yolu korunur — ortam degiskeni onceliklidir, boylece uretimde
--     anahtari hic DB'ye koymadan calistirmak mumkun kalir.
--
-- Idempotent.
-- ============================================================================

SET NOCOUNT ON;
GO

IF COL_LENGTH('ai.LlmProviders', 'ApiKeyEncrypted') IS NULL
    ALTER TABLE ai.LlmProviders ADD ApiKeyEncrypted varchar(max) NULL;
GO

IF COL_LENGTH('ai.LlmProviders', 'ApiKeySetAt') IS NULL
    ALTER TABLE ai.LlmProviders ADD ApiKeySetAt datetime2(0) NULL;
GO

IF COL_LENGTH('ai.LlmProviders', 'ApiKeySetByUserId') IS NULL
    ALTER TABLE ai.LlmProviders ADD ApiKeySetByUserId int NULL;
GO

-- ─────────────────────────────────────────────────────
-- Liste: sifreli degeri DONDURUR (worker cozecek) ama ekran icin ayri bir
-- "anahtar tanimli mi" bayragi da uretir. Ekran modeli duz degeri hic gormez.
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_List
    @SadeceAktif bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProviderId, Name, Kind, DisplayName, BaseUrl, RequestPath,
           ApiKeyRef, RequiresApiKey, ApiKeyEncrypted,
           CAST(CASE WHEN NULLIF(ApiKeyEncrypted, '') IS NULL THEN 0 ELSE 1 END AS bit) AS HasStoredKey,
           ApiKeySetAt,
           Model, FallbackModel, Priority, IsActive, Notes, CreatedAt, UpdatedAt
    FROM   ai.LlmProviders
    WHERE  (@SadeceAktif = 0 OR IsActive = 1)
    ORDER BY IsActive DESC, Priority, Name;
END
GO

-- ─────────────────────────────────────────────────────
-- Anahtar yazma. Duz metin buraya GELMEZ — cagiran sifreleyip verir.
-- Bos gonderilirse anahtar silinir (ortam degiskeni yoluna geri donulur).
-- ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_SetApiKey
    @SaglayiciId    int,
    @SifreliDeger   varchar(max) = NULL,
    @KullaniciId    int          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        UPDATE ai.LlmProviders
           SET ApiKeyEncrypted   = NULLIF(@SifreliDeger, ''),
               ApiKeySetAt       = CASE WHEN NULLIF(@SifreliDeger, '') IS NULL THEN NULL ELSE SYSDATETIME() END,
               ApiKeySetByUserId = CASE WHEN NULLIF(@SifreliDeger, '') IS NULL THEN NULL ELSE @KullaniciId END,
               UpdatedAt         = SYSDATETIME(),
               UpdatedByUserId   = @KullaniciId
         WHERE ProviderId = @SaglayiciId;

        IF @@ROWCOUNT = 0
            THROW 50112, N'Saglayici bulunamadi.', 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Aktif etme kurali guncellenir: ortam degiskeni ADI ya da saklanmis sifreli
-- anahtar — ikisinden biri yeterli.
CREATE OR ALTER PROCEDURE ai.sp_LlmProvider_SetActive
    @SaglayiciId int,
    @Aktif       bit,
    @KullaniciId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Is kurali: anahtar gerektiren saglayici, ne anahtar adi ne de saklanmis
        -- anahtar varken aktif edilemez
        IF @Aktif = 1 AND EXISTS (
                SELECT 1 FROM ai.LlmProviders
                WHERE ProviderId = @SaglayiciId
                  AND RequiresApiKey = 1
                  AND NULLIF(LTRIM(RTRIM(ApiKeyRef)), '') IS NULL
                  AND NULLIF(ApiKeyEncrypted, '') IS NULL)
            THROW 50113, N'Anahtar tanimlanmadan saglayici aktif edilemez.', 1;

        UPDATE ai.LlmProviders
           SET IsActive        = @Aktif,
               UpdatedAt       = SYSDATETIME(),
               UpdatedByUserId = @KullaniciId
         WHERE ProviderId = @SaglayiciId;

        IF @@ROWCOUNT = 0
            THROW 50112, N'Saglayici bulunamadi.', 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

PRINT '59_llm_provider_secret uygulandi.';
GO
