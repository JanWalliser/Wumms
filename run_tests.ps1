param([switch]$IncludeSoak)
$ErrorActionPreference = 'Stop'
$enginePath = (Get-Command godot* -ErrorAction SilentlyContinue | Where-Object Source -Like '*console.exe' | Select-Object -First 1).Source
if (-not $enginePath) { throw 'Godot-Konsolenprogramm nicht im Suchpfad gefunden.' }
$logDirectory = Join-Path $PSScriptRoot 'output/repair'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$cases = @(
    @{ Name='data_suite'; Args=@('--script','res://tests/test_runner.gd'); Marker='TEST RESULTS: 9 Passed, 0 Failed' },
    @{ Name='regression'; Args=@('res://tests/regression.tscn'); Marker='REGRESSION: 57 checks, 0 failed' },
    @{ Name='warehouse'; Args=@('--fixed-fps','60','res://tests/warehouse_acceptance.tscn'); Marker='WAREHOUSE ACCEPTANCE PASSED' },
    @{ Name='swarm_ui_balance'; Args=@('--fixed-fps','60','res://tests/swarm_ui_balance.tscn'); Marker='SWARM UI BALANCE PASSED' },
    @{ Name='progression_followup'; Args=@('--fixed-fps','60','res://tests/progression_followup.tscn'); Marker='PROGRESSION FOLLOWUP PASSED' },
    @{ Name='evolution'; Args=@('--fixed-fps','60','res://tests/evolution.tscn'); Marker='EVOLUTION PASSED' },
    @{ Name='warehouse_progression'; Args=@('--fixed-fps','60','res://tests/warehouse_progression.tscn'); Marker='WAREHOUSE PROGRESSION PASSED' },
    @{ Name='warehouse_coop'; Args=@('--fixed-fps','60','res://tests/warehouse_coop.tscn'); Marker='WAREHOUSE COOP PASSED' },
    @{ Name='character_release'; Args=@('--fixed-fps','60','res://tests/character_release.tscn'); Marker='CHARACTER RELEASE PASSED' },
    @{ Name='boss_presentation'; Args=@('--fixed-fps','60','res://tests/boss_presentation.tscn'); Marker='BOSS PRESENTATION PASSED' },
    @{ Name='tab_overlay'; Args=@('--fixed-fps','60','res://tests/tab_overlay.tscn'); Marker='TAB OVERLAY PASSED' },
    @{ Name='oblique_camera'; Args=@('--fixed-fps','60','res://tests/oblique_camera.tscn'); Marker='OBLIQUE CAMERA PASSED' },
    @{ Name='weapon_rework'; Args=@('--fixed-fps','60','res://tests/weapon_rework.tscn'); Marker='WEAPON REWORK PASSED' },
    @{ Name='warehouse_events'; Args=@('--fixed-fps','60','res://tests/warehouse_events.tscn'); Marker='WAREHOUSE EVENTS PASSED' },
    @{ Name='shield_formation'; Args=@('--fixed-fps','60','res://tests/shield_formation.tscn'); Marker='SHIELD FORMATION PASSED' },
    @{ Name='jinx_live_run'; Args=@('--fixed-fps','60','res://tests/jinx_weapon_run.tscn'); Marker='JINX LIVE RUN PASSED' },
    @{ Name='behavior'; Args=@('res://tests/behavior.tscn'); Marker='BEHAVIOR: 50 checks, 0 failed' },
    @{ Name='content_smoke'; Args=@('res://tests/content_smoke.tscn'); Marker='CONTENT SMOKE: 657 checks, 0 failed' },
    @{ Name='ui_smoke'; Args=@('res://tests/ui_smoke.tscn'); Marker='UI SMOKE: 8 menus and synthetic device routing, 0 failed' }
)
if ($IncludeSoak) { $cases += @{ Name='soak_final'; Args=@('--fixed-fps','60','res://tests/soak.tscn'); Marker='SOAK: 4 map timelines, 0 failed' } }
foreach ($case in $cases) {
    $logPath = Join-Path $logDirectory ($case.Name + '.log')
    & $enginePath --headless --path $PSScriptRoot --quit-after 12000 @($case.Args) *> $logPath
    $code = $LASTEXITCODE
    $result = Get-Content -LiteralPath $logPath -Raw
    if ($code -ne 0 -or $result -notlike ('*'+$case.Marker+'*') -or $result -match '(?m)^(SCRIPT ERROR:|ERROR:|FAIL:|WARNING:.*leaked)') {
        Write-Host $result
        throw ($case.Name + ': Prüfung fehlgeschlagen. Log: ' + $logPath)
    }
    Write-Host ($case.Name + ': bestanden')
}
Write-Host 'Alle ausgewählten Prüfungen sind erfolgreich und ohne Fehler im Log abgeschlossen.'
