$ErrorActionPreference = 'Stop'
$commands = @(Get-Command godot* -ErrorAction SilentlyContinue | Where-Object Source -Like '*.exe')
$enginePath = ($commands | Where-Object Source -Like '*console.exe' | Select-Object -First 1).Source
$runtimePath = ($commands | Where-Object Source -NotLike '*console.exe' | Select-Object -First 1).Source
if (-not $enginePath -or -not $runtimePath) { throw 'Godot-Laufzeit und Konsolenprogramm wurden nicht gefunden.' }
$buildDirectory = Join-Path $PSScriptRoot 'build'
$logDirectory = Join-Path $PSScriptRoot 'output/repair'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$packPath = Join-Path $buildDirectory 'WUMMS.pck'
$logPath = Join-Path $logDirectory 'export_pack.log'
& $enginePath --headless --path $PSScriptRoot --script 'res://tests/build_actor_assets.gd' *> (Join-Path $logDirectory 'actor_assets.log')
if ($LASTEXITCODE -ne 0 -or (Get-Content -LiteralPath (Join-Path $logDirectory 'actor_assets.log') -Raw) -match '(?m)^(ERROR:|SCRIPT ERROR:)') { throw 'Animationsgrafiken konnten nicht erstellt werden.' }
& $enginePath --headless --path $PSScriptRoot --script 'res://tests/build_warehouse_assets.gd' *> (Join-Path $logDirectory 'warehouse_assets.log')
if ($LASTEXITCODE -ne 0) { throw 'Kartentexturen konnten nicht erstellt werden.' }
& $enginePath --headless --path $PSScriptRoot --script 'res://tests/export_runtime_pack.gd' *> $logPath
if ($LASTEXITCODE -ne 0 -or (Get-Content -LiteralPath $logPath -Raw) -match '(?m)^(ERROR:|SCRIPT ERROR:)') { throw ('Paketbau fehlgeschlagen: ' + $logPath) }
$targetRuntime = Join-Path $buildDirectory 'WUMMS.exe'
# A running game may hold the executable open. The engine binary is unchanged
# between content builds, so do not rewrite an already identical runtime.
if (-not (Test-Path -LiteralPath $targetRuntime) -or (Get-FileHash -LiteralPath $runtimePath).Hash -ne (Get-FileHash -LiteralPath $targetRuntime).Hash) {
    Copy-Item -LiteralPath $runtimePath -Destination $targetRuntime -Force
}
& $enginePath --headless --path $PSScriptRoot --script 'res://tests/export_licenses.gd' *> (Join-Path $logDirectory 'runtime_licenses.log')
if ($LASTEXITCODE -ne 0) { throw 'Laufzeit-Lizenzhinweise konnten nicht ausgegeben werden.' }
Set-Content -LiteralPath (Join-Path $buildDirectory 'LIESMICH.txt') -Encoding utf8 -Value @'
WUMMS 0.2.0 - portabler Testbuild

WUMMS.exe und WUMMS.pck muessen im selben Ordner bleiben.
WUMMS.exe startet das Spiel ohne separate Godot-Installation.
Dieser Testbuild verwendet die vorhandene Godot-Engine als Laufzeit.
Ein schlanker Releaseexport mit Exportvorlagen ist eine gesonderte Ausgabe.
Die erste Karte verwendet jetzt den rekonstruierten Warehouse-Grundriss,
Originalboden und neue Umgebungsgrafiken. Spieler und Gegner bleiben vereinfacht.

WASD/Pfeile bewegen, E/R Faehigkeiten, C Auto-Zielen, Esc Pause, Tab Teamwerte.
Gamepad: linker/rechter Stick, A/B Faehigkeiten, RB Auto-Zielen, Start Pause.
Auswahl: Maus, W/S und Enter, 1-3 oder Gamepad. F2-F5: Spalte mit Tastatur uebernehmen.
R, Gamepad X oder Neu-generieren-Button: drei Rerolls pro Spieler und Run.

LAN: Beide PCs brauchen denselben Build. Lobby: LAN HOSTEN; am anderen PC
die angezeigte Host-IP eingeben und PER IP BEITRETEN waehlen.
Standard: UDP-Port 24872. Spiel in der Windows-Firewall fuer private Netzwerke zulassen.
Gast: Figur waehlen, Bereit anklicken. Der Host startet, wenn alle bereit sind.
Maximal vier Spieler. LAN-Gastprofile und deren Fortschritt liegen auf dem Host.
Tod: Respawn solange ein Mitspieler lebt; erst ein kompletter Team-Wipe beendet die Runde.

Profilfortschritt und Einstellungen werden im lokalen Godot-Benutzerdatenordner gespeichert.
'@
Write-Host ('Testbuild erstellt: ' + $buildDirectory)
