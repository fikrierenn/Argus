using Dapper;
using BkmArgus.Data;
using BkmArgus.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmArgus.Pages.Denetimler;

/// <summary>
/// Denetim madde sonucuna fotoğraf ekleme.
/// </summary>
public class ResultPhotosModel : PageModel
{
    private readonly IConfiguration _config;
    private readonly IWebHostEnvironment _env;

    public ResultPhotosModel(IConfiguration config, IWebHostEnvironment env)
    {
        _config = config;
        _env = env;
    }

    [BindProperty(SupportsGet = true)]
    public int AuditResultId { get; set; }

    public int AuditId { get; set; }
    public string ItemText { get; set; } = string.Empty;
    public List<AuditResultPhoto> Photos { get; set; } = [];

    public async Task<IActionResult> OnGetAsync()
    {
        using var conn = DbConnectionFactory.Create(_config);
        var result = await conn.QuerySingleOrDefaultAsync<(int AuditId, string ItemText)>(
            "SELECT r.AuditId, r.ItemText FROM AuditResults r WHERE r.Id = @Id",
            new { Id = AuditResultId });
        if (result == default) return NotFound();

        AuditId = result.AuditId;
        ItemText = result.ItemText ?? "";

        Photos = (await conn.QueryAsync<AuditResultPhoto>(
            "SELECT Id, AuditResultId, FilePath, Remark, CreatedAt FROM AuditResultPhotos WHERE AuditResultId = @Id ORDER BY CreatedAt DESC",
            new { Id = AuditResultId })).ToList();
        return Page();
    }

    private static readonly HashSet<string> AllowedExtensions = [".jpg", ".jpeg", ".png", ".webp"];
    private static readonly HashSet<string> AllowedMimeTypes = ["image/jpeg", "image/png", "image/webp"];
    private const long MaxFileSize = 5 * 1024 * 1024; // 5 MB

    public async Task<IActionResult> OnPostAsync(IFormFile? Photo)
    {
        if (Photo == null || Photo.Length == 0)
        {
            TempData["Error"] = "Lutfen bir fotograf secin.";
            return RedirectToPage(new { auditResultId = AuditResultId });
        }

        if (Photo.Length > MaxFileSize)
        {
            TempData["Error"] = "Dosya boyutu en fazla 5 MB olabilir.";
            return RedirectToPage(new { auditResultId = AuditResultId });
        }

        var extension = Path.GetExtension(Photo.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(extension))
        {
            TempData["Error"] = "Sadece JPG, JPEG, PNG ve WEBP dosyalari yuklenebilir.";
            return RedirectToPage(new { auditResultId = AuditResultId });
        }

        if (!AllowedMimeTypes.Contains(Photo.ContentType.ToLowerInvariant()))
        {
            TempData["Error"] = "Gecersiz dosya tipi.";
            return RedirectToPage(new { auditResultId = AuditResultId });
        }

        var uploadsDir = Path.Combine(_env.WebRootPath, "uploads", "audit");
        Directory.CreateDirectory(uploadsDir);
        var fileName = $"{AuditResultId}_{Guid.NewGuid():N}{extension}";
        var filePath = Path.Combine(uploadsDir, fileName);
        await using (var stream = new FileStream(filePath, FileMode.Create))
            await Photo.CopyToAsync(stream);

        var relativePath = $"/uploads/audit/{fileName}";

        using var conn = DbConnectionFactory.Create(_config);
        await conn.ExecuteAsync(
            "INSERT INTO AuditResultPhotos (AuditResultId, FilePath, Remark, CreatedAt) VALUES (@AuditResultId, @FilePath, NULL, GETDATE())",
            new { AuditResultId, FilePath = relativePath });

        return RedirectToPage(new { auditResultId = AuditResultId });
    }
}
