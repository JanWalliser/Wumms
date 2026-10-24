extends Node

# FortuneBonusRegistry - All 9 temporary power-up variants from Kommandantin Fortuna-Fritte (Miss Fortune Boons)

class_name FortuneBonusRegistry

static var bonuses: Dictionary = {
	"bonus_kart": {
		"id": "bonus_kart",
		"ref_name": "Anima Super Car",
		"display_name": "Knall-Kartoffel-Kart",
		"description": "Steige in ein rasendes Rennkart! +100% Lauftempo, Unverwundbarkeit und Überfahr-Rammschaden.",
		"duration": 15.0
	},
	"bonus_gun": {
		"id": "bonus_gun",
		"ref_name": "Battle Feline Gun Improver",
		"display_name": "Katzen-Kaliber-Kur",
		"description": "Erhöht die Feuerrate aller Waffen um 60% und verleiht +3 Extrageschosse.",
		"duration": 15.0
	},
	"bonus_cruise": {
		"id": "bonus_cruise",
		"ref_name": "Cruise Control",
		"display_name": "Autopilot-Achterbahn",
		"description": "Schaltet automatischen Ausweich-Turbo ein; Waffen schießen in alle Richtungen.",
		"duration": 12.0
	},
	"bonus_fired_up": {
		"id": "bonus_fired_up",
		"ref_name": "Fired Up",
		"display_name": "Feuriger Furzmodus",
		"description": "Hinterlässt eine gigantische Flammenspur, die Urviecher in Sekunden grillt.",
		"duration": 15.0
	},
	"bonus_health_back": {
		"id": "bonus_health_back",
		"ref_name": "Health Back Healthpack",
		"display_name": "Heil-Heimzahlung",
		"description": "Heilt sofort alle Spieler um 100% und spendiert einen 300-HP-Schutzschild.",
		"duration": 20.0
	},
	"bonus_pickpocketing": {
		"id": "bonus_pickpocketing",
		"ref_name": "Primordian Pickpocketing",
		"display_name": "Urzeit-Urlaubskasse",
		"description": "Jeder Treffer auf ein Urviech schüttelt glänzende Dönerdublonen heraus.",
		"duration": 15.0
	},
	"bonus_squad_shield": {
		"id": "bonus_squad_shield",
		"ref_name": "Squad Shield",
		"display_name": "Team-Tupperdeckel",
		"description": "Spannt einen unzerstörbaren Tupperdeckel-Schild über das gesamte Team.",
		"duration": 20.0
	},
	"bonus_stopwaves": {
		"id": "bonus_stopwaves",
		"ref_name": "Stopwaves",
		"display_name": "Stoppwellen-Stullen",
		"description": "Sendet alle 3 Sekunden eine Stoppwelle aus, die alle Urviecher einfriert.",
		"duration": 15.0
	},
	"bonus_rapid_fire": {
		"id": "bonus_rapid_fire",
		"ref_name": "Ultra Rapid Fire-r",
		"display_name": "Turbogeballer Ultra-Ungesund",
		"description": "-80% Abklingzeiten auf alle Waffen und Fähigkeiten. Absolutes Spam-Gewitter!",
		"duration": 12.0
	}
}

static func get_bonus_data(bonus_id: String) -> Dictionary:
	return bonuses.get(bonus_id, {})

static func get_all_bonus_ids() -> Array[String]:
	var keys: Array[String] = []
	for k in bonuses.keys():
		keys.append(k)
	return keys
