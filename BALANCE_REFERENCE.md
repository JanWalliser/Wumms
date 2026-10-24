# WUMMS – Projekt-Balance und Referenznotizen

## 1. Referenzlinks der ursprünglichen Vorlage (hier nicht extern verifiziert)
- **League of Legends Wiki: Swarm Mode (2024)**: [https://wiki.leagueoflegends.com/en-us/Swarm](https://wiki.leagueoflegends.com/en-us/Swarm)
- **LoLSwarm Perk Database**: [https://www.lolswarm.gg/Perks.php](https://www.lolswarm.gg/Perks.php)
- **LoLSwarm Champion Database**: [https://www.lolswarm.gg/Champions.php](https://www.lolswarm.gg/Champions.php)
- **LoLSwarm Objectives Database**: [https://www.lolswarm.gg/Objectives.php](https://www.lolswarm.gg/Objectives.php)
- **Riot Tech Blog: The Tech Behind Swarm**: [https://www.riotgames.com/en/news/the-tech-behind-swarm](https://www.riotgames.com/en/news/the-tech-behind-swarm)

## 2. Grundlegende Basiswerte
- **Grundbewegungstempo**: 350.0 Einheiten/Sekunde
- **Grund-Krit-Chance**: 5% (0.05)
- **Grund-Krit-Schaden**: 200% (2.0x)
- **Grund-Aufsammelradius**: 100.0 Einheiten
- **Spieler-Kollisionsradius**: 65.0 Einheiten (visuelle Hitbox 24.0)
- **Maximales Level**: 99

## 3. Stat-Formeln & Skalierung
### Fähigkeitstempo (Ability Haste)
Cooldowns werden nach der projektintern verwendeten Formel berechnet:
```
effective_cooldown = base_cooldown / (1.0 + max(-90.0, ability_haste) / 100.0)
```
*Begründung*: Verhindert lineare Abzüge, Nullabklingzeiten und mathematische Unterläufe.

### Rüstung & Schadensreduktion
```
damage_mitigated = raw_damage * (100.0 / (100.0 + max(0.0, armor)))
```

### Schwierigkeitsmultiplikatoren
| Schwierigkeit | Gegnerleben | Physischer Schaden | Zauberschaden | Goldmultiplikator |
|---|---|---|---|---|
| **Kartoffel-Kindergarten (Story)** | 1.0× | 1.0× | 1.0× | 1.0× |
| **Aua-Akademie (Hard)** | 3.0× | 2.0× | 1.5× | 1.5× |
| **Warum-tun-wir-uns-das-an?! (Extreme)** | 7.0× | 3.0× | 2.0× | 2.25× |

### Spieleranzahl-Skalierung
- 1 Spieler: 1.0×
- 2 Spieler: 1.6×
- 3 Spieler: 2.2×
- 4 Spieler: 2.8×

## 4. Dokumentierte Annahmen & historische Abweichungen
- **Erfahrungs-Shop-Upgrade (Hirnschmalz-Hantel)**: Historische Tabellen nannten teils 5%, teils 10% pro Stufe. Für WUMMS wurde der maßgebliche 2024er Stand von **5% pro Stufe** (maximal 5 Stufen = +25% Erfahrung) gewählt.
- **Erfahrungs-Kurve pro Stufe**: Importierte kumulative Swarm-Tabelle aus dem Clientarchiv 14.16, verknüpft über `GameModeMapData.mExperienceCurveData`. Die Kosten sind deren Differenzen, beispielsweise Level 11: 66, Level 24: 168, Level 40: 320 angezeigte XP. Die frühere frei fortgeschriebene Formel ist ersetzt. Die bestehende strikte Schwelle benötigt jeweils einen weiteren XP-Punkt. Eine einzelne absteigende Archivanomalie bei Level 91 ist dokumentiert korrigiert. Vollständige Tabelle und Grenzen: `output/swarm-balance/MAP1-ABLAUF-XP-EVENTS.md`.
- **Fähigkeiten-Neu-Würfeln (Reroll-Ausschluss)**: Beim Neu-Würfeln werden die davor aufgedeckten Fähigkeiten und Augments im aktuellen Auswahl-Event registriert und aus dem bevorzugten Angebotspool ausgeschlossen, sodass dieselben Fähigkeiten nicht erneut erscheinen, solange andere wählbare Optionen verfügbar sind.
- **Anima Power (Knallkraft 100)**: Bietet +1% Schaden, +1% Lauftempo, +1 Fähigkeitstempo und +1% Sammelradius pro Stufe zu fixen 3.000 Gold je Stufe bis maximal Stufe 100. Freigeschaltet nach Aatrox auf Hard.


## Abnahmestand 0.2.0
Die Zahlen sind Arbeitswerte des Prototyps. Historische Genauigkeit und faire Gewinnbarkeit sind nicht aus den Registry-Tests abzuleiten. Navigation verwendet nun eine begrenzte gleichgewichtete Kostenwelle mit ecksicherer Diagonalsteuerung; physische Gegner-Gegner-Kollision wird durch räumliche Separation ersetzt. Der 500-Gegner-Test protokolliert CPU-Frametimes, keine garantierten Grafik-FPS.

### Folgedurchgang 24.10.2026: frühe Level und Bomben-Drop

Die oben beschriebenen Kurven-Differenzen sind die bisherige Interpretation der Archivdaten, keine unabhängig bestätigte Serverskript-Rekonstruktion. Auf Wunsch nach langsamerer Frühphase gelten nun separat gekennzeichnete Projektfaktoren aus `assets/balance/progression-tuning.json`: Level 2–7 ×1,5, sanfter Übergang 8–10, ab 11 unverändert. Level 7 benötigt nun 162 statt 111 gutgeschriebene XP ohne Boni. Keine Kürzung der Kugelwerte. Der Bomben-Drop wirkt jetzt lokal (600 Referenz-/120 Welteinheiten), nicht mehr auf die gesamte Karte; sichere Aufnahme verhindert das klebende Symbol. Befund und genaue Tabelle: `output/swarm-balance/HAGELKANONE-BOMBE-XP-FOLLOWUP.md`.
