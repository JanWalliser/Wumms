param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$gamePath = Join-Path $projectPath 'build/WUMMS.exe'
$version = "0.2.0"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  WUMMS: Operation Knall-Kartoffel (Version $version)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not $Editor -and (Test-Path -LiteralPath $gamePath)) {
    $contentPack = Join-Path $projectPath 'build/WUMMS.pck'
    $buildStamp = if (Test-Path -LiteralPath $contentPack) { $contentPack } else { $gamePath }
    $buildTime = (Get-Item -LiteralPath $buildStamp).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[Launcher] Startmodus: Standalone-Build" -ForegroundColor Green
    Write-Host "[Launcher] Datei: $gamePath" -ForegroundColor Gray
    Write-Host "[Launcher] Build-Stand: $buildTime" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------"
    & $gamePath
    exit
}

$candidates = @(Get-Command godot*,Godot* -ErrorAction SilentlyContinue | Where-Object Source -Like '*.exe' | Select-Object -ExpandProperty Source -Unique)
if ($candidates.Count -eq 0) {
    $wingetPath = Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages'
    $candidates = @(Get-ChildItem -LiteralPath $wingetPath -Filter 'Godot*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$enginePath = $candidates | Where-Object { $_ -notlike '*console*' } | Select-Object -First 1
if (-not $enginePath) { $enginePath = $candidates | Select-Object -First 1 }
if (-not $enginePath) { Write-Host 'Bitte Godot 4.7 installieren oder build/WUMMS.exe bereitstellen.'; Read-Host 'Enter'; exit 1 }

if ($Editor) {
    Write-Host "[Launcher] Startmodus: Godot Editor aus Quelltext" -ForegroundColor Magenta
    Write-Host "[Launcher] Engine: $enginePath" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------"
    & $enginePath --path $projectPath --editor
} else {
    Write-Host "[Launcher] Startmodus: Engine-Start aus Quelltext" -ForegroundColor Green
    Write-Host "[Launcher] Engine: $enginePath" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------"
    & $enginePath --path $projectPath
}
