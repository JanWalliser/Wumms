extends Node

# ShopUpgradeRegistry - All 15 permanent Lobby Shop upgrades, costs, caps, and requirements

class_name ShopUpgradeRegistry

static var upgrades: Dictionary = {
	"damage": {
		"id": "damage",
		"ref_name": "Schaden",
		"display_name": "Schmerzschraube",
		"description": "+10% Schaden pro Stufe auf alle Angriffe.",
		"max_level": 8,
		"bonus_desc": "+10% Schaden",
		"costs": [200, 400, 800, 1500, 2500, 4000, 6000, 9000]
	},
	"armor": {
		"id": "armor",
		"ref_name": "Rüstung",
		"display_name": "Panzer-Paprika",
		"description": "+5 Rüstung pro Stufe zur Schadensminderung.",
		"max_level": 5,
		"bonus_desc": "+5 Rüstung",
		"costs": [200, 500, 1000, 2000, 4000]
	},
	"max_health": {
		"id": "max_health",
		"ref_name": "Maximales Leben",
		"display_name": "Überlebens-Ufo",
		"description": "+10% maximales Leben pro Stufe.",
		"max_level": 5,
		"bonus_desc": "+10% Max HP",
		"costs": [250, 600, 1200, 2400, 4500]
	},
	"health_regen": {
		"id": "health_regen",
		"ref_name": "Lebensregeneration",
		"display_name": "Heil-Hefe",
		"description": "+3 Lebensregeneration pro Sekunde je Stufe.",
		"max_level": 5,
		"bonus_desc": "+3 HP/s",
		"costs": [200, 500, 1000, 2000, 4000]
	},
	"movement_speed": {
		"id": "movement_speed",
		"ref_name": "Lauftempo",
		"display_name": "Flotte Flossen",
		"description": "+5% Lauftempo pro Stufe.",
		"max_level": 4,
		"bonus_desc": "+5% Tempo",
		"costs": [300, 800, 1800, 3500]
	},
	"pickup_radius": {
		"id": "pickup_radius",
		"ref_name": "Aufsammelradius",
		"display_name": "Sammelschnorchel",
		"description": "+25% Aufsammelradius pro Stufe.",
		"max_level": 3,
		"bonus_desc": "+25% Radius",
		"costs": [300, 1000, 2500]
	},
	"area_size": {
		"id": "area_size",
		"ref_name": "Flächengröße",
		"display_name": "Flächen-Fladen",
		"description": "+5% Flächengröße pro Stufe.",
		"max_level": 4,
		"bonus_desc": "+5% Fläche",
		"costs": [300, 800, 1800, 3500]
	},
	"duration": {
		"id": "duration",
		"ref_name": "Dauer",
		"display_name": "Dauer-Döner",
		"description": "+5% Wirkungsdauer pro Stufe.",
		"max_level": 4,
		"bonus_desc": "+5% Dauer",
		"costs": [300, 800, 1800, 3500]
	},
	"crit_chance": {
		"id": "crit_chance",
		"ref_name": "Kritische Trefferchance",
		"display_name": "Krit-Krümel",
		"description": "+5% Kritische Trefferchance pro Stufe.",
		"max_level": 4,
		"bonus_desc": "+5% Krit",
		"costs": [400, 1000, 2200, 4000]
	},
	"ability_haste": {
		"id": "ability_haste",
		"ref_name": "Fähigkeitstempo",
		"display_name": "Spam-Spindel",
		"description": "+5 Fähigkeitstempo pro Stufe.",
		"max_level": 5,
		"bonus_desc": "+5 Tempo",
		"costs": [250, 600, 1200, 2400, 4500]
	},
	"exp_gain": {
		"id": "exp_gain",
		"ref_name": "Erfahrung",
		"display_name": "Hirnschmalz-Hantel",
		"description": "+5% Erfahrungsgewinn pro Stufe.",
		"max_level": 5,
		"bonus_desc": "+5% EXP",
		"costs": [300, 750, 1500, 3000, 5000]
	},
	"projectile_count": {
		"id": "projectile_count",
		"ref_name": "Projektilanzahl",
		"display_name": "Kugel-Kopierer",
		"description": "+1 zusätzliches Projektil pro Stufe.",
		"max_level": 2,
		"bonus_desc": "+1 Kugel",
		"costs": [2500, 6000]
	},
	"gold_multiplier": {
		"id": "gold_multiplier",
		"ref_name": "Goldmultiplikator",
		"display_name": "Dublonen-Doppler",
		"description": "+15% verdiente Dönerdublonen pro Stufe.",
		"max_level": 3,
		"bonus_desc": "+15% Gold",
		"costs": [500, 1500, 3500]
	},
	"boon_duration": {
		"id": "boon_duration",
		"ref_name": "Dauer des Kampfhäschen-Bonus",
		"display_name": "Bonus-Befristungsbruch",
		"description": "+25% längere Dauer aller Miss-Fortune-Boni.",
		"max_level": 2,
		"bonus_desc": "+25% Dauer",
		"costs": [1000, 3000]
	},
	"anima_power": {
		"id": "anima_power",
		"ref_name": "Anima Power",
		"display_name": "Knallkraft 100",
		"description": "+1% Schaden, +1% Lauftempo, +1 Fähigkeitstempo, +1% Sammelradius pro Stufe.",
		"max_level": 100,
		"bonus_desc": "+1% Stats",
		"costs": [], # Special 3000 flat cost per rank
		"requires_quest": "warehouse_extreme_clear"
	}
}

static func get_cost(upgrade_id: String, current_level: int) -> int:
	if not upgrades.has(upgrade_id):
		return 999999
	var data: Dictionary = upgrades[upgrade_id]
	if current_level >= data["max_level"]:
		return -1 # Maxed out

	if upgrade_id == "anima_power":
		return 3000

	var costs_array: Array = data.get("costs", [])
	if current_level < costs_array.size():
		return costs_array[current_level]
	return 5000

static func is_unlocked_for_profile(upgrade_id: String, profile: Dictionary) -> bool:
	if upgrade_id in ["exp_gain", "projectile_count"]:
		return profile.get("unlocked_shop", []).has(upgrade_id)
	if upgrade_id == "anima_power":
		var completed: Array = profile.get("completed_quests", [])
		return completed.has("warehouse_extreme_clear") or completed.has("aatrox_hard") or profile.get("features",[]).has("extreme_and_anima")
	return true
