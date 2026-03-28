namespace SchemaManagement.Library.Models;

public class ValidationResult
{
    public bool IsValid { get; set; }
    public List<ValidationError> Errors { get; set; } = new();
    public List<ValidationError> Warnings { get; set; } = new();
    public List<string> Dependencies { get; set; } = new();
}

public class ValidationError
{
    public int LineNumber { get; set; }
    public int ColumnNumber { get; set; }
    public string ErrorMessage { get; set; } = string.Empty;
    public string ErrorCode { get; set; } = string.Empty;
    public string Severity { get; set; } = string.Empty;
}
