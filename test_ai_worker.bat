@echo off
echo ========================================
echo BKM Denetim AI Worker Service Test
echo ========================================
echo.

echo [%date% %time%] AI Worker Service test baslatiliyor...

echo.
echo 1. Veritabani baglanti testi...
dotnet run --project src/BkmDenetim.AiWorker/BkmDenetim.AiWorker.csproj test-db

if %ERRORLEVEL% NEQ 0 (
    echo [HATA] Veritabani baglanti testi basarisiz!
    pause
    exit /b 1
)

echo.
echo 2. AI Worker Service derleme testi...
dotnet build src/BkmDenetim.AiWorker/BkmDenetim.AiWorker.csproj

if %ERRORLEVEL% NEQ 0 (
    echo [HATA] AI Worker Service derleme basarisiz!
    pause
    exit /b 1
)

echo.
echo [BASARILI] Tum testler basarili!
echo.
echo AI Worker Service'i calistirmak icin:
echo dotnet run --project src/BkmDenetim.AiWorker/BkmDenetim.AiWorker.csproj
echo.
echo Veya Windows Service olarak yuklemek icin:
echo sc create "BKM Denetim AI Worker" binPath="[FULL_PATH_TO_EXE]"
echo.
pause