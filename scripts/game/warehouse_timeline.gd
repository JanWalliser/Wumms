extends RefCounted

# Imported wave timing/counts; existing enemy art/AI remains simplified.
static var _reference: Dictionary = {}
const CoopBalance = preload("res://scripts/game/warehouse_balance.gd")
var phase_index := -1
var states: Array[Dictionary] = []
var emitted := 0
var pressure_clock := 0.0
var shield_rings_started: Dictionary = {}
var shield_run := ""

static func is_shield_ring(wave: Dictionary) -> bool:
	return str(wave.get("name","")).ends_with("ShieldCircle") or str(wave.get("name","")).ends_with("LancerCircle")

func _tick_shield_rings(spawner) -> void:
	if not spawner is Node2D: return # Headless schedule simulations have no scene/physics.
	if shield_run!=GameManager.run_id:
		shield_run=GameManager.run_id
		shield_rings_started.clear()
	# Scripted enclosures keep their original clock/count independently of the
	# Story delay, ordinary density reduction, co-op count and normal spawn cap.
	for phase in reference_data()["phases"]:
		if GameManager.game_time<float(phase["start"]) or GameManager.game_time>=float(phase["start"])+35.0: continue
		for wave in phase["waves"]:
			if not is_shield_ring(wave) or shield_rings_started.has(wave["name"]): continue
			shield_rings_started[wave["name"]]=true
			var ring=preload("res://scripts/game/shield_formation.gd").new()
			spawner.get_parent().add_child(ring)
			ring.begin(spawner,wave)

# Project tuning: preserve the opening and scripted encounters, but fill late
# gaps with ordinary enemies. Solo rates; tick applies the shared team density
# before the arena safety cap, independently of the special-encounter budget.
static func pressure_floor(time: float, difficulty: String = "") -> float:
	if time < 480 or time >= 900: return 0.0
	var mode := GameManager.selected_difficulty if difficulty.is_empty() else difficulty
	var rate := lerpf(6.0,20.0,clampf((time-480.0)/400.0,0.0,1.0))
	return rate if mode=="story" else rate/0.8

static func pressure_candidate(wave: Dictionary) -> bool:
	var shape: Dictionary = wave.get("WaveShape",{})
	return not is_special(wave) and int(wave.get("MaxSpawnCount",0))>=500 and float(wave.get("SpawnIntervalSecs",0))>=0.1 and not wave.has("child_wave") and wave.get("ConditionalBehaviors",[]).is_empty() and not shape.has("radius") and not shape.has("SideLength")

static func gameplay_time(time: float, difficulty: String = "") -> float:
	var mode := GameManager.selected_difficulty if difficulty.is_empty() else difficulty
	if mode!="story" or time<45 or time>=900: return time
	return maxf(3,time-20)

static func is_special(wave: Dictionary) -> bool:
	var name: String = wave["name"]
	return (name.contains("Boss") and not name.contains("WaveDefBoss_")) or name.ends_with("Elite")

static func spawn_multiplier(wave: Dictionary, difficulty: String = "") -> float:
	var mode := GameManager.selected_difficulty if difficulty.is_empty() else difficulty
	return 0.8 if mode=="story" and not is_special(wave) else 1.0

static func team_factor(wave: Dictionary) -> float:
	return 1.0 if is_special(wave) else GameManager.get_warehouse_density()

static func wave_maximum(wave: Dictionary) -> int:
	return maxi(1,roundi(int(wave["MaxSpawnCount"])*spawn_multiplier(wave)*team_factor(wave)))

static func reference_data() -> Dictionary:
	if _reference.is_empty(): _reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/balance/warehouse-14.16.json"))
	return _reference

static func phase_at(time: float) -> int:
	var phases: Array = reference_data()["phases"]
	for i in phases.size():
		if time>=float(phases[i]["start"]) and time<float(phases[i]["end"]): return i
	return -1

func tick(spawner, delta: float) -> void:
	_tick_shield_rings(spawner)
	var time := gameplay_time(GameManager.game_time)
	var index := phase_at(time)
	if index<0: return
	var phase: Dictionary = reference_data()["phases"][index]
	var step := delta
	if index!=phase_index:
		step=minf(delta,maxf(0,time-float(phase["start"])))
		phase_index=index
		pressure_clock=0.0
		states.clear()
		for wave in phase["waves"]:
			states.append({"wave":wave,"clock":maxf(0.001,float(wave["SpawnIntervalSecs"]))/spawn_multiplier(wave)/team_factor(wave),"count":0})
	for state in states:
		var wave: Dictionary = state["wave"]
		if is_shield_ring(wave): continue
		if str(wave["name"]).ends_with("Boss_RekSai"): continue # MapBase owns the boss lifecycle.
		var multiplier := spawn_multiplier(wave)*team_factor(wave)
		var maximum := wave_maximum(wave)
		if int(state["count"])>=maximum: continue
		var interval := maxf(0.001,float(wave["SpawnIntervalSecs"]))/multiplier
		state["clock"]+=step
		var batches := 0
		while float(state["clock"])>=interval and int(state["count"])<maximum and batches<12:
			var amount := mini(int(wave["SpawnCountPerInterval"]),maximum-int(state["count"]))
			var spawned := 0
			for i in amount:
				if _spawn(spawner,wave,int(state["count"])+spawned,maximum): spawned+=1
			state["count"]+=spawned
			emitted+=spawned
			state["clock"]-=interval
			batches+=1
			if spawned<amount:
				# A full arena is not a debt to spawn hundreds at once after the next kill.
				state["clock"]=minf(float(state["clock"]),interval)
				break
	_tick_pressure(spawner,step)

func _tick_pressure(spawner, delta: float) -> void:
	var target := pressure_floor(GameManager.game_time)
	if target<=0.0:
		pressure_clock=0.0
		return
	var density := GameManager.get_warehouse_density()
	var scheduled_rate := 0.0
	var candidate: Dictionary = {}
	for state in states:
		var wave: Dictionary = state["wave"]
		if pressure_candidate(wave) and candidate.is_empty(): candidate=wave
		if is_special(wave) or wave.has("child_wave") or float(wave["SpawnIntervalSecs"])<0.1: continue
		var multiplier := spawn_multiplier(wave)*team_factor(wave)
		var maximum := wave_maximum(wave)
		if int(state["count"])<maximum:
			scheduled_rate+=float(wave["SpawnCountPerInterval"])*multiplier/float(wave["SpawnIntervalSecs"])
	var extra_rate := maxf(0.0,target*density-scheduled_rate)
	if candidate.is_empty() or extra_rate<=0.0 or spawner.active_enemies.size()>=spawner.max_concurrent_enemies:
		pressure_clock=0.0
		return
	# Accumulate fractional units, never missed spawn debt at a full arena.
	pressure_clock=minf(pressure_clock+maxf(0.0,delta)*extra_rate,extra_rate+1.0)
	while pressure_clock>=1.0:
		if not _spawn(spawner,candidate,0,1):
			pressure_clock=0.0
			break
		pressure_clock-=1.0
		emitted+=1

func _spawn(spawner, wave: Dictionary, ordinal: int, maximum: int) -> bool:
	var name: String = wave["name"]
	var special := is_special(wave)
	if spawner.active_enemies.size()>=spawner.max_concurrent_enemies+(CoopBalance.SPECIAL_RESERVE if special else 0): return false
	var pos: Vector2 = spawner.valid_spawn()
	var shape: Dictionary = wave["WaveShape"]
	var center: Vector2 = spawner._get_players_center()
	if shape.has("radius"):
		pos=spawner.safe_position(center+Vector2.from_angle(TAU*ordinal/maxi(1,maximum))*float(shape["radius"])*0.2)
	elif shape.has("SideLength"):
		var side := -1.0 if ordinal%2==0 else 1.0
		pos=spawner.safe_position(center+Vector2((float(ordinal)/maxi(1,maximum)-0.5)*float(shape["SideLength"])*0.2,side*float(shape["GapWidth"])*0.1))
	if not pos.is_finite(): return false
	var record: String = wave.get("characters",[{}])[0].get("CharacterRecord","")
	if wave.has("child_wave"): record=wave["child_wave"]["WaveShape"]["SpawnerCharacter"]["CharacterRecord"]
	var mapping := {"BasicMelee1_Pix":"standard_grunt","BasicMelee2_Ghoul":"standard_grunt","Shy":"ranged_spitter","Hunter":"fast_runner","BruiserMelee1_Tibbers":"aoe_bruiser","Swarmer":"fast_runner","Lancer":"heavy_tank","MiniDasher":"fast_runner","BasicMelee4_Red":"standard_grunt","Exploder":"kamikaze_exploder","BasicMelee3_Fuemigo":"standard_grunt","BruiserMelee2_Daisy":"aoe_bruiser","Fast":"fast_runner","Shield":"heavy_tank","Divider":"standard_grunt","Spawner":"support_buffer","MiniRekSai":"fast_runner"}
	var short_name := record.get_slice("/",1).trim_prefix("Strawberry_Enemy_")
	var id: String = "mini_boss" if record.contains("MiniBoss") else mapping.get(short_name,"standard_grunt")
	if name.ends_with("Elite"): id="elite_variant"
	var enemy = spawner._spawn_single_enemy(id,pos,CoopBalance.SPECIAL_RESERVE if special else 0)
	if not is_instance_valid(enemy): return false
	enemy.set_meta("reference_character",record)
	enemy.set_meta("reference_wave",name)
	# Normal XP is independent from increasing combat strength. Heavy units use purple orbs.
	enemy.exp_drop=20 if special else (4 if record.contains("BruiserMelee") else 1)
	if special:
		enemy.is_elite=true
		enemy.drops_access_card=true
	if record.contains("MiniBoss_Dasher"): enemy.set_meta("miniboss_kind","dasher")
	elif record.contains("MiniBoss_Artillery"): enemy.set_meta("miniboss_kind","artillery")
	if wave.has("child_wave"): enemy.set_meta("warehouse_spawner",true)
	if short_name=="Divider": enemy.set_meta("warehouse_divider",true)
	if not wave.get("ConditionalBehaviors",[]).is_empty():
		enemy.set_meta("despawn_at",GameManager.game_time+float(wave["ConditionalBehaviors"][0]["Condition"].get("duration",35)))
	return true
