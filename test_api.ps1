# Web Installer API Test Script
Write-Host "🌐 Web Installer API Test" -ForegroundColor Blue
Write-Host ""

# Test API endpoint
$apiUrl = "http://localhost:5555/api/status"

Write-Host "API URL: $apiUrl" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "📡 API çağrısı yapılıyor..." -ForegroundColor Cyan
    
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ContentType "application/json"
    
    Write-Host "✅ API yanıtı alındı:" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "🔗 Bağlantı Durumu: " -NoNewline
    if ($response.Connected) {
        Write-Host "✅ Bağlı" -ForegroundColor Green
    } else {
        Write-Host "❌ Bağlantı Yok" -ForegroundColor Red
    }
    
    Write-Host "📋 Şemalar: " -NoNewline
    if ($response.Schemas -and $response.Schemas.Count -gt 0) {
        Write-Host "$($response.Schemas -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "Şema bulunamadı" -ForegroundColor Red
    }
    
    Write-Host "⚙️ Stored Procedures:"
    if ($response.StoredProcedureCounts) {
        foreach ($schema in @('ai', 'etl', 'log', 'rpt')) {
            $count = if ($response.StoredProcedureCounts.$schema) { $response.StoredProcedureCounts.$schema } else { 0 }
            Write-Host "   $schema`: $count" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "🕒 Zaman: $($response.Timestamp)" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ API hatası: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Web installer çalışıyor mu kontrol edin:" -ForegroundColor Yellow
    Write-Host "   dotnet run --project src/BkmDenetim.Installer/BkmDenetim.Installer.csproj" -ForegroundColor Gray
    Write-Host "   Sonra 'Web Interface (Detaylı Kurulum)' seçin" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Test tamamlandı." -ForegroundColor Blue