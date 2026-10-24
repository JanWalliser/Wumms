extends Node

# CharacterRegistry - Registry of all 9 playable characters with Swarm 2024 stats, abilities, and funny lore

class_name CharacterRegistry

static var characters: Dictionary = {
	"jankz": {
		"id": "jankz",
		"ref_name": "Jinx",
		"display_name": "Jankz",
		"title": "Die Chaos-Kanone",
		"description": "Schießt schneller als ihr Verstand denken kann. Kills versetzen sie in helle Ekstase!",
		"starter_weapon": "weapon_meow_meow",
		"base_stats": {
			"max_health": 450.0,
			"armor": 0.0,
			"movement_speed": 360.0,
			"health_regen": 4.0,
			"crit_chance": 0.05,
			"ability_haste": 0.0,
			"pickup_radius": 100.0
		},
		"passive": {
			"name": "Völlig verjankzt!",
			"ref_name": "Get Excited!",
			"desc": "Nach 70 normalen Kills oder einem Elite-Kill: 8 Sekunden +150 Fähigkeitstempo und abklingendes Lauftempo (bis +35%)."
		},
		"ability_e": {
			"name": "Fischgräten-Festival",
			"ref_name": "Fishbones!",
			"cooldown": 10.0,
			"desc": "Feuert sechs explosive Fisch-Raketen in versetzten Paaren: links, Mitte, rechts zum Mauszeiger.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Super-Mega-Todesgurke",
			"ref_name": "Super Mega Death Rocket!",
			"cooldown": 35.0,
			"desc": "Schießt eine bildschirmfüllende Mega-Gurke ab, die beim ersten großen Ziel mit gigantischem Knall explodiert.",
			"unlock_level": 6
		}
	},
	"seraföhn": {
		"id": "seraföhn",
		"ref_name": "Seraphine",
		"display_name": "Sera-Föhn",
		"title": "Die Popstar-Sirene",
		"description": "Echot Projektile, verteilt Schilde und bringt mit ihren Furznoten alle zum Schweben.",
		"starter_weapon": "weapon_sound_wave",
		"base_stats": {
			"max_health": 420.0,
			"armor": 0.0,
			"movement_speed": 350.0,
			"health_regen": 5.0,
			"crit_chance": 0.05,
			"ability_haste": 5.0,
			"pickup_radius": 110.0
		},
		"passive": {
			"name": "Bühnen-Ballerina",
			"ref_name": "Stage Presence",
			"desc": "Fähigkeitseinsätze erzeugen Musiknoten, die Angriffe duplizieren und Projektile verdoppeln."
		},
		"ability_e": {
			"name": "Surround-Schnitzel",
			"ref_name": "Surround Sound",
			"cooldown": 12.0,
			"desc": "Erzeugt eine Schallwelle, die dem gesamten Team 120 Schild verleiht und Gegner verlangsamt.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Die perfekte Furznote",
			"ref_name": "The Perfect Note",
			"cooldown": 40.0,
			"desc": "Entfesselt eine gewaltige Schallwelle, die Gegner betäubt und massiven Schaden zufügt.",
			"unlock_level": 6
		}
	},
	"löwina": {
		"id": "löwina",
		"ref_name": "Leona",
		"display_name": "Löwina",
		"title": "Das wandelnde Schild-Ufo",
		"description": "Extrem zäher Tank mit Schildstoß, Rüstungsskalierung und blendendem Sonnenlicht.",
		"starter_weapon": "weapon_shield_slam",
		"base_stats": {
			"max_health": 600.0,
			"armor": 20.0,
			"movement_speed": 340.0,
			"health_regen": 7.0,
			"crit_chance": 0.05,
			"ability_haste": 0.0,
			"pickup_radius": 100.0
		},
		"passive": {
			"name": "Sonnenbrand-Sympathie",
			"ref_name": "Sunlight",
			"desc": "Treffer markieren Urviecher mit Sonnenbrand. Nachfolgender Schaden löst Solar-Explosionen aus."
		},
		"ability_e": {
			"name": "Eierklipse",
			"ref_name": "Eclipse",
			"cooldown": 11.0,
			"desc": "Erhöht Rüstung um +35 für 3s und explodiert anschließend in einem Sonnensturm mit Betäubung.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Sonnenexplodierter Käsekuchen",
			"ref_name": "Solar Flare",
			"cooldown": 38.0,
			"desc": "Ruft einen gigantischen Sonnenstrahl herab, der den Mittelpunkt betäubt und die Umgebung verbrennt.",
			"unlock_level": 6
		}
	},
	"illaupsi": {
		"id": "illaupsi",
		"ref_name": "Illaoi",
		"display_name": "Illa-Upsi",
		"title": "Die Tentakel-Prinzessin",
		"description": "Ruft gewaltige Ur-Tentakel herbei, die das Kampffeld zerlegen und sie kontinuierlich heilen.",
		"starter_weapon": "weapon_tentacle_slam",
		"base_stats": {
			"max_health": 580.0,
			"armor": 10.0,
			"movement_speed": 345.0,
			"health_regen": 6.0,
			"crit_chance": 0.05,
			"ability_haste": 0.0,
			"pickup_radius": 105.0
		},
		"passive": {
			"name": "Urzeit-Unkaputtbarkeit",
			"ref_name": "Primordian Resilience",
			"desc": "In der Nähe aktiver Tentakel regeneriert Illa-Upsi 8 HP pro Sekunde zusätzlich."
		},
		"ability_e": {
			"name": "Tentakel-Taschenschlag",
			"ref_name": "Tentacle Smash",
			"cooldown": 9.0,
			"desc": "Schlägt mit einem riesigen Tentakel vor sich auf den Boden und zertrümmert feindliche Linien.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Glaubens-Gummisprung",
			"ref_name": "Leap of Faith",
			"cooldown": 42.0,
			"desc": "Springt in die Luft und beschwört beim Aufprall 4 riesige Wackel-Tentakel, die ringsum einschlagen.",
			"unlock_level": 6
		}
	},
	"brioche": {
		"id": "brioche",
		"ref_name": "Briar",
		"display_name": "Brioche",
		"title": "Das bissige Berserker-Gebäck",
		"description": "Besitzt 0 Grundregeneration, saugt aber Leben aus blutenden Gegnern und stürzt sich im Fressflash ins Getümmel.",
		"starter_weapon": "weapon_pillory_swipe",
		"base_stats": {
			"max_health": 500.0,
			"armor": 5.0,
			"movement_speed": 365.0,
			"health_regen": 0.0,
			"crit_chance": 0.05,
			"ability_haste": 0.0,
			"pickup_radius": 100.0
		},
		"passive": {
			"name": "Brotzeit-Überlebensinstinkt",
			"ref_name": "Survival Instincts",
			"desc": "Blutungs-Effekte heilen Brioche pro Treffer um 2% ihres maximalen Lebens."
		},
		"ability_e": {
			"name": "Fisch-Fressflash & Baguette-Brüller",
			"ref_name": "Bloodlust Frenzy / Survival Scream",
			"cooldown": 12.0,
			"desc": "Stürmt wie von Sinnen auf Gegner zu (+40% Tempo, +30% Schaden) und beendet den Rausch mit Schockwellen-Brüllen.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Brioche-Bombardement",
			"ref_name": "Dive Bomb",
			"cooldown": 45.0,
			"desc": "Katapultiert sich quer über die Arena und schlägt wie ein Meteorit ein.",
			"unlock_level": 6
		}
	},
	"yasüff": {
		"id": "yasüff",
		"ref_name": "Yasuo",
		"display_name": "Yasüff",
		"title": "Der Windel-Wanderer",
		"description": "Verdoppelt Krit-Boni, gleitet durch Gegner und blockiert feindliche Geschosse mit seiner Windel-Wand.",
		"starter_weapon": "weapon_steel_tempest",
		"base_stats": {
			"max_health": 480.0,
			"armor": 5.0,
			"movement_speed": 355.0,
			"health_regen": 5.0,
			"crit_chance": 0.10,
			"ability_haste": 0.0,
			"pickup_radius": 100.0
		},
		"passive": {
			"name": "Weg des Wanderwürstchens",
			"ref_name": "Way of the Wanderer",
			"desc": "Kritische Trefferchance wird verdoppelt. Bewegung lädt einen Windschild bis zu 150 HP auf."
		},
		"ability_e": {
			"name": "Wischmopp-Klinge",
			"ref_name": "Sweeping Blade",
			"cooldown": 6.0,
			"desc": "Wirbelt durch Gegnerreihen, fügt Schaden zu und setzt die Position neu an.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Windel-Wand",
			"ref_name": "Wind Wall",
			"cooldown": 30.0,
			"desc": "Errichtet eine 5s anhaltende Barriere, die alle feindlichen Geschosse komplett absorbiert.",
			"unlock_level": 6
		}
	},
	"rübenrambo": {
		"id": "rübenrambo",
		"ref_name": "Riven",
		"display_name": "Rüben-Rambo",
		"title": "Die Kampfkarotte",
		"description": "Extrem mobil, baut Schilde durch Sprünge auf und zertrennt Urviecher mit ihrer Riesen-Rübenklinge.",
		"starter_weapon": "weapon_bunny_hop",
		"base_stats": {
			"max_health": 520.0,
			"armor": 10.0,
			"movement_speed": 360.0,
			"health_regen": 5.5,
			"crit_chance": 0.05,
			"ability_haste": 0.0,
			"pickup_radius": 100.0
		},
		"passive": {
			"name": "Rübenklinge",
			"ref_name": "Runic Blade",
			"desc": "Fähigkeitseinsätze laden 3 Ladungen auf, die nächste Angriffe um +40% verstärken."
		},
		"ability_e": {
			"name": "Heldenmumpitz",
			"ref_name": "Valor",
			"cooldown": 7.0,
			"desc": "Hechtet nach vorne und erhält einen Sofortschild in Höhe von 150 HP für 2,5 Sekunden.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Klinge des Exzesses",
			"ref_name": "Blade of the Exile",
			"cooldown": 35.0,
			"desc": "Entfesselt die Riesenrübe (+25% Schaden) und schleudert eine Windstoß-Schneide fächerförmig ab.",
			"unlock_level": 6
		}
	},
	"auarora": {
		"id": "auarora",
		"ref_name": "Aurora",
		"display_name": "Aua-Rora",
		"title": "Die Geister-Flitzpiepe",
		"description": "Taucht durch den Duschvorhang in die Geisterwelt ab und sperrt Feinde zwischen zwei Waffeln ein.",
		"starter_weapon": "weapon_guiding_hex",
		"base_stats": {
			"max_health": 460.0,
			"armor": 5.0,
			"movement_speed": 350.0,
			"health_regen": 5.0,
			"crit_chance": 0.05,
			"ability_haste": 0.0,
			"pickup_radius": 115.0
		},
		"passive": {
			"name": "Austreibung der Gummigeister",
			"ref_name": "Spiritual Abjuration",
			"desc": "Drei Treffer auf dasselbe Urviech entreißen einen Gummigeist, der 5% Max-HP-Schaden zufügt und heilt."
		},
		"ability_e": {
			"name": "Durch den Duschvorhang",
			"ref_name": "Across the Veil",
			"cooldown": 9.0,
			"desc": "Hüpft rückwärts, wird 2 Sekunden lang unantastbar und erhält +50% Lauftempo.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Zwischen zwei Waffeln",
			"ref_name": "Between Realms",
			"cooldown": 40.0,
			"desc": "Erschafft eine gigantische Geisterzone; wer den Rand berührt, wird auf die Gegenseite teleportiert.",
			"unlock_level": 6
		}
	},
	"xayaya": {
		"id": "xayaya",
		"ref_name": "Xayah",
		"display_name": "Xayaya",
		"title": "Die Feder-Furie",
		"description": "Verschießt Federklingen, lässt Federn fallen und ruft sie mit verheerender Durchdringung zurück.",
		"starter_weapon": "weapon_winged_dagger",
		"base_stats": {
			"max_health": 440.0,
			"armor": 0.0,
			"movement_speed": 355.0,
			"health_regen": 4.5,
			"crit_chance": 0.10,
			"ability_haste": 0.0,
			"pickup_radius": 100.0
		},
		"passive": {
			"name": "Fledermaus-Freidrehmodus",
			"ref_name": "Battle Bat Enrage",
			"desc": "Angriffe hinterlassen Federn auf dem Schlachtfeld, die für Fähigkeiten genutzt werden."
		},
		"ability_e": {
			"name": "Feder-Fang-Furie",
			"ref_name": "Sweeping Blade / Bladecaller",
			"cooldown": 8.0,
			"desc": "Ruft alle liegenden Federn blitzartig zurück; durchbohrte Gegner erleiden Schaden und Wurzel-Stun.",
			"unlock_level": 3
		},
		"ability_r": {
			"name": "Besteck-Bombardement",
			"ref_name": "Bladestorm",
			"cooldown": 38.0,
			"desc": "Springt für 1,5s unangreifbar in die Luft und feuert einen Fächer aus 8 riesigen Federn ab.",
			"unlock_level": 6
		}
	}
}

static func get_character_data(char_id: String) -> Dictionary:
	var actual_id := char_id if characters.has(char_id) else "jankz"
	var result: Dictionary = characters[actual_id].duplicate(true)
	result["base_stats"] = preload("res://scripts/core/swarm_balance.gd").apply("characters", actual_id, result["base_stats"])
	# Ability overrides belong to the character kit, never inside the stat bag.
	for key in ["ability_e","ability_r","passive"]:
		if result["base_stats"].has(key):
			result[key].merge(result["base_stats"][key],true)
			result["base_stats"].erase(key)
	return result

static func get_all_character_ids() -> Array[String]:
	var keys: Array[String] = []
	for k in characters.keys():
		keys.append(k)
	return keys
