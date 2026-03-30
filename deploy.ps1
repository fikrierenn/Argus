# deploy.ps1 — BKM Argus Deployment Script
# Usage: .\deploy.ps1 [-Environment Dev|Prod] [-SkipDb] [-SkipBuild]

param(
    [ValidateSet("Dev", "Prod")]
    [string]$Environment = "Dev",
    [switch]$SkipDb,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$WebProject = "$ProjectRoot\src\BkmArgus.Web\BkmArgus.Web.csproj"
$PublishDir = "$ProjectRoot\publish"
$SqlCliPath = "D:\Dev\sqlcli"

Write-Host "=== BKM Argus Deploy ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Skip DB: $SkipDb"
Write-Host "Skip Build: $SkipBuild"

# 1. Build + Test
if (-not $SkipBuild) {
    Write-Host "`n--- Build ---" -ForegroundColor Yellow
    dotnet build "$ProjectRoot\BkmArgus.sln" --configuration Release
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

    Write-Host "`n--- Tests ---" -ForegroundColor Yellow
    dotnet test "$ProjectRoot\tests\BkmArgus.Tests\BkmArgus.Tests.csproj" --configuration Release --no-build
    if ($LASTEXITCODE -ne 0) { Write-Error "Tests failed"; exit 1 }
}

# 2. DB Migration
if (-not $SkipDb) {
    Write-Host "`n--- DB Migration ---" -ForegroundColor Yellow

    # Migration order: schema changes first, then stored procedures
    $sqlFiles = @(
        "35_migration_auth.sql",
        "37_must_change_password.sql",
        "38_dof_state_machine.sql",
        "39_notifications.sql",
        "40_cross_correlation.sql",
        "30_sps_ref_rpt_english.sql",
        "31_sps_ai_log_etl_english.sql",
        "32_sps_remaining_english.sql",
        "33_column_rename_migration.sql",
        "34_column_rename_fk_ids.sql",
        "36_sps_auth.sql",
        "21_sps_audit.sql",
        "22_sps_audit_dashboard.sql"
    )

    foreach ($file in $sqlFiles) {
        $path = "$ProjectRoot\sql\$file"
        if (Test-Path $path) {
            Write-Host "  Deploying $file..."
            if (Test-Path $SqlCliPath) {
                & "$SqlCliPath\sqlcli.exe" --file "$path"
                if ($LASTEXITCODE -ne 0) { Write-Warning "Failed: $file" }
            } else {
                sqlcmd -i "$path" -b
                if ($LASTEXITCODE -ne 0) { Write-Warning "Failed: $file" }
            }
        } else {
            Write-Host "  Skipping $file (not found)" -ForegroundColor DarkGray
        }
    }

    Write-Host "`n--- Smoke Tests ---" -ForegroundColor Yellow
    $smokeTest = "$ProjectRoot\sql\99_smoke_tests.sql"
    if (Test-Path $smokeTest) {
        if (Test-Path $SqlCliPath) {
            & "$SqlCliPath\sqlcli.exe" --file "$smokeTest"
        } else {
            sqlcmd -i "$smokeTest" -b
        }
        if ($LASTEXITCODE -ne 0) { Write-Error "Smoke tests failed"; exit 1 }
        Write-Host "  Smoke tests passed" -ForegroundColor Green
    }
}

# 3. Publish
Write-Host "`n--- Publish ---" -ForegroundColor Yellow
if (Test-Path $PublishDir) { Remove-Item $PublishDir -Recurse -Force }
dotnet publish $WebProject --configuration Release --output $PublishDir
if ($LASTEXITCODE -ne 0) { Write-Error "Publish failed"; exit 1 }

Write-Host "`n=== Deploy Complete ===" -ForegroundColor Green
Write-Host "Published to: $PublishDir"
Write-Host "Run: dotnet $PublishDir\BkmArgus.Web.dll --urls http://0.0.0.0:5169"
