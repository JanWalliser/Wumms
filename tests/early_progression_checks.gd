extends RefCounted

static func run(player: Node2D, suite: Node, enemy: Node2D) -> void:
	var previous := {"time":GameManager.game_time,"level":GameManager.team_level,"xp":GameManager.current_team_exp,"required":GameManager.required_team_exp,"total":GameManager.total_xp_collected,"gold":GameManager.team_gold_earned}
	var expected := [5,15,23,30,38,45,53,54,57,58,66]
	for i in expected.size(): suite.check(GameManager.calculate_required_exp_for_level(i+1)==expected[i],"explicit early pacing level "+str(i+1))
	var to_seven := 0
	for i in range(1,7): to_seven+=GameManager.calculate_required_exp_for_level(i)+1
	suite.check(to_seven==162,"level seven requires 162 XP, previously 111, without hidden pickup penalties")
	for i in range(11,99): suite.check(GameManager.calculate_required_exp_for_level(i)==GameManager.calculate_reference_exp_for_level(i),"later XP costs unchanged at "+str(i))
	suite.clear_combat()
	player.current_stats["ability_haste"]=0
	player.current_stats["duration_multiplier"]=1
	var gun := WeaponInstance.new("weapon_gatling",player)
	gun.update(0)
	var first_effect = gun.effect_node
	first_effect.set_physics_process(false)
	for i in 159:
		GameManager.game_time+=0.05
		first_effect._physics_process(0.05)
		gun.update(0.05)
	suite.check(gun.casts==1 and gun.effect_node==first_effect,"eight-second barrage is one cast, not repeated casts")
	first_effect._physics_process(0.1)
	gun.update(0.1)
	for i in 95: gun.update(0.05)
	suite.check(gun.casts==1,"gatling cannot restart during five-second reload")
	for i in 10: gun.update(0.05)
	suite.check(gun.casts==2,"gatling restarts once after the full eight plus five second cycle")
	suite.clear_combat()
	# A crate shares the projectile target group but has no is_boss property.
	var crate = load("res://scenes/combat/loot_crate.tscn").instantiate()
	player.get_parent().add_child(crate)
	crate.global_position=player.global_position+Vector2(50,0)
	var bomb = load("res://scenes/combat/drop_item.tscn").instantiate()
	player.get_parent().add_child(bomb)
	bomb.setup(DropItem.ItemType.BOMB,1)
	bomb.global_position=player.global_position
	var far = load("res://scenes/enemies/enemy_base.tscn").instantiate()
	player.get_parent().add_child(far)
	far.set_physics_process(false)
	far.global_position=player.global_position+Vector2(300,0)
	var far_hp: float = far.current_health
	bomb.start_attraction(player)
	bomb._collect(player)
	suite.check(bomb.collected and bomb.is_queued_for_deletion() and not bomb.visible and not bomb.is_attracted,"bomb commits removal before enemy/crate/levelup callbacks")
	var kills: int = GameManager.total_run_kills
	bomb._collect(player)
	suite.check(GameManager.total_run_kills==kills,"duplicate bomb collection cannot reapply its explosion")
	suite.check(not crate.is_broken,"enemy-only pickup explosion does not access crate-only fields")
	suite.check(far.current_health==far_hp,"bomb cannot kill distant enemies or manufacture map-wide XP drops")
	far.queue_free()
	crate.queue_free()
	GameManager.game_time=previous["time"]
	GameManager.team_level=previous["level"]
	GameManager.current_team_exp=previous["xp"]
	GameManager.required_team_exp=previous["required"]
	GameManager.total_xp_collected=previous["total"]
	GameManager.team_gold_earned=previous["gold"]
	player.recalculate_stats()
