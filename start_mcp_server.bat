@echo off
echo ========================================
echo BKM Denetim MCP Server Başlatılıyor
echo ========================================
echo.

echo [%date% %time%] MCP Server başlatılıyor...
echo.
echo Web Arayüzü: http://localhost:5001
echo API Dokümantasyonu: http://localhost:5001/swagger
echo Health Check: http://localhost:5001/api/database/health
echo.

cd /d "%~dp0"
dotnet run --project src/BkmDenetim.McpServer/BkmDenetim.McpServer.csproj --urls "http://localhost:5001"

pause