using Microsoft.AspNetCore.Mvc;
using BkmArgus.McpServer.Services;
using System.Text.Json;

namespace BkmArgus.McpServer.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DatabaseController : ControllerBase
{
    private readonly DatabaseService _databaseService;
    private readonly ILogger<DatabaseController> _logger;

    public DatabaseController(DatabaseService databaseService, ILogger<DatabaseController> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    /// <summary>
    /// Veritabanı bağlantısını test eder
    /// </summary>
    [HttpGet("health")]
    public async Task<IActionResult> HealthCheck()
    {
        try
        {
            var isConnected = await _databaseService.TestConnectionAsync();
            return Ok(new { 
                Status = isConnected ? "Healthy" : "Unhealthy",
                Timestamp = DateTime.Now,
                Database = "BKMDenetim"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check başarısız");
            return StatusCode(500, new { Status = "Error", Message = ex.Message });
        }
    }

    /// <summary>
    /// Tüm tabloları listeler
    /// </summary>
    [HttpGet("tables")]
    public async Task<IActionResult> GetTables()
    {
        try
        {
            var tables = await _databaseService.GetTablesAsync();
            return Ok(new { 
                Success = true,
                Count = tables.Count(),
                Data = tables 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Tablolar alınırken hata");
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// Tüm view'ları listeler
    /// </summary>
    [HttpGet("views")]
    public async Task<IActionResult> GetViews()
    {
        try
        {
            var views = await _databaseService.GetViewsAsync();
            return Ok(new { 
                Success = true,
                Count = views.Count(),
                Data = views 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "View'lar alınırken hata");
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// Tüm stored procedure'leri listeler
    /// </summary>
    [HttpGet("procedures")]
    public async Task<IActionResult> GetStoredProcedures()
    {
        try
        {
            var procedures = await _databaseService.GetStoredProceduresAsync();
            return Ok(new { 
                Success = true,
                Count = procedures.Count(),
                Data = procedures 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Stored procedure'ler alınırken hata");
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// Tablo kolonlarını getirir
    /// </summary>
    [HttpGet("tables/{schema}/{table}/columns")]
    public async Task<IActionResult> GetTableColumns(string schema, string table)
    {
        try
        {
            var columns = await _databaseService.GetTableColumnsAsync(schema, table);
            return Ok(new { 
                Success = true,
                Schema = schema,
                Table = table,
                Count = columns.Count(),
                Data = columns 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Tablo kolonları alınırken hata: {Schema}.{Table}", schema, table);
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// SQL sorgusu çalıştırır
    /// </summary>
    [HttpPost("query")]
    public async Task<IActionResult> ExecuteQuery([FromBody] QueryRequest request)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.Sql))
            {
                return BadRequest(new { Success = false, Message = "SQL sorgusu boş olamaz" });
            }

            // Güvenlik kontrolü - sadece SELECT sorgularına izin ver
            var sqlTrimmed = request.Sql.Trim().ToUpper();
            if (!sqlTrimmed.StartsWith("SELECT") && !sqlTrimmed.StartsWith("WITH"))
            {
                return BadRequest(new { Success = false, Message = "Sadece SELECT sorguları desteklenir" });
            }

            var result = await _databaseService.ExecuteQueryAsync(request.Sql, request.MaxRows ?? 1000);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SQL sorgusu çalıştırılırken hata");
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// Stored procedure çalıştırır
    /// </summary>
    [HttpPost("procedures/{schema}/{procedure}")]
    public async Task<IActionResult> ExecuteStoredProcedure(string schema, string procedure, [FromBody] ProcedureRequest? request = null)
    {
        try
        {
            var fullProcedureName = $"{schema}.{procedure}";
            var result = await _databaseService.ExecuteStoredProcedureAsync(fullProcedureName, request?.Parameters);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Stored procedure çalıştırılırken hata: {Schema}.{Procedure}", schema, procedure);
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// Hızlı tablo verisi görüntüleme
    /// </summary>
    [HttpGet("tables/{schema}/{table}/data")]
    public async Task<IActionResult> GetTableData(string schema, string table, [FromQuery] int top = 100)
    {
        try
        {
            var sql = $"SELECT TOP ({top}) * FROM [{schema}].[{table}] ORDER BY 1 DESC";
            var result = await _databaseService.ExecuteQueryAsync(sql, top);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Tablo verisi alınırken hata: {Schema}.{Table}", schema, table);
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }

    /// <summary>
    /// Tablo kayıt sayısını getirir
    /// </summary>
    [HttpGet("tables/{schema}/{table}/count")]
    public async Task<IActionResult> GetTableCount(string schema, string table)
    {
        try
        {
            var sql = $"SELECT COUNT(*) as RecordCount FROM [{schema}].[{table}]";
            var result = await _databaseService.ExecuteQueryAsync(sql, 1);
            
            if (result.Success && result.Rows.Count > 0)
            {
                var count = result.Rows[0]["RecordCount"];
                return Ok(new { 
                    Success = true,
                    Schema = schema,
                    Table = table,
                    RecordCount = count,
                    ExecutionTime = result.ExecutionTime
                });
            }
            
            return Ok(new { Success = false, Message = "Kayıt sayısı alınamadı" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Tablo kayıt sayısı alınırken hata: {Schema}.{Table}", schema, table);
            return StatusCode(500, new { Success = false, Message = ex.Message });
        }
    }
}

public class QueryRequest
{
    public string Sql { get; set; } = string.Empty;
    public int? MaxRows { get; set; }
}

public class ProcedureRequest
{
    public Dictionary<string, object>? Parameters { get; set; }
}