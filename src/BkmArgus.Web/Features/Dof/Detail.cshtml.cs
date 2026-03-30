using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using BkmArgus.Web.Data;

namespace BkmArgus.Web.Features.Dof;

public class DetailModel : PageModel
{
    private readonly SqlDb _db;
    public DetailModel(SqlDb db) => _db = db;

    [BindProperty(SupportsGet = true)] public long Id { get; set; }

    public FindingDetailRow? Finding { get; private set; }
    public IReadOnlyList<StatusHistoryRow> History { get; private set; } = Array.Empty<StatusHistoryRow>();
    public IReadOnlyList<CommentRow> Comments { get; private set; } = Array.Empty<CommentRow>();
    public IReadOnlyList<AttachmentRow> Attachments { get; private set; } = Array.Empty<AttachmentRow>();

    public async Task<IActionResult> OnGetAsync()
    {
        Finding = await _db.QuerySingleAsync<FindingDetailRow>("dof.sp_Finding_Get", new { DofId = Id });
        if (Finding is null) return NotFound();

        History = await _db.QueryAsync<StatusHistoryRow>("dof.sp_Finding_History", new { DofId = Id });
        Comments = await _db.QueryAsync<CommentRow>("dof.sp_Finding_Comments", new { DofId = Id });
        Attachments = await _db.QueryAsync<AttachmentRow>("dof.sp_Attachment_List", new { DofId = Id });

        return Page();
    }

    public async Task<IActionResult> OnPostTransitionAsync(string newStatus, string? reason)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");
        var userRole = User.FindFirstValue(ClaimTypes.Role) ?? "DENETCI";

        await _db.ExecuteAsync("dof.sp_Finding_Transition", new
        {
            DofId = Id,
            NewStatus = newStatus,
            UserId = userId,
            UserRole = userRole,
            Reason = reason
        });

        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostCommentAsync(string commentText)
    {
        if (string.IsNullOrWhiteSpace(commentText))
            return RedirectToPage(new { id = Id });

        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");

        await _db.ExecuteAsync("dof.sp_Finding_AddComment", new
        {
            DofId = Id,
            AuthorUserId = userId,
            CommentText = commentText.Trim()
        });

        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostUploadAsync(IFormFile file, string? description)
    {
        if (file == null || file.Length == 0)
        {
            TempData["StatusMessage"] = "Dosya secilmedi.";
            return RedirectToPage(new { id = Id });
        }

        var allowedTypes = new[] { ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".jpg", ".jpeg", ".png", ".txt" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedTypes.Contains(ext))
        {
            TempData["StatusMessage"] = "Desteklenmeyen dosya tipi.";
            return RedirectToPage(new { id = Id });
        }
        if (file.Length > 10 * 1024 * 1024)
        {
            TempData["StatusMessage"] = "Dosya 10MB'dan buyuk olamaz.";
            return RedirectToPage(new { id = Id });
        }

        var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "dof");
        Directory.CreateDirectory(uploadsDir);
        var fileName = $"{Id}_{Guid.NewGuid():N}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
            await file.CopyToAsync(stream);

        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");
        await _db.ExecuteAsync("dof.sp_Attachment_Add", new
        {
            DofId = Id,
            FileName = file.FileName,
            FilePath = $"/uploads/dof/{fileName}",
            FileSize = file.Length,
            ContentType = file.ContentType,
            UploadedByUserId = userId,
            Description = description
        });

        TempData["StatusMessage"] = "Dosya yuklendi.";
        return RedirectToPage(new { id = Id });
    }

    public async Task<IActionResult> OnPostDeleteAttachmentAsync(int attachmentId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");

        var result = await _db.QuerySingleAsync<DeleteAttachmentResult>(
            "dof.sp_Attachment_Delete", new { AttachmentId = attachmentId, UserId = userId });

        if (result?.DeletedFilePath is not null)
        {
            var fullPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", result.DeletedFilePath.TrimStart('/'));
            if (System.IO.File.Exists(fullPath))
                System.IO.File.Delete(fullPath);

            TempData["StatusMessage"] = "Dosya silindi.";
        }
        else
        {
            TempData["StatusMessage"] = "Dosya silinemedi (yetki yok).";
        }

        return RedirectToPage(new { id = Id });
    }

    /// <summary>Valid next statuses based on current status.</summary>
    public IReadOnlyList<(string Status, string Label)> AllowedTransitions => Finding?.Status switch
    {
        "DRAFT"              => new[] { ("OPEN", "Ac"), ("REJECTED", "Reddet") },
        "OPEN"               => new[] { ("IN_PROGRESS", "Basla"), ("REJECTED", "Reddet") },
        "IN_PROGRESS"        => new[] { ("PENDING_VALIDATION", "Onaya Gonder") },
        "PENDING_VALIDATION" => new[] { ("CLOSED", "Kapat"), ("IN_PROGRESS", "Geri Gonder") },
        _                    => Array.Empty<(string, string)>()
    };

    public sealed record FindingDetailRow
    {
        public long DofId { get; init; }
        public string Title { get; init; } = "";
        public string? Description { get; init; }
        public int RiskLevel { get; init; }
        public string Status { get; init; } = "";
        public string? AssignedTo { get; init; }
        public long? AssignedToPersonnelId { get; init; }
        public DateTime? SlaDueDate { get; init; }
        public string? FindingSignature { get; init; }
        public string? SourceKey { get; init; }
        public DateTime CreatedAt { get; init; }
        public string? CreatedByName { get; init; }

        public string RiskLabel => RiskLevel switch
        {
            >= 5 => "Kritik",
            >= 4 => "Yuksek",
            >= 3 => "Orta",
            _ => "Dusuk"
        };

        public string StatusLabel => Status switch
        {
            "DRAFT"              => "Taslak",
            "OPEN"               => "Acik",
            "IN_PROGRESS"        => "Devam Ediyor",
            "PENDING_VALIDATION" => "Onay Bekliyor",
            "CLOSED"             => "Kapandi",
            "REJECTED"           => "Reddedildi",
            _                    => Status
        };

        public int SlaDaysLeft => SlaDueDate.HasValue
            ? (int)(SlaDueDate.Value.Date - DateTime.Today).TotalDays
            : 0;
    }

    public sealed record StatusHistoryRow
    {
        public string FromStatus { get; init; } = "";
        public string ToStatus { get; init; } = "";
        public string? Reason { get; init; }
        public string? ChangedByName { get; init; }
        public DateTime ChangedAt { get; init; }

        public string ToStatusLabel => ToStatus switch
        {
            "DRAFT"              => "Taslak",
            "OPEN"               => "Acik",
            "IN_PROGRESS"        => "Devam Ediyor",
            "PENDING_VALIDATION" => "Onay Bekliyor",
            "CLOSED"             => "Kapandi",
            "REJECTED"           => "Reddedildi",
            _                    => ToStatus
        };
    }

    public sealed record CommentRow
    {
        public long CommentId { get; init; }
        public string? AuthorName { get; init; }
        public string CommentText { get; init; } = "";
        public DateTime CreatedAt { get; init; }
    }

    public sealed record AttachmentRow
    {
        public int Id { get; init; }
        public string FileName { get; init; } = "";
        public string FilePath { get; init; } = "";
        public long FileSize { get; init; }
        public string? ContentType { get; init; }
        public string? UploadedByName { get; init; }
        public string? Description { get; init; }
        public DateTime CreatedAt { get; init; }
    }

    private sealed record DeleteAttachmentResult
    {
        public string? DeletedFilePath { get; init; }
    }
}
