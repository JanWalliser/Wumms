# WUMMS – Operation Knall-Kartoffel

Version 0.2.0: 2D-Koop-Prototyp für bis zu vier Teilnehmer, lokal oder über LAN/IP. Der aktuelle Produktumfang ist Karte 1, Warenhaus-Wahnsinn, mit Story, Hard und Extreme. Die anderen Karten bleiben interne Entwicklungsressourcen. Namensmapping und bestehende Saves werden weiter unterstützt; der Abschlussrelease ist weiterhin in Arbeit.

## Fortschritt der Ein-Karten-Ausgabe

- Story ist sofort verfügbar. Urzeit-Rexi besiegen schaltet Hard frei; ein Sieg auf Hard schaltet Extreme frei.
- Ein Sieg auf Extreme schaltet Knallkraft 100 (Anima) im Shop frei.
- Brioche: Teamlevel 20. Yasüff: eine Waffe entwickeln.
- Eisbein-Panzer: Brunnen zweimal aktivieren. Hasi-Megaböller: fünf Minibosse besiegen.
- Ein weiterer Passivplatz: drei Belastungs-Prüfungen auf Hard/Extreme. Die übrigen Slotziele bleiben erhalten.
- Alle übrigen Figuren, Waffen und Passiven sind über Ziele auf Karte 1 erreichbar. Drei Rerolls stehen ab dem ersten Run zur Verfügung.
- Die Freischaltungen für Schwierigkeit und Karte richten sich nach dem Hostprofil. Jeder Teilnehmer behält seinen eigenen Figuren- und Ausrüstungspool sowie seine dauerhaften Upgrades. Doppelte Profile teilen den Fortschritt bewusst.
- Schema 4 übernimmt alte Abschlüsse und erhält Gold, Käufe und bestehende Freischaltungen. Die alte Kartenhistorie bleibt gespeichert, ohne die anderen Karten in der Lobby anzubieten.

## Start

- `start_game.bat` startet zuerst den portablen Testbuild in `build/`, falls vorhanden. Andernfalls sucht es eine installierte Godot-Version.
- `open_editor.bat` öffnet das Projekt mit Godot.
- Der portable Testbuild besteht aus **WUMMS.exe und WUMMS.pck im selben Ordner**. Beide Dateien zusammen kopieren. Er verwendet die vorhandene Godot-Laufzeit; er ist kein schlanker Template-Releaseexport.
- Für eigene Exporte liegt ein Windows-Desktop-Preset vor. Dafür benötigt der Editor die zur Engineversion passenden Exportvorlagen.

Die Entwicklung und die automatischen Prüfungen verwenden Godot 4.7.2. Der Standardrenderer ist GL Compatibility.

## LAN über IP

Auf beiden PCs denselben aktuellen Build starten. In der Lobby klickt der Host auf **LAN HOSTEN**; dort werden seine IP-Adressen angezeigt. Der andere PC gibt die passende Host-IP ein und wählt **PER IP BEITRETEN**. Standard ist **UDP-Port 24872**, auf beiden PCs identisch. Beide Rechner müssen sich im selben erreichbaren LAN/WLAN befinden; Windows muss das Spiel im privaten Netzwerk zulassen. Bei mehreren IP-Adressen die Adresse des gemeinsamen Routers verwenden.

Jeder Gast erhält einen eigenen Spielerplatz mit Tastatur und Maus. Figur wählen, **Bereit!** aktivieren; anschließend startet der Host die Runde. Insgesamt bleiben maximal vier Spieler möglich. Zusätzliche lokale Controllerplätze können vor dem Hosten eingerichtet werden; sie belegen ebenfalls einen Platz. Ein Beitritt während einer laufenden Runde ist nicht möglich.

Der Host berechnet die gesamte Runde; Gäste erhalten Gegner, Projektile, Bosswarnungen, Drops, Ereignisse, Teamwerte und die verbindlichen Auswahlen. Jeder Gast wählt nur für seinen eigenen Platz. Pause und Auswahlen gelten für alle. Bei einem Gastabbruch wird dessen Platz entfernt und die Runde pausiert; ein Hostabbruch trennt die Sitzung.

**LAN-Gastprofile liegen auf dem Host**, getrennt nach dem Computernamen des Gasts. Sie starten mit den Standardfreischaltungen und behalten ihren dortigen Fortschritt für spätere Besuche. Vorhandene lokale Gastprofile werden nicht importiert. Rechner mit identischem Computernamen teilen dieses Gastprofil. Die normale lokale Profilauswahl wird nach dem Trennen wiederhergestellt.

Tod beendet die Runde erst, wenn alle Spieler gleichzeitig am Boden sind. Solange jemand lebt: Wiederbelebung durch Teamnähe ab zehn Sekunden oder automatischer Respawn nach 15 Sekunden, je weiterem Tod neun Sekunden mehr, maximal 60 Sekunden. Respawn gibt 50 % Leben und vier Sekunden Unverwundbarkeit. Während Pausen stehen beide Timer still. Niedergeschlagene Körper blockieren keine Gegner; die Wegfindung wird bei Tod und Wiederbelebung sofort auf die lebenden Spieler aktualisiert.

`powershell -File .\test_lan.ps1` prüft zwei echte ENet-Spielprozesse einschließlich Versionsprüfung, Lobby, Bewegung, Auswahl/Reroll, Tod/Respawn, Boss, Team-Wipe und Trennen. Mit `-VisualRun` werden zusätzlich beide Spielansichten gerendert und Screenshots unter `output/repair/` gespeichert. Ein Test auf zwei physischen PCs mit deren Firewall und WLAN bleibt erforderlich. Recherche und technische Grenzen: `LAN_MODUS.md`.

## Spielablauf

Profil → Lobby → freigeschaltete Figur/Karte/Schwierigkeit → Horden → Boss nach 15 Minuten → Ergebnis und Shop. Die Bossraserei beginnt fünf aktive Spielminuten nach dem Spawn.

Koop auf Karte 1: Normaler Nachschub wächst mit 1/1,5/2/2,5 statt linear mit den Slots. HP-Faktoren sind für normale Gegner, Spezialgegner und Boss getrennt; normale Gegner-XP gleichen die zusätzliche Menge aus. Das Grundbudget bleibt bei acht Minibossen und fünf Elitegegnern, mit weiteren Karten durch Prüfungen. Bosswarnungen haben einen festen, mit Basistempo verlassbaren Radius. Details und Abnahmegrenzen: `output/repair/PAKET_B_KOOP_BALANCE_BOSS.md`.

Ein gemeinsames Run-Level und Teamgold, individuelle Waffen und Passive. Maximal fünf Waffen einschließlich Starter und drei bis sechs freigeschaltete Passivplätze. Eine Zugangskarte bietet vorhandene gültige Evolutionen an: Waffenstufe 5 plus zugehöriges Passiv.

Mehrere Level-ups oder Karten werden nacheinander ausgewählt. Alle Spieler pausieren während der Auswahl. Derselbe Drop oder Runabschluss bezahlt nur einmal. Gleiche Profile in mehreren Slots teilen bewusst den Gastfortschritt und erhalten dieselbe Teamrunde einmal.

## Steuerung

| Aktion | Tastatur/Maus | Gamepad |
|---|---|---|
| Bewegen | WASD / Pfeile | linker Stick / Steuerkreuz |
| Manuell zielen | Maus | rechter Stick |
| Auto-Aim umschalten | C | RB |
| E ab Teamlevel 3 | E | A |
| R ab Teamlevel 6 | R | B |
| Pause | Esc | Start |
| Teamübersicht | Tab | Tastatur/Host |
| Auswahl | W/S, Pfeile, 1–5, Enter oder Maus | Stick/Steuerkreuz und A |
| Neu würfeln, dreimal pro Run | R oder Button | X |

F2 bis F5 übernehmen während einer Auswahl die jeweilige Spalte mit der Tastatur. Die Maus kann ebenfalls jede Spalte bestätigen, etwa wenn ein Controller ausfällt. Die Lobby zeigt die tatsächlich verbundenen Geräte; ein Gerät darf nur einem Teilnehmer gehören. Tastaturbelegungen und Lautstärken sind in den Einstellungen speicherbar.

Brioche kann ihren E-Rausch mit erneutem E vorzeitig beenden. Wiederbelebung ist nach zehn Sekunden durch Teamnähe möglich; alternativ erfolgt der automatische Respawn, solange noch jemand lebt. Ein kompletter Team-Wipe beendet den Run.

## Inhalte

Neun Figuren mit eigenen Passiven und E/R, 29 Waffen mit Evolutionsverhalten, zwölf Passive, 33 Augments und neun temporäre Boni. In der normalen Spielauswahl wird ausschließlich Warenhaus-Wahnsinn angeboten. Die Mechaniken sind als Prototyp umgesetzt; identische Balance oder Gestaltung wie in Swarm wird nicht behauptet.

Paket C, erster Figurenblock: eigene E/R-/Passiv-Icons für die acht weiteren Figuren, sichtbare Passivzustände und animierte Seraföhn-/Löwina-Grafiken. Heilungs-, Ladungs- und Wiederbelebungsfehler sind korrigiert. Figurenabschluss und Originaldatenabgleich bleiben offen; Details: `output/repair/PAKET_C_FIGUREN_ERSTER_BLOCK.md`.

- Auf Karte 1 den Ketchupbrunnen aufladen. Kanone, Frostplattformen und Flut der anderen Karten sind interne Entwicklungsinhalte und keine Freischaltvoraussetzungen dieser Ausgabe.
- Miezi-Missionen, Belastungsproben und Fortuna-Kartons werden vom EventDirector gesteuert. Die Aufgaben stehen im HUD.
- Augments und Boni folgen den Profil-Unlocks. Vor ihrer Freischaltung gibt es normale Vorrats-/Kartenbelohnungen. Drei Rerolls sind sofort verfügbar.
- Storyketten haben drei gespeicherte Kapitel: Figur auf Level 10, eigene Waffenentwicklung, danach Bosssieg.
- Die erste Karte nutzt den archivierten Warehouse-Grundriss mit Originalboden und rekonstruierten Umgebungsgrafiken. Spieler und Gegner verwenden weiterhin einfache Grafiken; die weiteren Karten bleiben grafische Prototypen. SFX und eine einfache eigene Musikschleife sind enthalten.

## Tests

`powershell -File .\run_tests.ps1` führt Daten-, Kern-, Verhaltens-, Inhalts- und UI-Prüfungen aus. Der Starter wertet Abschlussmarker, Exit-Codes und Fehler-/Leakmeldungen aus.

Die Warehouse-Abnahme prüft zusätzlich Originalpolygone, Kartenzugänge, vier Spielerstarts, Brunnen, Minimap, freie Ereignispositionen sowie echte Gegner- und Bossbewegung. Details, Art-Herkunft und Austausch der Grafiken: `output/warehouse-implementation/UMSETZUNG.md`.

`powershell -File .\run_tests.ps1 -IncludeSoak` ergänzt vier beschleunigte Horden-/Bosszeitlinien. Diese verwenden Unverwundbarkeit und einen erzwungenen Bosstod; sie belegen Stabilität, keine natürliche Gewinnbarkeit.

Der separate `tests/stress.tscn`-Aufbau misst 500 langlebige Gegner und vier volle Builds. Ein solcher Extremtest ist keine Garantie konstanter Bildrate auf anderer Hardware.

Details und Zuordnung aller 43 Auditbefunde: `output/repair/ABNAHME_UND_AENDERUNGEN.md`. Das alte Audit beschreibt den früheren Stand und wurde als historische Grundlage erhalten.

## Speicherstände und Entwicklermodus

Profile liegen unter `user://profiles/`, Einstellungen in `user://settings.cfg`. Schema 4 migriert bekannte alte IDs/Belohnungen und die bisherigen Mehrkarten-Freischaltungen und hält Backups vor. Ein sichtbarer Savefehler darf nicht als erfolgreicher Kauf oder abgeschlossene Speicherung gewertet werden.

Der F1-Entwicklermodus ist nur mit dem Startargument `-- --developer` verfügbar. Seine Eingriffe markieren den Run als Übung ohne weitere Profilbelohnungen.

Offene Abnahme: vier reale Controller mit Hotplug, längere Balance-/Spielgefühltests, Grafik-FPS unter hoher Last sowie Start auf einem fremden Windows-PC. Finale Art und ein optimierter Releaseexport sind gesonderte Produktionsarbeit.
