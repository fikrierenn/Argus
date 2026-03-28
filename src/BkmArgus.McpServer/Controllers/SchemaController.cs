using Microsoft.AspNetCore.Mvc;
using BkmArgus.McpServer.Services;
using BkmArgus.McpServer.Models;

namespace BkmArgus.McpServer.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SchemaController : ControllerBase
{
    private readonly SchemaExtractionService _schemaService;
    private readonly ILogger<SchemaController> _logger;

    public SchemaController(SchemaExtractionService schemaService, ILogger<SchemaController> logger)
    {
        _schemaService = schemaService;
        _logger = logger;
    }

    /// <summary>
    /// Belirtilen nesne tipinin schema'sını çıkarır
    /// </summary>
    [HttpGet("extract/{objectType}")]
    public async Task<IActionResult> ExtractSchema(string objectType)
    {
        try
        {
            var startTime = DateTime.Now;
            var result = new SchemaExtractionResult { Success = true };

            switch (objectType.ToLower())
            {
                case "tables":
                    var tables = await _schemaService.ExtractTablesAsync();
                    result.ObjectCount = tables.Count;
                    result.ExecutionTime = DateTime.Now - startTime;
                    result.Message = $"{tables.Count} tablo başarıyla çıkarıldı";
                    return Ok(new { 
                        Success = true, 
                        Data = tables, 
                        Result = result 
                    });

                case "views":
                    var views = await _schemaService.ExtractViewsAsync();
                    result.ObjectCount = views.Count;
                    result.ExecutionTime = DateTime.Now - startTime;
                    result.Message = $"{views.Count} view başarıyla çıkarıldı";
                    return Ok(new { 
                        Success = true, 
                        Data = views, 
                        Result = result 
                    });

                case "procedures":
                    var procedures = await _schemaService.ExtractProceduresAsync();
                    result.ObjectCount = procedures.Count;
                    result.ExecutionTime = DateTime.Now - startTime;
                    result.Message = $"{procedures.Count} stored procedure başarıyla çıkarıldı";
                    return Ok(new { 
                        Success = true, 
                        Data = procedures, 
                        Result = result 
                    });

                default:
                    return BadRequest(new { 
                        Success = false, 
                        Message = "Geçersiz nesne tipi. Desteklenen tipler: tables, views, procedures" 
                    });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Schema çıkarma hatası: {ObjectType}", objectType);
            return StatusCode(500, new { 
                Success = false, 
                Message = ex.Message 
            });
        }
    }

    /// <summary>
    /// Tüm schema nesnelerini çıkarır
    /// </summary>
    [HttpGet("extract/all")]
    public async Task<IActionResult> ExtractAllSchema()
    {
        try
        {
            var startTime = DateTime.Now;
            
            var tables = await _schemaService.ExtractTablesAsync();
            var views = await _schemaService.ExtractViewsAsync();
            var procedures = await _schemaService.ExtractProceduresAsync();

            var result = new SchemaExtractionResult
            {
                Success = true,
                ObjectCount = tables.Count + views.Count + procedures.Count,
                ExecutionTime = DateTime.Now - startTime,
                Message = $"Toplam {tables.Count + views.Count + procedures.Count} nesne çıkarıldı"
            };

            return Ok(new { 
                Success = true,
                Data = new {
                    Tables = tables,
                    Views = views,
                    Procedures = procedures
                },
                Result = result
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Tüm schema çıkarma hatası");
            return StatusCode(500, new { 
                Success = false, 
                Message = ex.Message 
            });
        }
    }

    /// <summary>
    /// Schema karşılaştırması yapar (placeholder - gelecekte implement edilecek)
    /// </summary>
    [HttpGet("compare")]
    public async Task<IActionResult> CompareSchema()
    {
        try
        {
            // TODO: Implement schema comparison logic
            await Task.Delay(100); // Placeholder
            
            var result = new SchemaComparisonResult
            {
                Summary = "Schema karşılaştırma özelliği henüz implement edilmedi",
                ComparisonDate = DateTime.Now
            };

            return Ok(new { 
                Success = true, 
                Data = result,
                Message = "Schema karşılaştırma özelliği geliştirilme aşamasında"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Schema karşılaştırma hatası");
            return StatusCode(500, new { 
                Success = false, 
                Message = ex.Message 
            });
        }
    }

    /// <summary>
    /// SQL dosyalarını günceller (placeholder - gelecekte implement edilecek)
    /// </summary>
    [HttpPost("update")]
    public async Task<IActionResult> UpdateSqlFiles()
    {
        try
        {
            // TODO: Implement SQL file update logic
            await Task.Delay(100); // Placeholder
            
            return Ok(new { 
                Success = true, 
                Message = "SQL dosya güncelleme özelliği geliştirilme aşamasında"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SQL dosya güncelleme hatası");
            return StatusCode(500, new { 
                Success = false, 
                Message = ex.Message 
            });
        }
    }
}