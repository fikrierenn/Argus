using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Data;
using Microsoft.Data.SqlClient;

namespace BkmArgus.AiWorker.Jobs;

/// <summary>
/// Agent Pipeline Monitor Job - Monitors running agent pipelines and cleans up stuck ones
/// </summary>
public class AgentPipelineMonitorJob : BaseAiJob
{
    public AgentPipelineMonitorJob(ILogger<AgentPipelineMonitorJob> logger, IOptions<AiWorkerOptions> options)
        : base(logger, options)
    {
    }

    public override async Task<JobResult> ExecuteAsync(CancellationToken cancellationToken = default)
    {
        var result = new JobResult { Success = true, Message = "Agent pipeline monitoring completed" };

        try
        {
            var maxRunningPipelines = 5;
            var timeoutMinutes = 30;

            _logger.LogInformation("Agent pipeline monitor job starting");

            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var monitoringResults = new Dictionary<string, object>
            {
                ["StuckPipelines"] = await HandleStuckPipelinesAsync(connection),
                ["FailedExecutions"] = await HandleFailedExecutionsAsync(connection),
                ["QueuedRequests"] = await ProcessQueuedRequestsAsync(connection, maxRunningPipelines),
                ["RunningPipelines"] = await GetRunningPipelineCountAsync(connection)
            };

            result.Data = monitoringResults;

            if ((int)monitoringResults["StuckPipelines"] > 0)
            {
                result.Message += $" {monitoringResults["StuckPipelines"]} stuck pipelines found.";
                _logger.LogWarning("{StuckPipelines} stuck pipelines found", monitoringResults["StuckPipelines"]);
            }

            _logger.LogInformation("Agent pipeline monitoring completed. Running: {Running}, Queued: {Queued}",
                monitoringResults["RunningPipelines"], monitoringResults["QueuedRequests"]);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Agent pipeline monitor job failed");
            result.Success = false;
            result.Message = $"Agent pipeline monitoring failed: {ex.Message}";
            result.Exception = ex;
        }

        return result;
    }

    private async Task<int> HandleStuckPipelinesAsync(SqlConnection connection)
    {
        // Find pipelines running for more than 30 minutes
        using var command = new SqlCommand(@"
            UPDATE ai.AgentPipelines
            SET Status = 'FAILED',
                EndTime = SYSDATETIME(),
                FinalOutput = '{""error"":""Pipeline timeout - exceeded maximum run time""}'
            WHERE Status = 'RUNNING'
              AND DATEDIFF(minute, StartTime, SYSDATETIME()) > 30
              AND EndTime IS NULL", connection);

        var stuckCount = await command.ExecuteNonQueryAsync();

        if (stuckCount > 0)
        {
            // Update related requests too
            using var updateRequests = new SqlCommand(@"
                UPDATE ai.AnalysisQueue
                SET Status = 'ERROR',
                    ErrorMessage = 'Agent pipeline timeout',
                    UpdatedAt = SYSDATETIME()
                WHERE RequestId IN (
                    SELECT RequestId FROM ai.AgentPipelines
                    WHERE Status = 'FAILED'
                      AND DATEDIFF(minute, COALESCE(EndTime, StartTime), SYSDATETIME()) < 1
                )", connection);

            await updateRequests.ExecuteNonQueryAsync();
        }

        return stuckCount;
    }

    private async Task<int> HandleFailedExecutionsAsync(SqlConnection connection)
    {
        // Find failed agent executions and mark their pipelines as failed
        using var command = new SqlCommand(@"
            WITH FailedPipelines AS (
                SELECT DISTINCT p.PipelineId
                FROM ai.AgentPipelines p
                INNER JOIN ai.AgentExecutions e ON e.RequestId = p.RequestId
                WHERE p.Status = 'RUNNING'
                  AND e.Status = 'FAILED'
                  AND e.EndTime IS NOT NULL
                  AND NOT EXISTS (
                      SELECT 1 FROM ai.AgentExecutions e2
                      WHERE e2.RequestId = p.RequestId
                        AND e2.Status IN ('RUNNING', 'COMPLETED')
                  )
            )
            UPDATE p SET
                Status = 'FAILED',
                EndTime = SYSDATETIME(),
                FinalOutput = '{""error"":""One or more agents failed""}'
            FROM ai.AgentPipelines p
            INNER JOIN FailedPipelines fp ON p.PipelineId = fp.PipelineId", connection);

        return await command.ExecuteNonQueryAsync();
    }

    private async Task<int> ProcessQueuedRequestsAsync(SqlConnection connection, int maxRunningPipelines)
    {
        // Check current running pipelines
        var runningCount = await GetRunningPipelineCountAsync(connection);

        if (runningCount >= maxRunningPipelines)
        {
            return 0; // No capacity for new pipelines
        }

        var availableSlots = maxRunningPipelines - runningCount;

        // Start new pipelines for queued requests
        using var command = new SqlCommand($@"
            WITH QueuedRequests AS (
                SELECT TOP ({availableSlots}) RequestId
                FROM ai.AnalysisQueue
                WHERE Status IN ('NEW', 'BEKLEMEDE')
                  AND NOT EXISTS (
                      SELECT 1 FROM ai.AgentPipelines p
                      WHERE p.RequestId = ai.AnalysisQueue.RequestId
                        AND p.Status IN ('PENDING', 'RUNNING')
                  )
                ORDER BY Priority DESC, CreatedAt
            )
            INSERT INTO ai.AgentPipelines (RequestId, Status, AgentSequence)
            SELECT
                q.RequestId,
                'PENDING',
                (SELECT STRING_AGG(CAST(AgentId AS varchar(10)), ',') WITHIN GROUP (ORDER BY ExecutionOrder)
                 FROM ai.AgentConfig WHERE IsActive = 1)
            FROM QueuedRequests q", connection);

        var queuedCount = await command.ExecuteNonQueryAsync();

        if (queuedCount > 0)
        {
            // Update request status
            using var updateCommand = new SqlCommand(@"
                UPDATE ai.AnalysisQueue
                SET Status = 'AGENT_PIPELINE_QUEUED',
                    UpdatedAt = SYSDATETIME()
                WHERE RequestId IN (
                    SELECT RequestId FROM ai.AgentPipelines
                    WHERE Status = 'PENDING'
                      AND DATEDIFF(second, StartTime, SYSDATETIME()) < 10
                )", connection);

            await updateCommand.ExecuteNonQueryAsync();
        }

        return queuedCount;
    }

    private async Task<int> GetRunningPipelineCountAsync(SqlConnection connection)
    {
        using var command = new SqlCommand(@"
            SELECT COUNT(*)
            FROM ai.AgentPipelines
            WHERE Status IN ('RUNNING', 'PENDING')", connection);

        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result ?? 0);
    }
}
