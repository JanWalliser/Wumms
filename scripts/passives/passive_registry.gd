extends Node

# PassiveRegistry - All 12 in-run passives with 5 upgrade tiers and max-out bonus options

class_name PassiveRegistry

static var passives: Dictionary = {
	"ability_haste": {
		"id": "ability_haste",
		"ref_name": "Fähigkeitstempo",
		"display_name": "Spam-Geschwindigkeit",
		"description": "Verringert Abklingzeiten spürbar durch höheres Fähigkeitstempo.",
		"stat_type": "ability_haste",
		"value_per_level": 10.0,
		"max_level": 5
	},
	"area_size": {
		"id": "area_size",
		"ref_name": "Flächengröße",
		"display_name": "Flächen-Fettleibigkeit",
		"description": "Vergrößert den Wirkungsbereich von Explosionen, Auren und Schockwellen.",
		"stat_type": "area_size",
		"value_per_level": 0.11,
		"max_level": 5
	},
	"armor": {
		"id": "armor",
		"ref_name": "Rüstung",
		"display_name": "Blechbauch",
		"description": "Reduziert erlittenen physischen Schaden und Schläge.",
		"stat_type": "armor",
		"value_per_level": 8.0,
		"max_level": 5
	},
	"crit_chance": {
		"id": "crit_chance",
		"ref_name": "Kritische Trefferchance",
		"display_name": "Glückstreffer-Gurkenglas",
		"description": "Erhöht die Wahrscheinlichkeit für verheerende kritische Treffer.",
		"stat_type": "crit_chance",
		"value_per_level": 0.08,
		"max_level": 5
	},
	"damage": {
		"id": "damage",
		"ref_name": "Schaden",
		"display_name": "Aua-Faktor",
		"description": "Erhöht den durch alle Waffen und Fähigkeiten verursachten Gesamtschaden.",
		"stat_type": "damage",
		"value_per_level": 0.10,
		"max_level": 5
	},
	"duration": {
		"id": "duration",
		"ref_name": "Dauer",
		"display_name": "Nicht-mehr-aufhören",
		"description": "Verlängert die Dauer von Schilden, Pfützen, Minen und Buffs.",
		"stat_type": "duration",
		"value_per_level": 0.12,
		"max_level": 5
	},
	"exp_gain": {
		"id": "exp_gain",
		"ref_name": "Erfahrung",
		"display_name": "Gehirn-Gummibärchen",
		"description": "Gewährt zusätzliche Schlauheit und beschleunigt Team-Level-ups.",
		"stat_type": "exp_gain",
		"value_per_level": 0.10,
		"max_level": 5
	},
	"health_regen": {
		"id": "health_regen",
		"ref_name": "Lebensregeneration",
		"display_name": "Selbstheil-Schnitzel",
		"description": "Heilt kontinuierlich Lebenspunkte im Sekundentakt.",
		"stat_type": "health_regen",
		"value_per_level": 4.0,
		"max_level": 5
	},
	"max_health": {
		"id": "max_health",
		"ref_name": "Maximales Leben",
		"display_name": "XXL-Pommesvorrat",
		"description": "Erhöht die maximalen Lebenspunkte drastisch.",
		"stat_type": "max_health",
		"value_per_level": 150.0,
		"max_level": 5
	},
	"movement_speed": {
		"id": "movement_speed",
		"ref_name": "Lauftempo",
		"display_name": "Turbo-Treter",
		"description": "Lässt dich flinker über das Kampffeld flitzen.",
		"stat_type": "movement_speed",
		"value_per_level": 0.09,
		"max_level": 5
	},
	"pickup_radius": {
		"id": "pickup_radius",
		"ref_name": "Aufsammelradius",
		"display_name": "Staubsauger-Schnauze",
		"description": "Zieht EXP-Linsen und Golddublonen aus größerer Entfernung magnetisch an.",
		"stat_type": "pickup_radius",
		"value_per_level": 0.35,
		"max_level": 5
	},
	"projectile_count": {
		"id": "projectile_count",
		"ref_name": "Projektilanzahl",
		"display_name": "Kugel-Klonerei",
		"description": "Feuert zusätzliche Geschosse bei allen mehrschussfähigen Waffen ab.",
		"stat_type": "projectile_count",
		"value_per_level": 1.0,
		"max_level": 5
	}
}

static func get_passive_data(passive_id: String) -> Dictionary:
	return passives.get(passive_id, {})

static func get_bonus(passive_id: String, level: int) -> float:
	var data := get_passive_data(passive_id)
	if data.is_empty(): return 0
	var rank := clampi(level,0,int(data.get("max_level",5)))
	var reference: Dictionary = preload("res://scripts/core/swarm_balance.gd").data().get("passives",{}).get(passive_id,{})
	if reference.has("levels"): return float(reference["levels"][rank])
	if passive_id=="projectile_count": return float([0,1,1,2,2,3][rank])
	return float(data.get("value_per_level",0))*rank

static func get_all_passive_ids() -> Array[String]:
	var keys: Array[String] = []
	for k in passives.keys():
		keys.append(k)
	return keys
