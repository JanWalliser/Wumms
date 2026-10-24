# WUMMS – Game Design & Systemdokumentation

## 1. Gameplay-Loop
1. **Hauptmenü**: Auswahl des Spielerprofils, Lobby-Start, Shop-Einkäufe oder Quest-Übersicht.
2. **Lobby (1–4 Spieler)**: Jeder lokale Spieler wählt sein individuelles Profil, sein Eingabegerät (Tastatur/Maus oder Gamepad 0–3) und seinen freigeschalteten Charakter. Anschließend werden Karte und Schwierigkeit gewählt.
3. **Run-Start**: Alle Spieler starten mit Stufe 1 und ihrer charakterbezogenen Startwaffe.
4. **Horden & Timeline (0:00 bis 15:00)**:
   - Kontinuierlich anrollende Gegnerwellen.
   - Besiegte Urviecher hinterlassen Erfahrungslinsen (Schlauheits-Schokolinse).
   - Team-Level-ups pausieren die Simulation und bieten jedem Spieler 3 individuelle Auswahlkarten an.
   - Elite-Gegner und Halbstarke lassen Zutritts-Zwieback (Zugangskarten) fallen.
   - Ab Stufe 3 wird die E-Fähigkeit freigeschaltet, ab Stufe 6 das Ultimate (R).
5. **Boss-Erscheinung (15:00)**:
   - Der Ober-Obermacker der gewählten Karte betritt das Feld.
   - Eine große Bosslebensleiste erscheint im HUD.
   - 5-Minuten-Ragetimer: Besiegen die Spieler den Boss nicht innerhalb von 5 Minuten, gerät er in Raserei und attackiert mit tödlicher Frequenz.
6. **Sieg / Niederlage**:
   - Belohnungen (Dönerdublonen) werden mit dem Schwierigkeitsmultiplikator berechnet.
   - Alle teilnehmenden Profile erhalten ihre Belohnungen und Quest-Fortschritte.

## 2. Multi-Player & Revive-Mechanik
- **Geteilter Bildschirm**: Dynamische Kamera fasst alle aktiven Teammitglieder ein und zoomt stufenlos mit.
- **Gemeinsame Progression**: Team-EXP und Gold kommen der gesamten Gruppe zugute.
- **Downed-Zustand**:
  - Sinkt das Leben eines Spielers auf 0, geht er zu Boden (Downed).
  - Ein 10-Sekunden-Timer verhindert sofortige Wiederbelebung.
  - Nach Ablauf der 10 Sekunden kann ein lebender Mitspieler die Wiederbelebungszone betreten.
  - Alternativ greift der automatische Respawn-Timer: 15 Sekunden Basiszeit, steigt um +9 Sekunden pro vorherigem Tod bis zu maximal 60 Sekunden.
  - Wiederbelebte Spieler starten mit 50% HP und 4 Sekunden Unverwundbarkeit.
  - Sind alle aktiven Spieler gleichzeitig ausgeschaltet, endet der Run in einer Niederlage.

## 3. Waffen- & Evolutions-Regeln
- Maximal 5 Waffen pro Spieler (1 Startwaffe + bis zu 4 gewählte Waffen).
- Jede Waffe besitzt 5 Basisstufen.
- **Evolution**:
  - Waffe muss Stufe 5 erreicht haben.
  - Das geforderte passive Item muss sich im Inventar des Spielers befinden.
  - Eine gesammelte Zugangskarte bietet die Evolution an.
  - Evolvierte Waffen ändern ihr mechanisches Verhalten drastisch (z.B. Dauerklingenorkan, Cluster-Bomben, Schockgefrieren).


## Verbindliche Regeln nach dem Audit
- Alle Teilnehmer teilen ein Run-Level; Waffen, Passive und Augments bleiben individuell.
- Eine gemeinsame Kamera, kein Splitscreen. Maximal vier Teilnehmer insgesamt.
- Der Host schaltet Karte/Schwierigkeit frei; jedes Profil behält seine Charakter-Unlocks.
- Gemeinsames Teamgold wird einmal je eindeutigem teilnehmendem Profil gutgeschrieben; dasselbe Profil in mehreren Slots ist ein geteilter Gastfortschritt.
- Bei Bosstod und Team-Wipe im selben Simulationsframe zählt der Bosssieg.
- Zugangskarten bieten garantiert eine Evolution an, sofern eine gültige existiert.
- Hard-Ziele zählen auch auf Extreme. Storyketten: Level 10, eigene Evolution, danach Bosssieg; Kapitel bleiben gespeichert.
- Debugaktionen markieren den aktuellen Run als Übung ohne weiteren Profilfortschritt.
