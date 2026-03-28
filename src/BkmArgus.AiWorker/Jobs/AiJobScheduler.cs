using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Text.Json;
using NCrontab;

namespace BkmArgus.AiWorker.Jobs;

/// <summary>
/// AI İş Zamanlayıcısı - AI geliştirme işlerini zamanlar ve yönetir
/// </summary>
public class AiJobScheduler : BackgroundService
{
    private readonly ILogger<AiJobScheduler> _logger;
    private readonly IServiceProvider _serviceProvider;
    private readonly AiJobConfiguration _configuration;
    private readonly Dictionary<string, CrontabSchedule> _schedules;
    private readonly Dictionary<string, DateTime> _nextRunTimes;
    private readonly Dictionary<string, bool> _runningJobs;

    public AiJobScheduler(
        ILogger<AiJobScheduler> logger, 
        IServiceProvider serviceProvider,
        IOptions<AiJobConfiguration> configuration)
    {
        _logger = logger;
        _serviceProvider = serviceProvider;
        _configuration = configuration.Value;
        _schedules = new Dictionary<string, CrontabSchedule>();
        _nextRunTimes = new Dictionary<string, DateTime>();
        _runningJobs = new Dictionary<string, bool>();

        InitializeSchedules();
    }

    private void InitializeSchedules()
    {
        foreach (var job in _configuration.AiEnhancementJobs)
        {
            if (job.Value.Enabled)
            {
                try
                {
                    var schedule = CrontabSchedule.Parse(job.Value.Schedule);
                    _schedules[job.Key] = schedule;
                    _nextRunTimes[job.Key] = schedule.GetNextOccurrence(DateTime.Now);
                    _runningJobs[job.Key] = false;
                    
                    _logger.LogInformation("İş zamanlandı {JobName}, cron: {Schedule}. Sonraki çalışma: {NextRun}", 
                        job.Key, job.Value.Schedule, _nextRunTimes[job.Key]);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "İş için cron zamanlaması ayrıştırılamadı {JobName}: {Schedule}", 
                        job.Key, job.Value.Schedule);
                }
            }
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("AI İş Zamanlayıcısı başlatıldı");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var now = DateTime.Now;
                var jobsToRun = new List<string>();

                // Hangi işlerin çalışması gerektiğini kontrol et
                foreach (var kvp in _nextRunTimes.ToList())
                {
                    if (now >= kvp.Value && !_runningJobs[kvp.Key])
                    {
                        jobsToRun.Add(kvp.Key);
                        // Sonraki çalışma zamanını güncelle
                        _nextRunTimes[kvp.Key] = _schedules[kvp.Key].GetNextOccurrence(now);
                    }
                }

                // İşleri çalıştır
                var runningJobCount = _runningJobs.Values.Count(x => x);
                var availableSlots = _configuration.GlobalSettings.MaxConcurrentJobs - runningJobCount;

                foreach (var jobName in jobsToRun.Take(availableSlots))
                {
                    _ = Task.Run(async () => await ExecuteJobAsync(jobName), stoppingToken);
                }

                // Sonraki kontrol için bekle (her 30 saniye)
                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "İş zamanlayıcısı ana döngüsünde hata");
                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
            }
        }

        _logger.LogInformation("AI İş Zamanlayıcısı durduruldu");
    }

    private async Task ExecuteJobAsync(string jobName)
    {
        if (!_configuration.AiEnhancementJobs.TryGetValue(jobName, out var jobConfig))
        {
            _logger.LogWarning("İş konfigürasyonu bulunamadı {JobName}", jobName);
            return;
        }

        _runningJobs[jobName] = true;
        var startTime = DateTime.Now;
        
        try
        {
            _logger.LogInformation("İş başlatılıyor {JobName}", jobName);

            JobResult result;
            
            if (jobConfig.JobType == "StoredProcedure")
            {
                result = await ExecuteStoredProcedureJobAsync(jobConfig);
            }
            else if (jobConfig.JobType == "Custom")
            {
                result = await ExecuteCustomJobAsync(jobConfig);
            }
            else
            {
                throw new NotSupportedException($"İş tipi {jobConfig.JobType} desteklenmiyor");
            }

            var duration = DateTime.Now - startTime;
            
            if (result.Success)
            {
                _logger.LogInformation("İş {JobName} başarıyla tamamlandı {Duration}ms içinde. {Message}", 
                    jobName, duration.TotalMilliseconds, result.Message);
                
                if (jobConfig.Notifications.OnSuccess)
                {
                    await SendNotificationAsync(jobName, "SUCCESS", result.Message, result.Data);
                }
            }
            else
            {
                _logger.LogError("İş {JobName} başarısız {Duration}ms sonra. {Message}", 
                    jobName, duration.TotalMilliseconds, result.Message);
                
                if (jobConfig.Notifications.OnFailure)
                {
                    await SendNotificationAsync(jobName, "FAILURE", result.Message, result.Exception);
                }
            }
        }
        catch (Exception ex)
        {
            var duration = DateTime.Now - startTime;
            _logger.LogError(ex, "İş {JobName} istisna fırlattı {Duration}ms sonra", jobName, duration.TotalMilliseconds);
            
            if (jobConfig.Notifications.OnFailure)
            {
                await SendNotificationAsync(jobName, "ERROR", ex.Message, ex);
            }
        }
        finally
        {
            _runningJobs[jobName] = false;
        }
    }

    private async Task<JobResult> ExecuteStoredProcedureJobAsync(AiJobConfig jobConfig)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbService = scope.ServiceProvider.GetRequiredService<Db>();
        
        try
        {
            var parameters = jobConfig.Parameters.Arguments ?? new Dictionary<string, object>();
            var timeoutMinutes = jobConfig.Parameters.TimeoutMinutes ?? _configuration.GlobalSettings.DefaultTimeoutMinutes;
            
            var result = await dbService.ExecuteStoredProcedureAsync(
                jobConfig.Parameters.StoredProcedure, 
                parameters);
            
            return new JobResult 
            { 
                Success = true, 
                Message = "Stored procedure başarıyla çalıştırıldı",
                Data = result
            };
        }
        catch (Exception ex)
        {
            return new JobResult 
            { 
                Success = false, 
                Message = $"Stored procedure çalıştırma başarısız: {ex.Message}",
                Exception = ex
            };
        }
    }

    private async Task<JobResult> ExecuteCustomJobAsync(AiJobConfig jobConfig)
    {
        using var scope = _serviceProvider.CreateScope();
        
        try
        {
            var className = jobConfig.Parameters.ClassName;
            
            // AI jobları için özel handling - sadece gerçekten C# gerektiren işler
            BaseAiJob jobInstance = className switch
            {
                "BkmArgus.AiWorker.Jobs.RiskPredictionJob" => 
                    ActivatorUtilities.CreateInstance<RiskPredictionJob>(scope.ServiceProvider),
                "BkmArgus.AiWorker.Jobs.AgentPipelineMonitorJob" => 
                    ActivatorUtilities.CreateInstance<AgentPipelineMonitorJob>(scope.ServiceProvider),
                _ => throw new InvalidOperationException($"İş sınıfı {className} desteklenmiyor")
            };
            
            var result = await jobInstance.ExecuteAsync();
            return result;
        }
        catch (Exception ex)
        {
            return new JobResult 
            { 
                Success = false, 
                Message = $"Özel iş çalıştırma başarısız: {ex.Message}",
                Exception = ex
            };
        }
    }

    private async Task SendNotificationAsync(string jobName, string status, string message, object data)
    {
        try
        {
            // Bildirim implementasyonu için placeholder
            // Email, Slack mesajları vb. gönderilebilir
            _logger.LogInformation("İş için bildirim {JobName}: {Status} - {Message}", jobName, status, message);
            
            // TODO: Konfigürasyona göre gerçek bildirim gönderimi implementasyonu
            await Task.CompletedTask;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "İş için bildirim gönderme başarısız {JobName}", jobName);
        }
    }
}

public class AiJobConfiguration
{
    public Dictionary<string, AiJobConfig> AiEnhancementJobs { get; set; } = new();
    public GlobalJobSettings GlobalSettings { get; set; } = new();
}

public class AiJobConfig
{
    public string Name { get; set; }
    public string Description { get; set; }
    public string Schedule { get; set; }
    public bool Enabled { get; set; }
    public string JobType { get; set; }
    public JobParameters Parameters { get; set; } = new();
    public NotificationSettings Notifications { get; set; } = new();
}

public class JobParameters
{
    public string StoredProcedure { get; set; }
    public string ClassName { get; set; }
    public Dictionary<string, object> Arguments { get; set; } = new();
    public int? TimeoutMinutes { get; set; }
    public int BatchSize { get; set; }
    public int MaxRunningPipelines { get; set; }
    public string DetectionMethod { get; set; }
    public decimal SensitivityLevel { get; set; }
    public int[] PredictionHorizons { get; set; }
}

public class NotificationSettings
{
    public bool OnSuccess { get; set; }
    public bool OnFailure { get; set; }
    public bool OnAnomaliesFound { get; set; }
    public bool OnRetrainingTriggered { get; set; }
    public bool OnHealthIssues { get; set; }
    public bool OnStuckPipelines { get; set; }
    
    // ETL bildirimleri
    public bool OnLargeTransfer { get; set; }
    public bool OnQualityIssues { get; set; }
    
    public string[] EmailRecipients { get; set; } = Array.Empty<string>();
}

public class GlobalJobSettings
{
    public int MaxConcurrentJobs { get; set; } = 3;
    public int DefaultTimeoutMinutes { get; set; } = 30;
    public int RetryCount { get; set; } = 2;
    public int RetryDelayMinutes { get; set; } = 5;
    public string LogLevel { get; set; } = "Information";
    public bool EnableDetailedLogging { get; set; } = true;
    public SmtpSettings NotificationSettings { get; set; } = new();
}

public class SmtpSettings
{
    public string SmtpServer { get; set; }
    public int SmtpPort { get; set; }
    public string FromEmail { get; set; }
    public bool EnableSsl { get; set; }
}