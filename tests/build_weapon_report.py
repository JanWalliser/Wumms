"""Publish the complete implemented Jinx loadout matrix and its evidence limits."""
import csv
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/swarm-balance'
data=json.loads((ROOT/'assets/balance/swarm-14.16.json').read_text(encoding='utf-8'))
names=dict(zip(['weapon_uwu_blaster','weapon_ani_mines','weapon_anti_shark','weapon_crossbow','weapon_blade_o_rang','weapon_mega_blast','weapon_slicers','weapon_batblades','weapon_transit','weapon_gatling','weapon_iceblast','weapon_lioness','weapon_paw_poison','weapon_radiant_field','weapon_shortbow','weapon_statikk','weapon_tibbers','weapon_annihilator','weapon_vortex_glove','weapon_yuumibot','weapon_meow_meow'],['UwU Blaster','Ani-Mines', 'Anti-Shark Sea Mine','Battle Bunny Crossbow','Blade-o-rang','Bunny Mega-Blast','Cyclonic Slicers','Echoing Batblades','Final City Transit','Gatling Bunny-Guns','Iceblast Armor',"Lioness’s Lament",'Paw Print Poisoner','Radiant Field','Searing Shortbow','Statikk Sword','T.I.B.B.E.R.S','The Annihilator','Vortex Glove','YuumiBot','Meow Meow / Battle Cat Barrage']))
notes={
'weapon_uwu_blaster':'Einzelne zielgerichtete Projektile; erster Gegner beendet das Projektil. Salvenabstand 0,033 s. Flugreichweite 1200, Geschwindigkeit 2000, Breite 40.',
'weapon_ani_mines':'Ringplatzierung in Entfernung 275. Flugzeit plus 0,5 s Vorbereitung, dann versetzte Detonationen. Evolution: zusätzlicher Dreiercluster mit 70 Schaden und Radius 300, pro Cluster ein Treffer je Gegner.',
'weapon_anti_shark':'Kontakt verursacht den Tabellenwert plus einen separaten Explosionswert: 50/80/110/140/170, Evolution 200. Sprünge: 3/4/4/5/5; Evolution sucht weiter, solange ein neues Ziel existiert. Keine zusätzlichen Minen durch Projektil-Boni.',
'weapon_crossbow':'Zufälliger Fächer, zusätzliche Krit-Chance 10/20/20/30/30 %, Evolution 30 %. Jedes Geschoss würfelt selbst; nur kritische Treffer durchdringen. Evolution 25 statt des bisherigen Projektwerts; zusätzliche erlaubte Projektile werden nicht bei 24 abgeschnitten.',
'weapon_blade_o_rang':'Zielgerichteter Hin- und Rückflug mit Abbremsen/Beschleunigen. Beide Flugphasen dürfen denselben Gegner jeweils einmal treffen. Evolution erzeugt zusätzliche radiale und kleine zurückkehrende Klingen. Der genaue Zufallsrhythmus der Serverimplementierung ist angenähert.',
'weapon_mega_blast':'Zahl sind Ziele, nicht zusätzliche Projektile. Einschlagradius 180 und Vorwarnung 0,5 s. Evolution: zunehmende Einschlaggrößen bis zur großen Abschlussdetonation. Exakte zufällige Anzahl pro Größenklasse ist nicht aus dem Datenarchiv ablesbar; aktuell zwölf Einschläge.',
'weapon_slicers':'Ein Ring, keine gestapelten Ringe. Gemeinsame Treffer-Sperre 1 s pro Ziel; Winkeltempo −2,5 rad/s, Rückstoß 150 Referenzeinheiten. Archivgeometrie korrigiert: Radius 200/350, Trefferbreite 100/130; der Bildgrößenfaktor 1,5/2 wird nicht mehr als zusätzliche Treffergröße verwendet. Evolution dauerhaft, daher ist die Daten-CD von 3 s kein Wiederbeschwörungszyklus. Eine gemeinsame Treffer-Sperre über alle eigenen Klingen ist die gewählte Anti-Mehrfachtreffer-Interpretation des LockoutTime-Felds. Serverskriptgenaue Reset-/Überlappungsregeln sind nicht verfügbar.',
'weapon_batblades':'Gerade durchdringende Projektile mit Abprallen an Terrain. Evolution erhöht Schaden um 25 % je Wandabprall. Der frühere erfundene wahre Schaden gegen Eliten wurde entfernt.',
'weapon_transit':'Tabellenschaden plus 5 × Rüstung. Zufälliger Zugpfad, Geschwindigkeit 850, Fahrstrecke 2750. Evolution hinterlässt alle 0,25 s Explosionen und betäubt. Der genaue originale Goldbonus bei Zug-Kills ist noch offen.',
'weapon_gatling':'Anhaltender 28-Grad-Kegel. Schaden je Tick, viermal pro Sekunde (Archivfeld TicksPerSecond = 4). Die Wiki nennt 0,264 s; hier gilt der direkte Datensatz. Abklingzeit beginnt nach der Salve: erster Basiszyklus ohne Boni etwa 8 + 5 = 13 s. Evolution: vier Verlangsamungsstapel mit 4 s Ablauf, der fünfte Treffer betäubt 6 s und gewährt 15 % Verwundbarkeit. Weitere Treffer verlängern die laufende Betäubung nicht endlos.',
'weapon_iceblast':'Wird zunächst scharf und blockiert einen eingehenden Schaden vollständig. Erst dann Nova und Abklingzeit. Schaden zusätzlich 2,5 × Rüstung. Evolution: Schild 200 + 20 % maximales Leben, Nova bei Gewährung und Schildende. Datenfeld Cooldown 18/18/17/17/16 hat Vorrang vor dem abweichenden allgemeinen Zauber-CD-Feld.',
'weapon_lioness':'Seitliche Dreifach-Sichelbahnen teilen sich eine Trefferliste; kein dreifacher Schaden auf einen Gegner. Evolution verschießt nach Vorbereitung Strahlen zu beiden Seiten. Exakte originale Spline-Geometrie und Vorbereitung sind noch nicht vollständig reproduziert.',
'weapon_paw_poison':'Bewegungsabhängige Spur, keine Schuss-CD. Nach mindestens 80 Referenzeinheiten und ausreichendem Abstand zur letzten Wolke neue Fläche; maximal 24 Wolken. Die archivierte DamagePerSecond-Berechnung bestätigt den Tabellenwert als DPS. Jeder 0,25-s-Tick teilt ein Viertel aus; eigene überlappende Wolken teilen sich eine Tick-Sperre. Rundung erfolgt pro Treffer auf ganze HP. Evolution gewährt Schild und Tempo beim Schaden.',
'weapon_radiant_field':'Eine persistente Aura. Schaden zusätzlich 5 % maximales Leben. Verwendet das archivierte TickRate-Feld 0,5 s; die Wiki-Angabe 0,264 s widerspricht diesem Feld. Evolution erzeugt bei Kills innerhalb der Aura 300-Schaden-Explosionen, Radius 200. Sekundäre Procs lösen zur Rekursionsbegrenzung keine weiteren Ketten aus.',
'weapon_shortbow':'Die Schadensspalte enthält DPS: pro 0,5-s-Tick die Hälfte dieses Werts. Flugzeit 0,5 s; Radius 200 und Dauer 5 s. Evolution wächst über 3 s auf doppelte Fläche und doppelten Tickschaden. CD bleibt nach archiviertem Spell 8 s; Wiki nennt für die Evolution abweichend 0. Nahe eigene Feuerflächen werden erneuert; überlappende eigene Flächen teilen eine Tick-Sperre von 0,5 s je Ziel. Diese Überlappungsregel sowie die DPS-Deutung und der konkrete Wachstumsverlauf bleiben gekennzeichnete Projektabstimmung.',
'weapon_statikk':'Zahl sind ausgewählte Gegner, kein Projektilbonus. Auswahl nach absolutem aktuellem Leben. Evolution: elektrisches Feld pro Ziel, Radius 100, Dauer 3 s, 0,528 s Tickabstand; Feldschaden 80 × Krit-Schadensmultiplikator, ohne eigenen Krit-Wurf.',
'weapon_tibbers':'Schaden je Hieb, höchstens zwei Hiebe/s, Ziel mit höchstem aktuellem Leben. Bewegung und Reichweite sind von Waffenfeuer getrennt. Evolution wächst während der Lebensdauer. Deren Archivwert ist 30 s, während manche Übersichten 28 s nennen. Begleiternavigation und Beschwörungsrhythmus sind noch nicht videoexakt.',
'weapon_annihilator':'Radius 1700, Vorwarnung 3 s. Normale Gegner werden beseitigt, Eliten/Bosse erhalten den Tabellenwert. Der zusätzliche XP-/Gold-Ertrag der Evolution ist noch nicht implementiert; dafür fehlt hier ein belastbarer vollständiger Loot-Abgleich.',
'weapon_vortex_glove':'Gegen Uhrzeigersinn/mit Uhrzeigersinn rotierende Ströme, 1 rad/s. Reichweite 1200, Geschwindigkeit 1500, Breite 70; 0,066 s Abstand innerhalb der Salve. Fähigkeitstempo und Dauer verändern den Strahl nicht.',
'weapon_yuumibot':'Beweglicher Begleiter statt stationärer Laser. Kontaktschaden, kurzer Hochwurf und eigener XP-Sammelbereich. Mehrere Drohnen dürfen gleichzeitig bestehen; CD beginnt beim Beschwören. Evolution erzeugt Heilpakete nach Schadensfortschritt. Fortschritt wird pro Spieler über Beschwörungen hinweg geteilt; große Treffer können mehrere 100-Punkte-Schwellen auslösen, ohne den Rest zu verlieren. Exakter Patrouillenpfad und Ausschluss bereits besuchter Zielgruppen bleiben angenähert.',
'weapon_meow_meow':'Die Daten-/Guidewerte 60/80/100/120/140 beschreiben die Salve. Mit 3/4/5/6/7 Clustern ergibt das 20 Schaden je Cluster. Diese Interpretation wird zusätzlich durch die detaillierte Waffenbeschreibung gestützt. Evolution: 20 am ersten Ziel, danach 40 % = 8 je weiterem Ziel. Salve statt gleichzeitiger Fächer; Basisreichweite 1500, Geschwindigkeit 3500, Breite 90. Der genaue serverseitige Abstand zwischen Clustern ist nicht bestätigt; aktuell 0,066 s.'}

def fmt(value):
    if value is None: return '—'
    return f'{value:g}' if isinstance(value,(int,float)) else str(value)

def at(weapon,key,rank,default=None):
    if rank==6: return weapon.get('evolution_'+key,default)
    values=weapon.get('base_'+key)
    return values[rank-1] if isinstance(values,list) else default

intro='''# Vollständiger Waffen- und Stat-Abgleich für Jinx

Stand: 24.10.2026. Umfang: alle 20 allgemeinen Waffen, Jinx’ Standardwaffe und Evolution, E/R, zwölf normale Stat-Passive und die 33 vorhandenen Yuumi-Augments. Andere Champion-Standardwaffen sind bewusst nicht Teil dieses Jinx-Durchgangs.

## Ergebnis und Belegqualität

Die Werte stammen jetzt überwiegend aus den tatsächlich archivierten 14.16-Spell-Datensätzen. Die alten frei erfundenen Grundtabellen und mehrere veraltete Guidewerte wurden ersetzt. Das Archiv enthält Konfigurationen und Tooltip-Berechnungen, aber nicht die damaligen Serverskripte. Deshalb sind Zahlenabgleich und vollständige mechanische Originaltreue unterschiedliche Aussagen. Nicht belegbare Details werden unten ausdrücklich genannt.

Primärdaten: [allgemeine Waffen und Augments](https://raw.communitydragon.org/14.16/game/data/maps/shipping/map33/map33.bin.json), [Jinx-Daten](https://raw.communitydragon.org/14.16/game/data/characters/strawberry_jinx/strawberry_jinx.bin.json). Gegenprüfung: [Riot 14.15](https://www.leagueoflegends.com/en-us/news/game-updates/patch-14-15-notes/), [Waffenmechaniken](https://leagueoflegends.fandom.com/wiki/Swarm_%28League_of_Legends%29/Weapons), [Jinx-Mechaniken](https://leagueoflegends.fandom.com/wiki/Swarm_%28League_of_Legends%29/Jinx), [Swarm-Systeme](https://wiki.leagueoflegends.com/en-us/Swarm). Die alte [14.14-Perkübersicht](https://lolswarm.gg/Perks.php) wird wegen nachgewiesener Widersprüche nicht mehr ungeprüft als Zahlenquelle verwendet.

Die Rohdaten und ein reproduzierbarer Import liegen unter `output/swarm-balance/research/` beziehungsweise `tests/import_swarm_reference.py`. Die Laufzeit verwendet `assets/balance/swarm-14.16.json`. `WAFFEN-REWORK-1.md` ist der historische erste Durchgang; dieser Bericht ersetzt dessen offenen Zahlenabgleich.

## Wie Angriffstempo und Levelaufstiege wirken

- Swarm verwendet für diese Waffen Fähigkeitstempo: effektive CD = Basis-CD / (1 + Tempo / 100). 50 Tempo ergibt also zwei Drittel der Basis-CD, 100 Tempo die Hälfte. Nicht jede Waffe unterstützt diesen Modifikator.
- Salvenabstand, Tickabstand, Flugdauer, aktive Dauer und Abklingzeit sind getrennte Zeiten. Eine Gatling-CD von 5 s bedeutet keine vollständige Salve alle 5 s. Die Salve läuft zuerst.
- Ein Team-Levelaufstieg verbessert die ausgewählte Waffe oder Passive um eine Stufe. Er erhöht nicht pauschal Schaden oder Projektilzahl aller Waffen. Jinx’ aktive Fähigkeiten erhalten dagegen ihre festgelegte Skalierung mit dem Teamlevel.
- Waffen werden auf Stufe 5 maximiert. Evolution benötigt zusätzlich den zugeordneten Passivwert und eine Zugangskarte. Zusätzliche Projektilwerte gelten nur für dafür vorgesehene Waffen; Zielanzahl, Begleiterzahl und Wirkungsfläche sind keine allgemeine Projektilanzahl.
- Alle Tabellen zeigen unmodifizierte Werte. Normale Schaden-, Flächen- und Dauerquellen werden anschließend jeweils einmal angewandt. Ränge einer Quelle addieren sich; getrennte Prozentquellen multiplizieren sich. Beispiel: +20 % Shop und +20 % Schaden-Passive ergeben Faktor 1,44.
- Entfernungen sind Original-Referenzeinheiten. Für die rekonstruierte Karte werden ausdrücklich umgestellte Waffenentfernungen einmal mit 0,2 umgerechnet. Gegnerleben, Schwierigkeitskurven und die bisher gewünschte Bewegungsabstimmung wurden in diesem Auftrag nicht global ersetzt.

## Jinx

**Angepasstes Spielgefühl auf Wunsch:** E schießt sofort, mit 45° Gesamtfächer und Geschwindigkeit 3600 (720 Welt-Einheiten/s). R lädt 0,5 s, fliegt mit 4000 (800 Welt-Einheiten/s) und zeigt die Rakete mit 80 % der bisherigen Bildgröße. Schaden, Trefferbreite, Reichweite und Explosionsradius bleiben unverändert. Die nachfolgenden Archivwerte dokumentieren das Original; die genannten Anpassungen überschreiben dessen Vorbereitung, Fächer und Fluggeschwindigkeit im Spiel.

Startwerte im Profil ohne Upgrades: 1000 HP, 0 Rüstung, 5 % Krit-Chance. Regeneration kommt aus den tatsächlich gewählten Boni.

E: freigeschaltet ab Level 3, 8 s Basis-CD, 0,35 s Vorbereitung laut archiviertem `mCastTime`. Neun Raketen plus erlaubter Projektilbonus, zufällige Richtungen innerhalb eines 90-Grad-Fächers um den Mauszeiger. Je Rakete 55 + 6 × (Teamlevel − 1), Reichweite 2200, Geschwindigkeit 1800, Breite 80, Explosionsradius 300. Die Wiki nennt abweichend 0,75 s Vorbereitung; hier wurde der direkte Datensatz bevorzugt.

R: freigeschaltet ab Level 6, 50 s Basis-CD und 0,75 s Vorbereitung. Schaden 500 + 50 × (Teamlevel − 1), multipliziert mit `1 + 2 × fehlender Lebensanteil` jedes einzelnen Ziels. Wahrer Flächenschaden; Reichweite 2000, Geschwindigkeit 2000, Breite 280, Radius 600. Explodiert genau einmal beim ersten Gegner oder am Reichweitenende. Die fehlerhafte Maximalschadensformel aus einer Wiki-Angabe wurde nicht übernommen; die Archivberechnung multipliziert den Basisschaden mit 3.

Passive: 70 normale Kills oder ein Elite-Kill lösen acht Sekunden +150 Fähigkeitstempo aus. Die bisher bewusst reduzierte, abklingende Tempo-Spitze von 35 % bleibt erhalten. **Diese Bewegungsamplitude ist weiterhin Projektabstimmung und kein bestätigter Originalwert.** Das Archiv enthält `MSBuff = 2,5`, aber ohne serverseitige Anwendung ergibt sich daraus keine sicher rekonstruierte Laufgeschwindigkeit. Der Bonus wird nicht nach jedem einzelnen Kill dauerhaft gestapelt. Nachprüfung: eigene, sofort aktualisierte Zustandsverwaltung statt eines sekündlich erneuerten dynamischen Buffs; bei Tod werden Laufbonus, Fähigkeitstempo und Killfortschritt entfernt. Doppelte Killmeldungen zählen einmal. Erneute echte Auslösungen erneuern acht Sekunden, ohne Boni zu stapeln. Das Augment „With Haste“ addiert seine Umrechnung auf die Basisgeschwindigkeit, statt den ganzen Shop-/Passiv-/Anima-Geschwindigkeitsblock zu multiplizieren. Ein Fortschrittsbalken (0–70) und ein Aktiv-Timer stehen jetzt am Charakter und im HUD. Die exakte Darstellung eines solchen Original-Zählers ist durch die verfügbaren Quellen nicht belegt; unsere Anzeige ist eine eigene Umsetzung.

Die große R-Rakete, kleine E-Raketen und der Explosions-Splash sind eigene transparente Bildgrafiken, direkt in die Projektile/Effekte eingebunden. Reichweite und Trefferradius werden getrennt von der Bildgröße berechnet. Erzeugungsnachweis und Prompts: `assets/projectiles/jinx/ARTWORK.md`. Vorschau im tatsächlichen Spielmaßstab: `output/swarm-ui/jinx-rockets-ingame.png`.

## Grafischer und funktionaler Folgedurchgang vom 24.10.2026

69 getrennte Icons für Jinx: 21 Waffen, zwölf Stat-Passive, 33 Yuumi-Augments, E, R und die angeborene Passive. HUD und Auswahl verwenden dieselbe semantische Zuordnung. Ein automatischer Test prüft unterschiedliche Ressourcen und tatsächliche Bildpixel. Neue handgemalte Standardwaffen-, E-, R-, Schnitzel-, Hagelkanonen- und ÜwÜ-Icons, transparente ÜwÜ-Geschosse und Hagelkanonen-Grafik; eigener Begleiteratlas für Zug, Teddy, Miezi und Mine. Native SVG-Motive für die übrigen Icons und zusätzliche Projektilformen. Alle Quellen/Prompts: `assets/projectiles/arsenal/JINX-ARTWORK.md`. Übersicht: `output/swarm-ui/jinx-item-gallery.png`.

Weiter korrigiert: Gift-DPS statt vierfachem Tickschaden, zeitlich ablaufende Gatling-Stapel, begrenzte Betäubung, laufende Aktualisierung des Gatling-Radius und Rangs, erhaltene Tickzeitreste, durchgehende Trefferprüfung schneller ÜwÜ-/Miau-Geschosse, Yuumi-Sammelradius entsprechend dem archivierten Stat-Multiplikator und Heilfortschritt über Beschwörungen. Der weiterentwickelte Teddy beschleunigt seine Angriffe mit 1 % je Sekunde bis +50 %; der Grundrhythmus bleibt eine dokumentierte Server-AI-Näherung.

## Alle Waffenstufen

Schaden ist pro Treffer/Cluster/Hieb/Tick, außer bei Kurzbogen und Giftspur: deren archivierter DPS-Wert wird in halbe beziehungsweise viertel Sekundenticks übersetzt. Bei Kontaktmine und skalierenden Waffen gelten zusätzlich die jeweiligen Erläuterungen. Ein Strich bedeutet, dass diese Kategorie nicht zur Waffe gehört.
'''
lines=[intro]
rows=[]
registry=(ROOT/'scripts/weapons/weapon_registry.gd').read_text(encoding='utf-8-sig')
import re
for id,name in names.items():
    w=data['weapons'][id]
    fragment=registry.split('"'+id+'": {',1)[1].split('\n\t}',1)[0]
    evolve=re.search(r'"evolution_requires": "([^"]+)"',fragment).group(1)
    lines += [f'### {name}',f'Evolution mit `{evolve}`. Zulässige Skalierungen: '+', '.join(w['modifiers'])+'. Kritische Treffer: '+('ja' if w['can_crit'] else 'nein')+'.','', '| Stufe | Schaden | Basis-CD s | Anzahl | Radius | Dauer s | Änderung Schaden / Anzahl |','|---|---:|---:|---:|---:|---:|---|']
    previous_damage=previous_count=None
    for rank in range(1,7):
        damage=at(w,'damage',rank)
        cooldown=at(w,'cooldown',rank)
        count=at(w,'projectiles',rank,1)
        radius=at(w,'radius',rank,w.get('area_radius'))
        duration=at(w,'duration',rank)
        change='neue Waffe' if rank==1 else f'{damage-previous_damage:+g} / {count-previous_count:+g}'
        lines.append('| '+' | '.join(map(fmt,['Evolution' if rank==6 else rank,damage,cooldown,count,radius,duration,change]))+' |')
        effective_range=w.get('evolution_range',w.get('range')) if rank==6 else at(w,'range',rank,w.get('range'))
        rows.append(dict(weapon=id,name=name,rank=rank,damage=damage,cooldown=cooldown,cooldown_haste50=cooldown/(1.5 if w['scales_haste'] else 1),cooldown_haste100=cooldown/(2 if w['scales_haste'] else 1),count=count,radius=radius,duration=duration,range=effective_range,speed=w.get('projectile_speed'),width=w.get('projectile_width'),crit=w['can_crit'],modifiers=','.join(w['modifiers']),damage_delta='' if rank==1 else damage-previous_damage,count_delta='' if rank==1 else count-previous_count))
        previous_damage,previous_count=damage,count
    lines += ['',notes[id],'']

lines+=['## Alle zwölf Stat-Passiven','','Die Spalten zeigen den gesamten Bonus auf der jeweiligen Stufe. Die Projektil-Passive gewährt auf Stufe 2 und 4 ausdrücklich kein weiteres Geschoss. Keine Passive überschreitet Stufe 5. Regeneration wird im Projekt weiterhin als HP pro fünf Sekunden geführt; HUD und Auswahl zeigen dieselbe Einheit.','','| Passive | Stufe 1 | Stufe 2 | Stufe 3 | Stufe 4 | Stufe 5 |','|---|---:|---:|---:|---:|---:|']
for id,p in data['passives'].items():
    percentage=id in ['area_size','crit_chance','damage','duration','exp_gain','movement_speed','pickup_radius']
    values=[fmt(round(x*100,3))+' %' if percentage else fmt(x) for x in p['levels'][1:]]
    lines.append('| '+id+' | '+' | '.join(values)+' |')

lines+=['','## Alle 33 Yuumi-Augments','','Die vorhandenen Augments wurden ebenfalls auf Auswirkungen auf Waffenschaden, Tempo und Projektilzahl geprüft. Statische Boni, Tradeoffs und die bisherigen erfundenen Effekte wurden korrigiert. Boni ab Erwerb zählen nicht rückwirkend. Größere Quelle-Unterschiede bleiben bei den nachfolgend genannten Serverdetails bestehen.','','| Augment | Eingebautes Verhalten |','|---|---|']
for id,entry in data['augments'].items(): lines.append('| '+id.removeprefix('augment_')+' | '+entry['description']+' |')

lines += ['''
## Was ausdrücklich noch keine exakte Originalrekonstruktion ist

Der Zahlenbestand ist vollständig für den gewählten Jinx-Waffenpool. Die folgenden Punkte verhindern weiterhin die Aussage „alles zu 100 % identisch“:

1. Serverabhängige Tick-/Cast-Regeln bei Radiant und Kurzbogen widersprechen teilweise den Wiki-Angaben; verwendete Datenfelder sind oben genannt. Salvenrhythmus der Jinx-Standardwaffe, Lioness-Splines, Begleiternavigation und die Zufallsverteilung der Mega-Blast-Evolution sind angenähert.
2. Animapocalypse-Lootbonus und Goldbonus des weiterentwickelten Zugs fehlen. Radiant-Sekundärketten sind begrenzt. Die eigene Regel zum Erneuern naher Feuerflächen bleibt erhalten. Diese Punkte werden nicht als vollständig implementierte Originalmechaniken ausgegeben.
3. Augments: Ebb And Flow und Size Scrambler werden kontinuierlich berechnet und ungefähr sekündlich auf Statwerte übertragen; der originale Update-Takt ist nicht vollständig bestätigt. Immobile Immolation verwendet die archivierten Kosten und Stapel. Emotionale-Unterstützung wirkt auf Begleiterschaden; zusätzliche, im Datensatz enthaltene unklar zuordenbare Pet-Unterwerte sind nicht geraten worden.
4. Death and Taxes: 2-%-Auslösung und Radius stammen aus der Referenz; aktueller Explosionsschaden 100 und Goldmenge 3 sind Projektwerte. Elite-Bomber-Bombe: Schaden 300, Radius 120 Welteinheiten und 1 s Verzögerung sind ebenfalls noch Projektwerte. Regenerative-Tissue-Zuwachs folgt der dokumentierten Mechanik; bei intern uneindeutigen Regenerationseinheiten ist die Projektkonvention HP5 beibehalten.
5. Jinx’ Passive behält die bisher vereinbarte reduzierte Bewegungsspitze. Anima-/Shop-/Passiv-Schaden und separate Tradeoffs werden sauber kombiniert; die vollständige Kombination sämtlicher Bewegungsboni ist weiterhin nicht als nachgemessene Originalbewegung zertifiziert.
6. Die isolierten Waffen- und Interaktionsprüfungen sind keine Langzeit-Balancegarantie. Insbesondere komplette Builds mit mehreren Flächenwaffen und allen Missionsbelohnungen benötigen reale Spieltests. Die Testfälle zeigen geprüfte Regeln und Grenzfälle, keine Aussage über jeden möglichen Run.

## Technische Korrekturen gegen Mehrfachauslösung

Direkt- und Explosionsschaden teilen sich bei normalen Explosionsgeschossen kein versehentliches doppeltes Hauptziel. Die Kontaktmine verwendet dagegen ausdrücklich ihren dokumentierten Kontakt-plus-Explosion-Schaden. Raketen reservieren die Explosion vor Treffer-Callbacks. Die Armbrust trifft jeden Gegner pro Flug nur einmal und entscheidet den Durchschlag anhand ihres eigenen Krit-Wurfs. Salven behalten ihre Angriffskennung; Niederschlagen verwirft vorbereitete E/R-Fähigkeiten und noch nicht abgeschossene Waffenprojektile. Dauerhafte Ringe und Aura werden aktualisiert, ohne weitere Kopien anzulegen. Nur tatsächlich aktive Schadenseffekte prüfen Gegner; rein visuelle Effekte verursachen keine zusätzlichen Treffer.

## Prüfungen und Dateien

- `run_tests.ps1`: elf Prüfsuiten, einschließlich aller Waffenränge, Passivgrenzen, erlaubter Modifikatoren, Krit/Durchschlag, E/R-Ausrichtung, Einschlag und Mehrfachauslösung sowie Augment-Wechselwirkungen. Ein zusätzlicher Lauf lässt alle 21 weiterentwickelten Waffen nacheinander mit echten Spielticks gegen Gegner laufen.
- `tests/fixtures/swarm-14.16-reference.json`: separat gespeicherte Archivfelder zum Vergleich der tatsächlichen Laufzeitwerte.
- `WAFFEN-JINX-LEVELWERTE.csv`: alle 126 Waffenstufen mit zusätzlichen Reichweiten, Geschwindigkeiten, Breiten und Deltas, ohne Spielerboni.
- `output/swarm-ui/jinx-rockets-ingame.png`: echte Rendereraufnahme mit eingefrorenen Effektbeispielen auf der Karte; keine Darstellung eines normalen Kampfmoments.
- Abschließendes Testergebnis des aktuellen Durchgangs und Paketprüfung stehen in `JINX-ITEMS-PRUEFUNG.txt`.

Die ausführbaren Spieldaten werden mit `build_test.ps1` neu erstellt. Bereits laufende Spiele müssen neu gestartet werden.
''']
(OUT/'WAFFEN-JINX-ANALYSE.md').write_text('\n'.join(lines),encoding='utf-8')
with (OUT/'WAFFEN-JINX-LEVELWERTE.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=rows[0].keys(),delimiter=';')
    writer.writeheader(); writer.writerows(rows)
print(f'Report: {len(names)} weapons, {len(rows)} ranks, 12 passives, {len(data["augments"])} augments.')
