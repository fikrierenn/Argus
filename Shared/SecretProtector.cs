using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace BkmArgus.Infrastructure;

/// <summary>
/// Veritabaninda saklanacak sirlari (LLM API anahtarlari gibi) sifreler ve cozer.
/// AES-256-GCM: gizlilik + butunluk birlikte, kurcalanmis sifreli metin cozulmez.
///
/// Ana anahtar veritabaninda DEGIL: BKM_SECRET_KEY ortam degiskeni veya
/// appsettings.Local.json. Boylece bir veritabani yedegi tek basina hicbir
/// anahtari acmaz (security-principles.md §5).
///
/// Web ve AiWorker ayni ana anahtari kullanir; biri sifreler, digeri cozer.
/// </summary>
public static class SecretProtector
{
    private const string MasterKeyName = "BKM_SECRET_KEY";
    private const int NonceSize = 12;   // AES-GCM standart
    private const int TagSize = 16;

    /// <summary>Ana anahtar tanimli mi — ekranda uyari gostermek icin.</summary>
    public static bool IsConfigured(IConfiguration configuration)
        => TryResolveMasterKey(configuration, out _);

    /// <summary>Duz metni sifreler; sonuc base64 (nonce | tag | sifreli metin).</summary>
    public static string Protect(IConfiguration configuration, string plainText)
    {
        if (string.IsNullOrEmpty(plainText))
        {
            return string.Empty;
        }

        if (!TryResolveMasterKey(configuration, out var key))
        {
            throw new InvalidOperationException(
                $"{MasterKeyName} tanimli degil. Sir sifrelenemez.");
        }

        var plain = Encoding.UTF8.GetBytes(plainText);
        var nonce = RandomNumberGenerator.GetBytes(NonceSize);
        var cipher = new byte[plain.Length];
        var tag = new byte[TagSize];

        using (var aes = new AesGcm(key, TagSize))
        {
            aes.Encrypt(nonce, plain, cipher, tag);
        }

        var packed = new byte[NonceSize + TagSize + cipher.Length];
        Buffer.BlockCopy(nonce, 0, packed, 0, NonceSize);
        Buffer.BlockCopy(tag, 0, packed, NonceSize, TagSize);
        Buffer.BlockCopy(cipher, 0, packed, NonceSize + TagSize, cipher.Length);

        return Convert.ToBase64String(packed);
    }

    /// <summary>
    /// Sifreli metni cozer. Cozulemezse bos doner — cagiran saglayiciyi kapali
    /// sayar. Sir icerdigi icin hata detayi asla loglanmaz.
    /// </summary>
    public static string Unprotect(IConfiguration configuration, string? protectedText)
    {
        if (string.IsNullOrWhiteSpace(protectedText))
        {
            return string.Empty;
        }

        if (!TryResolveMasterKey(configuration, out var key))
        {
            return string.Empty;
        }

        try
        {
            var packed = Convert.FromBase64String(protectedText);
            if (packed.Length <= NonceSize + TagSize)
            {
                return string.Empty;
            }

            var nonce = new byte[NonceSize];
            var tag = new byte[TagSize];
            var cipher = new byte[packed.Length - NonceSize - TagSize];

            Buffer.BlockCopy(packed, 0, nonce, 0, NonceSize);
            Buffer.BlockCopy(packed, NonceSize, tag, 0, TagSize);
            Buffer.BlockCopy(packed, NonceSize + TagSize, cipher, 0, cipher.Length);

            var plain = new byte[cipher.Length];
            using (var aes = new AesGcm(key, TagSize))
            {
                aes.Decrypt(nonce, cipher, tag, plain);
            }

            return Encoding.UTF8.GetString(plain);
        }
        catch (FormatException)
        {
            // Base64 bozuk — sessizce bos don, icerigi loglama
            return string.Empty;
        }
        catch (CryptographicException)
        {
            // Yanlis ana anahtar veya kurcalanmis veri
            return string.Empty;
        }
    }

    /// <summary>
    /// Ana anahtari cozer ve 32 bayta normalize eder. Kullanici rastgele uzunlukta
    /// bir parola verebilir; SHA-256 ile sabit uzunluga indirilir.
    /// </summary>
    private static bool TryResolveMasterKey(IConfiguration configuration, out byte[] key)
    {
        var raw = Environment.GetEnvironmentVariable(MasterKeyName)
                  ?? configuration[MasterKeyName]
                  ?? configuration[$"Security:{MasterKeyName}"];

        if (string.IsNullOrWhiteSpace(raw))
        {
            key = [];
            return false;
        }

        key = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
        return true;
    }
}
