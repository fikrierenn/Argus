using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Data;
using Microsoft.Data.SqlClient;
using System.Text.Json;

namespace BkmArgus.AiWorker.Jobs
{
    /// <summary>
    /// Tüm AI işleri için temel sınıf
    /// Ortak fonksiyonalite ve yardımcı metodları sağlar
    /// </summary>
    public abstract class BaseAiJob
    {
        protected readonly ILogger _logger;
        protected readonly AiWorkerOptions _options;
        protected readonly string _connectionString;

        protected BaseAiJob(ILogger logger, IOptions<AiWorkerOptions> options)
        {
            _logger = logger;
            _options = options.Value;
            _connectionString = _options.ConnectionString;
        }

        /// <summary>
        /// İşi çalıştırır
        /// </summary>
        public abstract Task<JobResult> ExecuteAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Stored procedure çalıştırır ve sonucu döndürür
        /// </summary>
        protected async Task<StoredProcedureResult> ExecuteStoredProcedureAsync(
            string procedureName,
            Dictionary<string, object> parameters = null,
            CancellationToken cancellationToken = default)
        {
            var result = new StoredProcedureResult();
            
            try
            {
                using var connection = new SqlConnection(_options.ConnectionString);
                await connection.OpenAsync(cancellationToken);

                using var command = new SqlCommand(procedureName, connection)
                {
                    CommandType = CommandType.StoredProcedure,
                    CommandTimeout = 300 // 5 dakika timeout
                };

                // Parametreleri ekle
                if (parameters != null)
                {
                    foreach (var param in parameters)
                    {
                        command.Parameters.AddWithValue($"@{param.Key}", param.Value ?? DBNull.Value);
                    }
                }

                using var reader = await command.ExecuteReaderAsync(cancellationToken);
                
                // İlk result set'i oku
                if (reader.HasRows)
                {
                    var data = new Dictionary<string, object>();
                    
                    if (await reader.ReadAsync(cancellationToken))
                    {
                        for (int i = 0; i < reader.FieldCount; i++)
                        {
                            var fieldName = reader.GetName(i);
                            var fieldValue = reader.IsDBNull(i) ? null : reader.GetValue(i);
                            data[fieldName] = fieldValue;
                        }
                    }
                    
                    result.Data = data;
                }

                result.Success = true;
                
                _logger.LogDebug("Stored procedure başarıyla çalıştırıldı: {ProcedureName}", procedureName);
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.ErrorMessage = ex.Message;
                _logger.LogError(ex, "Stored procedure çalıştırılırken hata: {ProcedureName}", procedureName);
            }

            return result;
        }

        /// <summary>
        /// Veritabanı bağlantısını test eder
        /// </summary>
        protected async Task<bool> TestDatabaseConnectionAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                using var connection = new SqlConnection(_options.ConnectionString);
                await connection.OpenAsync(cancellationToken);
                return connection.State == ConnectionState.Open;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Veritabanı bağlantı testi başarısız");
                return false;
            }
        }

        /// <summary>
        /// SQL sorgusu çalıştırır ve tek değer döndürür
        /// </summary>
        protected async Task<T> ExecuteScalarAsync<T>(string sql, CancellationToken cancellationToken = default)
        {
            try
            {
                using var connection = new SqlConnection(_options.ConnectionString);
                await connection.OpenAsync(cancellationToken);

                using var command = new SqlCommand(sql, connection);
                var result = await command.ExecuteScalarAsync(cancellationToken);

                if (result == null || result == DBNull.Value)
                    return default(T);

                return (T)Convert.ChangeType(result, typeof(T));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SQL sorgusu çalıştırılırken hata: {Sql}", sql);
                return default(T);
            }
        }

        /// <summary>
        /// İş sonucu için yardımcı metod
        /// </summary>
        protected JobResult CreateSuccessResult(string message, int recordsProcessed = 0, TimeSpan? executionTime = null)
        {
            return new JobResult
            {
                Success = true,
                Message = message,
                RecordsProcessed = recordsProcessed,
                ExecutionTime = executionTime ?? TimeSpan.Zero
            };
        }

        /// <summary>
        /// Hata sonucu için yardımcı metod
        /// </summary>
        protected JobResult CreateErrorResult(string message, Exception exception = null, TimeSpan? executionTime = null)
        {
            if (exception != null)
            {
                _logger.LogError(exception, "İş hatası: {Message}", message);
            }

            return new JobResult
            {
                Success = false,
                Message = message,
                ExecutionTime = executionTime ?? TimeSpan.Zero
            };
        }
    }

    /// <summary>
    /// İş sonucu sınıfı
    /// </summary>
    public class JobResult
    {
        public string JobName { get; set; }
        public bool Success { get; set; }
        public string Message { get; set; }
        public int RecordsProcessed { get; set; }
        public TimeSpan ExecutionTime { get; set; }
        public Dictionary<string, object> AdditionalData { get; set; } = new();
        public Dictionary<string, object> Data { get; set; } = new();
        public Exception? Exception { get; set; }
    }

    /// <summary>
    /// Stored procedure sonucu sınıfı
    /// </summary>
    public class StoredProcedureResult
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
        public Dictionary<string, object> Data { get; set; }
    }
}