@echo off
setlocal

rem Auto cleanup across all disks.
rem Finds project roots by .git or *.sln, then removes build/cache folders under those roots.
rem Also clears TEMP and NuGet caches.

set "LOG=%~dp0cleanup_all.log"
echo === cleanup_all.bat ===
echo Log: %LOG%
echo. > "%LOG%"
echo Start: %DATE% %TIME%>>"%LOG%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue';" ^
  "$log='%LOG%';" ^
  "$targets=@('bin','obj','.vs','TestResults','packages','node_modules','dist','build','.cache','.turbo','.next','.pytest_cache');" ^
  "$exclude=@('\Windows\','\Program Files\','\Program Files (x86)\','\ProgramData\','\Recovery\','\System Volume Information\','\$Recycle.Bin\');" ^
  "$roots=New-Object 'System.Collections.Generic.HashSet[string]';" ^
  "$drives=(Get-PSDrive -PSProvider FileSystem).Root;" ^
  "foreach($d in $drives){" ^
  "  Get-ChildItem -Path $d -Directory -Filter .git -Recurse | ForEach-Object {" ^
  "    $p=$_.Parent.FullName; if($exclude | Where-Object { $p -like '*'+$_+'*' }){return}; $null=$roots.Add($p)" ^
  "  }" ^
  "  Get-ChildItem -Path $d -Filter *.sln -Recurse | ForEach-Object {" ^
  "    $p=$_.Directory.FullName; if($exclude | Where-Object { $p -like '*'+$_+'*' }){return}; $null=$roots.Add($p)" ^
  "  }" ^
  "}" ^
  "foreach($r in $roots){" ^
  "  Get-ChildItem -Path $r -Directory -Recurse -Force | Where-Object { $targets -contains $_.Name } | ForEach-Object {" ^
  "    try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop; Add-Content -Path $log -Value ('Silindi: '+$_.FullName) } catch {}" ^
  "  }" ^
  "}" ^
  "$temps=@($env:TEMP,'C:\Windows\Temp',\"$env:USERPROFILE\.nuget\packages\",\"$env:USERPROFILE\.nuget\http-cache\",\"$env:USERPROFILE\.nuget\plugins-cache\");" ^
  "foreach($t in $temps){" ^
  "  if(Test-Path $t){ Get-ChildItem -Path $t -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Add-Content -Path $log -Value ('Temizlendi: '+$t) }" ^
  "}" ^
  "Add-Content -Path $log -Value ('Finish: '+(Get-Date));"

echo === done ===
exit /b 0
