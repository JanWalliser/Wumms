extends Node

# EnemyRegistry - Stats and archetypes for all standard enemies, elites, minibosses and map bosses

class_name EnemyRegistry

static var enemies: Dictionary = {
	"standard_grunt": {
		"id": "standard_grunt",
		"display_name": "Standard-Gurkengang",
		"max_health": 120.0,
		"armor": 0.0,
		"speed": 220.0,
		"damage": 15.0,
		"exp_drop": 3,
		"gold_drop": 2,
		"is_elite": false,
		"is_boss": false
	},
	"fast_runner": {
		"id": "fast_runner",
		"display_name": "Schneller Nahkampfgegner",
		"max_health": 80.0,
		"armor": 0.0,
		"speed": 330.0,
		"damage": 20.0,
		"exp_drop": 4,
		"gold_drop": 3,
		"is_elite": false,
		"is_boss": false
	},
	"heavy_tank": {
		"id": "heavy_tank",
		"display_name": "Schwer gepanzerter Gegner",
		"max_health": 450.0,
		"armor": 25.0,
		"speed": 160.0,
		"damage": 35.0,
		"exp_drop": 10,
		"gold_drop": 5,
		"is_elite": false,
		"is_boss": false
	},
	"ranged_spitter": {
		"id": "ranged_spitter",
		"display_name": "Fernkampfangreifer",
		"max_health": 100.0,
		"armor": 0.0,
		"speed": 200.0,
		"damage": 25.0,
		"exp_drop": 5,
		"gold_drop": 3,
		"is_elite": false,
		"is_boss": false
	},
	"kamikaze_exploder": {
		"id": "kamikaze_exploder",
		"display_name": "Explodierender Gegner",
		"max_health": 90.0,
		"armor": 0.0,
		"speed": 310.0,
		"damage": 80.0,
		"exp_drop": 6,
		"gold_drop": 4,
		"is_elite": false,
		"is_boss": false
	},
	"aoe_bruiser": {
		"id": "aoe_bruiser",
		"display_name": "Gegner mit Flächenangriffen",
		"max_health": 600.0,
		"armor": 15.0,
		"speed": 180.0,
		"damage": 40.0,
		"exp_drop": 15,
		"gold_drop": 8,
		"is_elite": false,
		"is_boss": false
	},
	"support_buffer": {
		"id": "support_buffer",
		"display_name": "Unterstützungs-Urviech",
		"max_health": 200.0,
		"armor": 5.0,
		"speed": 240.0,
		"damage": 12.0,
		"exp_drop": 8,
		"gold_drop": 5,
		"is_elite": false,
		"is_boss": false
	},
	"elite_variant": {
		"id": "elite_variant",
		"display_name": "Premium-Pöbel",
		"max_health": 1800.0,
		"armor": 15.0,
		"speed": 235.0,
		"damage": 50.0,
		"exp_drop": 45,
		"gold_drop": 50,
		"is_elite": true,
		"is_boss": false,
		"drops_access_card": true
	},
	"mini_boss": {
		"id": "mini_boss",
		"display_name": "Halbstarker Hauptgegner",
		"max_health": 5500.0,
		"armor": 20.0,
		"speed": 225.0,
		"damage": 75.0,
		"exp_drop": 100,
		"gold_drop": 120,
		"is_elite": true,
		"is_boss": false,
		"drops_access_card": true
	},
	"boss_reksai": {
		"id": "boss_reksai",
		"display_name": "Urzeit-Rexi",
		"max_health": 25000.0,
		"armor": 25.0,
		"speed": 250.0,
		"damage": 90.0,
		"exp_drop": 300,
		"gold_drop": 500,
		"is_elite": true,
		"is_boss": true
	},
	"boss_briar": {
		"id": "boss_briar",
		"display_name": "Ur-Brioche",
		"max_health": 32000.0,
		"armor": 20.0,
		"speed": 290.0,
		"damage": 105.0,
		"exp_drop": 400,
		"gold_drop": 600,
		"is_elite": true,
		"is_boss": true
	},
	"boss_belveth": {
		"id": "boss_belveth",
		"display_name": "Bella-Viech Prime",
		"max_health": 40000.0,
		"armor": 30.0,
		"speed": 270.0,
		"damage": 115.0,
		"exp_drop": 500,
		"gold_drop": 800,
		"is_elite": true,
		"is_boss": true
	},
	"boss_aatrox": {
		"id": "boss_aatrox",
		"display_name": "Aua-Trox, der Endgegner",
		"max_health": 55000.0,
		"armor": 35.0,
		"speed": 260.0,
		"damage": 140.0,
		"exp_drop": 800,
		"gold_drop": 1500,
		"is_elite": true,
		"is_boss": true
	}
}

static func get_enemy_data(enemy_id: String) -> Dictionary:
	var actual_id := enemy_id if enemies.has(enemy_id) else "standard_grunt"
	return preload("res://scripts/core/swarm_balance.gd").apply("enemies", actual_id, enemies[actual_id])
