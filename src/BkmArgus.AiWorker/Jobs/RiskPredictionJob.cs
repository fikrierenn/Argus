using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Data;
using Microsoft.Data.SqlClient;
using System.Text.Json;

namespace BkmArgus.AiWorker.Jobs;

/// <summary>
/// Risk Prediction Job - Predicts future risk levels
/// </summary>
public class RiskPredictionJob : BaseAiJob
{
    public RiskPredictionJob(ILogger<RiskPredictionJob> logger, IOptions<AiWorkerOptions> options)
        : base(logger, options)
    {
    }

    public override async Task<JobResult> ExecuteAsync(CancellationToken cancellationToken = default)
    {
        var result = new JobResult { Success = true, Message = "Risk prediction completed successfully" };

        try
        {
            var predictionHorizons = new int[] { 7, 14, 30 };
            var timeoutMinutes = 30;

            _logger.LogInformation("Risk prediction job starting. Horizons: {Horizons}", string.Join(", ", predictionHorizons));

            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var totalPredictions = 0;

            // Get active prediction models
            var models = await GetActivePredictionModelsAsync(connection);

            foreach (var model in models)
            {
                foreach (var horizon in predictionHorizons)
                {
                    // Get active location/product combinations requiring prediction
                    var targets = await GetPredictionTargetsAsync(connection, horizon);

                    foreach (var target in targets)
                    {
                        try
                        {
                            var predictions = await GeneratePredictionsAsync(connection, model.ModelId, target.LocationId, target.ProductId, horizon);
                            totalPredictions += predictions;
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Prediction failed for Location {LocationId}, Product {ProductId}, Horizon {Horizon}",
                                target.LocationId, target.ProductId, horizon);
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
            _logger.LogInformation("Risk prediction job completed. {TotalPredictions} predictions generated", totalPredictions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Risk prediction job failed");
            result.Success = false;
            result.Message = $"Risk prediction job failed: {ex.Message}";
            result.Exception = ex;
        }

        return result;
    }

    private async Task<List<PredictionModel>> GetActivePredictionModelsAsync(SqlConnection connection)
    {
        var models = new List<PredictionModel>();

        using var command = new SqlCommand(@"
            SELECT ModelId, ModelName, ModelType, PredictionHorizon, ModelParameters
            FROM ai.PredictionModels
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

        // Get high-risk items from last 7 days that need prediction
        using var command = new SqlCommand(@"
            SELECT DISTINCT TOP 100 LocationId, ProductId
            FROM rpt.DailyProductRisk r
            WHERE SnapshotDay >= DATEADD(day, -7, CAST(SYSDATETIME() AS date))
              AND RiskScore >= 70
              AND NOT EXISTS (
                  SELECT 1 FROM ai.RiskPredictions p
                  WHERE p.LocationId = r.LocationId
                    AND p.ProductId = r.ProductId
                    AND p.PredictionDate = CAST(SYSDATETIME() AS date)
                    AND DATEDIFF(day, p.PredictionDate, p.TargetDate) = @Horizon
              )
            ORDER BY MAX(r.RiskScore) DESC", connection);

        command.Parameters.AddWithValue("@Horizon", horizon);

        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            targets.Add(new PredictionTarget
            {
                LocationId = reader.GetInt32("LocationId"),
                ProductId = reader.GetInt32("ProductId")
            });
        }

        return targets;
    }

    private async Task<int> GeneratePredictionsAsync(SqlConnection connection, int modelId, int locationId, int productId, int horizon)
    {
        using var command = new SqlCommand("ai.sp_RiskPrediction_Run", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300 // 5 minutes
        };

        command.Parameters.AddWithValue("@ModelId", modelId);
        command.Parameters.AddWithValue("@MekanId", locationId);
        command.Parameters.AddWithValue("@StokId", productId);
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
        public int LocationId { get; set; }
        public int ProductId { get; set; }
    }
}
