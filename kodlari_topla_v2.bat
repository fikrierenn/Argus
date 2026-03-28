@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

REM ============================================
REM  YonetIQ Repo Audit Collector
REM  Çıktı: REPO_AUDIT_BUNDLE.txt
REM ============================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "APP=%ROOT%\yonetiq"
set "OUT=%ROOT%\REPO_AUDIT_BUNDLE.txt"
set "INV=%ROOT%\all_files_clean.txt"
set "BUILD=%ROOT%\build_now.txt"
set "GITSTATUS=%ROOT%\git_status_now.txt"
set "DOTNETINFO=%ROOT%\dotnet_info_now.txt"

echo [1/6] Temizlik...
if exist "%OUT%" del /f /q "%OUT%"
if exist "%INV%" del /f /q "%INV%"
if exist "%BUILD%" del /f /q "%BUILD%"
if exist "%GITSTATUS%" del /f /q "%GITSTATUS%"
if exist "%DOTNETINFO%" del /f /q "%DOTNETINFO%"

echo [2/6] Dosya envanteri olusturuluyor...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root = [System.IO.Path]::GetFullPath('%ROOT%');" ^
  "$files = Get-ChildItem -Path $root -File -Recurse | Where-Object {" ^
  "  $_.FullName -notmatch '\\\.git\\' -and" ^
  "  $_.FullName -notmatch '\\\.vs\\' -and" ^
  "  $_.FullName -notmatch '\\\.tmp_build\\' -and" ^
  "  $_.FullName -notmatch '\\bin\\' -and" ^
  "  $_.FullName -notmatch '\\obj\\' -and" ^
  "  $_.FullName -notmatch '\\wwwroot\\lib\\' -and" ^
  "  $_.FullName -notmatch '\\wwwroot\\css\\bootstrap\\' -and" ^
  "  $_.FullName -notmatch '\\wwwroot\\css\\open-iconic\\' -and" ^
  "  $_.Extension -in '.cs','.razor','.sql','.md','.json','.csproj','.sln','.ps1','.bat','.py','.yml','.yaml','.txt'" ^
  "};" ^
  "$files | Sort-Object FullName | Select-Object -ExpandProperty FullName | Set-Content -Encoding UTF8 '%INV%'"

echo [3/6] dotnet bilgisi aliniyor...
where dotnet >nul 2>nul
if %errorlevel%==0 (
  dotnet --info > "%DOTNETINFO%" 2>&1
) else (
  > "%DOTNETINFO%" echo dotnet bulunamadi.
)

echo [4/6] Guncel build aliniyor...
if exist "%APP%\YonetIQ.csproj" (
  dotnet build "%APP%\YonetIQ.csproj" -nologo -clp:ErrorsOnly;Summary > "%BUILD%" 2>&1
) else (
  > "%BUILD%" echo YonetIQ.csproj bulunamadi: %APP%\YonetIQ.csproj
)

echo [5/6] Git durumu aliniyor...
where git >nul 2>nul
if %errorlevel%==0 (
  git -C "%ROOT%" status --short > "%GITSTATUS%" 2>&1
  echo.>> "%GITSTATUS%"
  echo ----- BRANCHES ----- >> "%GITSTATUS%"
  git -C "%ROOT%" branch --show-current >> "%GITSTATUS%" 2>&1
) else (
  > "%GITSTATUS%" echo git bulunamadi.
)

echo [6/6] Tek bundle dosyasi olusturuluyor...
(
  echo ============================================================
  echo REPO AUDIT BUNDLE
  echo ============================================================
  echo ROOT: %ROOT%
  echo APP : %APP%
  echo DATE: %DATE% %TIME%
  echo ============================================================
  echo.
  
  echo ====================
  echo SECTION: DOTNET INFO
  echo ====================
  type "%DOTNETINFO%"
  echo.
  
  echo ====================
  echo SECTION: GIT STATUS
  echo ====================
  type "%GITSTATUS%"
  echo.
  
  echo =========================
  echo SECTION: CURRENT BUILD
  echo =========================
  type "%BUILD%"
  echo.
  
  echo =========================
  echo SECTION: CLEAN INVENTORY
  echo =========================
  type "%INV%"
  echo.
  
  echo ============================================================
  echo SECTION: FILE CONTENTS
  echo ============================================================
  echo.
) > "%OUT%"

for /f "usebackq delims=" %%F in ("%INV%") do (
  echo ------------------------------------------------------------>> "%OUT%"
  echo FILE: %%F>> "%OUT%"
  echo ------------------------------------------------------------>> "%OUT%"
  type "%%F" >> "%OUT%" 2>nul
  echo.>> "%OUT%"
  echo.>> "%OUT%"
)

echo.
echo Tamamlandi.
echo Bana su dosyayi gonder:
echo %OUT%
echo.
pause
endlocal