param([switch]$VerboseRun, [switch]$VisualRun)
$ErrorActionPreference = 'Stop'
$engine = (Get-Command godot* | Where-Object Source -Like '*console.exe' | Select-Object -First 1).Source
if (-not $engine) { throw 'Godot-Konsolenprogramm nicht gefunden.' }
$testName = 'LAN_TEST_' + [Guid]::NewGuid().ToString('N')
$port = Get-Random -Minimum 28000 -Maximum 30000
$logDir = Join-Path $PSScriptRoot 'output/repair'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$hostLog = Join-Path $logDir 'lan_host.log'
$clientLog = Join-Path $logDir 'lan_client.log'
$hostErr = Join-Path $logDir 'lan_host_errors.log'
$clientErr = Join-Path $logDir 'lan_client_errors.log'
$common = @('--headless', '--path', ('"' + $PSScriptRoot + '"'), '--script', 'res://tests/lan_peer.gd', '--', ('--lan-test-name=' + $testName), ('--lan-test-port=' + $port))
if ($VerboseRun) { $common = @('--verbose') + $common }
if ($VisualRun) { $common = @('--rendering-method', 'gl_compatibility', '--position', '-10000,-10000', '--resolution', '1280x720') + @($common | Where-Object { $_ -ne '--headless' }) }
$hostProcess = Start-Process -FilePath $engine -ArgumentList ($common + '--lan-test-host') -PassThru -WindowStyle Hidden -RedirectStandardOutput $hostLog -RedirectStandardError $hostErr
Start-Sleep -Milliseconds 1000
$clientProcess = Start-Process -FilePath $engine -ArgumentList ($common + '--lan-test-client') -PassThru -WindowStyle Hidden -RedirectStandardOutput $clientLog -RedirectStandardError $clientErr
try {
    $deadline = (Get-Date).AddSeconds(90)
    while (-not ($hostProcess.HasExited -and $clientProcess.HasExited) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 300 }
    if (-not $hostProcess.HasExited -or -not $clientProcess.HasExited) { throw 'LAN-Test hat das Zeitlimit überschritten.' }
    foreach ($log in @($hostLog, $clientLog, $hostErr, $clientErr)) {
        $content = Get-Content -LiteralPath $log -Raw
        Write-Output $content
        if ($content -match '(?m)^(FAIL:|SCRIPT ERROR:|ERROR:|WARNING:.*leaked)') { throw ('LAN-Test fehlgeschlagen: ' + $log) }
    }
    if ($hostProcess.ExitCode -ne 0 -or $clientProcess.ExitCode -ne 0) { throw 'LAN-Spielprozess mit Fehler beendet.' }
    Write-Output 'LAN INTEGRATION PASSED: two real ENet processes'
} finally {
    foreach ($process in @($hostProcess, $clientProcess)) { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
}
