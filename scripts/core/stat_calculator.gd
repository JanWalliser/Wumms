extends Node

# StatCalculator - Centralized stat computation according to Swarm 2024 specifications
# Prevents accidental compounding, distinguishes flat and percentage bonuses,
# and supports character base stats, shop upgrades, run passives, augments, and temporary buffs.

const BASE_MOVEMENT_SPEED: float = 350.0
const BASE_CRIT_CHANCE: float = 0.05
const BASE_CRIT_DAMAGE: float = 2.0
const BASE_PICKUP_RADIUS: float = 100.0
const PLAYER_COLLISION_RADIUS: float = 65.0
const MAX_LEVEL: int = 99

# Calculates effective cooldown using Swarm Ability Haste formula:
# effective_cooldown = base_cooldown / (1.0 + ability_haste / 100.0)
static func calculate_effective_cooldown(base_cooldown: float, ability_haste: float) -> float:
	var haste_clamped := maxf(-90.0, ability_haste) # Prevent divide-by-zero or negative cooldowns
	return maxf(0.05, base_cooldown / (1.0 + haste_clamped / 100.0))

# Armor damage mitigation:
# damage_taken = raw_damage * (100.0 / (100.0 + max(0.0, armor)))
static func calculate_armor_mitigation(raw_damage: float, armor: float) -> float:
	if armor >= 0.0:
		return raw_damage * (100.0 / (100.0 + armor))
	else:
		# Negative armor amplifies damage
		return raw_damage * (2.0 - 100.0 / (100.0 - armor))

# Recalculates all derived stats for a player based on their base stats,
# shop upgrades, run passives, augments, and temporary buffs.
static func compute_player_stats(
	base_stats: Dictionary,
	shop_upgrades: Dictionary,
	passives: Dictionary,
	augments: Array,
	temp_buffs: Dictionary
) -> Dictionary:
	var stats: Dictionary = {}

	# 1. Start from base stats
	var base_hp: float = float(base_stats.get("max_health", 500.0))
	var base_armor: float = float(base_stats.get("armor", 0.0))
	var base_regen: float = float(base_stats.get("health_regen", 0.0))
	var base_speed: float = float(base_stats.get("movement_speed", BASE_MOVEMENT_SPEED))
	var base_haste: float = float(base_stats.get("ability_haste", 0.0))
	var base_crit: float = float(base_stats.get("crit_chance", BASE_CRIT_CHANCE))
	var base_crit_dmg: float = float(base_stats.get("crit_damage", BASE_CRIT_DAMAGE))
	var base_area: float = 1.0
	var base_dmg_mult: float = 1.0
	var base_duration: float = 1.0
	var base_pickup: float = float(base_stats.get("pickup_radius", BASE_PICKUP_RADIUS))
	var base_exp: float = 1.0
	var base_gold: float = 1.0
	var bonus_proj: int = 0
	var bonus_shield: float = 0.0
	var knockback_mult: float = 1.0

	# 2. Add Permanent Shop Upgrades
	# Schaden: +10% per rank
	var shop_dmg: float = float(shop_upgrades.get("damage", 0)) * 0.10
	# Rüstung: +5 flat per rank
	var shop_armor: float = float(shop_upgrades.get("armor", 0)) * 5.0
	# Maximales Leben: +10% per rank
	var shop_hp_pct: float = float(shop_upgrades.get("max_health", 0)) * 0.10
	# Lebensregeneration: +3 flat per rank
	var shop_regen: float = float(shop_upgrades.get("health_regen", 0)) * 3.0
	# Lauftempo: +5% per rank
	var shop_speed_pct: float = float(shop_upgrades.get("movement_speed", 0)) * 0.05
	# Aufsammelradius: +25% per rank
	var shop_pickup_pct: float = float(shop_upgrades.get("pickup_radius", 0)) * 0.25
	# Flächengröße: +5% per rank
	var shop_area_pct: float = float(shop_upgrades.get("area_size", 0)) * 0.05
	# Dauer: +5% per rank
	var shop_dur_pct: float = float(shop_upgrades.get("duration", 0)) * 0.05
	# Kritische Trefferchance: +5% points per rank
	var shop_crit: float = float(shop_upgrades.get("crit_chance", 0)) * 0.05
	# Fähigkeitstempo: +5 flat per rank
	var shop_haste: float = float(shop_upgrades.get("ability_haste", 0)) * 5.0
	# Erfahrung: +5% per rank (confirmed 2024 standard 5% per rank)
	var shop_exp_pct: float = float(shop_upgrades.get("exp_gain", 0)) * 0.05
	# Projektilanzahl: +1 flat per rank (max 2)
	var shop_proj: int = int(shop_upgrades.get("projectile_count", 0))
	# Goldmultiplikator: +15% per rank
	var shop_gold_pct: float = float(shop_upgrades.get("gold_multiplier", 0)) * 0.15
	# Anima Power: +1% damage, +1% move speed, +1 ability haste, +1% pickup radius per level
	var anima_lvl: int = int(shop_upgrades.get("anima_power", 0))
	var anima_dmg: float = anima_lvl * 0.01
	var anima_spd: float = anima_lvl * 0.01
	var anima_haste: float = anima_lvl * 1.0
	var anima_pickup: float = anima_lvl * 0.01

	# 3. Add In-Run Passives (levels 1 to 5)
	# Fähigkeitstempo: +10 per level
	var pass_haste: float = PassiveRegistry.get_bonus("ability_haste",int(passives.get("ability_haste",0)))
	# Flächengröße: +11% per level
	var pass_area: float = PassiveRegistry.get_bonus("area_size",int(passives.get("area_size",0)))
	# Rüstung: +8 per level
	var pass_armor: float = PassiveRegistry.get_bonus("armor",int(passives.get("armor",0)))
	# Krit-Chance: +8% points per level
	var pass_crit: float = PassiveRegistry.get_bonus("crit_chance",int(passives.get("crit_chance",0)))
	# Schaden: +10% per level
	var pass_dmg: float = PassiveRegistry.get_bonus("damage",int(passives.get("damage",0)))
	# Dauer: +12% per level
	var pass_dur: float = PassiveRegistry.get_bonus("duration",int(passives.get("duration",0)))
	# Erfahrung: +10% per level
	var pass_exp: float = PassiveRegistry.get_bonus("exp_gain",int(passives.get("exp_gain",0)))
	# Lebensregeneration: +4 per level
	var pass_regen: float = PassiveRegistry.get_bonus("health_regen",int(passives.get("health_regen",0)))
	# Maximales Leben: +150 flat per level
	var pass_hp_flat: float = PassiveRegistry.get_bonus("max_health",int(passives.get("max_health",0)))
	# Lauftempo: +9% per level
	var pass_speed: float = PassiveRegistry.get_bonus("movement_speed",int(passives.get("movement_speed",0)))
	# Aufsammelradius: +35% per level
	var pass_pickup: float = PassiveRegistry.get_bonus("pickup_radius",int(passives.get("pickup_radius",0)))
	# Projektilanzahl: Table: 1->+1, 2->+1, 3->+2, 4->+2, 5->+3 (up to +3 from passive)
	var pass_proj_level: int = clampi(int(passives.get("projectile_count", 0)),0,5)
	var pass_proj: int = int(PassiveRegistry.get_bonus("projectile_count",pass_proj_level))

	# 4. Process Augments
	var aug_dmg_pct: float = 0.0
	var aug_dmg_multiplier: float = 1.0
	var aug_hp_multiplier: float = 1.0
	var aug_hp_pct: float = 0.0
	var aug_hp_flat: float = 0.0
	var aug_armor_flat: float = 0.0
	var aug_speed_pct: float = 0.0
	var aug_speed_multiplier: float = 1.0
	var aug_haste_flat: float = 0.0
	var aug_crit_flat: float = 0.0
	var aug_crit_dmg_flat: float = 0.0
	var aug_proj_flat: int = 0
	var aug_area_pct: float = 0.0
	var aug_dur_pct: float = 0.0
	var aug_pickup_pct: float = 0.0
	var aug_exp_pct: float = 0.0
	var aug_gold_pct: float = 0.0
	var aug_regen_flat: float = 0.0

	for aug in augments:
		var aug_id: String = ""
		if aug is String:
			aug_id = aug
		elif aug is Dictionary:
			aug_id = aug.get("id", "")

		match aug_id:
			"augment_glass_cannon":
				aug_dmg_multiplier *= 1.40
				aug_hp_multiplier *= 0.70
			"augment_spray_and_pray":
				aug_proj_flat += 4
				aug_dmg_multiplier *= 0.65
			"augment_armor_up":
				pass # Stacks are granted on incoming hits.
			"augment_bite_sized":
				aug_hp_multiplier *= 0.80
				aug_speed_multiplier *= 1.20
				aug_haste_flat += 36.0
			"augment_bullet_mania":
				aug_dmg_multiplier *= 0.85
			"augment_heavy_hitter":
				aug_dmg_multiplier *= 1.50
				aug_haste_flat -= 30.0
			"augment_juggernaut":
				aug_armor_flat += 10.0
			"augment_larger_than_life":
				aug_hp_multiplier *= 1.30
				aug_regen_flat += 30.0
				aug_speed_multiplier *= 0.85
			"augment_long_range":
				pass
			"augment_metabolic_overdrive":
				aug_hp_multiplier *= 0.40
			"augment_mission_critical":
				aug_crit_flat += 0.10
			"augment_pick_me_up":
				aug_exp_pct += 0.15
			"augment_point_blank":
				pass
			"augment_regenerative_tissue":
				pass # Granted by health-pack pickups, not at acquisition.
			"augment_ultimate_speed_up":
				pass
			"augment_uptime_upgrade":
				aug_dur_pct += 0.60
			"augment_with_haste":
				pass
			"augment_experienced_fighter":
				pass # Shared team bonus is applied by EXP pickups.
			"augment_death_and_taxes":
				pass
			"augment_card_collector":
				pass
			"augment_cross_country":
				pass
			"augment_ramming_runner":
				aug_speed_multiplier*=1.1
			"augment_gathering_speed":
				aug_speed_multiplier*=0.85

	# 5. Temporary Buffs (Boon / Miss Fortune effects)
	var buff_dmg_pct: float = float(temp_buffs.get("damage_pct", 0.0))
	var buff_speed_pct: float = float(temp_buffs.get("speed_pct", 0.0))
	var buff_haste_flat: float = float(temp_buffs.get("ability_haste", 0.0))
	var buff_proj_flat: int = int(temp_buffs.get("projectile_count", 0))
	var buff_shield_flat: float = float(temp_buffs.get("shield", 0.0))

	# 6. Aggregate Total Modifiers
	# Max Health: (base_hp * (1.0 + sum(hp_percent))) + flat_bonuses
	var total_hp_pct: float = maxf(-0.80, shop_hp_pct + aug_hp_pct)
	var total_hp_flat: float = pass_hp_flat + aug_hp_flat
	stats["max_health"] = maxf(100.0,(base_hp+total_hp_flat)*(1+shop_hp_pct)*aug_hp_multiplier*(1+float(temp_buffs.get("max_health_pct",0))))

	# Armor: base + flat bonuses
	stats["armor"] = maxf(-50.0, base_armor + shop_armor + pass_armor + aug_armor_flat + float(temp_buffs.get("armor",0)))

	# Health Regen: base + flat bonuses
	stats["health_regen"] = maxf(0.0, base_regen + shop_regen + pass_regen + aug_regen_flat+float(temp_buffs.get("health_regen",0)))

	# Movement Speed: base_speed * (1.0 + sum(speed_percent))
	var total_speed_pct: float = maxf(-0.70, shop_speed_pct + pass_speed + anima_spd + aug_speed_pct + buff_speed_pct)
	stats["movement_speed"] = maxf(120.0,base_speed*(1+shop_speed_pct)*(1+pass_speed)*(1+anima_spd)*aug_speed_multiplier*maxf(0.3,1+buff_speed_pct))

	# Ability Haste: flat sum
	stats["ability_haste"] = maxf(-50.0, base_haste + shop_haste + pass_haste + anima_haste + aug_haste_flat + buff_haste_flat)

	# Crit Chance: clamped [0.0, 1.0]
	stats["crit_chance"] = clampf(base_crit + shop_crit + pass_crit + aug_crit_flat, 0.0, 1.0)

	# Crit Damage: multiplier
	stats["crit_damage"] = maxf(1.5, base_crit_dmg + aug_crit_dmg_flat)
	# +25 percentage points: base 200% becomes 225%, matching archive factor 1.125.
	if augments.has("augment_mission_critical"): stats["crit_damage"]+=0.25
	if augments.has("augment_juggernaut"): aug_dmg_pct+=stats["armor"]*0.005
	if augments.has("augment_with_haste"): stats["movement_speed"]+=base_speed*maxf(0,stats["ability_haste"])*0.005
	# Jinx's 14.15 passive is additive to other bonus movement, not a multiplier.
	stats["movement_speed"]+=base_speed*float(temp_buffs.get("jinx_speed_pct",0))

	# Damage Multiplier: base 1.0 + sum(percentages)
	var total_dmg_pct: float = maxf(-0.80, shop_dmg + pass_dmg + anima_dmg + aug_dmg_pct + buff_dmg_pct)
	# Different percentage sources multiply; ranks within a source add.
	stats["damage_multiplier"] = maxf(0.1,base_dmg_mult*(1+shop_dmg)*(1+pass_dmg)*(1+anima_dmg)*aug_dmg_multiplier*maxf(0.1,1+aug_dmg_pct)*maxf(0.1,1+buff_dmg_pct))

	# Projectile Count: flat bonus added to base weapon projectile count
	stats["bonus_projectiles"] = max(0, bonus_proj + shop_proj + pass_proj + aug_proj_flat + buff_proj_flat)

	# Area Size Multiplier
	var total_area_pct: float = maxf(-0.50, shop_area_pct + pass_area + aug_area_pct + float(temp_buffs.get("area_pct",0)))
	stats["area_multiplier"] = maxf(0.3,base_area*(1+shop_area_pct)*(1+pass_area)*maxf(0.1,1+aug_area_pct)*maxf(0.1,1+float(temp_buffs.get("area_pct",0))))

	# Duration Multiplier
	var total_dur_pct: float = maxf(-0.50, shop_dur_pct + pass_dur + aug_dur_pct)
	stats["duration_multiplier"] = maxf(0.3,base_duration*(1+shop_dur_pct)*(1+pass_dur)*maxf(0.1,1+aug_dur_pct))

	# Pickup Radius
	var total_pickup_pct: float = maxf(-0.70, shop_pickup_pct + pass_pickup + anima_pickup + aug_pickup_pct)
	stats["pickup_radius"] = maxf(30.0,base_pickup*(1+shop_pickup_pct)*(1+pass_pickup)*(1+anima_pickup)*maxf(0.1,1+aug_pickup_pct))
	if augments.has("augment_pick_me_up"): stats["pickup_radius"]=0

	# Experience Multiplier
	var total_exp_pct: float = shop_exp_pct + pass_exp + aug_exp_pct
	stats["exp_multiplier"] = maxf(0.5,base_exp*(1+shop_exp_pct)*(1+pass_exp)*maxf(0.1,1+aug_exp_pct))

	# Gold Multiplier
	var total_gold_pct: float = shop_gold_pct + aug_gold_pct
	stats["gold_multiplier"] = maxf(0.5, base_gold * (1.0 + total_gold_pct))

	stats["shield"] = bonus_shield + buff_shield_flat
	stats["knockback_multiplier"] = knockback_mult

	stats["cooldown_multiplier"] = 0.2 if temp_buffs.get("rapid_fire",0)>0 else 1.0
	stats["projectile_speed_multiplier"] = 1.0
	if base_stats.get("character_id","") == "yasüff": stats["crit_chance"] = minf(1.0,stats["crit_chance"]+0.15)
	return stats

