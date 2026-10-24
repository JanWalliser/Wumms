# WUMMS – Asset Replacement Guide

Alle visuellen und akustischen Platzhalter in WUMMS sind über zentrale Registries (`AssetRegistry` und `AudioManager`) modular entkoppelt. Du kannst alle Placeholder durch eigene 2D-Sprites, Sprite-Sheets oder Audio-Dateien ersetzen, **ohne eine einzige Zeile GDScript verändern zu müssen**!

---

## 🎨 1. Charaktere ersetzen
Platziere deine 2D-PNGs (empfohlene Auflösung: 64×64 oder 128×128 Pixel, zentriert) in das Verzeichnis:
`res://assets/characters/`

| Dateiname | Zugeordneter Charakter |
|---|---|
| `jankz.png` | Jankz |
| `seraföhn.png` | Sera-Föhn |
| `löwina.png` | Löwina |
| `illaupsi.png` | Illa-Upsi |
| `brioche.png` | Brioche |
| `yasüff.png` | Yasüff |
| `rübenrambo.png` | Rüben-Rambo |
| `auarora.png` | Aua-Rora |
| `xayaya.png` | Xayaya |

Wenn eine Datei existiert, lädt `AssetRegistry` automatisch das PNG. Fehlt die Datei, greift der prozedurale Retro-Cartoon-Placeholder als transparenter Fallback.

---

## 👾 2. Gegner & Bosse ersetzen
Verzeichnis: `res://assets/enemies/`

| Dateiname | Gegner / Boss |
|---|---|
| `standard_grunt.png` | Standard-Gurkengang |
| `fast_runner.png` | Schneller Nahkampfgegner |
| `heavy_tank.png` | Schwer gepanzerter Gegner |
| `ranged_spitter.png` | Fernkampfangreifer |
| `kamikaze_exploder.png` | Explodierender Gegner |
| `aoe_bruiser.png` | Gegner mit Flächenangriffen |
| `support_buffer.png` | Unterstützungs-Urviech |
| `elite_variant.png` | Premium-Pöbel |
| `mini_boss.png` | Halbstarker Hauptgegner |
| `boss_reksai.png` | Urzeit-Rexi (Karte 1) |
| `boss_briar.png` | Ur-Brioche (Karte 2) |
| `boss_belveth.png` | Bella-Viech Prime (Karte 3) |
| `boss_aatrox.png` | Aua-Trox, der Endgegner (Karte 4) |

---

## 💎 3. Sammelobjekte & Pickups ersetzen
Verzeichnis: `res://assets/pickups/`

| Dateiname | Pickup |
|---|---|
| `exp_orb.png` | Schlauheits-Schokolinse (Erfahrung) |
| `gold.png` | Dönerdublonen |
| `health_pack.png` | Sanitäter-Semmel |
| `access_card.png` | Zutritts-Zwieback |
| `vacuum.png` | Super-Staubsauger-Saugnapf |
| `bomb.png` | Bumm-Birne |

---

## 🔊 4. Audio & Soundeffekte ersetzen
Verzeichnis: `res://assets/audio/` (.wav-Format)

| Dateiname | Trigger |
|---|---|
| `shoot.wav` | Schuss abfeuern |
| `hit.wav` | Treffer erhalten |
| `crit.wav` | Kritischer Treffer |
| `explosion.wav` | Explosion / Mine / Bombe |
| `coin.wav` | Gold / EXP aufheben |
| `heal.wav` | Heilung |
| `level_up.wav` | Team-Level-up Fanfare |
| `evolve.wav` | Waffen-Evolution Fanfare |
| `boss_spawn.wav` | Boss-Warnung |
| `death.wav` | Spieler geht zu Boden |
| `revive.wav` | Spieler wiederbelebt |
| `card.wav` | Zugangskarte eingesammelt |
