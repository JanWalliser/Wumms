# LAN-Modus und Tod/Respawn

Stand: 25. Oktober 2026. Startanleitung im Abschnitt „LAN über IP“ der README.

## Recherchierte Regeln

Die [Swarm-Regelübersicht, Abschnitt Revival](https://wiki.leagueoflegends.com/en-us/Swarm#Revival) beschreibt: zehn Sekunden bis zur Wiederbelebung durch Teamnähe, automatischen Respawn mit 15 Sekunden Basis und neun zusätzlichen Sekunden je Tod bis maximal 60 Sekunden, 50 % Leben und vier Sekunden Unverwundbarkeit. Alle gleichzeitig niedergeschlagen bedeutet Niederlage. Die Quelle ist eine Community-Dokumentation. Ihre zusätzliche Angabe „fünfter Tod“ widerspricht der angegebenen Formel; wir verwenden die explizite Formel (15, 24, 33, 42, 51, 60, 60 …).

Die [offiziellen Riot-Patchnotes 14.14](https://www.leagueoflegends.com/en-us/news/game-updates/patch-14-14-notes/) verlinken eine frühere Swarm-Supportseite; diese lieferte bei der Recherche einen 404-Fehler. Für die Detailwerte liegt damit keine erreichbare offizielle Bestätigung vor.

Der [Abschnitt Enemies](https://wiki.leagueoflegends.com/en-us/Swarm#Enemies) beschreibt die Verfolgung des nächsten Kämpfers sowie wirkungslose Angriffe auf niedergeschlagene Ziele. Er dokumentiert nicht präzise, wann bei Tod ein Zielwechsel erfolgt oder ob tote Körper physisch blockieren. Unsere explizite Umsetzung: Nur lebende Spieler sind Navigations- und Angriffsziele, tote Körper blockieren nicht. Bereits angekündigte Flächenangriffe bleiben an ihrer angekündigten Position. Dies ist eine nachvollziehbare Spielregel für unseren Koop und keine Behauptung über den unbekannten Original-Servercode.

## Umsetzung

- ENet über UDP, Standardport 24872; ein Host und bis zu drei Gäste, insgesamt maximal vier Spieler inklusive lokaler Plätze.
- Host berechnet Kampf, Zufall, Quests, Respawn, Auswahlen und Speicherung. Gäste simulieren keine eigene Runde.
- Komprimierte vollständige Spielzustände mit 20 Aktualisierungen pro Sekunde; Paketteile bleiben unter der MTU. Unvollständige alte Zustände werden verworfen, neuere Zustände können unmittelbar weiterlaufen. Positionsglättung zwischen Zuständen.
- Lobby, Fähigkeiten, Auswahlen und Rerolls verwenden zuverlässige Nachrichten. Eingabe und Spielzustände verwenden eigene Kanäle; Versions-/Inhaltsprüfung vor Slotvergabe.
- Gegenspieler-Ziele und Navigationsfelder werden beim Tod und Respawn sofort aktualisiert. Bewegung stoppt beim Tod; Kollisionen kehren erst bei Wiederbelebung zurück. Respawn setzt einen lebenden Mitspieler voraus.
- Jeder Gast besitzt genau einen vom Host vergebenen Platz. Fremde Profile, Schwierigkeitsgrad und fremde Auswahlen lassen sich vom Gast nicht ändern. Veraltete Auswahl- und Rerollnachrichten werden verworfen.
- Eingaben verfallen nach 300 Millisekunden ohne Aktualisierung. Verbindungsaufbau und Laden haben Zeitlimits. Keine späten Beitritte, keine Hostmigration und kein Wiederbeitritt in die laufende Runde.
- Gastfortschritt wird auf dem Host nach Computername gespeichert; vorhandene lokale Gastprofile werden nicht übertragen. Kein Internet-Matchmaking, keine automatische Routerkonfiguration.

## Abnahme

`test_lan.ps1` startet zwei getrennte Prozesse mit echter ENet-Verbindung über Loopback. Geprüft werden inkompatible Builds, Slotbesitz, Figurenwahl, Bereitschaft, gemeinsamer Start, Bewegung, replizierte Gegner und Warnflächen, deaktivierte Gastsimulation, Reroll/Auswahl, Pausen, Einzel-Tod ohne Spielende, Respawn auf beiden PCs, steigende Timer bis zum Limit, Team-Wiederbelebung, Boss, vollständiger Team-Wipe und Gastabbruch.

Mit `-VisualRun` laufen beide Prozesse mit Grafik; Lobby, Gast-Spielansicht und Gast-Auswahl werden zusätzlich als PNG gespeichert und visuell geprüft. Die vorhandenen 19 Spieltests werden separat durch `run_tests.ps1` ausgeführt.

Noch nicht abgenommen sind zwei physische PCs, vier echte Teilnehmer, längere LAN-Partien und WLAN unter Paketverlust oder hoher Gegnerlast. Schadenszahlen als kurzlebige Textlabels werden aktuell nicht übertragen; Lebenspunkte, Schadensergebnis, Projektile und Warnflächen schon. Gaststeuerung erfolgt zunächst mit Tastatur/Maus.
