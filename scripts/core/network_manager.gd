extends Node

signal session_changed
signal status_changed(message: String)

const PORT := 24872
const PROTOCOL := 1
const Replication = preload("res://scripts/core/lan_replication.gd")
var enabled := false
var hosting := false
var in_run := false
var applying := false
var local_slot := 0
var status := "Lokales Spiel an diesem PC"
var owners: Dictionary = {} # peer id -> slot; slot ownership is host assigned
var remote_inputs: Dictionary = {}
var remote_profiles: Dictionary = {}
var player_name := OS.get_environment("COMPUTERNAME").left(32)
var _saved_slots: Array[Dictionary] = []
var _waiting: Dictionary = {}
var _joining := false
var _connect_deadline := 0
var _clock := 0.0
var _serial := 0
var _last_serial := -1
var _selection_revision := ""
var _client_event := -1
var _client_revision := 0
var _host_revision := 0
var _replication = Replication.new()
var _fingerprint := ""
var _incoming: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave("Verbindung fehlgeschlagen. IP, Port und Firewall prüfen."))
	multiplayer.server_disconnected.connect(func(): leave("Verbindung zum Host verloren.", true))
	multiplayer.peer_disconnected.connect(_peer_left)
	ProfileManager.player_slots_changed.connect(func():
		if enabled and hosting and not in_run: broadcast_lobby())

func is_client() -> bool:
	return enabled and not hosting

func owns_slot(slot: int) -> bool:
	if not enabled: return true
	if is_client(): return slot == local_slot
	return not owners.values().has(slot)

func set_status(message: String) -> void:
	status = message
	status_changed.emit(message)

func host(port: int = PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 3, 3)
	if error != OK:
		set_status("Hosten fehlgeschlagen: Port %d ist möglicherweise belegt." % port)
		return error
	_saved_slots = ProfileManager.player_slots.duplicate(true)
	enabled = true
	hosting = true
	multiplayer.multiplayer_peer = peer
	set_status("LAN-Host · IP: %s · UDP-Port %d" % [local_addresses(), port])
	session_changed.emit()
	return OK

func join(address: String, port: int = PORT) -> Error:
	address = address.strip_edges()
	if not address.is_valid_ip_address() or port < 1 or port > 65535:
		set_status("Bitte eine gültige IP-Adresse und einen Port von 1 bis 65535 eingeben.")
		return ERR_INVALID_PARAMETER
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, 3)
	if error != OK:
		set_status("Verbindung konnte nicht gestartet werden.")
		return error
	_saved_slots = ProfileManager.player_slots.duplicate(true)
	enabled = true
	hosting = false
	local_slot = -1
	_joining = true
	_connect_deadline = Time.get_ticks_msec() + 10000
	multiplayer.multiplayer_peer = peer
	set_status("Verbinde mit %s:%d …" % [address, port])
	session_changed.emit()
	return OK

func leave(message: String = "Lokales Spiel an diesem PC", show_lobby: bool = false) -> void:
	var was_client := is_client()
	var was_run := in_run
	if enabled and hosting: _closed.rpc(message if message != "Lokales Spiel an diesem PC" else "Der Host hat die Sitzung beendet.")
	if enabled: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	enabled = false
	hosting = false
	in_run = false
	_joining = false
	local_slot = 0
	owners.clear()
	remote_inputs.clear()
	remote_profiles.clear()
	_waiting.clear()
	_replication.replicas.clear()
	_last_serial = -1
	_incoming.clear()
	_selection_revision = ""
	_client_event = -1
	if not _saved_slots.is_empty():
		ProfileManager.player_slots.assign(_saved_slots)
		_saved_slots.clear()
	if was_client:
		GameManager.run_finalized = true
		GameManager.current_selection.clear()
		GameManager.active_player_nodes.clear()
		GameManager.current_boss_node = null
		GameManager.current_map = null
		GameManager.set_state(GameManager.GameState.MENU)
	set_status(message)
	session_changed.emit()
	if show_lobby and was_run: get_tree().change_scene_to_file.call_deferred("res://scenes/ui/lobby.tscn")

@rpc("authority", "call_remote", "reliable")
func _closed(message: String) -> void:
	leave.call_deferred(message, true)

func local_addresses() -> String:
	var addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if ":" not in address and not address.begins_with("127.") and not address.begins_with("169.254."): addresses.append(address)
	return ", ".join(addresses) if not addresses.is_empty() else "keine LAN-IP gefunden"

func fingerprint() -> String:
	if _fingerprint.is_empty():
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		for root in ["res://scripts", "res://scenes", "res://assets/balance"]: _hash_directory(root, hash)
		_fingerprint = hash.finish().hex_encode()
	return _fingerprint

func _hash_directory(path: String, hash: HashingContext) -> void:
	var files := DirAccess.get_files_at(path)
	files.sort()
	for file in files:
		if file.get_extension() not in ["gd", "tscn", "json"]: continue
		hash.update((path + "/" + file).to_utf8_buffer())
		hash.update(FileAccess.get_file_as_bytes(path + "/" + file))
	var directories := DirAccess.get_directories_at(path)
	directories.sort()
	for directory in directories: _hash_directory(path + "/" + directory, hash)

func _connected() -> void:
	_hello.rpc_id(1, PROTOCOL, fingerprint(), player_name)

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, content: String, player_name: String) -> void:
	if not hosting: return
	var peer := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL or content != fingerprint():
		_rejected.rpc_id(peer, "Unterschiedliche Spielversionen. Auf beiden PCs denselben Build verwenden.")
		return
	if in_run:
		_rejected.rpc_id(peer, "Die Runde läuft bereits. Beitritt ist nur in der Lobby möglich.")
		return
	if owners.has(peer): return
	var slot := -1
	for i in range(1, 4):
		if not ProfileManager.player_slots[i]["active"]:
			slot = i
			break
	if slot < 0:
		_rejected.rpc_id(peer, "Die Lobby ist voll (maximal vier Spieler).")
		return
	player_name = player_name.strip_edges().left(32)
	if player_name.is_empty(): player_name = "LAN-Gast"
	var profile_id := "lan_" + player_name.sha256_text().left(16)
	if SaveManager.load_profile(profile_id).is_empty():
		if not SaveManager.save_profile(SaveManager.create_default_profile(profile_id, player_name)):
			_rejected.rpc_id(peer, "Gastprofil konnte auf dem Host nicht gespeichert werden.")
			return
	owners[peer] = slot
	var data: Dictionary = ProfileManager.player_slots[slot]
	data["active"] = true
	data["device_id"] = -100 - slot
	data["profile_id"] = profile_id
	data["profile_data"] = SaveManager.load_profile(profile_id)
	data["character_id"] = "jankz"
	data["is_ready"] = false
	_assigned.rpc_id(peer, slot)
	ProfileManager.player_slots_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	leave.call_deferred(reason)

@rpc("authority", "call_remote", "reliable")
func _assigned(slot: int) -> void:
	local_slot = slot
	_joining = false
	set_status("Verbunden · Du bist Spieler %d · Fortschritt wird beim Host gespeichert." % (slot + 1))

func broadcast_lobby() -> void:
	if not hosting: return
	var slots := ProfileManager.player_slots.duplicate(true)
	for slot in slots:
		if slot["active"]: slot["profile_data"] = SaveManager.load_profile(slot["profile_id"])
	_lobby.rpc(slots)
	session_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _lobby(slots: Array) -> void:
	if not is_client() or in_run: return
	ProfileManager.player_slots.assign(slots)
	for slot in slots:
		if slot["active"]: remote_profiles[slot["profile_id"]] = slot["profile_data"]
	ProfileManager.player_slots_changed.emit()
	session_changed.emit()

func request_slot(field: String, value: Variant) -> void:
	if is_client() and local_slot >= 0: _slot_change.rpc_id(1, field, value)

@rpc("any_peer", "call_remote", "reliable")
func _slot_change(field: String, value: Variant) -> void:
	if not hosting or in_run: return
	var slot: int = owners.get(multiplayer.get_remote_sender_id(), -1)
	if slot < 0: return
	var data: Dictionary = ProfileManager.player_slots[slot]
	if field == "is_ready" and value is bool: data[field] = value
	elif field == "character_id" and value is String and data["profile_data"].get("unlocked_characters", []).has(value):
		data[field] = value
		data["is_ready"] = false
	else: return
	ProfileManager.player_slots_changed.emit()

func start_run(map_id: String, difficulty: String) -> void:
	if not hosting or in_run or not ProfileManager.are_all_active_slots_ready(): return
	in_run = true
	_waiting.clear()
	for peer in owners: _waiting[peer] = Time.get_ticks_msec() + 20000
	_serial = 0
	_selection_revision = ""
	_begin.rpc(map_id, difficulty)
	GameManager.start_new_run(map_id, difficulty)
	GameManager.set_state(GameManager.GameState.PAUSED)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

@rpc("authority", "call_remote", "reliable")
func _begin(map_id: String, difficulty: String) -> void:
	if not is_client() or local_slot < 0: return
	in_run = true
	_last_serial = -1
	_client_event = -1
	applying = true
	GameManager.start_new_run(map_id, difficulty)
	GameManager.set_state(GameManager.GameState.PAUSED)
	applying = false
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

func world_ready(map: Node) -> void:
	if not enabled: return
	if is_client():
		_replication.prepare_client(map)
		_loaded.rpc_id(1)
	elif _waiting.is_empty(): GameManager.set_state(GameManager.GameState.GAMEPLAY)

@rpc("any_peer", "call_remote", "reliable")
func _loaded() -> void:
	if not hosting or not in_run: return
	_waiting.erase(multiplayer.get_remote_sender_id())
	if _waiting.is_empty(): GameManager.set_state(GameManager.GameState.GAMEPLAY)

func _process(delta: float) -> void:
	if _joining and Time.get_ticks_msec() > _connect_deadline:
		leave("Zeitüberschreitung. Host-IP, UDP-Port 24872 und Windows-Firewall prüfen.")
	if not enabled or not in_run or not is_instance_valid(GameManager.current_map): return
	if is_client(): _replication.interpolate(delta)
	if hosting:
		for peer in _waiting.keys():
			if Time.get_ticks_msec() > int(_waiting[peer]):
				multiplayer.multiplayer_peer.disconnect_peer(peer)
				_peer_left(peer)
	_clock += delta
	if _clock < 0.05: return
	_clock = 0
	if hosting:
		if not _waiting.is_empty(): return
		_serial += 1
		var snapshot: Dictionary = _replication.capture(GameManager.current_map)
		snapshot["serial"] = _serial
		var raw := var_to_bytes(snapshot)
		var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		var count := ceili(compressed.size() / 1000.0)
		for part in count:
			_snapshot_part.rpc(_serial, part, count, raw.size(), compressed.slice(part * 1000, (part + 1) * 1000))
		_sync_selection()
	else:
		if local_slot < 0: return
		var focused := DisplayServer.get_name() == "headless" or get_window().has_focus()
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down") if focused else Vector2.ZERO
		var mouse := InputManager.get_mouse_world_position(get_viewport())
		_input_state.rpc_id(1, movement, mouse)

@rpc("authority", "call_remote", "unreliable", 1)
func _snapshot_part(serial: int, part: int, count: int, raw_size: int, data: PackedByteArray) -> void:
	if not is_client() or not in_run or not is_instance_valid(GameManager.current_map): return
	if serial <= _last_serial or part < 0 or count < 1 or count > 4096 or part >= count or data.size() > 1000 or raw_size < 1 or raw_size > 8 * 1024 * 1024: return
	# Each UDP packet stays below the MTU. Incomplete old snapshots are discarded;
	# a lost packet never blocks newer state or the reliable lobby/choice channel.
	if not _incoming.has(serial): _incoming[serial] = {"parts": {}, "size": raw_size, "count": count}
	var frame: Dictionary = _incoming[serial]
	if frame["size"] != raw_size or frame["count"] != count: return
	frame["parts"][part] = data
	for old in _incoming.keys():
		if old < serial - 2: _incoming.erase(old)
	if frame["parts"].size() != count: return
	var compressed := PackedByteArray()
	for index in count: compressed.append_array(frame["parts"][index])
	_incoming.erase(serial)
	var raw := compressed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.is_empty(): return
	var snapshot = bytes_to_var(raw)
	if not snapshot is Dictionary or int(snapshot.get("serial", -1)) <= _last_serial: return
	_last_serial = snapshot["serial"]
	applying = true
	_replication.apply(GameManager.current_map, snapshot)
	applying = false

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _input_state(move: Vector2, mouse: Vector2) -> void:
	if not hosting or not in_run: return
	var slot: int = owners.get(multiplayer.get_remote_sender_id(), -1)
	if slot < 0 or not move.is_finite() or not mouse.is_finite(): return
	remote_inputs[slot] = {"move": move.limit_length(), "mouse": mouse, "time": Time.get_ticks_msec()}

func remote_movement(slot: int) -> Vector2:
	var data: Dictionary = remote_inputs.get(slot, {})
	if Time.get_ticks_msec() - int(data.get("time", -1000)) > 300: return Vector2.ZERO
	return preload("res://scripts/maps/world_projection.gd").world_direction(data.get("move", Vector2.ZERO))

func remote_aim(slot: int, at: Vector2) -> Vector2:
	return (remote_inputs.get(slot, {}).get("mouse", at + Vector2.RIGHT) - at).normalized()

func _input(event: InputEvent) -> void:
	if not is_client() or not in_run or local_slot < 0 or event.is_echo(): return
	if event.is_action_pressed("pause_game"):
		_pause.rpc_id(1)
	elif GameManager.current_state == GameManager.GameState.GAMEPLAY:
		if event.is_action_pressed("ability_e"): _action.rpc_id(1, "e")
		if event.is_action_pressed("ability_r"): _action.rpc_id(1, "r")
		if event.is_action_pressed("toggle_auto_aim"): _action.rpc_id(1, "aim")

@rpc("any_peer", "call_remote", "reliable")
func _action(action: String) -> void:
	if not hosting or GameManager.current_state != GameManager.GameState.GAMEPLAY: return
	var slot: int = owners.get(multiplayer.get_remote_sender_id(), -1)
	if slot < 0: return
	if action in ["e", "r"]: InputManager.ability_edges[str(slot) + action] = Engine.get_physics_frames()
	elif action == "aim": InputManager.toggle_auto_aim(slot)

func request_pause() -> void:
	if is_client(): _pause.rpc_id(1)

func relay_sound(event: String, pitch: float) -> void:
	if hosting and in_run: _sound.rpc(event, pitch)

@rpc("authority", "call_remote", "unreliable", 1)
func _sound(event: String, pitch: float) -> void:
	if is_client() and in_run: AudioManager.play_sfx(event, pitch)

@rpc("any_peer", "call_remote", "reliable")
func _pause() -> void:
	if not hosting or not owners.has(multiplayer.get_remote_sender_id()): return
	if GameManager.current_state == GameManager.GameState.GAMEPLAY: GameManager.set_state(GameManager.GameState.PAUSED)
	elif GameManager.current_state == GameManager.GameState.PAUSED and _waiting.is_empty(): GameManager.set_state(GameManager.GameState.GAMEPLAY)

func _modal() -> Node:
	var world := GameManager.current_map.get_parent().get_parent() if is_instance_valid(GameManager.current_map) else null
	return world.get_node_or_null("CanvasLayer/LevelUpModal") if world else null

func _sync_selection() -> void:
	var modal := _modal()
	if not modal: return
	var data := {"event": GameManager.current_selection, "choices": modal.player_choices_data,
		"rerolls": modal.rerolls}
	var signature := var_to_bytes(data).hex_encode()
	if signature == _selection_revision: return
	_selection_revision = signature
	_host_revision += 1
	data["revision"] = _host_revision
	_selection.rpc(data)

@rpc("authority", "call_remote", "reliable")
func _selection(data: Dictionary) -> void:
	if not is_client() or not in_run: return
	var modal := _modal()
	if not modal: return
	_client_event = data["event"].get("id", -1)
	_client_revision = data["revision"]
	modal.show_network_selection(data)

func choose(slot: int, index: int, event: int, reroll: bool = false) -> void:
	if is_client() and slot == local_slot and event == _client_event:
		_choice.rpc_id(1, index, event, _client_revision, reroll)

@rpc("any_peer", "call_remote", "reliable")
func _choice(index: int, event: int, revision: int, reroll: bool) -> void:
	if not hosting or not in_run or revision != _host_revision: return
	var slot: int = owners.get(multiplayer.get_remote_sender_id(), -1)
	var modal := _modal()
	if slot < 0 or not modal or event != modal.event_id or not modal.player_choices_data.has(slot): return
	if reroll: modal._reroll(slot, event)
	elif index >= 0 and index < modal.player_choices_data[slot].size(): modal._confirm_selection(slot, index, event)
	_sync_selection()

func _peer_left(peer: int) -> void:
	if not hosting or not owners.has(peer): return
	var slot: int = owners[peer]
	owners.erase(peer)
	remote_inputs.erase(slot)
	_waiting.erase(peer)
	ProfileManager.player_slots[slot]["active"] = false
	if in_run:
		var modal := _modal()
		if modal and modal.player_choices_data.has(slot):
			modal.player_choices_data.erase(slot)
			if modal.player_panels.has(slot): modal.player_panels[slot].hide()
		GameManager.player_completed_level_up_selection(slot)
		for player in GameManager.active_player_nodes.duplicate():
			if player.player_slot_index == slot:
				GameManager.active_player_nodes.erase(player)
				player.queue_free()
		GameManager.players_ready.emit()
		GameManager.check_all_players_downed()
		if GameManager.current_selection.is_empty(): GameManager.set_state(GameManager.GameState.PAUSED)
		set_status("Spieler %d hat die Verbindung getrennt. Die Runde ist pausiert." % (slot + 1))
	else: ProfileManager.player_slots_changed.emit()
