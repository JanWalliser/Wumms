extends RefCounted

static func run(player: Node2D, suite: Node, enemy: Node2D, second: Node2D) -> void:
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/swarm-14.16-reference.json"))
	player.passives.clear()
	player.augments.clear()
	player.temp_buffs.clear()
	player.recalculate_stats()
	player.current_stats["crit_chance"]=0
	for id in fixtures:
		var fixture: Dictionary = fixtures[id]
		var weapon := WeaponInstance.new(id,player)
		for rank in range(1,7):
			weapon.level=mini(rank,5)
			weapon.is_evolved=rank==6
			var label: String = id+" rank "+str(rank)
			var expected: float
			if id=="weapon_meow_meow": expected=float(fixture["fields"]["Damage"][rank])/float(fixture["fields"]["MinigunBulletCount"][rank])
			else: expected=float(fixture["fields"][fixture["mapping"]["damage"]][rank])
			suite.check(is_equal_approx(weapon.get_damage(),expected),label+" damage from archived spell")
			var cd_key: String = fixture.get("mapping",{}).get("cooldown","cooldownTime")
			var expected_cd: float = float(fixture["fields"][cd_key][rank])
			if id=="weapon_radiant_field": expected_cd=0.5 # Archived TickRate rather than dummy spell cooldown.
			suite.check(is_equal_approx(weapon.get_effective_cooldown(),expected_cd),label+" cooldown from archive")
			var count_key = fixture.get("mapping",{}).get("count",null)
			var expected_count: int = int(fixture["fields"]["MinigunBulletCount"][rank]) if id=="weapon_meow_meow" else (int(fixture["fields"][count_key][rank]) if count_key!=null else 1)
			suite.check(weapon.get_projectiles()==expected_count,label+" number from archive")
			player.current_stats["bonus_projectiles"]=3
			suite.check(weapon.get_projectiles()==expected_count+(3 if weapon.data.get("scales_projectiles",true) else 0),label+" projectile modifier whitelist")
			player.current_stats["bonus_projectiles"]=0
			player.current_stats["ability_haste"]=100
			suite.check(is_equal_approx(weapon.get_effective_cooldown(),expected_cd/(2 if weapon.data.get("scales_haste",true) else 1)),label+" haste whitelist")
			player.current_stats["ability_haste"]=0
			var radius_key = fixture.get("mapping",{}).get("radius",null)
			if radius_key!=null:
				suite.check(is_equal_approx(weapon.effect_radius(),float(fixture["fields"][radius_key][rank])*0.2),label+" map radius converted once")
	for id in PassiveRegistry.get_all_passive_ids():
		for rank in range(6):
			suite.check(is_equal_approx(PassiveRegistry.get_bonus(id,rank),preload("res://scripts/core/swarm_balance.gd").data()["passives"][id]["levels"][rank]),id+" passive rank "+str(rank))
	var mixed := StatCalculator.compute_player_stats({"max_health":1000},{"damage":2,"duration":2,"max_health":2},{"damage":2,"duration":2,"max_health":2},[],{})
	suite.check(is_equal_approx(mixed["damage_multiplier"],1.44),"different damage sources multiply without repeated application")
	suite.check(is_equal_approx(mixed["duration_multiplier"],1.1*1.24),"different duration sources multiply")
	suite.check(is_equal_approx(mixed["max_health"],1560),"flat passive HP receives shop percent modifier")
	player.current_stats["damage_multiplier"]=1
	var cat := WeaponInstance.new("weapon_meow_meow",player)
	cat.is_evolved=true
	cat.fire()
	var bullet = suite.owned_projectiles(player)[0]
	var health: float = enemy.current_health
	var other_health: float = second.current_health
	bullet._handle_target_hit(enemy)
	bullet._handle_target_hit(second)
	suite.check(enemy.current_health==health-20 and second.current_health==other_health-8,"Battle Cat pierces at forty percent after first target")
	suite.clear_combat()
	var crossbow := WeaponInstance.new("weapon_crossbow",player)
	crossbow.is_evolved=true
	player.current_stats["bonus_projectiles"]=3
	crossbow.fire()
	suite.check(suite.owned_projectiles(player).size()==28,"evolved ballista is not truncated by old 24-projectile cap")
	player.current_stats["bonus_projectiles"]=0
	bullet=suite.owned_projectiles(player)[0]
	bullet.attacker_stats["crit_chance"]=0
	bullet._handle_target_hit(enemy)
	suite.check(bullet.expired,"crossbow arrow stops on a noncritical hit")
	bullet=suite.owned_projectiles(player)[0]
	bullet.attacker_stats["crit_chance"]=1
	bullet._handle_target_hit(enemy)
	suite.check(not bullet.expired,"crossbow arrow pierces on its own critical roll")
	suite.clear_combat()
	player.current_stats["crit_chance"]=0
	var mine := WeaponInstance.new("weapon_anti_shark",player)
	mine.fire()
	var sea_mine = suite.owned_projectiles(player)[0]
	sea_mine.global_position=enemy.global_position
	var before_mine: float = enemy.current_health
	var before_splash: float = second.current_health
	sea_mine._handle_target_hit(enemy)
	suite.check(enemy.current_health==before_mine-95,"sea mine deliberately combines contact 45 and explosion 50")
	suite.check(second.current_health==before_splash-50,"sea mine deals only explosion to secondary targets")
	suite.clear_combat()
	var crescent := WeaponInstance.new("weapon_lioness",player)
	crescent.fire()
	var crescent_health: float = enemy.current_health
	for path in suite.owned_projectiles(player): path._handle_target_hit(enemy)
	suite.check(enemy.current_health==crescent_health-60,"three crescent paths share one hit budget")
	suite.clear_combat()
	var range_rocket = player._spawn_jinx_rocket(Vector2.RIGHT,500,"r")
	range_rocket.position=Vector2(5000,5000)
	range_rocket.initial_pos=range_rocket.position
	for frame in 30:
		if range_rocket.expired: break
		range_rocket._physics_process(0.05)
	suite.check(range_rocket.expired and is_equal_approx(range_rocket.initial_pos.distance_to(range_rocket.global_position),400),"R explodes exactly at its range even with no enemy")
	suite.clear_combat()
	var armor := WeaponInstance.new("weapon_iceblast",player)
	armor.fire()
	suite.check(player.get_meta("iceblast_armed",false),"ice armor arms rather than immediately damaging surroundings")
	var player_hp: float = player.current_health
	DamageSystem.apply_damage({},player,100,false,enemy)
	suite.check(player.current_health==player_hp and not player.get_meta("iceblast_armed",false),"ice armor completely nullifies first incoming damage")
	suite.check(armor.cooldown_timer==18,"ice armor cooldown starts upon consumption")
	suite.clear_combat()
	var old_level: int = GameManager.team_level
	GameManager.team_level=1
	enemy.current_health=50000
	enemy.max_health=100000
	enemy.armor=500
	var rocket = player._spawn_jinx_rocket(Vector2.LEFT,500,"r")
	rocket.global_position=enemy.global_position
	rocket._explode_rocket()
	suite.check(enemy.current_health==49000,"R computes missing-health multiplier per victim and bypasses armor")
	var remaining_hp: float = enemy.current_health
	rocket._explode_rocket()
	suite.check(enemy.current_health==remaining_hp,"R explosion cannot trigger twice")
	suite.check(rocket.missile_texture!=null and rocket.max_travel_distance==400,"R has authored sprite and original converted range")
	suite.clear_combat()
	GameManager.team_level=old_level
	enemy.armor=0
	enemy.current_health=100000
	for asset in ["small-rocket","ultimate-rocket","rocket-explosion"]:
		var texture: Texture2D = load("res://assets/projectiles/jinx/"+asset+".res")
		suite.check(texture!=null and texture.get_image().detect_alpha()!=Image.ALPHA_NONE,asset+" ships with real alpha")
	for id in AugmentRegistry.get_all_augment_ids():
		suite.check(preload("res://scripts/core/swarm_balance.gd").data()["augments"].has(id) and not AugmentRegistry.get_augment_data(id)["description"].is_empty(),id+" has reconciled description")
	var tradeoff := StatCalculator.compute_player_stats({"max_health":1000},{},{},["augment_glass_cannon","augment_spray_and_pray"],{})
	suite.check(is_equal_approx(tradeoff["damage_multiplier"],0.91) and tradeoff["bonus_projectiles"]==4,"Glass Cannon and Spray tradeoffs multiply rather than cancelling additively")
	suite.check(tradeoff["max_health"]==700,"Glass Cannon costs thirty percent health")
	var duration := StatCalculator.compute_player_stats({}, {},{},["augment_uptime_upgrade"],{})
	suite.check(is_equal_approx(duration["duration_multiplier"],1.6),"Uptime supplies sixty percent duration")
	var critical := StatCalculator.compute_player_stats({}, {},{},["augment_mission_critical"],{})
	suite.check(is_equal_approx(critical["crit_chance"],0.15) and is_equal_approx(critical["crit_damage"],2.25),"Mission Critical adds ten crit points and twenty-five critical-damage points")
	var heavy := StatCalculator.compute_player_stats({}, {},{},["augment_heavy_hitter"],{})
	suite.check(heavy["ability_haste"]==-30 and heavy["damage_multiplier"]==1.5,"Heavy Hitter has its original tradeoff")
	var pickup := StatCalculator.compute_player_stats({}, {},{},["augment_pick_me_up"],{})
	suite.check(pickup["pickup_radius"]==0 and is_equal_approx(pickup["exp_multiplier"],1.15),"Pick Me Up removes collection range and adds XP")
	var haste := StatCalculator.compute_player_stats({}, {},{"ability_haste":2},["augment_with_haste"],{})
	suite.check(haste["ability_haste"]==20 and is_equal_approx(haste["movement_speed"],385),"With Haste converts haste to speed without inventing more haste")
	player.augments=["augment_ultimate_speed_up"]
	player.temp_buffs.clear()
	player.recalculate_stats()
	player._activate_ability_r()
	suite.check(player.ability_r_max_cd==50 and player.ability_e_max_cd==8,"character kit binds archived E/R cooldowns rather than legacy registry fields")
	suite.check(player.ability_r_cd==25,"Ultimate Speed Up grants one hundred ultimate haste")
	player.pending_jinx_abilities.clear()
	GameManager.team_level=1
	player.augments=["augment_bullet_mania"]
	player.register_augment("augment_bullet_mania")
	player.recalculate_stats()
	suite.check(player.get_stat("bonus_projectiles")==0,"Bullet Mania gives no instant projectiles")
	GameManager.team_level=7
	var bonus: Dictionary = player._update_augment_state(0.016,true)
	suite.check(bonus.get("projectile_count",0)==1,"Bullet Mania counts six levels after acquisition")
	player.augments=["augment_card_collector"]
	player.set_meta("cards",5)
	player.register_augment("augment_card_collector")
	player.set_meta("cards",6)
	bonus=player._update_augment_state(0.016,true)
	suite.check(is_equal_approx(bonus.get("damage_pct",0),0.05),"Card Collector does not retroactively count previous cards")
	var saved_time: float = GameManager.game_time
	GameManager.game_time=0
	player.augments=["augment_circle_of_stats"]
	player.register_augment("augment_circle_of_stats")
	bonus=player._update_augment_state(0.016,true)
	suite.check(is_equal_approx(bonus.get("speed_pct",0),0.3),"Circle of Stats starts with thirty percent speed")
	GameManager.game_time=8
	bonus=player._update_augment_state(0.016,true)
	suite.check(bonus.get("ability_haste",0)==40,"Circle cycles to haste after eight seconds")
	player.augments=["augment_ebb_and_flow"]
	GameManager.game_time=0
	player.register_augment("augment_ebb_and_flow")
	bonus=player._update_augment_state(0.016,true)
	suite.check(bonus.get("ability_haste",0)==-50,"Ebb and Flow lower bound")
	GameManager.game_time=16
	bonus=player._update_augment_state(0.016,true)
	suite.check(bonus.get("ability_haste",0)==125,"Ebb and Flow upper bound")
	GameManager.game_time=saved_time
	GameManager.team_level=old_level
	player.augments.clear()
	player.temp_buffs.clear()
	player.recalculate_stats()
	suite.clear_combat()
