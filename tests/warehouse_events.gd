extends Node
var checks := 0
var failures: Array[String] = []
var temporary_id := 'warehouse_events_'+str(Time.get_ticks_usec())
const Timeline = preload('res://scripts/game/warehouse_timeline.gd')

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr('FAIL: ',label)

func _ready() -> void: call_deferred('run_tests')

func clear_enemies(map: Node) -> void:
	for formation in get_tree().get_nodes_in_group("shield_formations"): formation.free()
	for enemy in map.spawner.active_enemies:
		if is_instance_valid(enemy): enemy.free()
	map.spawner.active_enemies.clear()

func run_tests() -> void:
	var slots := ProfileManager.player_slots.duplicate(true)
	AudioManager.sfx_volume=0
	AudioManager.music_player.stop()
	GameManager.set_process(false)
	var profile := SaveManager.create_default_profile(temporary_id,'Warehouse events')
	profile['features'].append('yuumi_quests')
	profile['features'].append('belveth_trials')
	profile['features'].append('boons_unlocked')
	SaveManager.save_profile(profile)
	for i in 4:
		ProfileManager.player_slots[i]['active']=i==0
		ProfileManager.player_slots[i]['profile_id']=temporary_id
		ProfileManager.player_slots[i]['character_id']='jankz'
		ProfileManager.player_slots[i]['device_id']=-1
	GameManager.start_new_run('map_warehouse','story')
	GameManager.practice_mode=true
	var world = load('res://scenes/game/game_world.tscn').instantiate()
	add_child(world)
	var map = world.current_map_node
	map.spawner.set_physics_process(false)
	map.set_process(false)
	var director = map.get_node('EventDirector')
	director.set_process(false)
	var player = GameManager.active_player_nodes[0]
	player.set_physics_process(false)
	player.weapon_controller.set_process(false)
	player.set_meta('god_mode',true)
	check(GameManager.calculate_required_exp_for_level(11)==66,'XP uses archived increments after ten')
	check(GameManager.calculate_required_exp_for_level(24)==168,'level 24 requires 168 displayed XP, not 132')
	check(GameManager.calculate_required_exp_for_level(40)==320,'level 40 requires 320 displayed XP')
	for level in range(2,99): check(GameManager.calculate_required_exp_for_level(level)>GameManager.calculate_required_exp_for_level(level-1),'monotonic XP increment '+str(level))
	check(Timeline.phase_at(0)==-1 and Timeline.phase_at(3)==0 and Timeline.phase_at(45)==1 and Timeline.phase_at(900)==20,'archived phase boundaries include three-second start')
	# Deterministically simulate the whole original schedule; free units without reward.
	var minibosses := 0
	var elites := 0
	var phase_counts: Dictionary = {}
	var minute_counts: Dictionary = {}
	check(Timeline.pressure_floor(479,'story')==0 and Timeline.pressure_floor(900,'story')==0,'late pressure leaves opening and boss encounter unchanged')
	check(is_equal_approx(Timeline.pressure_floor(480,'story'),6.0) and is_equal_approx(Timeline.pressure_floor(880,'story'),20.0),'late floor rises from six to twenty enemies per second per player')
	check(is_equal_approx(Timeline.pressure_floor(600,'hard')*0.8,Timeline.pressure_floor(600,'story')),'easy retains twenty percent lighter pressure than hard')
	for second in range(0,901):
		GameManager.game_time=second
		map.spawner.warehouse_timeline.tick(map.spawner,1.0)
		for enemy in map.spawner.active_enemies:
			enemy.set_physics_process(false)
			var source: String = enemy.get_meta('reference_character','')
			if source.contains('MiniBoss'): minibosses+=1
			elif enemy.drops_access_card: elites+=1
			var phase: int = Timeline.phase_at(second)
			phase_counts[phase]=int(phase_counts.get(phase,0))+1
			var minute := int(second/60)
			minute_counts[minute]=int(minute_counts.get(minute,0))+1
			check(enemy.exp_drop in [1,4,20],'wave enemy XP is an orb denomination')
		clear_enemies(map)
	check(minibosses==8 and elites==5,'exactly eight minibosses and five elite waves before the boss')
	check(int(minute_counts.get(9,0))>=450,'minute nine no longer collapses into the low-density wave')
	check(int(minute_counts.get(13,0))>=1000 and int(minute_counts.get(14,0))>=1100,'final minutes maintain dense normal-enemy replenishment')
	check(map.spawner.warehouse_timeline.pressure_clock==0.0,'supplemental pressure stops at the boss')
	# A full arena cannot bank a catch-up horde, and refills use ordinary wave units.
	GameManager.game_time=570
	var limited_timeline = Timeline.new()
	var original_cap: int = map.spawner.max_concurrent_enemies
	map.spawner.max_concurrent_enemies=0
	limited_timeline.tick(map.spawner,1.0)
	check(limited_timeline.emitted==0 and limited_timeline.pressure_clock==0.0,'full arena discards pressure debt')
	map.spawner.max_concurrent_enemies=original_cap
	limited_timeline.tick(map.spawner,1.0/60.0)
	check(limited_timeline.emitted<=2,'reopening arena does not release a backlog')
	clear_enemies(map)
	check(int(phase_counts.get(16,0))>int(phase_counts.get(0,0))*10,'late ghoul wave has over ten times the opening spawn count')
	var frequency_counts: Array[int] = []
	for fps in [30,60,120]:
		var frame_timeline = Timeline.new()
		for frame in fps*3:
			GameManager.game_time=570.0+float(frame)/fps
			frame_timeline.tick(map.spawner,1.0/fps)
			clear_enemies(map)
		frequency_counts.append(frame_timeline.emitted)
	check(frequency_counts.max()-frequency_counts.min()<=1 and frequency_counts.min()>=26,'late refill is consistent at thirty, sixty and one hundred twenty FPS')
	GameManager.game_time=200
	GameManager.selected_difficulty='story'
	director._schedule_events()
	check(director.pending_spires.any(func(e): return e['type']=='mission'),'unlocked Yuumi spire scheduled')
	check(not director.pending_spires.any(func(e): return e['type']=='trial'),'no Belveth trials in story')
	director.pending_spires.clear()
	director.scheduled.clear()
	GameManager.selected_difficulty='hard'
	GameManager.game_time=250
	director._schedule_events()
	check(director.pending_spires.any(func(e): return e['type']=='trial'),'unlocked Belveth trial scheduled on hard')
	director.pending_spires.clear()
	GameManager.game_time=0
	for kind in preload('res://scripts/game/swarm_challenge.gd').YUUMI+preload('res://scripts/game/swarm_challenge.gd').TRIALS:
		GameManager.set_state(GameManager.GameState.GAMEPLAY)
		director.start_event('trial' if kind in ['miniboss','horde','circle','linked','meteors','darkness'] else 'mission',player.global_position)
		var before := GameManager.selection_queue.size()
		director.finish_event(true)
		check(not director.active.is_empty() and GameManager.selection_queue.size()==before,'touching/capturing alone cannot reward '+kind)
		director._begin_challenge(kind)
		var task = director.challenge
		check(is_instance_valid(task) and task.kind==kind,'task instantiates '+kind)
		if OS.get_cmdline_user_args().has('--capture') and kind in ['football','vases','boxes','meteors','darkness']:
			task.update(1.3 if kind=='meteors' else 0.016)
			director.active['position']=task.target
			director.message=task.description()
			for frame in 4:
				await get_tree().process_frame
				RenderingServer.force_draw(false,1.0/60)
			get_viewport().get_texture().get_image().save_png('res://output/swarm-ui/warehouse-event-'+kind+'.png')
			task.progress=0
		for enemy in task.entities:
			if enemy is Enemy: enemy.set_physics_process(false)
		if kind=='football':
			player.global_position=task.origin
			check(task.update(0.01)==0,'football proximity does not complete quest')
			task.ball=task.goal
			check(task.update(0.01)==1,'ball in goal completes football')
		elif kind=='boxes':
			for i in 5:
				player.global_position=task.points[0]
				task.update(0.01)
				check(task.carried.has(player.get_instance_id()),'box must be carried '+str(i))
				player.global_position=task.goal
				task.update(0.01)
			check(task.result==1 and not player.temp_buffs.has('yuumi_box'),'five deliveries complete boxes and remove carry slow')
		elif kind=='vases':
			for vase in task.entities: vase.receive_damage(1000,false,player)
			check(task.update(0.01)==1,'all fifteen destructible vases required')
		elif kind in ['race','marathon','laser']:
			for i in int(task.required):
				player.global_position=task.target
				task.update(1.01 if kind=='laser' else 0.01)
			check(task.result==1,'all checkpoints complete '+kind)
		elif kind=='beach_ball':
			for i in 6:
				player.global_position=task.target
				task.update(4.01)
			check(task.result==1,'six landing interceptions complete beach ball')
		elif kind=='yarn':
			for i in 8:
				task.ball=task._safe(player.global_position+Vector2(20,0))
				player.global_position=task.ball-Vector2(10,0)
				task.update(0.2)
			check(task.progress>0 and task.result==0,'yarn tracks rolled distance instead of contact')
		elif kind in ['chumper','miniboss']:
			var victim = task.entities[0]
			task.record_kill(victim)
			task.record_kill(victim)
			check(task.progress==1 and task.update(0.01)==1,'only unique quest target kill completes '+kind)
		elif kind=='horde':
			task.update(1.6)
			var outsider := Enemy.new()
			task.record_kill(outsider)
			outsider.free()
			check(task.progress==0,'unrelated kills cannot complete combat trial')
		elif kind in ['circle','linked','meteors','darkness']:
			player.global_position=task.origin
			task.update(1)
			check(task.progress==1 and task.result==0,'survival trial requires elapsed time '+kind)
		director.finish_event(false)
		check(not player.temp_buffs.has('yuumi_box'),'cleanup removes quest debuffs '+kind)
		clear_enemies(map)
		await get_tree().process_frame
	# Failure and exactly-once reward.
	director.start_event('mission',player.global_position)
	director._begin_challenge('beach_ball')
	player.global_position=director.challenge.target+Vector2(500,0)
	check(director.challenge.update(4.1)==-1,'missed beach-ball landing fails')
	director.finish_event(false)
	director.start_event('trial',player.global_position)
	director._begin_challenge('circle')
	var gold_before := GameManager.team_gold_earned
	director.challenge.progress=30
	check(director.challenge.update(0)==1,'survival goal completes')
	director.finish_event(true)
	director.finish_event(true)
	check(GameManager.team_gold_earned==gold_before+150,'trial reward paid exactly once')
	GameManager.return_to_menu()
	world.free()
	ProfileManager.player_slots=slots
	SaveManager.delete_profile(temporary_id)
	GameManager.set_process(true)
	await get_tree().process_frame
	print('WAREHOUSE EVENTS: ',checks,' checks, ',failures.size(),' failed')
	if failures.is_empty(): print('WAREHOUSE EVENTS PASSED')
	get_tree().quit(0 if failures.is_empty() else 1)
