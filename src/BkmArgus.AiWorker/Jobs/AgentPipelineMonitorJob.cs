using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Data;
using Microsoft.Data.SqlClient;

namespace BkmArgus.AiWorker.Jobs;

/// <summary>
/// Agent Pipeline İzleme İşi - Çalışan agent pipeline'larını izler ve takılı olanları temizler
/// </summary>
public class AgentPipelineMonitorJob : BaseAiJob
{
    public AgentPipelineMonitorJob(ILogger<AgentPipelineMonitorJob> logger, IOptions<AiWorkerOptions> options)
        : base(logger, options)
    {
    }

    public override async Task<JobResult> ExecuteAsync(CancellationToken cancellationToken = default)
    {
        var result = new JobResult { Success = true, Message = "Agent pipeline izleme tamamlandı" };
        
        try
        {
            // Varsayılan parametreler - normalde configuration'dan gelecek
            var maxRunningPipelines = 5;
            var timeoutMinutes = 30;
            
            _logger.LogInformation("Agent pipeline izleme işi başlatılıyor");
            
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
                result.Message += $" {monitoringResults["StuckPipelines"]} takılı pipeline bulundu.";
                _logger.LogWarning("{StuckPipelines} takılı pipeline bulundu", monitoringResults["StuckPipelines"]);
            }
            
            _logger.LogInformation("Agent pipeline izleme tamamlandı. Çalışan: {Running}, Sırada: {Queued}", 
                monitoringResults["RunningPipelines"], monitoringResults["QueuedRequests"]);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Agent pipeline izleme işi başarısız");
            result.Success = false;
            result.Message = $"Agent pipeline izleme başarısız: {ex.Message}";
            result.Exception = ex;
        }
        
        return result;
    }

    private async Task<int> HandleStuckPipelinesAsync(SqlConnection connection)
    {
        // 30 dakikadan fazla çalışan pipeline'ları bul
        using var command = new SqlCommand(@"
            UPDATE ai.AiAgentPipeline 
            SET Status = 'FAILED',
                EndTime = SYSDATETIME(),
                FinalOutput = '{""error"":""Pipeline timeout - maksimum çalışma süresini aştı""}'
            WHERE Status = 'RUNNING' 
              AND DATEDIFF(minute, StartTime, SYSDATETIME()) > 30
              AND EndTime IS NULL", connection);
        
        var stuckCount = await command.ExecuteNonQueryAsync();
        
        if (stuckCount > 0)
        {
            // İlgili istekleri de güncelle
            using var updateRequests = new SqlCommand(@"
                UPDATE ai.AiAnalizIstegi 
                SET Durum = 'ERROR',
                    HataMesaji = 'Agent pipeline timeout',
                    GuncellemeTarihi = SYSDATETIME()
                WHERE IstekId IN (
                    SELECT RequestId FROM ai.AiAgentPipeline 
                    WHERE Status = 'FAILED' 
                      AND DATEDIFF(minute, COALESCE(EndTime, StartTime), SYSDATETIME()) < 1
                )", connection);
            
            await updateRequests.ExecuteNonQueryAsync();
        }
        
        return stuckCount;
    }

    private async Task<int> HandleFailedExecutionsAsync(SqlConnection connection)
    {
        // Başarısız agent yürütmelerini bul ve pipeline'larını başarısız olarak işaretle
        using var command = new SqlCommand(@"
            WITH FailedPipelines AS (
                SELECT DISTINCT p.PipelineId
                FROM ai.AiAgentPipeline p
                INNER JOIN ai.AiAgentExecution e ON e.RequestId = p.RequestId
                WHERE p.Status = 'RUNNING'
                  AND e.Status = 'FAILED'
                  AND e.EndTime IS NOT NULL
                  AND NOT EXISTS (
                      SELECT 1 FROM ai.AiAgentExecution e2 
                      WHERE e2.RequestId = p.RequestId 
                        AND e2.Status IN ('RUNNING', 'COMPLETED')
                  )
            )
            UPDATE p SET 
                Status = 'FAILED',
                EndTime = SYSDATETIME(),
                FinalOutput = '{""error"":""Bir veya daha fazla agent başarısız""}'
            FROM ai.AiAgentPipeline p
            INNER JOIN FailedPipelines fp ON p.PipelineId = fp.PipelineId", connection);
        
        return await command.ExecuteNonQueryAsync();
    }

    private async Task<int> ProcessQueuedRequestsAsync(SqlConnection connection, int maxRunningPipelines)
    {
        // Mevcut çalışan pipeline'ları kontrol et
        var runningCount = await GetRunningPipelineCountAsync(connection);
        
        if (runningCount >= maxRunningPipelines)
        {
            return 0; // Yeni pipeline'lar için kapasite yok
        }
        
        var availableSlots = maxRunningPipelines - runningCount;
        
        // Sıradaki istekler için yeni pipeline'lar başlat
        using var command = new SqlCommand($@"
            WITH QueuedRequests AS (
                SELECT TOP ({availableSlots}) IstekId
                FROM ai.AiAnalizIstegi
                WHERE Durum IN ('NEW', 'BEKLEMEDE')
                  AND NOT EXISTS (
                      SELECT 1 FROM ai.AiAgentPipeline p 
                      WHERE p.RequestId = ai.AiAnalizIstegi.IstekId 
                        AND p.Status IN ('PENDING', 'RUNNING')
                  )
                ORDER BY Oncelik DESC, OlusturmaTarihi
            )
            INSERT INTO ai.AiAgentPipeline (RequestId, Status, AgentSequence)
            SELECT 
                q.IstekId,
                'PENDING',
                (SELECT STRING_AGG(CAST(AgentId AS varchar(10)), ',') WITHIN GROUP (ORDER BY ExecutionOrder)
                 FROM ai.AiAgentConfig WHERE IsActive = 1)
            FROM QueuedRequests q", connection);
        
        var queuedCount = await command.ExecuteNonQueryAsync();
        
        if (queuedCount > 0)
        {
            // İstek durumunu güncelle
            using var updateCommand = new SqlCommand(@"
                UPDATE ai.AiAnalizIstegi 
                SET Durum = 'AGENT_PIPELINE_QUEUED',
                    GuncellemeTarihi = SYSDATETIME()
                WHERE IstekId IN (
                    SELECT RequestId FROM ai.AiAgentPipeline 
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
            FROM ai.AiAgentPipeline 
            WHERE Status IN ('RUNNING', 'PENDING')", connection);
        
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result ?? 0);
    }
}