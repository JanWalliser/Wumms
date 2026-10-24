extends Node

var failed := 0
var marks: Dictionary = {}
var host_profile := ""
var guest_profile := ""
var test_name := ""
var port := 28473

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.sfx_volume = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lan-test-name="): test_name = arg.trim_prefix("--lan-test-name=")
		if arg.begins_with("--lan-test-port="): port = int(arg.trim_prefix("--lan-test-port="))
	if OS.get_cmdline_user_args().has("--lan-test-host"): run_host.call_deferred()
	else: run_client.call_deferred()

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value: failed += 1

func until(predicate: Callable, message: String, seconds: float = 12) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().create_timer(0.02).timeout
	check(false, "timeout: " + message)
	return false

@rpc("any_peer", "call_remote", "reliable")
func mark(key: String, value: Variant = true) -> void:
	marks[key] = value

func run_host() -> void:
	var lobby = load("res://scenes/ui/lobby.tscn").instantiate()
	get_tree().root.add_child(lobby)
	get_tree().current_scene = lobby
	host_profile = "lan_test_" + test_name.sha256_text().left(16)
	guest_profile = "lan_" + test_name.sha256_text().left(16)
	SaveManager.save_profile(SaveManager.create_default_profile(host_profile, "LAN host test"))
	ProfileManager.set_player_profile(0, host_profile)
	for i in range(1, 4): ProfileManager.player_slots[i]["active"] = false
	check(NetworkManager.host(port) == OK, "real ENet server starts")
	if not await until(func(): return NetworkManager.owners.size() == 1 and ProfileManager.player_slots[1]["is_ready"], "join and ready"):
		finish()
		return
	check(ProfileManager.player_slots[1]["character_id"] == "seraföhn", "guest changes own character")
	check(ProfileManager.player_slots[1]["device_id"] <= -100, "remote device independent from host keyboard")
	await screenshot("lan-host-lobby")
	NetworkManager.start_run("map_warehouse", "story")
	if not await until(func(): return is_instance_valid(GameManager.current_map) and GameManager.current_state == GameManager.GameState.GAMEPLAY, "start barrier"):
		finish()
		return
	GameManager.practice_mode = true
	var map = GameManager.current_map
	map.spawner.set_physics_process(false)
	var players := GameManager.active_player_nodes
	for player in players: player.set_meta("god_mode", true)
	var guest: PlayerController = players[1]
	var original := guest.global_position
	mark.rpc("move")
	await until(func(): return guest.global_position.distance_to(original) > 30, "guest movement reaches host")
	check(guest.global_position.distance_to(original) > 30, "guest moves on authoritative host")
	mark.rpc("stop")
	await get_tree().create_timer(0.3).timeout
	var enemy = map.spawner._spawn_single_enemy("heavy_tank", map.get_safe_position(guest.global_position + Vector2(150, 0), 30))
	enemy.set_physics_process(false)
	RuntimeEffect.spawn(map, enemy, guest.global_position, {"visual":"enemy_slam", "radius":45, "warmup":3.0, "duration":5.0, "damage":0})
	var snapshot: Dictionary = NetworkManager._replication.capture(map)
	check(not var_to_bytes(snapshot).is_empty(), "snapshot serializes without objects")
	mark.rpc("replication")
	await until(func(): return marks.has("replicated"), "client entities and frozen simulation")
	GameManager.add_team_exp(GameManager.required_team_exp + 1)
	await until(func(): return not GameManager.current_selection.is_empty(), "level selection")
	var modal = NetworkManager._modal()
	var event: int = modal.event_id
	var before: int = modal.rerolls.get(1, 3)
	mark.rpc("select")
	await until(func(): return int(modal.rerolls.get(1, 3)) == before - 1, "remote reroll")
	check(GameManager.pending_level_up_players.has(1), "reroll does not confirm selection")
	mark.rpc("confirm")
	await until(func(): return not GameManager.pending_level_up_players.has(1), "remote choice")
	check(GameManager.pending_level_up_players.has(0), "guest cannot complete host selection")
	modal._confirm_selection(0, 0, event)
	await until(func(): return GameManager.current_state == GameManager.GameState.GAMEPLAY, "all choices resume")
	# Downed players remain in the run, but stop blocking or attracting enemies.
	guest.global_position = map.get_safe_position(players[0].global_position + Vector2(250, 0), 30)
	guest._enter_downed_state()
	check(not GameManager.run_finalized and guest.is_downed, "single death does not end coop run")
	check(guest.collision_layer == 0 and guest.velocity == Vector2.ZERO, "corpse neither moves nor blocks enemies")
	check(enemy._find_closest_player() == players[0], "enemy selects living host instead of corpse")
	guest.auto_respawn_timer = 0.7
	mark.rpc("downed")
	await until(func(): return marks.has("downed_seen"), "client sees downed player and timer")
	await until(func(): return not guest.is_downed, "automatic respawn")
	check(guest.current_health == guest.get_stat("max_health") * 0.5 and guest.is_invulnerable_active, "respawn has half health and protection")
	check(guest.collision_layer == 1 and guest.collision_mask == 49, "respawn restores body collisions")
	# The original timers advance with active play, never while paused.
	guest._enter_downed_state()
	check(guest.auto_respawn_duration == 24, "second death increases respawn timer by nine seconds")
	GameManager.set_state(GameManager.GameState.PAUSED)
	var timer_before: float = guest.auto_respawn_timer
	await get_tree().create_timer(0.25).timeout
	check(guest.auto_respawn_timer == timer_before, "pause freezes death timers")
	GameManager.set_state(GameManager.GameState.GAMEPLAY)
	guest.global_position = players[0].global_position
	guest._process_downed_state(9.9)
	check(guest.is_downed, "nearby teammate cannot revive before ten seconds")
	guest._process_downed_state(0.11)
	check(not guest.is_downed, "nearby living teammate revives after ten seconds")
	for death in range(3, 8):
		guest._enter_downed_state()
		check(guest.auto_respawn_duration == minf(60, 15 + (death - 1) * 9), "respawn escalation and cap, death %d" % death)
		guest.revive_player()
	mark.rpc("revived")
	await until(func(): return marks.has("revived_seen"), "client sees revival")
	GameManager.spawn_map_boss()
	mark.rpc("boss")
	await until(func(): return marks.has("boss_seen"), "client boss replication")
	# A real team wipe ends the run once, also when a respawn timer is almost done.
	guest._enter_downed_state()
	guest.auto_respawn_timer = 0.001
	players[0]._enter_downed_state()
	guest._process_downed_state(1)
	check(guest.is_downed, "no automatic revive after last living teammate dies")
	await until(func(): return GameManager.run_finalized, "team wipe finalization")
	check(GameManager.current_state == GameManager.GameState.RUN_DEFEAT, "only full team wipe ends in defeat")
	mark.rpc("wipe")
	await until(func(): return marks.has("wipe_seen"), "client defeat screen")
	mark.rpc("disconnect")
	await until(func(): return NetworkManager.owners.is_empty(), "guest disconnect")
	check(not ProfileManager.player_slots[1]["active"], "disconnect releases remote slot")
	finish()

func run_client() -> void:
	var lobby = load("res://scenes/ui/lobby.tscn").instantiate()
	get_tree().root.add_child(lobby)
	get_tree().current_scene = lobby
	NetworkManager.player_name = test_name
	check(NetworkManager.join("not-an-ip", port) == ERR_INVALID_PARAMETER, "invalid IP rejected")
	NetworkManager._fingerprint = "intentionally-incompatible-test-version"
	NetworkManager.join("127.0.0.1", port)
	await until(func(): return not NetworkManager.enabled, "version rejection")
	check(NetworkManager.status.contains("Spielversionen"), "incompatible build rejected before slot assignment")
	NetworkManager._fingerprint = ""
	check(NetworkManager.join("127.0.0.1", port) == OK, "client starts")
	if not await until(func(): return NetworkManager.local_slot == 1, "slot assignment"):
		finish()
		return
	await until(func(): return ProfileManager.player_slots[1]["active"], "lobby snapshot")
	check(not NetworkManager.owns_slot(0) and NetworkManager.owns_slot(1), "client owns only assigned slot")
	NetworkManager.request_slot("character_id", "seraföhn")
	NetworkManager.request_slot("is_ready", true)
	await until(func(): return marks.has("move"), "host started")
	Input.action_press("move_right")
	await until(func(): return marks.has("stop"), "host observed input")
	Input.action_release("move_right")
	await until(func(): return marks.has("replication") and get_tree().get_nodes_in_group("enemies").any(func(node): return node is Enemy), "replicated enemy")
	check(not GameManager.current_map.is_physics_processing(), "client map simulation disabled")
	check(not GameManager.current_map.spawner.is_physics_processing(), "client spawner disabled")
	check(GameManager.active_player_nodes.size() == 2, "client has both players")
	for player in GameManager.active_player_nodes: check(not player.is_physics_processing(), "client player cannot simulate damage or respawn")
	check(not get_tree().get_nodes_in_group("runtime_effects").is_empty(), "host attack telegraph replicated")
	await screenshot("lan-client-game")
	mark.rpc_id(1, "replicated")
	await until(func(): return marks.has("select") and NetworkManager._client_event >= 0, "selection replica")
	var modal = NetworkManager._modal()
	await screenshot("lan-client-selection")
	modal._reroll(1, modal.event_id)
	await until(func(): return modal.rerolls.get(1, 3) == 2, "reroll update")
	await until(func(): return marks.has("confirm"), "confirm requested")
	modal._confirm_selection(1, 0, modal.event_id)
	await until(func(): return marks.has("downed") and GameManager.active_player_nodes[1].is_downed, "downed replica")
	check(GameManager.active_player_nodes[1].auto_respawn_timer > 0, "replicated respawn countdown")
	mark.rpc_id(1, "downed_seen")
	await until(func(): return marks.has("revived") and not GameManager.active_player_nodes[1].is_downed, "revived replica")
	mark.rpc_id(1, "revived_seen")
	await until(func(): return marks.has("boss") and is_instance_valid(GameManager.current_boss_node), "boss replica")
	check(not GameManager.current_boss_node.is_physics_processing(), "boss AI runs only on host")
	mark.rpc_id(1, "boss_seen")
	await until(func(): return marks.has("wipe") and GameManager.current_state == GameManager.GameState.RUN_DEFEAT, "defeat replica")
	check(GameManager.run_finalized, "client shares host run end")
	mark.rpc_id(1, "wipe_seen")
	await until(func(): return marks.has("disconnect"), "disconnect requested")
	finish()

func screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/repair/" + filename + ".png")

func finish() -> void:
	NetworkManager.leave()
	GameManager.run_finalized = true
	GameManager.current_selection.clear()
	GameManager.set_state(GameManager.GameState.MENU)
	GameManager.active_player_nodes.clear()
	GameManager.current_boss_node = null
	GameManager.current_map = null
	if get_tree().current_scene: get_tree().current_scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	for id in [host_profile, guest_profile]:
		if not id.is_empty(): SaveManager.delete_profile(id)
	print("LAN PEER ", "HOST" if not host_profile.is_empty() else "CLIENT", ": ", failed, " failed")
	get_tree().quit(0 if failed == 0 else 1)
