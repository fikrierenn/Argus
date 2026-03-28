using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Data;
using Microsoft.Data.SqlClient;
using System.Text.Json;

namespace BkmArgus.AiWorker.Jobs;

/// <summary>
/// Risk Tahmin İşi - Gelecekteki risk seviyelerini tahmin eder
/// </summary>
public class RiskPredictionJob : BaseAiJob
{
    public RiskPredictionJob(ILogger<RiskPredictionJob> logger, IOptions<AiWorkerOptions> options)
        : base(logger, options)
    {
    }

    public override async Task<JobResult> ExecuteAsync(CancellationToken cancellationToken = default)
    {
        var result = new JobResult { Success = true, Message = "Risk tahmini başarıyla tamamlandı" };
        
        try
        {
            // Varsayılan parametreler - normalde configuration'dan gelecek
            var predictionHorizons = new int[] { 7, 14, 30 };
            var timeoutMinutes = 30;
            
            _logger.LogInformation("Risk tahmin işi başlatılıyor. Ufuklar: {Horizons}", string.Join(", ", predictionHorizons));
            
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            
            var totalPredictions = 0;
            
            // Aktif tahmin modellerini al
            var models = await GetActivePredictionModelsAsync(connection);
            
            foreach (var model in models)
            {
                foreach (var horizon in predictionHorizons)
                {
                    // Tahmin gerektiren aktif mekan/stok kombinasyonlarını al
                    var targets = await GetPredictionTargetsAsync(connection, horizon);
                    
                    foreach (var target in targets)
                    {
                        try
                        {
                            var predictions = await GeneratePredictionsAsync(connection, model.ModelId, target.MekanId, target.StokId, horizon);
                            totalPredictions += predictions;
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Mekan {MekanId}, Stok {StokId}, Ufuk {Horizon} için tahmin oluşturulamadı", 
                                target.MekanId, target.StokId, horizon);
                        }
                    }
                }
            }
            
            result.Data = new Dictionary<string, object>
            {
                ["TotalPredictions"] = totalPredictions,
                ["ModelsUsed"] = models.Count,
                ["Horizons"] = predictionHorizons
            };
            _logger.LogInformation("Risk tahmin işi tamamlandı. {TotalPredictions} tahmin oluşturuldu", totalPredictions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Risk tahmin işi başarısız oldu");
            result.Success = false;
            result.Message = $"Risk tahmin işi başarısız: {ex.Message}";
            result.Exception = ex;
        }
        
        return result;
    }

    private async Task<List<PredictionModel>> GetActivePredictionModelsAsync(SqlConnection connection)
    {
        var models = new List<PredictionModel>();
        
        using var command = new SqlCommand(@"
            SELECT ModelId, ModelName, ModelType, PredictionHorizon, ModelParameters
            FROM ai.AiPredictionModel 
            WHERE Status = 'AKTIF' AND IsActive = 1
            ORDER BY ModelId", connection);
        
        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            models.Add(new PredictionModel
            {
                ModelId = reader.GetInt32("ModelId"),
                ModelName = reader.GetString("ModelName"),
                ModelType = reader.GetString("ModelType"),
                PredictionHorizon = reader.GetInt32("PredictionHorizon"),
                ModelParameters = reader.IsDBNull("ModelParameters") ? null : reader.GetString("ModelParameters")
            });
        }
        
        return models;
    }

    private async Task<List<PredictionTarget>> GetPredictionTargetsAsync(SqlConnection connection, int horizon)
    {
        var targets = new List<PredictionTarget>();
        
        // Son 7 günden tahmin gerektiren yüksek riskli öğeleri al
        using var command = new SqlCommand(@"
            SELECT DISTINCT TOP 100 MekanId, StokId
            FROM rpt.RiskUrunOzet_Gunluk r
            WHERE KesimGunu >= DATEADD(day, -7, CAST(SYSDATETIME() AS date))
              AND RiskSkor >= 70
              AND NOT EXISTS (
                  SELECT 1 FROM ai.AiRiskPrediction p
                  WHERE p.MekanId = r.MekanId 
                    AND p.StokId = r.StokId
                    AND p.PredictionDate = CAST(SYSDATETIME() AS date)
                    AND DATEDIFF(day, p.PredictionDate, p.TargetDate) = @Horizon
              )
            ORDER BY MAX(r.RiskSkor) DESC", connection);
        
        command.Parameters.AddWithValue("@Horizon", horizon);
        
        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            targets.Add(new PredictionTarget
            {
                MekanId = reader.GetInt32("MekanId"),
                StokId = reader.GetInt32("StokId")
            });
        }
        
        return targets;
    }

    private async Task<int> GeneratePredictionsAsync(SqlConnection connection, int modelId, int mekanId, int stokId, int horizon)
    {
        using var command = new SqlCommand("ai.sp_AiRisk_Predict", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300 // 5 dakika
        };
        
        command.Parameters.AddWithValue("@ModelId", modelId);
        command.Parameters.AddWithValue("@MekanId", mekanId);
        command.Parameters.AddWithValue("@StokId", stokId);
        command.Parameters.AddWithValue("@PredictionHorizon", horizon);
        
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result ?? 0);
    }

    private class PredictionModel
    {
        public int ModelId { get; set; }
        public string ModelName { get; set; }
        public string ModelType { get; set; }
        public int PredictionHorizon { get; set; }
        public string ModelParameters { get; set; }
    }

    private class PredictionTarget
    {
        public int MekanId { get; set; }
        public int StokId { get; set; }
    }
}