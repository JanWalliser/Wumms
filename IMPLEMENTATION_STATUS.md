# WUMMS 0.2.0 – tatsächlicher Implementierungsstand

Fortschreibung: 24.10.2026. Diese Datei ersetzt die frühere pauschale „vollständig“-Checkliste. Die normale Spielauswahl umfasst jetzt ausschließlich Karte 1 mit Story, Hard und Extreme. Die übrigen Karten sind interne Entwicklungsressourcen.

Paket A ist umgesetzt: zentraler Katalog mit 50 erreichbaren Spielzielen, Ein-Karten-Freischaltungen und Schema-4-Migration unter Erhalt bisheriger Belohnungen. Details: `output/repair/PAKET_A_KARTE_1_FORTSCHRITT.md`. Koop-Balance, Boss-Fairness, Figurenabschluss und Veröffentlichung sind weiterhin offen; dies ist keine Abschlussrelease-Freigabe.

Fortschreibung Paket B: gemeinsame Teamfaktoren, festes Spezialgegner-/Kartenbudget, normalisierte Gegner-XP und fairere Bosswarnung sind technisch umgesetzt. Vierzehn Testsuiten bestanden; natürliche Balance-Runs bleiben offen. Details: `output/repair/PAKET_B_KOOP_BALANCE_BOSS.md`. Die vorangehende Paket-A-Aussage beschreibt den damaligen Zwischenstand.

| Bereich | Stand |
|---|---|
| Runzustände, Auswahlwarteschlange und Einmaligkeit | implementiert; Kern- und Verhaltenstests |
| Karte 1 als Produktumfang | nur Warenhaus-Wahnsinn in der Lobby; alle Schwierigkeiten und Inhalte dort freischaltbar; andere Karten intern erhalten |
| Fraktionen, Damage, Rüstung, Schild, DoT, Revive | zentralisiert; automatisierte Interaktionsprüfungen |
| Neun Figuren mit Passiv und E/R | Prototypmechaniken implementiert; Inhalts-/Einzeltests |
| Paket C, erster Figurenblock | 24 eigene E/R/Passiv-Icons, Passivanzeigen, Animationen für Seraföhn/Löwina; Heilungs-/Ladungs-/Lebenszyklusfehler behoben; Figurenabschluss bleibt offen |
| Größen und Anzeigen nach Bildreferenz | Jinx optisch × 1,8; Zwischenbosse etwa fünf Jinx-Höhen; gerahmte Level-/HP-Anzeigen und Mini-/Elite-/Bosswarnungen auf der Minimap; Balancewerte unverändert |
| Schräge Kartenansicht und Minimap | Karte 1 als schräge 2,5D-Projektion, aufrechte Figuren und angepasste Eingaberichtungen; Minimap 308 px bei 1080p mit Bildausschnitt-Markierung |
| 29 Waffen und Evolutionen | verschiedene Laufzeitstrategien implementiert; alle Basis-/Evolutionsaufrufe getestet |
| 33 Augments / neun Boni / Rerolls | Erwerbs- und Effektlogik implementiert; alle IDs ausgeführt |
| Questquellen und Storykapitel | angebunden; Persistenz und einmalige Belohnung geprüft |
| Profile, Shop, Migration und Backup | implementiert; Typ-/Werte-/Backupprüfungen; Savefehler sichtbar |
| HUD und lokale Auswahlsteuerung | initiale Bindung repariert; synthetische Geräte- und Sichtprüfung |
| LAN per IP | Host und bis zu drei Gäste; authoritative Spielzustände, Auswahlen und Tod/Respawn in zwei echten ENet-Prozessen sowie mit Grafik geprüft; physisches LAN/WLAN und Langläufe noch offen; Gastprofile auf dem Host, Details in `LAN_MODUS.md` |
| TAB-Ansicht | grafisches Icon-Rezeptbuch mit Hoverinfos und separatem Live-Wertefeld; Spielerwechsel und Bedienung während der Auswahl; Rezepte von Karten entfernt |
| Performance | Cache, begrenzte Beutedichte, getrennte Navigations-/Separationstakte, VFX-/SFX-Budgets; Extremmessungen im Log |
| Grafik/Audio | eigene prozedurale Platzhalter, SFX und einfache Musik; keine finale Produktion |
| Windows | Startskripte, Preset und portabler Laufzeit-/Paketbuild; schlanker Templateexport separat |

Automatisch geprüft: neun Datensuiten, 57 Kernprüfungen, 26 Verhaltensprüfungen, 657 Inhaltschecks sowie acht Menüs und synthetische Gamepadweiterleitung. Diese Zahlen dürfen nicht als Anzahl vollständig balancierter Spielkombinationen interpretiert werden.

Weiterhin manuell abzunehmen: vier physische Controller, komplette faire Runs und sämtliche Buildkombinationen, reale Grafik-Frametimes auf Zielhardware, fremder Windows-PC und finale Gestaltung. Konkrete Änderungen, Nachweise und Grenzen je F01–F43 stehen in `output/repair/ABNAHME_UND_AENDERUNGEN.md`.
