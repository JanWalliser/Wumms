extends RefCounted

static func run(player: Node2D, suite: Node, enemy: Node2D) -> void:
	const Timeline = preload("res://scripts/game/warehouse_timeline.gd")
	for phase in Timeline.reference_data()["phases"]:
		for wave in phase["waves"]:
			suite.check(is_equal_approx(Timeline.spawn_multiplier(wave,"story"),1.0 if Timeline.is_special(wave) else 0.8),"story density only reduces regular waves: "+str(wave["name"]))
			suite.check(Timeline.spawn_multiplier(wave,"hard")==1,"hard wave density unchanged")
	suite.check(Timeline.phase_at(Timeline.gameplay_time(64.9,"story"))==0,"first stronger wave waits until 65 seconds")
	suite.check(Timeline.phase_at(Timeline.gameplay_time(65,"story"))==1,"first stronger wave begins twenty seconds later")
	suite.check(Timeline.gameplay_time(600,"story")==580 and Timeline.gameplay_time(600,"hard")==600,"later story phases have flat twenty second delay")
	suite.check(Timeline.gameplay_time(900,"story")==900,"boss remains at fifteen minutes")
	var old_time: float = GameManager.game_time
	GameManager.game_time=200
	suite.check(GameManager.get_enemy_time_multipliers()==GameManager.get_enemy_time_multipliers(180),"live story strength uses twenty second grace period")
	GameManager.game_time=old_time
	suite.clear_combat()
	var origin := enemy.global_position
	enemy._begin_ranged_attack(Vector2.RIGHT)
	enemy.global_position+=Vector2(100,100)
	enemy._tick_ranged_attack(0.59)
	var shots := suite.get_tree().get_nodes_in_group("projectiles")
	suite.check(shots.is_empty(),"ranged shot waits for its warning")
	enemy._tick_ranged_attack(0.01)
	shots=suite.get_tree().get_nodes_in_group("projectiles")
	suite.check(shots.size()==1,"warning produces exactly one projectile")
	var shot = shots[0]
	shot.set_physics_process(false)
	suite.check(shot.global_position==origin and shot.direction==Vector2.RIGHT,"shot uses warning origin even after knockback")
	suite.check(shot.max_travel_distance==500,"shot range equals warning length")
	for i in 14: shot._physics_process(0.1)
	suite.check(shot.expired and shot.global_position.is_equal_approx(origin+Vector2(500,0)),"projectile expires at the warning endpoint without overshooting")
	enemy._tick_ranged_attack(1)
	suite.check(enemy.pending_ranged_attack.is_empty(),"fired attack cannot repeat")
	suite.clear_combat()
	enemy._begin_ranged_attack(Vector2.RIGHT)
	enemy.pending_ranged_attack["run"]="expired-test-run"
	enemy._tick_ranged_attack(1)
	suite.check(suite.get_tree().get_nodes_in_group("projectiles").is_empty(),"stale run cannot fire a delayed enemy attack")
	enemy._begin_ranged_attack(Vector2.RIGHT)
	enemy.apply_status_effect("stun",1)
	enemy._process_special(1)
	suite.check(enemy.pending_ranged_attack.is_empty(),"stun cancels pending ranged shot")
	enemy.global_position=origin
	var modal = suite.get_node("GameWorld").level_up_modal
	var old_rerolls: Dictionary = modal.rerolls.duplicate()
	modal.rerolls.clear()
	modal._open_modal()
	var button = modal.player_panels[0].get_node("RerollButton")
	suite.check(button.visible and not button.disabled and modal.rerolls[0]==3,"starter profile receives visible three-use reroll button")
	modal._reroll(0,modal.event_id+1)
	suite.check(modal.rerolls[0]==3,"stale selection cannot spend a reroll")
	button.pressed.emit()
	suite.check(modal.rerolls[0]==2,"visible reroll button is connected to regeneration")
	for i in 2: modal._reroll(0,modal.event_id)
	modal._reroll(0,modal.event_id)
	suite.check(modal.rerolls[0]==0 and modal.player_panels[0].get_node("RerollButton").disabled,"three rerolls work and fourth is disabled")
	modal._rebuild_columns()
	suite.check(modal.rerolls[0]==0,"opening another choice does not replenish run rerolls")
	modal.hide()
	modal.rerolls=old_rerolls
	suite.clear_combat()
