"""Publish the imported original timeline separately from reconstructed event parameters."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/swarm-balance'
data = json.loads((ROOT / 'assets/balance/warehouse-14.16.json').read_text(encoding='utf-8'))
curve = data['experience']['cumulative']
rows = []
for phase in data['phases']:
    for wave in phase['waves']:
        characters = ', '.join(c['CharacterRecord'].split('/')[1] for c in wave.get('characters', [])) or 'Spawner controller'
        rows.append([phase['index'], phase['start'], phase['end'], wave['name'], characters, wave['SpawnIntervalSecs'], wave['SpawnCountPerInterval'], wave['MaxSpawnCount'], json.dumps(wave['WaveShape'])])
with (OUT / 'MAP1-WELLEN-14.16.csv').open('w', encoding='utf-8-sig', newline='') as file:
    writer = csv.writer(file, delimiter=';')
    writer.writerow(['Phase', 'Start_s', 'Ende_s', 'Originalname', 'Gegner', 'Intervall_s', 'Gegner_pro_Intervall_Solo', 'Maximum', 'Originalform'])
    writer.writerows(rows)
xp_rows = []
for i, cumulative in enumerate(curve):
    level = i + 1
    old = level * 5 if level <= 20 else 100 + (level - 20) * 8 if level <= 40 else 260 + (level - 40) * 12
    cost = cumulative - (curve[i - 1] if i else 0)
    xp_rows.append([level, old, cost, cost + 1, cumulative])
with (OUT / 'XP-LEVELKURVE-14.16.csv').open('w', encoding='utf-8-sig', newline='') as file:
    writer = csv.writer(file, delimiter=';')
    writer.writerow(['Level', 'Alte_Anzeige', 'Neue_Anzeige', 'Tatsaechliche_Kosten_strikte_Schwelle', 'Kumulatives_Archiv'])
    writer.writerows(xp_rows)

text = '''# Map 1: XP, Wellen und Ereignisse

Stand: 23.10.2026.

## Quellen und Genauigkeit

- Primärdatensatz: [Clientarchiv 14.16, map33.bin.json](https://raw.communitydragon.org/14.16/game/data/maps/shipping/map33/map33.bin.json). Lokal unverändert unter research/map33-14.16.json archiviert. GameModeMapData.mExperienceCurveData identifiziert die verwendete XP-Kurve {9f34b4bd}; die alternative Standardspielkurve wurde nicht verwendet.
- [Riot: The Tech Behind Swarm](https://www.riotgames.com/en/news/the-tech-behind-swarm) beschreibt datengetriebene Wellen. Der Import folgt StrawberryMapData → LoLModesRoundsListData → LoLModesRoundData → LoLModesPhaseData → 39 MapA-Wellendefinitionen.
- [Yuumi-Aufgabenliste](https://mobalytics.gg/lol/guides/swarm-yuumi-quest-guide): neun Aufgabentypen. Deren Ziele sind spielbar umgesetzt. Entfernungen, Objektzahlen, Zeitlimits und Grafiken sind Nachbau-Abstimmung.
- [Damals gemeldetes PBE-Spielerfeedback](https://www.reddit.com/r/LeaguePBE/comments/1dofhci/pbe_bugs_and_feedback_thread_swarm/) bestätigt Meteoren und Dunkelheit bei Bel’Veth. [Weiteres damaliges Feedback](https://www.reddit.com/r/LeaguePBE/comments/1ec9lqi) beschreibt Verkettung und zusätzliche Manta-/Bruiser-Wellen.
- [Aufgaben und Freischaltungen](https://www.mobafire.com/league-of-legends/news/swarm-guide) beschreibt Aktivierung, Vasen/Kisten und Bel’Veth nach fünf Minuten Hard. [Systemübersicht](https://wiki.leagueoflegends.com/en-us/Swarm): Karten, Spires und HUD.

**Grenze:** Vollständige Serverskripte der Spires fehlen im Clientarchiv. Eine erschöpfende, servergenaue Liste aller Bel’Veth-Varianten und exakten Spire-Sekunden konnte nicht verifiziert werden. Eventzeiten und Minigameparameter sind deshalb gekennzeichnete Abstimmung. Gegnergrafik und manche archetypspezifischen Angriffe bleiben vereinfacht.

## XP

Die alte Kurve war nach Level 20 frei fortgeschrieben und schon ab Level 11 nicht deckungsgleich mit dem Archiv. Jetzt werden Differenzen der originalen kumulativen Schwellen verwendet.

| Level | Alte Anzeige | Neue Anzeige | Tatsächliche Kosten bei bisheriger strikter Schwelle |
|---|---:|---:|---:|
'''
for level, old, new, actual, cumulative in xp_rows:
    if level in [1, 2, 10, 11, 20, 24, 30, 40, 50, 60, 90, 91, 98]:
        text += f'| {level} | {old} | {new} | {actual} |\n'
text += '''
Die bestehende >-Schwelle bleibt erhalten: nach 168/168 erfolgt der Aufstieg bei einem weiteren XP-Punkt. Die CSV nennt das offen. Die kumulative Archivschwelle 91 fällt irrtümlich von 38125 auf 19035 und danach auf 39955. Diese einzelne Anomalie wurde mit 39035 korrigiert und protokolliert.

Warehouse-Zuordnung: normale Einheiten 1 XP, schwere Bruiser 4 XP, Elite-/Minibosse 20 XP. Die exakte serverseitige Orb-Zuordnung jeder Unterart ist nicht aus expGivenOnDeath ableitbar (überall 0, da Pickups verwendet werden); sie bleibt Nachbau-Abstimmung. Normale XP steigen nicht automatisch mit der Kampfstärke. Prüfungsgegner geben keine Farm-XP zusätzlich zur Abschlussbelohnung, Divider-Kinder keine weiteren XP. Aufhebeboni und Bruchteilsüberträge werden einmal angewendet. Ein Magnet erzeugt selbst keine XP, kann aber angesammelte Orbs gemeinsam einsammeln.

## Originaler Wellenablauf

Drei Sekunden Startphase; erste normale Phase bis 00:45, danach 45-Sekunden-Abschnitte bis 15:00. Kein erfundener universeller Zehn-Sekunden-Stopp: einzelne Wellen haben lange 8-/10-Sekunden-Spawnintervalle. Bereits lebende Gegner bleiben währenddessen aktiv.

| Start | Zusätzliche feste Gegner (Solo) |
|---|---|
| 01:30 | Pix-Sandwich mit 100 Einheiten |
| 02:15 | 1 Bruiser-Miniboss |
| 03:45 | 1 Hunter-Elite; 60 Schilde im Ring |
| 04:30 | Schwärmer, 15/s |
| 05:15 | 2 Dasher-Minibosse |
| 06:00 | 1 MiniDasher-Elite; normale MiniDasher 10/0,75s |
| 07:30 | 70 Schilde im Ring |
| 08:15 | 2 Artillerie-Minibosse |
| 09:45 | 1 Lancer-Elite |
| 10:30 | Spawner-Abschnitt |
| 11:15 | 3 Bruiser-Minibosse |
| 12:00 | 1 Shield-Elite; 15 Ghouls alle 0,75s |
| 13:30 | 1 Daisy-Elite |
| 15:00 | Rek’Sai plus eigene Boss-Adds |

Alle 39 Definitionen einschließlich Formen stehen in MAP1-WELLEN-14.16.csv und der importierten JSON. Formationseinheiten mit hinterlegtem Timeout werden ohne Kill/XP entfernt. Die Quelldaten sind vollständig importiert; Weltmaßstab, Navigation und Verhalten nutzen die vorhandene vereinfachte Engine. Divider erzeugen zwei Kinder; Nachbau-Kinder geben keine zusätzliche XP. Spawner produzieren weitere normale Einheiten.

Der Zufalls-Elitewurf wurde auf Warehouse ersetzt. Acht feste Minibosse und fünf Elite-Einheiten ergeben 13 garantierte Karten-Gelegenheiten bei erfolgreichem Besiegen. Prüfungen können weitere Karten geben. Spawnmengen skalieren mit Spielern. Maximal 550 reguläre lebende Gegner plus reservierte Plätze für feste Ziele und Prüfungen. Ein voller Pool erzeugt keine riesige nachträgliche Spawn-Schuld. Die letzten Heavy-Wellen sind nicht dichter als jede frühere Schwarmwelle: der Originalphasenplan entscheidet.

Minimap wie gewünscht: Endboss sichtbar, Minibosse ohne Gegner-Markierung. Das weicht bewusst von der Original-Systembeschreibung mit eigenem Miniboss-Symbol ab. Karten und Spires bleiben sichtbar.

## Yuumi

Drei Spieler-Sekunden Aktivierung im Kreis starten nur die Aufgabe. Erst Abschluss öffnet die Augment-Auswahl. Keine Belohnung bei Ablauf, verfehltem Strandball oder Abbruch. Spielpausen stoppen Fortschritt und Timer; die bestehende Auswahlwarteschlange verarbeitet gleichzeitige Level-/Karten-/Augment-Ereignisse.

| Typ | Spielbares Ziel |
|---|---|
| Nothing But Net | Ball durch Berührung ins goldene Tor schieben; Wandkontakt wird geprüft |
| Anti-Antiques | Alle 15 angreifbaren Vasen zerstören, ohne normale Kisten-Drops/XP |
| That Darn Yarn | Wollknäuel 650 Welteinheiten tatsächlich rollen |
| Catch The Chumper | Fliehendes markiertes Ziel besiegen; fremde Kills zählen nicht |
| Box Hoarding | Fünf Kisten einzeln aufnehmen und abliefern; temporärer Trage-Laufmalus |
| Bounce The Beach Ball | Sechs Landepunkte rechtzeitig erreichen; ein verfehlter Ball scheitert |
| Race To The Finish | Drei Checkpoints in Reihenfolge |
| Marathon | Sechs weiter entfernte Checkpoints in Reihenfolge |
| Laser Chase | Fünf Zielpunkte jeweils eine Sekunde halten |

Belohnungen sind einmalig. Trage-Mali werden beim Abbruch entfernt; Kisten niedergeschlagener Träger werden wieder verfügbar. Aufgabenobjekte und Sondergegner werden bei Ende bereinigt.

## Bel’Veth

Hard/Extreme nach Freischaltung durch fünf Minuten Hard; keine Bel’Veth-Spire auf Story. Fortschritt und Profilmerkmal werden gespeichert. Sechs spielbare Vorlagen: markierten Miniboss töten; 35 markierte Wellengegner töten; 30 Sekunden gemeinsam im Kreis; 30 Sekunden in begrenztem Teamabstand; 30 Sekunden Meteoren ausweichen; 30 Sekunden mit begrenzter Sicht überleben. Zeiten, Radien, Schaden und Mengen sind Nachbau-Abstimmung und keine kopierten Serverparameter. Nicht als erschöpfender Originalkatalog zertifiziert.

Erfolg gibt einmal eine Karte, 150 Gold und einsammelbare XP ungefähr in Höhe zweier unmodifizierter Levelkosten. Das ist die große Eventbelohnung, nicht die normale XP-Rate. Prüfungsziele geben Karte/XP nicht zusätzlich beim Tod. Meteoren haben eine Vorwarnung; Dunkelheit lässt HUD und Minimap lesbar.

Eventfenster im Nachbau: Yuumi 02:30/07:30/12:30, Bel’Veth 04:00/09:00/13:30, Miss Fortune 01:30/04:30/06:30/09:30/11:30/14:30. Sekunden sind angenäherte öffentliche Zeitfenster, keine aus dem Wellenarchiv belegten Originalsekunden. Angeboten werden mehrere Spires gleichzeitig, aber nur eine Minispielaufgabe läuft. Beim Endboss werden offene Aufgaben ohne Belohnung abgebrochen.

## Prüfung und nächste Aufgabe

Die Abnahme simuliert den ganzen Solo-Wellenplan, kontrolliert 8/5 feste Karten-Gegner, hohe Schwarmdichte und alle Aufgaben einschließlich Scheitern, Cleanup, Freischaltungen und einmaliger Belohnung. Native Grafikaufnahmen: output/swarm-ui/warehouse-event-*.png. Endgültige Ergebnisse: MAP1-PRUEFUNG.txt.

Evolutionen sind in TODO.md als eigener nächster Durchgang festgehalten. Bestehende Grundlogik bleibt erhalten; dieser Umbau ist keine vollständige Evolutionsüberarbeitung.
'''
(OUT / 'MAP1-ABLAUF-XP-EVENTS.md').write_text(text, encoding='utf-8')
print('Wellen-/XP-Tabellen und Analyse gespeichert.')
